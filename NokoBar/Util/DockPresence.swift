import AppKit

/// NokoBar is a menu-bar-only app (LSUIElement). While at least one report window is open it
/// becomes a regular app, so it gets a Dock icon and shows up in Cmd+Tab.
@MainActor
enum DockPresence {
    private static var count = 0

    static func windowOpened() {
        count += 1
        if count == 1 {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    static func windowClosed() {
        count = max(0, count - 1)
        if count == 0 { NSApp.setActivationPolicy(.accessory) }
    }
}
