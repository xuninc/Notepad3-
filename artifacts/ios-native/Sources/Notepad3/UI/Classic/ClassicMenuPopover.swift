import UIKit

/// Windows-classic-styled dropdown popover for the Aero menu bar. Renders
/// rows in a flat sharp-cornered list with a thin border and a subtle drop
/// shadow. Replaces UIMenu for the AeroMenuBar so the dropdown's chrome
/// matches the menu bar that triggered it.
///
/// Each row has a 16pt SF Symbol icon column on the left, a text label, and
/// an optional trailing accessory (checkmark for toggles, chevron for
/// submenus). Rows highlight to the palette's primary on touch.
final class ClassicMenuPopover {

    // MARK: - Public model

    enum Row {
        case action(title: String, symbol: String?, checked: Bool, destructive: Bool, handler: () -> Void)
        case submenu(title: String, symbol: String?, children: [Row])
        case divider
    }

    // MARK: - Private state

    private let rows: [Row]
    private let palette: Palette
    private weak var anchor: UIView?
    private let onDismiss: () -> Void

    private weak var window: UIWindow?
    private var menuView: UIView?
    private var dismisser: UIView?
    private var subPopover: ClassicMenuPopover?

    // MARK: - Init

    init(rows: [Row], palette: Palette, anchor: UIView, onDismiss: @escaping () -> Void = {}) {
        self.rows = rows
        self.palette = palette
        self.anchor = anchor
        self.onDismiss = onDismiss
    }

    // MARK: - Show / dismiss

    /// Presents the popover anchored to the bottom-leading edge of `anchor`.
    /// If `anchor` is not yet in a window, returns false without presenting.
    @discardableResult
    func present() -> Bool {
        guard let anchor = anchor, let window = anchor.window else { return false }
        self.window = window

        // Background dismisser covers the whole window. Taps on it dismiss.
        // The menu view is added on top so it intercepts its own taps before
        // the dismisser sees them.
        let dismisser = UIView()
        dismisser.translatesAutoresizingMaskIntoConstraints = false
        dismisser.backgroundColor = .clear
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleBackgroundTap))
        dismisser.addGestureRecognizer(tap)
        window.addSubview(dismisser)
        NSLayoutConstraint.activate([
            dismisser.topAnchor.constraint(equalTo: window.topAnchor),
            dismisser.leadingAnchor.constraint(equalTo: window.leadingAnchor),
            dismisser.trailingAnchor.constraint(equalTo: window.trailingAnchor),
            dismisser.bottomAnchor.constraint(equalTo: window.bottomAnchor),
        ])
        self.dismisser = dismisser

        let menu = makeMenuView()
        menu.translatesAutoresizingMaskIntoConstraints = false
        window.addSubview(menu)

        // Compute final size from auto-layout
        menu.layoutIfNeeded()
        let desired = menu.systemLayoutSizeFitting(
            CGSize(width: 320, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .defaultLow,
            verticalFittingPriority: .required
        )
        let menuWidth = max(180, min(desired.width, 320))
        let menuHeight = desired.height

        // Place top-leading at anchor's bottom-leading, in window coords
        let anchorFrame = anchor.convert(anchor.bounds, to: window)
        var leading = anchorFrame.minX
        var top = anchorFrame.maxY

        // Keep on-screen
        let safe = window.safeAreaInsets
        let maxX = window.bounds.maxX - safe.right - 4
        let maxY = window.bounds.maxY - safe.bottom - 4
        if leading + menuWidth > maxX {
            leading = max(safe.left + 4, maxX - menuWidth)
        }
        if top + menuHeight > maxY {
            // No room below: flip above the anchor
            top = max(safe.top + 4, anchorFrame.minY - menuHeight)
        }

        NSLayoutConstraint.activate([
            menu.leadingAnchor.constraint(equalTo: window.leadingAnchor, constant: leading),
            menu.topAnchor.constraint(equalTo: window.topAnchor, constant: top),
            menu.widthAnchor.constraint(equalToConstant: menuWidth),
        ])
        self.menuView = menu

        return true
    }

    func dismiss() {
        subPopover?.dismiss()
        subPopover = nil
        menuView?.removeFromSuperview()
        dismisser?.removeFromSuperview()
        menuView = nil
        dismisser = nil
        onDismiss()
    }

    @objc private func handleBackgroundTap() {
        dismiss()
    }

    // MARK: - Menu view

    private func makeMenuView() -> UIView {
        let container = UIView()
        container.backgroundColor = palette.background
        container.layer.borderWidth = 1
        container.layer.borderColor = palette.border.cgColor
        container.layer.cornerRadius = 0  // Windows-classic = sharp corners
        container.layer.shadowColor = UIColor.black.cgColor
        container.layer.shadowOffset = CGSize(width: 1, height: 2)
        container.layer.shadowRadius = 3
        container.layer.shadowOpacity = 0.25
        container.layer.masksToBounds = false

        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .fill
        stack.distribution = .fill
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 4),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -4),
        ])

        for row in rows {
            switch row {
            case .action(let title, let symbol, let checked, let destructive, let handler):
                let rowView = ClassicMenuPopoverRow(
                    title: title,
                    symbol: symbol,
                    checked: checked,
                    hasSubmenu: false,
                    destructive: destructive,
                    palette: palette
                ) { [weak self] in
                    handler()
                    self?.dismiss()
                }
                stack.addArrangedSubview(rowView)

            case .submenu(let title, let symbol, let children):
                weak var weakRow: ClassicMenuPopoverRow?
                let rowView = ClassicMenuPopoverRow(
                    title: title,
                    symbol: symbol,
                    checked: false,
                    hasSubmenu: true,
                    destructive: false,
                    palette: palette
                ) { [weak self] in
                    guard let self, let anchor = weakRow else { return }
                    self.openSubmenu(rows: children, anchor: anchor)
                }
                weakRow = rowView
                stack.addArrangedSubview(rowView)

            case .divider:
                let div = UIView()
                div.translatesAutoresizingMaskIntoConstraints = false
                div.backgroundColor = palette.border
                let wrap = UIView()
                wrap.translatesAutoresizingMaskIntoConstraints = false
                wrap.addSubview(div)
                NSLayoutConstraint.activate([
                    div.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale),
                    div.leadingAnchor.constraint(equalTo: wrap.leadingAnchor, constant: 26),
                    div.trailingAnchor.constraint(equalTo: wrap.trailingAnchor, constant: -2),
                    div.topAnchor.constraint(equalTo: wrap.topAnchor, constant: 3),
                    div.bottomAnchor.constraint(equalTo: wrap.bottomAnchor, constant: -3),
                ])
                stack.addArrangedSubview(wrap)
            }
        }

        return container
    }

    private func openSubmenu(rows: [Row], anchor: UIView) {
        subPopover?.dismiss()
        let sub = ClassicMenuPopover(rows: rows, palette: palette, anchor: anchor) { [weak self] in
            self?.subPopover = nil
        }
        sub.present()
        subPopover = sub
    }
}

