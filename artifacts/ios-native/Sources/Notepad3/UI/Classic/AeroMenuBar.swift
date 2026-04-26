import UIKit

/// Aero-era horizontal menu bar: File · Edit · View · Tools · Help. Each
/// button presents a `ClassicMenuPopover` — a Windows-classic-styled flat
/// dropdown — instead of UIKit's stock `UIMenu`. Business logic lives in
/// the caller; the bar only fires closures.
///
/// The chrome draws a subtle vertical gradient using the active palette's
/// `chromeGradientStart/End` pair.
final class AeroMenuBar: UIView {
    // File
    var onNew: (() -> Void)?
    var onOpen: (() -> Void)?
    var onSave: (() -> Void)?
    var onDuplicateDoc: (() -> Void)?
    var onClose: (() -> Void)?
    var onCloseOthers: (() -> Void)?

    // Edit
    var onUndo: (() -> Void)?
    var onRedo: (() -> Void)?
    var onCut: (() -> Void)?
    var onCopy: (() -> Void)?
    var onPaste: (() -> Void)?
    var onSelectAll: (() -> Void)?
    var onFind: (() -> Void)?
    var onGotoLine: (() -> Void)?
    var onInsertDateTime: (() -> Void)?
    var onSortLines: (() -> Void)?
    var onTrimSpaces: (() -> Void)?
    var onDuplicateLine: (() -> Void)?
    var onDeleteLine: (() -> Void)?

    // View
    var onToggleToolbar: (() -> Void)?
    var onToggleToolbarLabels: (() -> Void)?
    var onSetToolbarRowsSingle: (() -> Void)?
    var onSetToolbarRowsDouble: (() -> Void)?
    var onToggleZen: (() -> Void)?
    var onToggleCompare: (() -> Void)?
    var onSwitchToMobileLayout: (() -> Void)?

    // Tools
    var onPreferences: (() -> Void)?
    var onPickTheme: ((ThemeName) -> Void)?

    // Help
    var onAbout: (() -> Void)?
    var onVersion: (() -> Void)?

    // Checked-state providers — the bar calls these when building the menu so
    // dropdown checkmarks reflect the caller's current state at open time.
    var isToolbarOpen: (() -> Bool)?
    var isToolbarLabelsVisible: (() -> Bool)?
    var isToolbarRowsDouble: (() -> Bool)?
    var isZenMode: (() -> Bool)?
    var isCompareOpen: (() -> Bool)?
    var currentTheme: (() -> ThemeName)?

    private let gradient = CAGradientLayer()
    private let separator = UIView()
    private let stack = UIStackView()
    private var palette: Palette = .classic
    private var buttons: [UIButton] = []
    private var rowProviders: [ObjectIdentifier: () -> [ClassicMenuPopover.Row]] = [:]
    private var currentPopover: ClassicMenuPopover?

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

        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.alignment = .fill
        stack.distribution = .fill
        stack.spacing = 0
        addSubview(stack)

        separator.translatesAutoresizingMaskIntoConstraints = false
        addSubview(separator)

        let specs: [(String, () -> [ClassicMenuPopover.Row])] = [
            ("File",  { [weak self] in self?.fileRows()  ?? [] }),
            ("Edit",  { [weak self] in self?.editRows()  ?? [] }),
            ("View",  { [weak self] in self?.viewRows()  ?? [] }),
            ("Tools", { [weak self] in self?.toolsRows() ?? [] }),
            ("Help",  { [weak self] in self?.helpRows()  ?? [] }),
        ]

        for (title, provider) in specs {
            let button = makeMenuButton(title: title, provider: provider)
            buttons.append(button)
            stack.addArrangedSubview(button)
        }

