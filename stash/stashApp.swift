import Cocoa

/// Pure NSApplication entry point — no SwiftUI scenes, no phantom windows.
/// The app runs entirely from AppDelegate (menu bar + overlay panels).
@main
enum StashMain {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)

        let delegate = AppDelegate()
        app.delegate = delegate

        app.run()
    }
}
