import UIKit

/// Classic desktop-style toolbar: a horizontally-scrolling strip of icon
/// buttons, optionally with a text label below each. Can be rendered as
/// one or two rows.
///
/// Mirrors the RN `styles.toolbar` with its `palette.chromeGradient` background.
/// The caller assigns closures to `on…` slots; long-press surfaces the
/// button's label as an accessibility hint (and an iOS tooltip on iOS 16+).
final class ClassicToolbar: UIView {
    // Callbacks, one per button. All optional — buttons with a nil closure
    // still render and are tappable but emit nothing.
    var onNew: (() -> Void)?
    var onOpen: (() -> Void)?
    var onSave: (() -> Void)?
    var onCut: (() -> Void)?
    var onCopy: (() -> Void)?
    var onPaste: (() -> Void)?
    var onUndo: (() -> Void)?
    var onRedo: (() -> Void)?
    var onFind: (() -> Void)?
    var onReplace: (() -> Void)?
    var onTrim: (() -> Void)?
    var onSort: (() -> Void)?
    var onDocs: (() -> Void)?
    var onCompare: (() -> Void)?
    var onMore: (() -> Void)?

    // Additional callbacks mirroring the RN classic toolbar's full icon set.
    var onSelectAll: (() -> Void)?
    var onSelectLine: (() -> Void)?
    var onSelectParagraph: (() -> Void)?
    var onInsertDateTime: (() -> Void)?
    var onDuplicateLine: (() -> Void)?
    var onDeleteLine: (() -> Void)?
    var onGotoLine: (() -> Void)?
    var onToggleReadMode: (() -> Void)?
    var onToggleZenMode: (() -> Void)?
    var onToggleTrackpad: (() -> Void)?
    var onPreferences: (() -> Void)?
    var onDeleteDoc: (() -> Void)?

    // Toggle-state providers. Return true if the underlying mode is active;
    // the toolbar re-tints the matching button on `refresh()`.
    var isReadMode: (() -> Bool)?
    var isZenMode: (() -> Bool)?
    var isTrackpadOn: (() -> Bool)?

    private let gradient = CAGradientLayer()
    private let separator = UIView()
    private let container = UIView()
    private let topRow = UIScrollView()
    private let topStack = UIStackView()
    private let bottomRow = UIScrollView()
    private let bottomStack = UIStackView()
    private let rowSeparator = UIView()
    private var heightConstraint: NSLayoutConstraint?

    // Map of button id -> the button view in the current layout, so `refresh()`
    // can re-tint toggleable buttons without a full rebuild.
    private var buttonsById: [String: ClassicToolbarButton] = [:]

    private var palette: Palette = .classic
    private var labelsVisible: Bool = false
    private var rows: Int = 1

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

        gradient.startPoint = CGPoint(x: 0.5, y: 0)
        gradient.endPoint = CGPoint(x: 0.5, y: 1)
        layer.insertSublayer(gradient, at: 0)

        container.translatesAutoresizingMaskIntoConstraints = false
        addSubview(container)

        for scroll in [topRow, bottomRow] {
            scroll.translatesAutoresizingMaskIntoConstraints = false
            scroll.showsHorizontalScrollIndicator = false
            scroll.alwaysBounceHorizontal = false
        }
        for stack in [topStack, bottomStack] {
            stack.translatesAutoresizingMaskIntoConstraints = false
            stack.axis = .horizontal
            stack.alignment = .center
            stack.spacing = 2
        }

        topRow.addSubview(topStack)
        bottomRow.addSubview(bottomStack)

        rowSeparator.translatesAutoresizingMaskIntoConstraints = false
        separator.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(topRow)
        container.addSubview(rowSeparator)
        container.addSubview(bottomRow)
        addSubview(separator)

        let hc = heightAnchor.constraint(equalToConstant: 30)
        heightConstraint = hc

