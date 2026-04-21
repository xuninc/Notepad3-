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

    static func palette(for name: ThemeName) -> Palette {
        switch name {
        case .classic: return .classic
        case .light: return .light
        case .dark: return .dark
        // TODO: retro, modern, cyberpunk, sunset, custom
        case .retro, .modern, .cyberpunk, .sunset, .custom: return .light
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
