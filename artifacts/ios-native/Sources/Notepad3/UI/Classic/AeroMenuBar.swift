import UIKit

/// Aero-era horizontal menu bar: File · Edit · View · Tools · Help. Each button
/// presents a `UIMenu` of actions mirroring the RN classic layout. Business
/// logic lives in the caller — the bar only fires closures.
///
/// The chrome draws a subtle vertical gradient using the active palette's
/// `chromeGradientStart/End` pair, matching the RN `LinearGradient` behind
/// `styles.menuBar`.
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

        let specs: [(String, () -> UIMenu)] = [
            ("File",  { [weak self] in self?.fileMenu()  ?? UIMenu() }),
            ("Edit",  { [weak self] in self?.editMenu()  ?? UIMenu() }),
            ("View",  { [weak self] in self?.viewMenu()  ?? UIMenu() }),
            ("Tools", { [weak self] in self?.toolsMenu() ?? UIMenu() }),
            ("Help",  { [weak self] in self?.helpMenu()  ?? UIMenu() }),
        ]

        for (title, provider) in specs {
            let button = makeMenuButton(title: title, provider: provider)
            buttons.append(button)
            stack.addArrangedSubview(button)
        }

        // Trailing filler keeps buttons hugged to the leading edge, matching
        // the RN menu bar which left-aligns its items.
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

    private func makeMenuButton(title: String, provider: @escaping () -> UIMenu) -> UIButton {
        // UIDeferredMenuElement.uncached ensures the menu is rebuilt each tap
        // so checkmarks reflect the latest caller state.
        let deferred = UIDeferredMenuElement.uncached { completion in
            completion(provider().children)
        }
        let rootMenu = UIMenu(title: title, children: [deferred])
        rootMenu.preferredElementSize = .small

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
        button.showsMenuAsPrimaryAction = true
        button.menu = rootMenu
        button.accessibilityLabel = title
        button.accessibilityTraits = [.button]
        return button
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

    // MARK: - Menus

    private func fileMenu() -> UIMenu {
        UIMenu(title: "File", children: [
            UIAction(title: "New", image: UIImage(systemName: "doc.badge.plus")) { [weak self] _ in self?.onNew?() },
            UIAction(title: "Open…", image: UIImage(systemName: "folder")) { [weak self] _ in self?.onOpen?() },
            UIAction(title: "Save…", image: UIImage(systemName: "square.and.arrow.down")) { [weak self] _ in self?.onSave?() },
            UIMenu(options: .displayInline, children: [
                UIAction(title: "Duplicate", image: UIImage(systemName: "plus.square.on.square")) { [weak self] _ in self?.onDuplicateDoc?() },
            ]),
            UIMenu(options: .displayInline, children: [
                UIAction(title: "Close", image: UIImage(systemName: "xmark")) { [weak self] _ in self?.onClose?() },
                UIAction(title: "Close others", image: UIImage(systemName: "xmark.rectangle")) { [weak self] _ in self?.onCloseOthers?() },
            ]),
        ])
    }

    private func editMenu() -> UIMenu {
        let undoRedo = UIMenu(options: .displayInline, children: [
            UIAction(title: "Undo", image: UIImage(systemName: "arrow.uturn.backward")) { [weak self] _ in self?.onUndo?() },
            UIAction(title: "Redo", image: UIImage(systemName: "arrow.uturn.forward")) { [weak self] _ in self?.onRedo?() },
        ])
        let clipboard = UIMenu(options: .displayInline, children: [
            UIAction(title: "Cut", image: UIImage(systemName: "scissors")) { [weak self] _ in self?.onCut?() },
            UIAction(title: "Copy", image: UIImage(systemName: "doc.on.doc")) { [weak self] _ in self?.onCopy?() },
            UIAction(title: "Paste", image: UIImage(systemName: "doc.on.clipboard")) { [weak self] _ in self?.onPaste?() },
            UIAction(title: "Paste", image: UIImage(systemName: "doc.on.clipboard.fill")) { [weak self] _ in self?.onPaste?() },
        ])
        let selection = UIMenu(options: .displayInline, children: [
            UIAction(title: "Select All", image: UIImage(systemName: "selection.pin.in.out")) { [weak self] _ in self?.onSelectAll?() },
            UIAction(title: "Find", image: UIImage(systemName: "magnifyingglass")) { [weak self] _ in self?.onFind?() },
            UIAction(title: "Go to line…", image: UIImage(systemName: "arrow.right.to.line")) { [weak self] _ in self?.onGotoLine?() },
        ])
        let text = UIMenu(options: .displayInline, children: [
            UIAction(title: "Insert date/time", image: UIImage(systemName: "clock")) { [weak self] _ in self?.onInsertDateTime?() },
            UIAction(title: "Sort lines", image: UIImage(systemName: "arrow.up.arrow.down")) { [weak self] _ in self?.onSortLines?() },
            UIAction(title: "Trim trailing spaces", image: UIImage(systemName: "scissors")) { [weak self] _ in self?.onTrimSpaces?() },
            UIAction(title: "Duplicate line", image: UIImage(systemName: "plus.square.on.square")) { [weak self] _ in self?.onDuplicateLine?() },
            UIAction(title: "Delete line", image: UIImage(systemName: "minus.square"), attributes: .destructive) { [weak self] _ in self?.onDeleteLine?() },
        ])
        return UIMenu(title: "Edit", children: [undoRedo, clipboard, selection, text])
    }

    private func viewMenu() -> UIMenu {
        let toolbarOpen = isToolbarOpen?() ?? true
        let labelsVisible = isToolbarLabelsVisible?() ?? false
        let rowsDouble = isToolbarRowsDouble?() ?? false
        let zen = isZenMode?() ?? false
        let compare = isCompareOpen?() ?? false

        let toolbarGroup = UIMenu(options: .displayInline, children: [
            actionWithCheck(title: "Toolbar", checked: toolbarOpen) { [weak self] in self?.onToggleToolbar?() },
            actionWithCheck(title: "Show labels", checked: labelsVisible) { [weak self] in self?.onToggleToolbarLabels?() },
        ])
        let rowsGroup = UIMenu(title: "Toolbar rows", image: UIImage(systemName: "rectangle.split.1x2"), children: [
            actionWithCheck(title: "Single row", checked: !rowsDouble) { [weak self] in self?.onSetToolbarRowsSingle?() },
            actionWithCheck(title: "Two rows", checked: rowsDouble) { [weak self] in self?.onSetToolbarRowsDouble?() },
        ])
        let viewModes = UIMenu(options: .displayInline, children: [
            actionWithCheck(title: "Zen mode", checked: zen) { [weak self] in self?.onToggleZen?() },
            actionWithCheck(title: "Compare", checked: compare) { [weak self] in self?.onToggleCompare?() },
        ])
        let layout = UIMenu(options: .displayInline, children: [
            UIAction(title: "Switch layout to mobile", image: UIImage(systemName: "iphone")) { [weak self] _ in self?.onSwitchToMobileLayout?() },
        ])
        return UIMenu(title: "View", children: [toolbarGroup, rowsGroup, viewModes, layout])
    }

    private func toolsMenu() -> UIMenu {
        let prefs = UIAction(title: "Preferences…", image: UIImage(systemName: "gear")) { [weak self] _ in self?.onPreferences?() }
        let current = currentTheme?() ?? .classic

        let quickThemes = ThemeName.allCases
            .filter { $0 != .custom }
            .map { name in
                actionWithCheck(title: label(for: name), checked: name == current) { [weak self] in
                    self?.onPickTheme?(name)
                }
            }
        let themeMenu = UIMenu(title: "Theme", image: UIImage(systemName: "paintpalette"), children: quickThemes)
        return UIMenu(title: "Tools", children: [prefs, themeMenu])
    }

    private func helpMenu() -> UIMenu {
        UIMenu(title: "Help", children: [
            UIAction(title: "About Notepad 3++", image: UIImage(systemName: "info.circle")) { [weak self] _ in self?.onAbout?() },
            UIAction(title: "Version", image: UIImage(systemName: "tag")) { [weak self] _ in self?.onVersion?() },
        ])
    }

    private func actionWithCheck(title: String, checked: Bool, handler: @escaping () -> Void) -> UIAction {
        let action = UIAction(title: title) { _ in handler() }
        action.state = checked ? .on : .off
        return action
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