        // Trailing filler keeps buttons hugged to the leading edge.
        let filler = UIView()
        filler.translatesAutoresizingMaskIntoConstraints = false
        filler.setContentHuggingPriority(.defaultLow, for: .horizontal)
        stack.addArrangedSubview(filler)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 24),

            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -2),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),

            separator.leadingAnchor.constraint(equalTo: leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: bottomAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale),
        ])
    }

    private func makeMenuButton(title: String, provider: @escaping () -> [ClassicMenuPopover.Row]) -> UIButton {
        var cfg = UIButton.Configuration.plain()
        cfg.title = title
        cfg.baseForegroundColor = palette.foreground
        cfg.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8)
        cfg.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var out = incoming
            out.font = .systemFont(ofSize: 12, weight: .medium)
            return out
        }

        let button = UIButton(type: .system)
        button.configuration = cfg
        button.accessibilityLabel = title
        button.accessibilityTraits = [.button]
        button.addTarget(self, action: #selector(menuButtonTapped(_:)), for: .touchUpInside)
        rowProviders[ObjectIdentifier(button)] = provider
        return button
    }

    @objc private func menuButtonTapped(_ sender: UIButton) {
        // Tapping the same menu button while its popover is open dismisses it.
        let wasOpen = currentPopover != nil
        currentPopover?.dismiss()
        currentPopover = nil
        if wasOpen { return }

        guard let provider = rowProviders[ObjectIdentifier(sender)] else { return }
        let popover = ClassicMenuPopover(
            rows: provider(),
            palette: palette,
            anchor: sender
        ) { [weak self] in
            self?.currentPopover = nil
        }
        popover.present()
        currentPopover = popover
    }

    func applyPalette(_ p: Palette) {
        palette = p
        gradient.colors = [p.chromeGradientStart.cgColor, p.chromeGradientEnd.cgColor]
        separator.backgroundColor = p.border
        for button in buttons {
            var cfg = button.configuration
            cfg?.baseForegroundColor = p.foreground
            button.configuration = cfg
            button.tintColor = p.foreground
        }
    }

    // MARK: - Menu rows

    private func fileRows() -> [ClassicMenuPopover.Row] {
        [
            .action(title: "New",          symbol: "doc.badge.plus",          checked: false, destructive: false) { [weak self] in self?.onNew?() },
            .action(title: "Open…",        symbol: "folder",                  checked: false, destructive: false) { [weak self] in self?.onOpen?() },
            .action(title: "Save…",        symbol: "square.and.arrow.down",   checked: false, destructive: false) { [weak self] in self?.onSave?() },
            .divider,
            .action(title: "Duplicate",    symbol: "plus.square.on.square",   checked: false, destructive: false) { [weak self] in self?.onDuplicateDoc?() },
            .divider,
            .action(title: "Close",        symbol: "xmark",                   checked: false, destructive: false) { [weak self] in self?.onClose?() },
            .action(title: "Close others", symbol: "xmark.rectangle",         checked: false, destructive: false) { [weak self] in self?.onCloseOthers?() },
        ]
    }

    private func editRows() -> [ClassicMenuPopover.Row] {
        [
            .action(title: "Undo",                 symbol: "arrow.uturn.backward",     checked: false, destructive: false) { [weak self] in self?.onUndo?() },
            .action(title: "Redo",                 symbol: "arrow.uturn.forward",      checked: false, destructive: false) { [weak self] in self?.onRedo?() },
            .divider,
            .action(title: "Cut",                  symbol: "scissors",                 checked: false, destructive: false) { [weak self] in self?.onCut?() },
            .action(title: "Copy",                 symbol: "doc.on.doc",               checked: false, destructive: false) { [weak self] in self?.onCopy?() },
            .action(title: "Paste",                symbol: "doc.on.clipboard",         checked: false, destructive: false) { [weak self] in self?.onPaste?() },
            .divider,
            .action(title: "Select All",           symbol: "selection.pin.in.out",     checked: false, destructive: false) { [weak self] in self?.onSelectAll?() },
            .action(title: "Find",                 symbol: "magnifyingglass",          checked: false, destructive: false) { [weak self] in self?.onFind?() },
            .action(title: "Go to line…",          symbol: "arrow.right.to.line",      checked: false, destructive: false) { [weak self] in self?.onGotoLine?() },
            .divider,
            .action(title: "Insert date/time",     symbol: "clock",                    checked: false, destructive: false) { [weak self] in self?.onInsertDateTime?() },
            .action(title: "Sort lines",           symbol: "arrow.up.arrow.down",      checked: false, destructive: false) { [weak self] in self?.onSortLines?() },
            .action(title: "Trim trailing spaces", symbol: "scissors",                 checked: false, destructive: false) { [weak self] in self?.onTrimSpaces?() },
            .action(title: "Duplicate line",       symbol: "plus.square.on.square",    checked: false, destructive: false) { [weak self] in self?.onDuplicateLine?() },
            .action(title: "Delete line",          symbol: "minus.square",             checked: false, destructive: true)  { [weak self] in self?.onDeleteLine?() },
        ]
    }

    private func viewRows() -> [ClassicMenuPopover.Row] {
        let toolbarOpen   = isToolbarOpen?()           ?? true
        let labelsVisible = isToolbarLabelsVisible?()  ?? false
        let rowsDouble    = isToolbarRowsDouble?()     ?? false
        let zen           = isZenMode?()               ?? false
        let compare       = isCompareOpen?()           ?? false

        let rowsSubmenu: [ClassicMenuPopover.Row] = [
            .action(title: "Single row", symbol: "rectangle",              checked: !rowsDouble, destructive: false) { [weak self] in self?.onSetToolbarRowsSingle?() },
            .action(title: "Two rows",   symbol: "rectangle.split.1x2",    checked: rowsDouble,  destructive: false) { [weak self] in self?.onSetToolbarRowsDouble?() },
        ]

        return [
            .action(title: "Toolbar",                  symbol: "rectangle.topthird.inset.filled", checked: toolbarOpen,   destructive: false) { [weak self] in self?.onToggleToolbar?() },
            .action(title: "Show labels",              symbol: "textformat.size",                 checked: labelsVisible, destructive: false) { [weak self] in self?.onToggleToolbarLabels?() },
            .divider,
            .submenu(title: "Toolbar rows", symbol: "rectangle.split.1x2", children: rowsSubmenu),
            .divider,
            .action(title: "Zen mode",                 symbol: "rectangle.compress.vertical",     checked: zen,           destructive: false) { [weak self] in self?.onToggleZen?() },
            .action(title: "Compare",                  symbol: "rectangle.split.2x1",             checked: compare,       destructive: false) { [weak self] in self?.onToggleCompare?() },
            .divider,
            .action(title: "Switch layout to mobile",  symbol: "iphone",                          checked: false,         destructive: false) { [weak self] in self?.onSwitchToMobileLayout?() },
        ]
    }

    private func toolsRows() -> [ClassicMenuPopover.Row] {
        let current = currentTheme?() ?? .classic
        let themeChildren: [ClassicMenuPopover.Row] = ThemeName.allCases
            .filter { $0 != .custom }
            .map { name in
                .action(title: label(for: name), symbol: nil, checked: name == current, destructive: false) { [weak self] in
                    self?.onPickTheme?(name)
                }
            }
        return [
            .action(title: "Preferences…", symbol: "gear", checked: false, destructive: false) { [weak self] in self?.onPreferences?() },
            .divider,
            .submenu(title: "Theme", symbol: "paintpalette", children: themeChildren),
        ]
    }

    private func helpRows() -> [ClassicMenuPopover.Row] {
        [
            .action(title: "About Notepad 3++", symbol: "info.circle", checked: false, destructive: false) { [weak self] in self?.onAbout?() },
            .action(title: "Version",           symbol: "tag",         checked: false, destructive: false) { [weak self] in self?.onVersion?() },
        ]
    }

    private func label(for name: ThemeName) -> String {
        switch name {
        case .classic:   return "Classic"
        case .light:     return "Light"
        case .dark:      return "Dark"
        case .retro:     return "Retro"
        case .modern:    return "Modern"
        case .cyberpunk: return "Cyberpunk"
        case .sunset:    return "Rachel's Sunset"
        case .custom:    return "Custom"
        }
    }
}
