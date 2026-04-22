import UIKit

/// Circular floating action button for the mobile layout. Lives bottom-right,
/// hovering above the `MobileBottomBar`. Primary color background with a
/// plus glyph. Press gives a brief scale-down + opacity dip; tap fires
/// `onTap`. Callers update placement with `setBottomInset(_:)` to account
/// for the bar height plus safe-area padding. Mirrors the RN `mobileFab`.
final class MobileFAB: UIControl {
    /// Outer diameter, per the RN spec.
    static let diameter: CGFloat = 56

    var onTap: (() -> Void)?

    private let iconView = UIImageView()
    private var palette: Palette = .light
    private var bottomInset: CGFloat = 80
    private var bottomConstraint: NSLayoutConstraint?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        layer.cornerRadius = Self.diameter / 2
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.25
        layer.shadowOffset = CGSize(width: 0, height: 3)
        layer.shadowRadius = 6
        accessibilityLabel = "New document"
        accessibilityTraits = .button
        isAccessibilityElement = true

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.contentMode = .scaleAspectFit
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 24, weight: .bold)
        iconView.image = UIImage(systemName: "plus")
        iconView.isUserInteractionEnabled = false
        addSubview(iconView)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: Self.diameter),
            heightAnchor.constraint(equalToConstant: Self.diameter),
            iconView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 28),
            iconView.heightAnchor.constraint(equalToConstant: 28),
        ])

        addTarget(self, action: #selector(tapped), for: .touchUpInside)
        applyPalette(palette)
    }

    /// Pin this FAB to the bottom-right of `host`, 16pt from the trailing
    /// edge, `bottomInset`pt above the bottom safe-area guide. Callers
    /// that own the `MobileBottomBar` typically pass `barHeight + 8`.
    func install(in host: UIView, bottomInset: CGFloat = 80) {
        self.bottomInset = bottomInset
        host.addSubview(self)
        let bc = bottomAnchor.constraint(equalTo: host.safeAreaLayoutGuide.bottomAnchor, constant: -bottomInset)
        bottomConstraint = bc
        NSLayoutConstraint.activate([
            trailingAnchor.constraint(equalTo: host.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            bc,
        ])
    }

    /// Adjust the vertical offset after layout — e.g. when the bottom bar
    /// hides or the accessory keyboard bar appears.
    func setBottomInset(_ inset: CGFloat) {
        bottomInset = inset
        bottomConstraint?.constant = -inset
    }

    func applyPalette(_ p: Palette) {
        palette = p
        backgroundColor = p.primary
        iconView.tintColor = p.primaryForeground
    }

    @objc private func tapped() { onTap?() }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(
                withDuration: 0.12,
                delay: 0,
                usingSpringWithDamping: 0.8,
                initialSpringVelocity: 0,
                options: [.allowUserInteraction, .beginFromCurrentState]
            ) {
                let scale: CGFloat = self.isHighlighted ? 0.93 : 1.0
                self.transform = CGAffineTransform(scaleX: scale, y: scale)
                self.alpha = self.isHighlighted ? 0.88 : 1.0
            }
        }
    }
}
