import UIKit

enum ThemeName: String, Codable, CaseIterable {
    case classic, light, dark, retro, modern, cyberpunk, sunset, custom
}

enum ThemePreference: Codable, Equatable {
    case named(ThemeName)
    case system
}

enum LayoutMode: String, Codable {
    case classic, mobile
}

enum AccessoryRows: String, Codable {
    case single, double
}

enum StarterContent: String, Codable {
    case welcome, blank
}

struct Palette: Equatable {
    var background: UIColor
    var foreground: UIColor
    var card: UIColor
    var primary: UIColor
    var primaryForeground: UIColor
    var secondary: UIColor
    var muted: UIColor
    var mutedForeground: UIColor
    var accent: UIColor
    var border: UIColor
    var editorBackground: UIColor
    var editorGutter: UIColor
    var destructive: UIColor
    var success: UIColor
    var titleGradientStart: UIColor
    var titleGradientEnd: UIColor
    var chromeGradientStart: UIColor
    var chromeGradientEnd: UIColor
    var radius: CGFloat
}

extension Palette {
    static let classic = Palette(
        background: hex("#dbe5f1"),
        foreground: hex("#1a2334"),
        card: hex("#dde7f3"),
        primary: hex("#3a78c4"),
        primaryForeground: .white,
        secondary: hex("#c4d5ec"),
        muted: hex("#eef3fa"),
        mutedForeground: hex("#4a5e7a"),
        accent: hex("#2c5d9b"),
        border: hex("#7a96bd"),
        editorBackground: .white,
        editorGutter: hex("#eef3fa"),
        destructive: hex("#a83232"),
        success: hex("#1f6f3f"),
        titleGradientStart: hex("#5a8fcf"),
        titleGradientEnd: hex("#2c5d9b"),
        chromeGradientStart: hex("#eef3fa"),
        chromeGradientEnd: hex("#cad9ed"),
        radius: 4
    )

    static let light = Palette(
        background: hex("#f5f5f7"),
        foreground: hex("#1a1a1a"),
        card: .white,
        primary: hex("#0a64a4"),
        primaryForeground: .white,
        secondary: hex("#e6e6e6"),
        muted: hex("#f0f0f0"),
        mutedForeground: hex("#5a5a5a"),
        accent: hex("#0a64a4"),
        border: hex("#cfcfcf"),
        editorBackground: .white,
        editorGutter: hex("#f4f4f4"),
        destructive: hex("#a83232"),
        success: hex("#1f6f3f"),
        titleGradientStart: .white,
        titleGradientEnd: hex("#f0f0f0"),
        chromeGradientStart: hex("#fafafa"),
        chromeGradientEnd: hex("#ececec"),
        radius: 6
    )

    static let dark = Palette(
        background: hex("#1e1e1e"),
        foreground: hex("#e6e6e6"),
        card: hex("#2a2a2a"),
        primary: hex("#4ea3dc"),
        primaryForeground: hex("#0a0a0a"),
        secondary: hex("#3a3a3a"),
        muted: hex("#262626"),
        mutedForeground: hex("#a8a8a8"),
        accent: hex("#4ea3dc"),
        border: hex("#3f3f46"),
        editorBackground: hex("#1e1e1e"),
        editorGutter: hex("#262626"),
        destructive: hex("#e07070"),
        success: hex("#7fbf7f"),
        titleGradientStart: hex("#3a3a3a"),
        titleGradientEnd: hex("#1a1a1a"),
        chromeGradientStart: hex("#2e2e2e"),
        chromeGradientEnd: hex("#1f1f1f"),
        radius: 6
    )