        NSLayoutConstraint.activate([
            hc,

            container.topAnchor.constraint(equalTo: topAnchor),
            container.leadingAnchor.constraint(equalTo: leadingAnchor),
            container.trailingAnchor.constraint(equalTo: trailingAnchor),
            container.bottomAnchor.constraint(equalTo: separator.topAnchor),

            topRow.topAnchor.constraint(equalTo: container.topAnchor),
            topRow.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            topRow.trailingAnchor.constraint(equalTo: container.trailingAnchor),

            rowSeparator.topAnchor.constraint(equalTo: topRow.bottomAnchor),
            rowSeparator.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            rowSeparator.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            rowSeparator.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale),

            bottomRow.topAnchor.constraint(equalTo: rowSeparator.bottomAnchor),
            bottomRow.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            bottomRow.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            bottomRow.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            topStack.topAnchor.constraint(equalTo: topRow.contentLayoutGuide.topAnchor),
            topStack.leadingAnchor.constraint(equalTo: topRow.contentLayoutGuide.leadingAnchor, constant: 4),
            topStack.trailingAnchor.constraint(equalTo: topRow.contentLayoutGuide.trailingAnchor, constant: -4),
            topStack.bottomAnchor.constraint(equalTo: topRow.contentLayoutGuide.bottomAnchor),
            topStack.heightAnchor.constraint(equalTo: topRow.frameLayoutGuide.heightAnchor),

            bottomStack.topAnchor.constraint(equalTo: bottomRow.contentLayoutGuide.topAnchor),
            bottomStack.leadingAnchor.constraint(equalTo: bottomRow.contentLayoutGuide.leadingAnchor, constant: 4),
            bottomStack.trailingAnchor.constraint(equalTo: bottomRow.contentLayoutGuide.trailingAnchor, constant: -4),
            bottomStack.bottomAnchor.constraint(equalTo: bottomRow.contentLayoutGuide.bottomAnchor),
            bottomStack.heightAnchor.constraint(equalTo: bottomRow.frameLayoutGuide.heightAnchor),

            separator.leadingAnchor.constraint(equalTo: leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: bottomAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale),
        ])

        rebuild()
    }

    // MARK: - Public API

    func setLabelsVisible(_ visible: Bool) {
        guard labelsVisible != visible else { return }
        labelsVisible = visible
        rebuild()
    }

    func setRows(_ count: Int) {
        let clamped = max(1, min(2, count))
        guard rows != clamped else { return }
        rows = clamped
        rebuild()
    }

    func applyPalette(_ p: Palette) {
        palette = p
        gradient.colors = [p.chromeGradientStart.cgColor, p.chromeGradientEnd.cgColor]
        separator.backgroundColor = p.border
        rowSeparator.backgroundColor = p.border
        rebuild()
    }

    /// Re-evaluates toggleable-button state and updates tints / icons accordingly.
    /// Callers invoke this after mutating state the toolbar displays (e.g. after
    /// toggling read mode externally). Cheaper than a full rebuild.
    func refresh() {
        applyToggleState()
    }

    // MARK: - Layout

    private func items() -> [ClassicToolbarKind] {
        // Mirrors the RN ordering (`/artifacts/mobile/app/index.tsx`, the classic
        // toolbar `items` array). Feather icon names mapped to SF Symbols. The
        // existing 15 callbacks (New/Open/Save/Cut/Copy/Paste/Undo/Redo/Find/
        // Replace/Trim/Sort/Docs/Compare/More) are preserved and interleaved
        // into the same RN groups so host wiring still works.
        let readActive = isReadMode?() ?? false
        let readSymbol = readActive ? "eye" : "eye.slash"
        return [
            // File group
            .button(ClassicToolbarItemSpec(id: "tb-new",     symbol: "doc.badge.plus",                  label: "New")              { [weak self] in self?.onNew?() }),
            .button(ClassicToolbarItemSpec(id: "tb-open",    symbol: "folder",                          label: "Open")             { [weak self] in self?.onOpen?() }),
            .button(ClassicToolbarItemSpec(id: "tb-save",    symbol: "square.and.arrow.down",           label: "Save")             { [weak self] in self?.onSave?() }),
            .separator,

            // Clipboard group
            .button(ClassicToolbarItemSpec(id: "tb-cut",     symbol: "scissors",                        label: "Cut")              { [weak self] in self?.onCut?() }),
            .button(ClassicToolbarItemSpec(id: "tb-copy",    symbol: "doc.on.clipboard",                label: "Copy")             { [weak self] in self?.onCopy?() }),
            .button(ClassicToolbarItemSpec(id: "tb-paste",   symbol: "square.and.arrow.down.on.square", label: "Paste")            { [weak self] in self?.onPaste?() }),
            .separator,

            // Selection group (RN: Select all / Select line / Select paragraph)
            .button(ClassicToolbarItemSpec(id: "tb-selall",  symbol: "character.textbox",               label: "Select all")       { [weak self] in self?.onSelectAll?() }),
            .button(ClassicToolbarItemSpec(id: "tb-selline", symbol: "text.line.first.and.arrowtriangle.forward", label: "Select line") { [weak self] in self?.onSelectLine?() }),
            .button(ClassicToolbarItemSpec(id: "tb-selpar",  symbol: "paragraphsign",                   label: "Select paragraph") { [weak self] in self?.onSelectParagraph?() }),
            .separator,

            // Edit-history group
            .button(ClassicToolbarItemSpec(id: "tb-undo",    symbol: "arrow.uturn.backward",            label: "Undo")             { [weak self] in self?.onUndo?() }),
            .button(ClassicToolbarItemSpec(id: "tb-redo",    symbol: "arrow.uturn.forward",             label: "Redo")             { [weak self] in self?.onRedo?() }),
            .separator,

            // Find / Replace / Insert date-time
            .button(ClassicToolbarItemSpec(id: "tb-find",    symbol: "magnifyingglass",                 label: "Find")             { [weak self] in self?.onFind?() }),
            .button(ClassicToolbarItemSpec(id: "tb-rep",     symbol: "arrow.triangle.2.circlepath",     label: "Replace")          { [weak self] in self?.onReplace?() }),
            .button(ClassicToolbarItemSpec(id: "tb-stamp",   symbol: "clock",                           label: "Insert date")      { [weak self] in self?.onInsertDateTime?() }),
            .separator,

            // Line-level edits
            .button(ClassicToolbarItemSpec(id: "tb-dupl",    symbol: "plus.square.on.square",           label: "Duplicate line")   { [weak self] in self?.onDuplicateLine?() }),
            .button(ClassicToolbarItemSpec(id: "tb-cutl",    symbol: "minus.square",                    label: "Delete line",
                                           destructive: true)                                                                      { [weak self] in self?.onDeleteLine?() }),
            .button(ClassicToolbarItemSpec(id: "tb-goto",    symbol: "arrow.down.to.line",              label: "Goto line")        { [weak self] in self?.onGotoLine?() }),
            .button(ClassicToolbarItemSpec(id: "tb-trim",    symbol: "text.alignleft",                  label: "Trim")             { [weak self] in self?.onTrim?() }),
            .button(ClassicToolbarItemSpec(id: "tb-sort",    symbol: "arrow.up.arrow.down",             label: "Sort")             { [weak self] in self?.onSort?() }),
            .separator,

            // View / toggles
            .button(ClassicToolbarItemSpec(id: "tb-docs",    symbol: "list.bullet",                     label: "Docs")             { [weak self] in self?.onDocs?() }),
            .button(ClassicToolbarItemSpec(id: "tb-cmp",     symbol: "rectangle.split.2x1",             label: "Compare")          { [weak self] in self?.onCompare?() }),
            .button(ClassicToolbarItemSpec(id: "tb-read",    symbol: readSymbol,                        label: "Read mode")        { [weak self] in self?.onToggleReadMode?(); self?.refresh() }),
            .button(ClassicToolbarItemSpec(id: "tb-zen",     symbol: "rectangle.compress.vertical",     label: "Zen mode")         { [weak self] in self?.onToggleZenMode?(); self?.refresh() }),
            .button(ClassicToolbarItemSpec(id: "tb-mouse",   symbol: "rectangle.and.hand.point.up.left", label: "Trackpad")        { [weak self] in self?.onToggleTrackpad?(); self?.refresh() }),
            .separator,

            // Settings / overflow
            .button(ClassicToolbarItemSpec(id: "tb-prefs",   symbol: "gear",                            label: "Preferences")      { [weak self] in self?.onPreferences?() }),
            .button(ClassicToolbarItemSpec(id: "tb-more",    symbol: "ellipsis",                        label: "More")             { [weak self] in self?.onMore?() }),
            .separator,

            // Destructive
            .button(ClassicToolbarItemSpec(id: "tb-del",     symbol: "trash",                           label: "Delete doc",
                                           destructive: true)                                                                      { [weak self] in self?.onDeleteDoc?() }),
        ]
    }

    private func rebuild() {
        topStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        bottomStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        buttonsById.removeAll(keepingCapacity: true)

        let all = items()
        let useTwoRows = rows == 2
        rowSeparator.isHidden = !useTwoRows
        bottomRow.isHidden = !useTwoRows

        let rowHeight: CGFloat = labelsVisible ? 44 : 30
        let rule: CGFloat = 1 / UIScreen.main.scale
        let totalHeight: CGFloat = useTwoRows ? (rowHeight * 2 + rule) : rowHeight
        heightConstraint?.constant = totalHeight + rule

        if useTwoRows {
            let half = (all.count + 1) / 2
            let top = Array(all.prefix(half))
            let bottom = Array(all.suffix(from: half))
            fill(stack: topStack, with: top)
            fill(stack: bottomStack, with: bottom)
        } else {
            fill(stack: topStack, with: all)
        }

        applyToggleState()
    }

    private func fill(stack: UIStackView, with items: [ClassicToolbarKind]) {
        for item in items {
            switch item {
            case .separator:
                let sep = UIView()
                sep.translatesAutoresizingMaskIntoConstraints = false
                sep.backgroundColor = palette.border
                sep.widthAnchor.constraint(equalToConstant: 1).isActive = true
                sep.heightAnchor.constraint(equalToConstant: 18).isActive = true
                let wrapper = UIView()
                wrapper.translatesAutoresizingMaskIntoConstraints = false
                wrapper.addSubview(sep)
                NSLayoutConstraint.activate([
                    wrapper.widthAnchor.constraint(equalToConstant: 8),
                    sep.centerXAnchor.constraint(equalTo: wrapper.centerXAnchor),
                    sep.centerYAnchor.constraint(equalTo: wrapper.centerYAnchor),
                ])
                stack.addArrangedSubview(wrapper)
            case .button(let spec):
                let button = ClassicToolbarButton(spec: spec, palette: palette, showLabel: labelsVisible)
                buttonsById[spec.id] = button
                stack.addArrangedSubview(button)
            }
        }
    }

    /// Re-tints toggleable buttons based on the current state providers.
    /// `tb-read` also swaps its icon between `eye` and `eye.slash`.
    private func applyToggleState() {
        if let readBtn = buttonsById["tb-read"] {
            let active = isReadMode?() ?? false
            readBtn.setActive(active, tint: palette.primary, inactiveTint: palette.foreground)
            readBtn.setSymbol(active ? "eye" : "eye.slash")
        }
        if let zenBtn = buttonsById["tb-zen"] {
            let active = isZenMode?() ?? false
            zenBtn.setActive(active, tint: palette.primary, inactiveTint: palette.foreground)
        }
        if let trackBtn = buttonsById["tb-mouse"] {
            let active = isTrackpadOn?() ?? false
            trackBtn.setActive(active, tint: palette.primary, inactiveTint: palette.foreground)
        }
    }
}

