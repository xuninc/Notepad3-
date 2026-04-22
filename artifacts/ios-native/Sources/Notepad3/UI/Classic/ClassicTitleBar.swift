import UIKit

/// Notepad2-style title bar: gradient chrome across the top with a small
/// doc icon and the active document title, mimicking a Windows Aero window
/// caption. Sits ABOVE the `AeroMenuBar`. Gradient colors come from the
/// palette's `titleGradient` fields.
final class ClassicTitleBar: UIView {
    private let gradient = CAGradientLayer()
    private let iconView = UIImageView()
    private let titleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradient.frame = bounds
    }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 0, y: 1)
        layer.insertSublayer(gradient, at: 0)

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.contentMode = .scaleAspectFit
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        iconView.image = UIImage(systemName: "doc.text")
        addSubview(iconView)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        titleLabel.lineBreakMode = .byTruncatingMiddle
        addSubview(titleLabel)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 14),
            iconView.heightAnchor.constraint(equalToConstant: 14),

            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 6),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -8),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    func setTitle(_ title: String) {
        titleLabel.text = "\(title) - Notepad 3++"
    }

    func applyPalette(_ p: Palette) {
        gradient.colors = [p.titleGradientStart.cgColor, p.titleGradientEnd.cgColor]
        iconView.tintColor = p.primaryForeground
        titleLabel.textColor = p.primaryForeground
    }
}