    static let retro = Palette(
        background: hex("#c0c0c0"),
        foreground: hex("#000000"),
        card: hex("#c0c0c0"),
        primary: hex("#000080"),
        primaryForeground: hex("#ffffff"),
        secondary: hex("#a8a8a8"),
        muted: hex("#d4d0c8"),
        mutedForeground: hex("#404040"),
        accent: hex("#000080"),
        border: hex("#808080"),
        editorBackground: hex("#ffffff"),
        editorGutter: hex("#dcdcdc"),
        destructive: hex("#800000"),
        success: hex("#005900"),
        titleGradientStart: hex("#000080"),
        titleGradientEnd: hex("#000080"),
        chromeGradientStart: hex("#c0c0c0"),
        chromeGradientEnd: hex("#c0c0c0"),
        radius: 0
    )

    static let modern = Palette(
        background: hex("#f8fafc"),
        foreground: hex("#0f172a"),
        card: hex("#ffffff"),
        primary: hex("#6366f1"),
        primaryForeground: hex("#ffffff"),
        secondary: hex("#eef2ff"),
        muted: hex("#f1f5f9"),
        mutedForeground: hex("#64748b"),
        accent: hex("#8b5cf6"),
        border: hex("#e2e8f0"),
        editorBackground: hex("#ffffff"),
        editorGutter: hex("#f8fafc"),
        destructive: hex("#ef4444"),
        success: hex("#10b981"),
        titleGradientStart: hex("#ffffff"),
        titleGradientEnd: hex("#f8fafc"),
        chromeGradientStart: hex("#ffffff"),
        chromeGradientEnd: hex("#f1f5f9"),
        radius: 12
    )

    static let sunset = Palette(
        background: hex("#fff6fa"),
        foreground: hex("#3a1a3a"),
        card: hex("#ffffff"),
        primary: hex("#ff3d8a"),
        primaryForeground: hex("#ffffff"),
        secondary: hex("#ffd6e6"),
        muted: hex("#eaf3fb"),
        mutedForeground: hex("#6e3a5e"),
        accent: hex("#ff7a3d"),
        border: hex("#ffb3d1"),
        editorBackground: hex("#fffafd"),
        editorGutter: hex("#ffe8f1"),
        destructive: hex("#c0264e"),
        success: hex("#8fd9b8"),
        titleGradientStart: hex("#ff7a3d"),
        titleGradientEnd: hex("#ff3d8a"),
        chromeGradientStart: hex("#d8f1e4"),
        chromeGradientEnd: hex("#d6ecff"),
        radius: 8
    )

    static let cyberpunk = Palette(
        background: hex("#0b0820"),
        foreground: hex("#f0f6ff"),
        card: hex("#150f33"),
        primary: hex("#ff2bd1"),
        primaryForeground: hex("#0b0820"),
        secondary: hex("#1f1850"),
        muted: hex("#161139"),
        mutedForeground: hex("#9af7ff"),
        accent: hex("#00f0ff"),
        border: hex("#ff2bd1"),
        editorBackground: hex("#070518"),
        editorGutter: hex("#0e0a26"),
        destructive: hex("#ff5577"),
        success: hex("#76ff7a"),
        titleGradientStart: hex("#ff2bd1"),
        titleGradientEnd: hex("#7b00ff"),
        chromeGradientStart: hex("#1a1340"),
        chromeGradientEnd: hex("#0e0a26"),
        radius: 2
    )

    static func palette(for name: ThemeName) -> Palette {
        switch name {
        case .classic:   return .classic
        case .light:     return .light
        case .dark:      return .dark
        case .retro:     return .retro
        case .modern:    return .modern
        case .sunset:    return .sunset
        case .cyberpunk: return .cyberpunk
        case .custom:    return .light // custom palette builder not yet wired
        }
    }
}

private func hex(_ s: String) -> UIColor {
    var v = s
    if v.hasPrefix("#") { v.removeFirst() }
    guard v.count == 6, let n = UInt32(v, radix: 16) else { return .magenta }
    return UIColor(
        red: CGFloat((n >> 16) & 0xFF) / 255,
        green: CGFloat((n >> 8) & 0xFF) / 255,
        blue: CGFloat(n & 0xFF) / 255,
        alpha: 1
    )
}
