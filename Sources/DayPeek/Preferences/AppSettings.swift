import AppKit

enum SettingsKey {
    static let appearance = "appearanceMode"
    static let pinPanel = "pinPanel"
    static let panelWidth = "panelWidth"
    static let panelHeight = "panelHeight"
    /// Show the edit / date / delete buttons when hovering a row. Default on.
    static let showRowActions = "showRowActions"
}

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    static var current: AppearanceMode {
        AppearanceMode(rawValue: UserDefaults.standard.string(forKey: SettingsKey.appearance) ?? "") ?? .system
    }

    func apply() {
        switch self {
        case .system: NSApp.appearance = nil
        case .light: NSApp.appearance = NSAppearance(named: .aqua)
        case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }
}
