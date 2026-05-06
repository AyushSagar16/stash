import AppKit
import Foundation
import OSLog

struct ReleaseInfo: Decodable, Sendable {
    let tagName: String
    let name: String?
    let body: String?
    let htmlUrl: String
    let prerelease: Bool
    let assets: [Asset]

    struct Asset: Decodable, Sendable {
        let name: String
        let browserDownloadUrl: String
        let contentType: String
        let size: Int

        enum CodingKeys: String, CodingKey {
            case name, size
            case browserDownloadUrl = "browser_download_url"
            case contentType = "content_type"
        }
    }

    enum CodingKeys: String, CodingKey {
        case name, body, prerelease, assets
        case tagName = "tag_name"
        case htmlUrl = "html_url"
    }

    /// Tag with any leading `v` stripped — the form we compare against and store.
    var normalizedVersion: String {
        tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
    }

    /// First asset that looks like a macOS DMG — by content type or `.dmg` extension.
    var dmgAsset: Asset? {
        assets.first {
            $0.contentType == "application/x-apple-diskimage" || $0.name.lowercased().hasSuffix(".dmg")
        }
    }
}

@MainActor
final class UpdateChecker {
    private let log = Logger(subsystem: "com.stash.app", category: "UpdateCheck")

    /// `https://api.github.com/repos/<owner>/<repo>/releases/latest`
    private let releasesURL = URL(string: "https://api.github.com/repos/AyushSagar16/stash/releases/latest")!

    /// 6h matches HistoryPruner's cadence. Cheap one HTTPS call.
    private let checkInterval: TimeInterval = 6 * 3600

    /// Don't re-fetch if the last successful check was within this window.
    /// Survives Timer drift across sleep/wake and makes manual triggers idempotent.
    private let networkCooldown: TimeInterval = 6 * 3600

    private let session: URLSession
    private var timer: Timer?

    /// Last detected newer-than-local non-prerelease release, if any. Set by
    /// `check()`, consumed by `requestPromptIfAvailable()`.
    private(set) var pendingRelease: ReleaseInfo?

    /// Invoked on the main actor whenever the prompt should be shown — i.e. when
    /// `requestPromptIfAvailable()` is called and there's a non-skipped pending
    /// release. AppDelegate owns the actual prompt UI (NSAlert).
    var onUpdateAvailable: ((ReleaseInfo) -> Void)?

    private enum DefaultsKey {
        static let lastCheckAt = "Stash.UpdateCheck.lastCheckAt"
        static let skippedVersion = "Stash.UpdateCheck.skippedVersion"
    }

    init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)
    }

    /// Run an initial check 5s after launch, then every 6 hours.
    /// The 5s delay keeps the first hotkey-summon snappy.
    func start() {
        timer?.invalidate()

        Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            await self?.check()
        }

        timer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.check()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// Fetch the latest release and, if it's a newer non-prerelease, cache it
    /// in `pendingRelease`. Does NOT fire the prompt — that happens in
    /// `requestPromptIfAvailable()`, called on each overlay show.
    /// Failures are logged and swallowed.
    func check(force: Bool = false) async {
        let defaults = UserDefaults.standard

        if !force,
           let last = defaults.object(forKey: DefaultsKey.lastCheckAt) as? Date,
           Date().timeIntervalSince(last) < networkCooldown {
            log.info("last check < \(Int(self.networkCooldown / 3600), privacy: .public)h ago, skipping")
            return
        }

        guard let release = await fetchLatest() else { return }
        defaults.set(Date(), forKey: DefaultsKey.lastCheckAt)

        if release.prerelease {
            log.info("latest is prerelease (\(release.tagName, privacy: .public)) — ignoring")
            pendingRelease = nil
            return
        }

        let local = Self.localVersion()
        guard Self.isNewer(release.normalizedVersion, than: local) else {
            log.info("up to date (local=\(local, privacy: .public), latest=\(release.tagName, privacy: .public))")
            pendingRelease = nil
            return
        }

        log.info("update available: \(release.tagName, privacy: .public) (local \(local, privacy: .public))")
        pendingRelease = release
    }

    /// Re-fire the prompt if we have a cached newer release that the user hasn't
    /// chosen to skip. Called on each overlay show so the prompt nags reliably.
    func requestPromptIfAvailable() {
        guard let release = pendingRelease else { return }
        let skipped = UserDefaults.standard.string(forKey: DefaultsKey.skippedVersion)
        if skipped == release.normalizedVersion {
            log.info("\(release.tagName, privacy: .public) is on the skip list — not prompting")
            return
        }
        onUpdateAvailable?(release)
    }

    private func fetchLatest() async -> ReleaseInfo? {
        var request = URLRequest(url: releasesURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue(Self.userAgent(), forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                log.error("releases API status \(http.statusCode, privacy: .public)")
                return nil
            }
            return try JSONDecoder().decode(ReleaseInfo.self, from: data)
        } catch {
            log.error("releases fetch failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    // MARK: - helpers

    private static func localVersion() -> String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    private static func userAgent() -> String {
        "Stash/\(localVersion()) (com.ayushsagar.stash)"
    }

    /// Returns true iff `remote` is strictly higher semver than `local`.
    /// Strips a leading `v`, splits on `.`, pads to 3 components, integer-compares.
    static func isNewer(_ remote: String, than local: String) -> Bool {
        func components(_ s: String) -> [Int] {
            let stripped = s.hasPrefix("v") ? String(s.dropFirst()) : s
            var parts = stripped.split(separator: ".").compactMap { Int($0) }
            while parts.count < 3 { parts.append(0) }
            return Array(parts.prefix(3))
        }
        let r = components(remote)
        let l = components(local)
        for (a, b) in zip(r, l) {
            if a != b { return a > b }
        }
        return false
    }
}
