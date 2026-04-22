import UIKit

/// Thin wrapper for the three UIFeedbackGenerator kinds so callers don't
/// have to allocate + prepare generators at every tap. Generators are
/// lightweight; keeping one per kind around is fine for app-level use.
enum Haptics {
    private static let selection = UISelectionFeedbackGenerator()
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let medium = UIImpactFeedbackGenerator(style: .medium)
    private static let notify = UINotificationFeedbackGenerator()

    static func selectionChanged() { selection.selectionChanged() }
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        (style == .medium ? medium : light).impactOccurred()
    }
    static func success() { notify.notificationOccurred(.success) }
    static func warning() { notify.notificationOccurred(.warning) }
    static func error() { notify.notificationOccurred(.error) }
}
