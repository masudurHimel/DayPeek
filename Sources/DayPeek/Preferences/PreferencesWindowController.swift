import AppKit
import SwiftUI

/// Standard titled, closable preferences window. Created lazily, kept
/// alive across closes, and restores its last position via frame autosave.
final class PreferencesWindowController: NSObject {
    private var window: NSWindow?

    func show() {
        let window = ensureWindow()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func ensureWindow() -> NSWindow {
        if let window { return window }

        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 200),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        newWindow.title = "DayPeek Preferences"
        newWindow.isReleasedWhenClosed = false

        let hosting = NSHostingView(rootView: PreferencesView())
        newWindow.contentView = hosting
        newWindow.setContentSize(hosting.fittingSize)

        newWindow.center()
        newWindow.setFrameAutosaveName("DayPeekPreferences")

        window = newWindow
        return newWindow
    }
}
