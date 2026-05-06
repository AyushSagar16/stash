import SwiftUI

@main
struct StashApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // No visible scene at launch. The overlay panel is created and
        // shown on demand by the hotkey monitor (see AppDelegate).
        Settings {
            EmptyView()
        }
    }
}
