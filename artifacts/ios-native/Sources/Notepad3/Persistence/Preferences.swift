import UIKit

/// Tab strip vs dropdown list layout.
enum TabsLayout: String, Codable {
    case tabs, list
}

/// Single- or double-row toolbar.
enum ToolbarRows: String, Codable {
    case single, double
}

// NOTE: `LayoutMode`, `StarterContent`, and `AccessoryRows` are defined in
// `Models/Theme.swift` and reused here — do not redefine them.

/// Observable bag of user preferences, persisted to UserDefaults.
///
/// Mirrors the RN `useTheme()`/prefs modal state from `app/index.tsx` so the
/// iOS port has the same toggles (tabs layout, toolbar rows, accessory rows,
/// layout mode, starter content, custom palette overrides). Exposes a
/// token-based observer API matching `ThemeController`.
final class Preferences {
    static let shared = Preferences()

    // MARK: Keys

    private let keyTabsLayout       = "notepad3pp.tabsLayout"
    private let keyToolbarLabels    = "notepad3pp.toolbarLabels"
    private let keyToolbarRows      = "notepad3pp.toolbarRows"
    private let keyAccessoryRows    = "notepad3pp.accessoryRows"
    private let keyLayoutMode       = "notepad3pp.layoutMode"
    private let keyStarterContent   = "notepad3pp.starterContent"
    private let keyCustomPalette    = "notepad3pp.customPalette"

    private let defaults = UserDefaults.standard
    private var observers: [UUID: () -> Void] = [:]

    // MARK: Typed accessors

    var tabsLayout: TabsLayout {
        get { TabsLayout(rawValue: defaults.string(forKey: keyTabsLayout) ?? "") ?? .tabs }
        set {
            defaults.set(newValue.rawValue, forKey: keyTabsLayout)
            notify()
        }
    }

    var toolbarLabels: Bool {
        get {
            // Default off to match RN behavior.
            if defaults.object(forKey: keyToolbarLabels) == nil { return false }
            return defaults.bool(forKey: keyToolbarLabels)
        }
        set {
            defaults.set(newValue, forKey: keyToolbarLabels)
            notify()
        }
    }

    var toolbarRows: ToolbarRows {
        get { ToolbarRows(rawValue: defaults.string(forKey: keyToolbarRows) ?? "") ?? .single }
        set {
            defaults.set(newValue.rawValue, forKey: keyToolbarRows)
            notify()
        }
    }

    var accessoryRows: AccessoryRows {
        get { AccessoryRows(rawValue: defaults.string(forKey: keyAccessoryRows) ?? "") ?? .single }
        set {
            defaults.set(newValue.rawValue, forKey: keyAccessoryRows)
            notify()
        }
    }

    var layoutMode: LayoutMode {
        get { LayoutMode(rawValue: defaults.string(forKey: keyLayoutMode) ?? "") ?? .mobile }
        set {
            defaults.set(newValue.rawValue, forKey: keyLayoutMode)
            notify()
        }
    }

    var starterContent: StarterContent {
        get { StarterContent(rawValue: defaults.string(forKey: keyStarterContent) ?? "") ?? .welcome }
        set {
            defaults.set(newValue.rawValue, forKey: keyStarterContent)
            notify()
        }
    }

    /// Field name → hex string overrides. Empty dict means "no custom palette
    /// set yet" (so the Custom theme option can stay hidden).
    var customPalette: [String: String] {
        get {
            guard let data = defaults.data(forKey: keyCustomPalette),
                  let dict = try? JSONDecoder().decode([String: String].self, from: data)
            else { return [:] }
            return dict
        }
        set {
            if newValue.isEmpty {
                defaults.removeObject(forKey: keyCustomPalette)
            } else if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: keyCustomPalette)
            }
            notify()
        }
    }

    // MARK: Observation

    @discardableResult
    func observe(_ block: @escaping () -> Void) -> UUID {
        let id = UUID()
        observers[id] = block
        return id
    }

    func unobserve(_ id: UUID) {
        observers.removeValue(forKey: id)
    }

    private func notify() {
        for block in observers.values { block() }
    }
}
