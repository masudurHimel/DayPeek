import AppKit

/// Owns the menu bar status item: a template checklist glyph. Left-click
/// toggles the panel; right-click (or ctrl-click) shows the two-item context
/// menu. The menu is assigned only for the duration of the click — a
/// permanently assigned menu would hijack left-click as well.
@MainActor
final class StatusItemController: NSObject {
    private let statusItem: NSStatusItem
    private let store = ReminderStore()
    private let panelController: PanelController
    private let preferencesWindow = PreferencesWindowController()

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        panelController = PanelController(store: store)
        super.init()

        if let button = statusItem.button {
            button.image = Self.menuBarIcon()
            button.imagePosition = .imageOnly
            button.target = self
            button.action = #selector(statusItemClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        NotificationCenter.default.addObserver(
            self, selector: #selector(dayChanged),
            name: .NSCalendarDayChanged, object: nil
        )

        // Ask for Reminders access right away so the first panel open is instant.
        Task { await store.reload() }
    }

    /// Template checklist glyph: the menu bar renders it white on dark bars and
    /// black on light ones, like every other system status item.
    private static func menuBarIcon() -> NSImage {
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        let image = NSImage(systemSymbolName: "checklist", accessibilityDescription: "DayPeek")!
            .withSymbolConfiguration(config)!
        image.isTemplate = true
        return image
    }

    @objc private func dayChanged() {
        Task { await store.reload() }
    }

    @objc private func statusItemClicked() {
        let event = NSApp.currentEvent
        let isRightClick = event?.type == .rightMouseUp
            || (event?.modifierFlags.contains(.control) ?? false)
        if isRightClick {
            showContextMenu()
        } else {
            panelController.toggle(relativeTo: statusItem)
        }
    }

    private func showContextMenu() {
        panelController.hideUnlessPinned()

        let menu = NSMenu()
        let preferences = NSMenuItem(
            title: "Preferences…", action: #selector(openPreferences), keyEquivalent: ","
        )
        preferences.target = self
        menu.addItem(preferences)
        let quit = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func openPreferences() {
        preferencesWindow.show()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
