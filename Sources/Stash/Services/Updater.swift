import AppKit
import Foundation
import OSLog

enum UpdateStage: Sendable {
    case downloading
    case mounting
    case installing
    case relaunching

    var userFacing: String {
        switch self {
        case .downloading: "Downloading update…"
        case .mounting:    "Verifying download…"
        case .installing:  "Installing…"
        case .relaunching: "Restarting Stash…"
        }
    }
}

enum UpdateError: Error, LocalizedError {
    case noDmgAsset
    case mountFailed(String)
    case appNotFoundInDMG
    case bundleParentNotWritable(String)
    case relauncherFailed(String)

    var errorDescription: String? {
        switch self {
        case .noDmgAsset:                       "Release has no DMG to download."
        case .mountFailed(let s):               "Couldn't mount the downloaded DMG: \(s)"
        case .appNotFoundInDMG:                 "Stash.app wasn't found inside the downloaded DMG."
        case .bundleParentNotWritable(let s):   "Stash needs write access to \(s) to install the update."
        case .relauncherFailed(let s):          "Couldn't start the install helper: \(s)"
        }
    }
}

/// Downloads, mounts, and installs the new release in-place, then relaunches.
///
/// The actual swap-and-relaunch happens in a detached shell script: this process
/// stages the new bundle, hands the script the running PID, and triggers
/// `NSApp.terminate`. The script waits for our exit, atomically renames the
/// running bundle aside, moves the staged copy into place (with rollback if
/// that fails), detaches the DMG, and `open`s the new bundle.
@MainActor
final class Updater {
    private let log = Logger(subsystem: "com.stash.app", category: "Updater")

    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 600  // DMGs are <5MB but be generous
        self.session = URLSession(configuration: config)
    }

    /// Run the full update flow. Calls `onStage` on the main actor as the flow
    /// progresses. On success, this never returns — the process terminates so
    /// the helper can swap bundles. Errors throw before termination.
    func install(_ release: ReleaseInfo, onStage: @MainActor @escaping (UpdateStage) -> Void) async throws {
        guard let asset = release.dmgAsset, let assetURL = URL(string: asset.browserDownloadUrl) else {
            throw UpdateError.noDmgAsset
        }

        let currentBundle = Bundle.main.bundleURL
        let parent = currentBundle.deletingLastPathComponent()
        guard FileManager.default.isWritableFile(atPath: parent.path) else {
            throw UpdateError.bundleParentNotWritable(parent.path)
        }

        // 1. Download.
        onStage(.downloading)
        log.info("downloading \(asset.name, privacy: .public) from \(assetURL.absoluteString, privacy: .public)")
        var request = URLRequest(url: assetURL)
        request.setValue("Stash-Updater", forHTTPHeaderField: "User-Agent")
        let (downloadedTemp, _) = try await session.download(for: request)

        let dmgPath = FileManager.default.temporaryDirectory
            .appending(path: "Stash-update-\(UUID().uuidString).dmg")
        try? FileManager.default.removeItem(at: dmgPath)
        try FileManager.default.moveItem(at: downloadedTemp, to: dmgPath)
        log.info("downloaded to \(dmgPath.path, privacy: .public)")

        // 2. Mount.
        onStage(.mounting)
        let mountPoint = try mountDmg(at: dmgPath)
        log.info("mounted at \(mountPoint, privacy: .public)")

        // 3. Locate Stash.app inside the mount and stage it next to the running bundle.
        onStage(.installing)
        let mountedApp = URL(fileURLWithPath: mountPoint).appending(path: "Stash.app")
        guard FileManager.default.fileExists(atPath: mountedApp.path) else {
            try? detachDmg(at: mountPoint)
            try? FileManager.default.removeItem(at: dmgPath)
            throw UpdateError.appNotFoundInDMG
        }

        let stagingPath = parent.appending(path: "Stash.app.update-\(UUID().uuidString.prefix(8))")
        try? FileManager.default.removeItem(at: stagingPath)
        do {
            try FileManager.default.copyItem(at: mountedApp, to: stagingPath)
        } catch {
            try? detachDmg(at: mountPoint)
            try? FileManager.default.removeItem(at: dmgPath)
            throw error
        }
        log.info("staged copy at \(stagingPath.path, privacy: .public)")

        // Strip quarantine so Gatekeeper doesn't block the relaunch.
        runDetached(
            "/usr/bin/xattr",
            arguments: ["-dr", "com.apple.quarantine", stagingPath.path]
        )

        // 4. Spawn the detached relauncher and quit.
        onStage(.relaunching)
        let pid = ProcessInfo.processInfo.processIdentifier
        let scriptPath = try writeRelauncher(
            currentBundle: currentBundle,
            stagingPath: stagingPath,
            mountPoint: mountPoint,
            dmgPath: dmgPath,
            pid: pid
        )
        try spawnDetached(scriptPath: scriptPath)
        log.info("relauncher spawned; terminating self")

        // Give the relauncher a moment to enter its wait loop, then quit.
        try? await Task.sleep(for: .milliseconds(300))
        NSApp.terminate(nil)
    }

    // MARK: - hdiutil

    private func mountDmg(at dmgPath: URL) throws -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        task.arguments = ["attach", "-nobrowse", "-readonly", "-plist", dmgPath.path]
        let stdout = Pipe()
        let stderr = Pipe()
        task.standardOutput = stdout
        task.standardError = stderr

        do {
            try task.run()
        } catch {
            throw UpdateError.mountFailed(error.localizedDescription)
        }
        task.waitUntilExit()

        let outData = stdout.fileHandleForReading.readDataToEndOfFile()
        guard task.terminationStatus == 0 else {
            let err = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            throw UpdateError.mountFailed("hdiutil exit \(task.terminationStatus): \(err)")
        }
        guard let plist = try? PropertyListSerialization.propertyList(from: outData, format: nil) as? [String: Any],
              let entities = plist["system-entities"] as? [[String: Any]] else {
            throw UpdateError.mountFailed("couldn't parse hdiutil plist")
        }
        for entity in entities {
            if let mp = entity["mount-point"] as? String, !mp.isEmpty {
                return mp
            }
        }
        throw UpdateError.mountFailed("no mount-point in hdiutil plist")
    }

    private func detachDmg(at mountPoint: String) throws {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        task.arguments = ["detach", mountPoint, "-force"]
        task.standardOutput = Pipe()
        task.standardError = Pipe()
        try task.run()
        task.waitUntilExit()
    }

    // MARK: - relauncher

    private func writeRelauncher(
        currentBundle: URL,
        stagingPath: URL,
        mountPoint: String,
        dmgPath: URL,
        pid: Int32
    ) throws -> URL {
        func sq(_ s: String) -> String {
            "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
        }

        let script = """
        #!/bin/sh
        set -u
        ORIG=\(sq(currentBundle.path))
        NEW=\(sq(stagingPath.path))
        MOUNT=\(sq(mountPoint))
        DMG=\(sq(dmgPath.path))
        PID=\(pid)

        # Wait up to 15s for the original Stash process to exit.
        i=0
        while [ "$i" -lt 30 ]; do
          if ! kill -0 "$PID" 2>/dev/null; then break; fi
          sleep 0.5
          i=$((i + 1))
        done
        kill -0 "$PID" 2>/dev/null && kill -9 "$PID" 2>/dev/null

        # Atomic-ish swap with rollback.
        rm -rf "$ORIG.old" 2>/dev/null
        if [ -e "$ORIG" ] && ! mv "$ORIG" "$ORIG.old"; then
          hdiutil detach "$MOUNT" -force >/dev/null 2>&1 || true
          rm -f "$DMG"
          exit 1
        fi
        if mv "$NEW" "$ORIG"; then
          rm -rf "$ORIG.old"
        else
          mv "$ORIG.old" "$ORIG" 2>/dev/null
          hdiutil detach "$MOUNT" -force >/dev/null 2>&1 || true
          rm -f "$DMG"
          exit 1
        fi

        # Cleanup mount + DMG.
        hdiutil detach "$MOUNT" -force >/dev/null 2>&1 || true
        rm -f "$DMG"

        # Relaunch.
        open "$ORIG"

        # Self-cleanup.
        rm -f "$0"
        """

        let scriptPath = FileManager.default.temporaryDirectory
            .appending(path: "stash-update-relauncher-\(UUID().uuidString).sh")
        try script.write(to: scriptPath, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptPath.path)
        return scriptPath
    }

    /// Spawn the relauncher fully detached: trailing `&` returns control to sh
    /// immediately, so when our process terminates the script is independently
    /// re-parented to launchd and continues running.
    private func spawnDetached(scriptPath: URL) throws {
        let cmd = "\(shellQuote(scriptPath.path)) </dev/null >/dev/null 2>&1 &"
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", cmd]
        task.standardOutput = Pipe()
        task.standardError = Pipe()
        do {
            try task.run()
        } catch {
            throw UpdateError.relauncherFailed(error.localizedDescription)
        }
        task.waitUntilExit()  // sh returns immediately because of trailing `&`
    }

    private func runDetached(_ executable: String, arguments: [String]) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: executable)
        task.arguments = arguments
        task.standardOutput = Pipe()
        task.standardError = Pipe()
        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            log.error("\(executable, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func shellQuote(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