// MARK: - Row view

private final class ClassicMenuPopoverRow: UIControl {
    private let titleLabel = UILabel()
    private let iconView = UIImageView()
    private let accessoryView = UIImageView()
    private let palette: Palette
    private let baseTextColor: UIColor
    private let onTap: () -> Void

    init(title: String, symbol: String?, checked: Bool, hasSubmenu: Bool, destructive: Bool, palette: Palette, onTap: @escaping () -> Void) {
        self.palette = palette
        self.baseTextColor = destructive ? palette.destructive : palette.foreground
        self.onTap = onTap
        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = baseTextColor
        if let symbol = symbol {
            iconView.image = UIImage(
                systemName: symbol,
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .regular)
            )
        }
        addSubview(iconView)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = title
        titleLabel.textColor = baseTextColor
        titleLabel.font = .systemFont(ofSize: 13, weight: .regular)
        addSubview(titleLabel)

        accessoryView.translatesAutoresizingMaskIntoConstraints = false
        accessoryView.contentMode = .scaleAspectFit
        accessoryView.tintColor = baseTextColor
        if hasSubmenu {
            accessoryView.image = UIImage(
                systemName: "chevron.right",
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 10, weight: .regular)
            )
        } else if checked {
            accessoryView.image = UIImage(
                systemName: "checkmark",
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 11, weight: .regular)
            )
        }
        addSubview(accessoryView)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 24),

            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 16),
            iconView.heightAnchor.constraint(equalToConstant: 16),

            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: accessoryView.leadingAnchor, constant: -8),

            accessoryView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            accessoryView.centerYAnchor.constraint(equalTo: centerYAnchor),
            accessoryView.widthAnchor.constraint(equalToConstant: 12),
            accessoryView.heightAnchor.constraint(equalToConstant: 12),
        ])

        addTarget(self, action: #selector(tapped), for: .touchUpInside)

        isAccessibilityElement = true
        accessibilityLabel = title
        accessibilityTraits = [.button]
    }

    required init?(coder: NSCoder) { fatalError() }

    override var isHighlighted: Bool {
        didSet {
            backgroundColor = isHighlighted ? palette.primary : .clear
            let textColor = isHighlighted ? palette.primaryForeground : baseTextColor
            titleLabel.textColor = textColor
            iconView.tintColor = textColor
            accessoryView.tintColor = textColor
        }
    }

    @objc private func tapped() { onTap() }
}
