import UIKit

/// Tab strip vs dropdown list layout.
enum TabsLayout: String, Codable {
    case tabs, list
}

/// Single- or double-row toolbar.
enum ToolbarRows: String, Codable {
    case single, double
}

enum AccessoryToolbarButtonSize: String, Codable, CaseIterable {
    case small, medium, large

    var displayTitle: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        }
    }
}

enum AccessoryToolbarContentMode: String, Codable, CaseIterable {
    case iconAndText = "icon_and_text"
    case iconOnly = "icon_only"
    case textOnly = "text_only"

    var displayTitle: String {
        switch self {
        case .iconAndText: return "Text + icon"
        case .iconOnly: return "Icon only"
        case .textOnly: return "Text only"
        }
    }
}

enum AccessoryToolbarButton: String, Codable, CaseIterable {
    case hideKeyboard = "hide_keyboard"
    case cut
    case copy
    case paste
    case selectWord = "select_word"
    case selectLine = "select_line"
    case selectAll = "select_all"
    case undo
    case redo
    case readMode = "read_mode"
    case find
    case replace
    case insertDate = "insert_date"
    case openDocuments = "open_documents"
    case compare
    case more
    case shift
    case moveUp = "move_up"
    case deleteBackward = "delete_backward"
    case moveLeft = "move_left"
    case moveDown = "move_down"
    case moveRight = "move_right"

    var displayTitle: String {
        switch self {
        case .hideKeyboard: return "Hide"
        case .cut: return "Cut"
        case .copy: return "Copy"
        case .paste: return "Paste"
        case .selectWord: return "Word"
        case .selectLine: return "Line"
        case .selectAll: return "All"
        case .undo: return "Undo"
        case .redo: return "Redo"
        case .readMode: return "Read"
        case .find: return "Find"
        case .replace: return "Replace"
        case .insertDate: return "Date"
        case .openDocuments: return "Open"
        case .compare: return "Compare"
        case .more: return "More"
        case .shift: return "Shift"
        case .moveUp: return "Up"
        case .deleteBackward: return "Delete"
        case .moveLeft: return "Left"
        case .moveDown: return "Down"
        case .moveRight: return "Right"
        }
    }

    static let staticCandidates: [AccessoryToolbarButton] = [
        .shift,
        .moveUp,
        .deleteBackward,
        .moveLeft,
        .moveDown,
        .moveRight,
    ]

    static let defaultStaticButtons: Set<AccessoryToolbarButton> = Set(staticCandidates)
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
    private let keyAccessoryButtonSize = "notepad3pp.accessoryToolbarButtonSize"
    private let keyAccessoryContentMode = "notepad3pp.accessoryToolbarContentMode"
    private let keyStaticAccessoryButtons = "notepad3pp.staticAccessoryButtons"
    private let keyHiddenAccessoryButtons = "notepad3pp.hiddenAccessoryButtons"
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

    var accessoryToolbarButtonSize: AccessoryToolbarButtonSize {
        get {
            AccessoryToolbarButtonSize(rawValue: defaults.string(forKey: keyAccessoryButtonSize) ?? "")
                ?? .medium
        }
        set {
            defaults.set(newValue.rawValue, forKey: keyAccessoryButtonSize)
            notify()
        }
    }

    var accessoryToolbarContentMode: AccessoryToolbarContentMode {
        get {
            AccessoryToolbarContentMode(rawValue: defaults.string(forKey: keyAccessoryContentMode) ?? "")
                ?? .iconAndText
        }
        set {
            defaults.set(newValue.rawValue, forKey: keyAccessoryContentMode)
            notify()
        }
    }

    var staticAccessoryButtons: Set<AccessoryToolbarButton> {
        get { decodeButtonSet(key: keyStaticAccessoryButtons, fallback: AccessoryToolbarButton.defaultStaticButtons) }
        set {
            defaults.set(encodeButtonSet(newValue), forKey: keyStaticAccessoryButtons)
            notify()
        }
    }

    var hiddenAccessoryButtons: Set<AccessoryToolbarButton> {
        get { decodeButtonSet(key: keyHiddenAccessoryButtons, fallback: []) }
        set {
            defaults.set(encodeButtonSet(newValue), forKey: keyHiddenAccessoryButtons)
            notify()
        }
    }

    func toggleStaticAccessoryButton(_ button: AccessoryToolbarButton) {
        var pinned = staticAccessoryButtons
        var hidden = hiddenAccessoryButtons
        if pinned.contains(button) {
            pinned.remove(button)
        } else {
            pinned.insert(button)
            hidden.remove(button)
        }
        defaults.set(encodeButtonSet(pinned), forKey: keyStaticAccessoryButtons)
        defaults.set(encodeButtonSet(hidden), forKey: keyHiddenAccessoryButtons)
        notify()
    }

    func toggleHiddenAccessoryButton(_ button: AccessoryToolbarButton) {
        var pinned = staticAccessoryButtons
        var hidden = hiddenAccessoryButtons
        if hidden.contains(button) {
            hidden.remove(button)
        } else {
            hidden.insert(button)
            pinned.remove(button)
        }
        defaults.set(encodeButtonSet(pinned), forKey: keyStaticAccessoryButtons)
        defaults.set(encodeButtonSet(hidden), forKey: keyHiddenAccessoryButtons)
        notify()
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

    private func decodeButtonSet(key: String, fallback: Set<AccessoryToolbarButton>) -> Set<AccessoryToolbarButton> {
        guard let raw = defaults.string(forKey: key) else { return fallback }
        if raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return [] }
        return Set(raw.split(separator: ",").compactMap { AccessoryToolbarButton(rawValue: String($0).trimmingCharacters(in: .whitespacesAndNewlines)) })
    }

    private func encodeButtonSet(_ buttons: Set<AccessoryToolbarButton>) -> String {
        buttons.map(\.rawValue).sorted().joined(separator: ",")
    }
}
