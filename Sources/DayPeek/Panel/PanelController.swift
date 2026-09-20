import AppKit
import SwiftUI

/// Drives the card's pop-in/out animation. The PanelController flips
/// `isPresented` right after ordering the window in (and before ordering it
/// out), so the card grows down from the menu bar and retracts back up.
final class PanelState: ObservableObject {
    @Published var isPresented = false
    /// Bumped once the panel is fully hidden so the list scrolls back to the
    /// top off-screen and the next open starts from the top.
    @Published var scrollResetToken = 0
    /// Id of the reminder whose title is being edited inline, if any. Lives
    /// here so Esc can cancel the edit instead of closing the panel.
    @Published var editingID: String?
}

/// Shows, hides, and positions the floating panel, reloads reminders every
/// time it opens, persists its size across launches, and closes it when the
/// user clicks elsewhere (unless the panel is pinned).
@MainActor
final class PanelController: NSObject, NSWindowDelegate {
    private var panel: PeekPanel?
    private let store: ReminderStore
    private let state = PanelState()
    private var lastAutoClose: TimeInterval = 0
    private var isClosing = false

    init(store: ReminderStore) {
        self.store = store
        super.init()
    }

    private var isPinned: Bool {
        UserDefaults.standard.bool(forKey: SettingsKey.pinPanel)
    }

    var isVisible: Bool { panel?.isVisible ?? false }

    func toggle(relativeTo statusItem: NSStatusItem) {
        if isVisible && !isClosing {
            hide()
        } else {
            // The click that lands on the status item first closes the panel
            // via windowDidResignKey; without this guard, "click icon to
            // dismiss" would instantly reopen it.
            if ProcessInfo.processInfo.systemUptime - lastAutoClose < 0.25 { return }
            show(relativeTo: statusItem)
        }
    }

    /// Duration of the SwiftUI pop/retract spring (see PanelRootView).
    private let animationDuration: TimeInterval = 0.32

    func show(relativeTo statusItem: NSStatusItem) {
        let panel = ensurePanel()
        isClosing = false
        position(panel, relativeTo: statusItem)

        // The window shadow is re-rendered on every frame while the card
        // scales, which is what made the pop feel choppy. Drop it for the
        // animation and put it back once the card has settled.
        panel.hasShadow = false
        panel.makeKeyAndOrderFront(nil)
        // Flip on the next runloop pass so the card's collapsed state is on
        // screen first and the change animates.
        DispatchQueue.main.async { [weak self] in
            self?.state.isPresented = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration + 0.05) { [weak self] in
            guard let self, !self.isClosing, panel.isVisible else { return }
            panel.hasShadow = true
            panel.invalidateShadow()
            // Refresh only after the animation, so a data change can't
            // re-layout the rows mid-spring. EKEventStoreChanged keeps the
            // list current while it stays open.
            Task { await self.store.reload() }
        }
    }

    func hide() {
        guard let panel, panel.isVisible, !isClosing else { return }
        isClosing = true
        panel.hasShadow = false
        state.isPresented = false
        // Order the window out only after the retract animation has played.
        DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration - 0.04) { [weak self] in
            guard let self, self.isClosing else { return }
            self.isClosing = false
            panel.orderOut(nil)
            self.state.scrollResetToken += 1
        }
    }

    func hideUnlessPinned() {
        if isVisible && !isPinned { hide() }
    }

    private func ensurePanel() -> PeekPanel {
        if let panel { return panel }

        let defaults = UserDefaults.standard
        var width = defaults.double(forKey: SettingsKey.panelWidth)
        var height = defaults.double(forKey: SettingsKey.panelHeight)
        if width == 0 { width = 360 }
        if height == 0 { height = 440 }
        width = min(max(width, 280), 560)
        height = min(max(height, 240), 900)

        let newPanel = PeekPanel(contentRect: NSRect(x: 0, y: 0, width: width, height: height))
        newPanel.delegate = self
        newPanel.onEscape = { [weak self] in
            guard let self else { return }
            // While a title is being edited, Esc cancels the edit; the next
            // Esc closes the panel.
            if self.state.editingID != nil {
                self.state.editingID = nil
            } else {
                self.hide()
            }
        }
        newPanel.contentView = NSHostingView(rootView: PanelRootView(store: store, state: state))
        panel = newPanel
        return newPanel
    }

    private func position(_ panel: NSPanel, relativeTo statusItem: NSStatusItem) {
        guard let button = statusItem.button, let buttonWindow = button.window else { return }
        let buttonRect = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let size = panel.frame.size

        var x = buttonRect.midX - size.width / 2
        let y = buttonRect.minY - size.height - 6
        if let screen = buttonWindow.screen {
            x = min(max(x, screen.frame.minX + 8), screen.frame.maxX - size.width - 8)
        }
        panel.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
    }

    // MARK: - NSWindowDelegate

    func windowDidResignKey(_ notification: Notification) {
        guard isVisible, !isPinned else { return }
        // A row's date or delete popover is a child window of the panel; it
        // taking key status isn't the user clicking away.
        if let key = NSApp.keyWindow, panel?.childWindows?.contains(key) == true { return }
        lastAutoClose = ProcessInfo.processInfo.systemUptime
        hide()
    }

    func windowDidEndLiveResize(_ notification: Notification) {
        guard let panel else { return }
        UserDefaults.standard.set(Double(panel.frame.width), forKey: SettingsKey.panelWidth)
        UserDefaults.standard.set(Double(panel.frame.height), forKey: SettingsKey.panelHeight)
    }
}