// MARK: - Private helpers

fileprivate struct ClassicToolbarItemSpec {
    let id: String
    let symbol: String
    let label: String
    let destructive: Bool
    let action: () -> Void

    init(id: String, symbol: String, label: String, destructive: Bool = false, action: @escaping () -> Void) {
        self.id = id
        self.symbol = symbol
        self.label = label
        self.destructive = destructive
        self.action = action
    }
}

fileprivate enum ClassicToolbarKind {
    case button(ClassicToolbarItemSpec)
    case separator
}

private final class ClassicToolbarButton: UIControl {
    private let iconView = UIImageView()
    private let label = UILabel()
    private let action: () -> Void
    private let specLabel: String
    private let baseTint: UIColor

    init(spec: ClassicToolbarItemSpec, palette: Palette, showLabel: Bool) {
        self.action = spec.action
        self.specLabel = spec.label
        self.baseTint = spec.destructive ? palette.destructive : palette.foreground
        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false
        isAccessibilityElement = true
        accessibilityTraits = .button
        accessibilityLabel = spec.label
        accessibilityHint = spec.label

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.contentMode = .scaleAspectFit
        iconView.image = UIImage(systemName: spec.symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .regular))
        iconView.tintColor = baseTint
        iconView.isUserInteractionEnabled = false
        addSubview(iconView)

        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = spec.label
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 10, weight: .regular)
        label.textColor = baseTint
        label.isHidden = !showLabel
        label.isUserInteractionEnabled = false
        addSubview(label)

        layer.cornerRadius = min(palette.radius, 4)

        let minWidth: CGFloat = showLabel ? 52 : 30
        let height: CGFloat = showLabel ? 40 : 26

        NSLayoutConstraint.activate([
            widthAnchor.constraint(greaterThanOrEqualToConstant: minWidth),
            heightAnchor.constraint(equalToConstant: height),

            iconView.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            iconView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 18),
            iconView.heightAnchor.constraint(equalToConstant: 18),

            label.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 2),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 4),
            label.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -4),
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
        ])

        addTarget(self, action: #selector(tapped), for: .touchUpInside)

        // Long-press surfaces the label via the accessibility announcer.
        // VoiceOver users already get this via `accessibilityHint`.
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(longPressFired(_:)))
        longPress.minimumPressDuration = 0.4
        addGestureRecognizer(longPress)
    }

    required init?(coder: NSCoder) { fatalError() }

    override var isHighlighted: Bool {
        didSet {
            backgroundColor = isHighlighted ? UIColor.label.withAlphaComponent(0.08) : .clear
        }
    }

    @objc private func tapped() { action() }

    @objc private func longPressFired(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        UIAccessibility.post(notification: .announcement, argument: specLabel)
    }

    /// Flips tint between the palette's primary (active) and the button's base
    /// tint (inactive) — used by `ClassicToolbar.applyToggleState()`.
    /// `inactiveTint` is accepted for API symmetry but `baseTint` (set at init
    /// from the spec's destructive flag) always wins for the inactive color so
    /// a destructive button stays destructive-colored when untoggled.
    func setActive(_ active: Bool, tint: UIColor, inactiveTint: UIColor) {
        _ = inactiveTint
        let color = active ? tint : baseTint
        iconView.tintColor = color
        label.textColor = color
    }

    func setSymbol(_ name: String) {
        iconView.image = UIImage(systemName: name, withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .regular))
    }
}
