import Cocoa
import Carbon.HIToolbox

/// Registers a global hotkey (⌥Space) using Carbon RegisterEventHotKey.
/// This is the standard macOS approach used by apps like Alfred and Raycast.
/// Does NOT require Accessibility permissions.
final class HotkeyService: @unchecked Sendable {
    private var hotkeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    nonisolated(unsafe) static var callback: (() -> Void)?

    init(callback: @escaping () -> Void) {
        HotkeyService.callback = callback
        registerHotkey()
    }

    deinit {
        if let ref = hotkeyRef {
            UnregisterEventHotKey(ref)
        }
        if let ref = handlerRef {
            RemoveEventHandler(ref)
        }
    }

    private func registerHotkey() {
        // 1. Install a Carbon event handler for hotkey events
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        var handler: EventHandlerRef?
        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { (_: EventHandlerCallRef?, _: EventRef?, _: UnsafeMutableRawPointer?) -> OSStatus in
                HotkeyService.callback?()
                return noErr
            },
            1,
            &eventType,
            nil,
            &handler
        )
        self.handlerRef = handler

        if installStatus != noErr {
            print("[Stash] ⚠️ Failed to install Carbon event handler: \(installStatus)")
            return
        }

        // 2. Register ⌥Space as a global hotkey
        var hotKeyID = EventHotKeyID(
            signature: OSType(0x53544153), // "STAS"
            id: 1
        )

        var hotkey: EventHotKeyRef?
        let regStatus = RegisterEventHotKey(
            UInt32(kVK_Space),
            UInt32(optionKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotkey
        )
        self.hotkeyRef = hotkey

        if regStatus != noErr {
            print("[Stash] ⚠️ Failed to register hotkey: \(regStatus)")
        } else {
            print("[Stash] ✅ Global hotkey ⌥Space registered successfully")
        }
    }
}
