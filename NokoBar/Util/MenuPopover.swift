import AppKit

/// Closes the menu bar popover (the MenuBarExtra `.window` panel). SwiftUI has no public
/// API for this before macOS 15, so find the panel by its class name.
@MainActor
enum MenuPopover {
    static func close() {
        for window in NSApp.windows where String(describing: type(of: window)).contains("MenuBarExtraWindow") {
            window.close()
        }
    }
}
