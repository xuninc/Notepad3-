import UIKit

/// Observable theme state. Holds the user's theme preference (named theme or
/// "match system") and resolves that to a concrete `Palette` whenever the
/// trait collection or preference changes. Persists to UserDefaults.
/// Observers register an opaque token and get notified after any change.
final class ThemeController {
    static let shared = ThemeController()

    private let preferenceKey = "notepad3pp.themePreference"
    private let fallbackSystemLight: ThemeName = .light
    private let fallbackSystemDark: ThemeName = .dark

    private(set) var preference: ThemePreference
    private(set) var systemIsDark: Bool = false

    private var observers: [UUID: () -> Void] = [:]

    init() {
        // Default to Classic — the Aero blue / Notepad 2 aesthetic that the
        // app's name and chrome borrow from. Users can switch to any other
        // theme (including "match system") from Preferences.
        let raw = UserDefaults.standard.string(forKey: preferenceKey) ?? "named:classic"
        self.preference = ThemeController.decode(raw)
    }

    /// Resolves the user's preference + current system style to a concrete theme.
    var resolvedTheme: ThemeName {
        switch preference {
        case .named(let name): return name
        case .system: return systemIsDark ? fallbackSystemDark : fallbackSystemLight
        }
    }

    /// Resolved concrete palette. For a named theme, returns its preset.
    /// For `.custom`, starts from `.light` and overlays any hex overrides
    /// stored in `Preferences.customPalette` so partial customizations are
    /// legal (user only tweaks 2–3 fields, rest stay sane).
    var palette: Palette {
        let name = resolvedTheme
        guard name == .custom else { return Palette.palette(for: name) }
        return Palette.byOverlaying(overrides: Preferences.shared.customPalette, onto: .light)
    }

    /// Called by the top-level view controller whenever its trait collection
    /// changes, so "match system" can pick up light↔dark swaps.
    func updateSystemStyle(isDark: Bool) {
        guard systemIsDark != isDark else { return }
        systemIsDark = isDark
        if case .system = preference { notify() }
    }

    func setPreference(_ next: ThemePreference) {
        preference = next
        UserDefaults.standard.set(ThemeController.encode(next), forKey: preferenceKey)
        notify()
    }

    /// Quick-toggle between light and dark. If the current preference is
    /// "match system" we switch it away to an explicit light/dark (inverse of
    /// what the system is right now) so the tap visibly does something.
    func quickToggleDarkLight() {
        switch preference {
        case .named(.dark):
            setPreference(.named(.light))
        case .named(.light):
            setPreference(.named(.dark))
        default:
            setPreference(.named(resolvedTheme == .dark ? .light : .dark))
        }
    }

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

    // ThemePreference is stored as either "system" or "named:<name>" so we
    // don't need a JSON encoder for a single field.
    private static func encode(_ pref: ThemePreference) -> String {
        switch pref {
        case .system: return "system"
        case .named(let name): return "named:\(name.rawValue)"
        }
    }

    private static func decode(_ raw: String) -> ThemePreference {
        if raw == "system" { return .system }
        if raw.hasPrefix("named:"), let name = ThemeName(rawValue: String(raw.dropFirst("named:".count))) {
            return .named(name)
        }
        return .named(.light)
    }
}
