import UIKit

/// Bottom chrome for the mobile layout. Five equal-width tap targets —
/// Open, Find, Compare, New, More — each with an SF Symbol glyph stacked
/// over a tiny caption. The bar pins to the bottom safe-area inset and
/// owns no state; callers flip palettes via `applyPalette(_:)` and react
/// to taps through the exposed closures. Mirrors the RN `mobileBottomBar`.
final class MobileBottomBar: UIView {
    var onOpen: (() -> Void)?
    var onFind: (() -> Void)?
    var onCompare: (() -> Void)?
    var onNew: (() -> Void)?
    var onMore: (() -> Void)?

    private let stack = UIStackView()
    private let separator = UIView()
    private let openButton: BottomButton
    private let findButton: BottomButton
    private let compareButton: BottomButton
    private let newButton: BottomButton
    private let moreButton: BottomButton

    private var palette: Palette = .light

    override init(frame: CGRect) {
        openButton    = BottomButton(symbol: "list.bullet",           title: "Open")
        findButton    = BottomButton(symbol: "magnifyingglass",       title: "Find")
        compareButton = BottomButton(symbol: "rectangle.split.1x2",   title: "Compare")
        newButton     = BottomButton(symbol: "square.and.pencil",     title: "New")
        moreButton    = BottomButton(symbol: "ellipsis",              title: "More")
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false

        separator.translatesAutoresizingMaskIntoConstraints = false
        addSubview(separator)

        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.alignment = .fill
        stack.distribution = .fillEqually
        stack.spacing = 0
        addSubview(stack)

        let buttons = [openButton, findButton, compareButton, newButton, moreButton]
        buttons.forEach { stack.addArrangedSubview($0) }

        openButton.addTarget(self, action: #selector(openTapped), for: .touchUpInside)
        findButton.addTarget(self, action: #selector(findTapped), for: .touchUpInside)
        compareButton.addTarget(self, action: #selector(compareTapped), for: .touchUpInside)
        newButton.addTarget(self, action: #selector(newTapped), for: .touchUpInside)
        moreButton.addTarget(self, action: #selector(moreTapped), for: .touchUpInside)

        NSLayoutConstraint.activate([
            separator.topAnchor.constraint(equalTo: topAnchor),
            separator.leadingAnchor.constraint(equalTo: leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: trailingAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale),

            stack.topAnchor.constraint(equalTo: separator.bottomAnchor, constant: 6),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            stack.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -6),
        ])

        applyPalette(palette)
    }

    func applyPalette(_ p: Palette) {
        palette = p
        backgroundColor = p.card
        separator.backgroundColor = p.border
        [openButton, findButton, compareButton, newButton, moreButton].forEach { $0.applyPalette(p) }
    }

    @objc private func openTapped()    { onOpen?() }
    @objc private func findTapped()    { onFind?() }
    @objc private func compareTapped() { onCompare?() }
    @objc private func newTapped()     { onNew?() }
    @objc private func moreTapped()    { onMore?() }
}

/// Tall, equal-width cell in the bottom bar: glyph stacked on a tiny label.
/// Dims on press via UIControl's highlight state; palette is applied to
/// both icon and label together to keep the two colors in lockstep.
private final class BottomButton: UIControl {
    private let iconView = UIImageView()
    private let label = UILabel()
    private var palette: Palette = .light

    init(symbol: String, title: String) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        isAccessibilityElement = true
        accessibilityTraits = .button
        accessibilityLabel = title

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.contentMode = .scaleAspectFit
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 22, weight: .regular)
        iconView.image = UIImage(systemName: symbol)
        iconView.isUserInteractionEnabled = false
        addSubview(iconView)

        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = title
        label.font = .systemFont(ofSize: 10, weight: .medium)
        label.textAlignment = .center
        label.isUserInteractionEnabled = false
        addSubview(label)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: 48),

            iconView.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            iconView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 26),
            iconView.heightAnchor.constraint(equalToConstant: 24),

            label.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 2),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -2),
            label.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -4),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func applyPalette(_ p: Palette) {
        palette = p
        iconView.tintColor = p.foreground
        label.textColor = p.mutedForeground
    }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.08) {
                self.alpha = self.isHighlighted ? 0.55 : 1.0
            }
        }
    }
}
