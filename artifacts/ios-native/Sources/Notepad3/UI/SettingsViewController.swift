import UIKit

/// Preferences screen. 1-for-1 port of the RN prefs modal (`app/index.tsx`
/// `prefsOpen`/`modalSection`), adapted to an `insetGrouped` UITableView:
///
///  - Theme: "Match system" + all named themes. `.custom` only appears
///    after the user has saved at least one custom palette override.
///  - Appearance: tabs layout, toolbar labels switch, toolbar rows,
///    keyboard accessory rows.
///  - Layout: mobile / classic.
///  - Starter content: welcome scratchpad / blank page.
///  - Custom palette: pushes `CustomPaletteBuilderViewController`.
///
/// All changes persist immediately via `ThemeController` / `Preferences` so
/// observers (editor chrome, tab strip, keyboard accessory) repaint live.
final class SettingsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    // MARK: - Model

    private enum Row {
        case themePreference(ThemePreference, label: String, hint: String?)
        case tabsLayoutSegment
        case toolbarLabelsSwitch
        case toolbarRowsSegment
        case accessoryRowsSegment
        case layoutModeSegment
        case starterContentSegment
        case customPaletteButton
    }

    private struct Section {
        let title: String
        let footer: String?
        let rows: [Row]
    }

    private let themes = ThemeController.shared
    private let prefs = Preferences.shared
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)

    private var prefsToken: UUID?
    private var themesToken: UUID?

    // MARK: - Sections

    private var sections: [Section] {
        // `.custom` is hidden until the user has set at least one override.
        let hasCustom = !prefs.customPalette.isEmpty
        let explicit: [Row] = ThemeName.allCases
            .filter { name in name != .custom || hasCustom }
            .map { name in .themePreference(.named(name), label: label(for: name), hint: hint(for: name)) }
        let system: Row = .themePreference(.system, label: "Match system", hint: "Flip light and dark with the OS")

        return [
            Section(title: "Theme", footer: nil, rows: [system] + explicit),
            Section(
                title: "Appearance",
                footer: "Toolbar labels always show text under each icon.",
                rows: [
                    .tabsLayoutSegment,
                    .toolbarLabelsSwitch,
                    .toolbarRowsSegment,
                    .accessoryRowsSegment,
                ]
            ),
            Section(
                title: "Layout",
                footer: "Mobile uses a bottom bar + sheet; Classic uses desktop-style menus.",
                rows: [.layoutModeSegment]
            ),
            Section(
                title: "Starter content",
                footer: nil,
                rows: [.starterContentSegment]
            ),
            Section(
                title: "Custom palette",
                footer: "Override individual colors. Selecting a custom palette makes the \u{201C}Custom\u{201D} theme available above.",
                rows: [.customPaletteButton]
            ),
        ]
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Preferences"

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(dismissSelf)
        )

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "row")
        tableView.register(SegmentedRowCell.self, forCellReuseIdentifier: "segment")
        tableView.register(SwitchRowCell.self, forCellReuseIdentifier: "switch")
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        prefsToken = prefs.observe { [weak self] in self?.reload() }
        themesToken = themes.observe { [weak self] in self?.reload() }

        applyPalette()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
    }

    deinit {
        if let id = prefsToken { prefs.unobserve(id) }
        if let id = themesToken { themes.unobserve(id) }
    }

    private func reload() {
        applyPalette()
        tableView.reloadData()
    }

    @objc private func dismissSelf() {
        dismiss(animated: true)
    }

    private func applyPalette() {
        let palette = themes.palette
        view.backgroundColor = palette.background
        tableView.backgroundColor = palette.background
        let nav = UINavigationBarAppearance()
        nav.configureWithDefaultBackground()
        nav.backgroundColor = palette.card
        nav.titleTextAttributes = [.foregroundColor: palette.foreground]
        navigationItem.standardAppearance = nav
        navigationItem.scrollEdgeAppearance = nav
        navigationController?.navigationBar.tintColor = palette.primary
    }

    // MARK: - Data source

    func numberOfSections(in tableView: UITableView) -> Int { sections.count }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        sections[section].title
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        sections[section].footer
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].rows.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = sections[indexPath.section].rows[indexPath.row]
        let palette = themes.palette

        switch row {
        case .themePreference(let pref, let label, let hint):
            let cell = tableView.dequeueReusableCell(withIdentifier: "row", for: indexPath)
            var cfg = cell.defaultContentConfiguration()
            cfg.text = label
            cfg.secondaryText = hint
            cfg.textProperties.color = palette.foreground
            cfg.secondaryTextProperties.color = palette.mutedForeground
            cell.contentConfiguration = cfg
            cell.accessoryType = (pref == themes.preference) ? .checkmark : .none
            cell.backgroundColor = palette.card
            cell.tintColor = palette.primary
            cell.selectionStyle = .default
            return cell

        case .tabsLayoutSegment:
            let cell = tableView.dequeueReusableCell(withIdentifier: "segment", for: indexPath) as! SegmentedRowCell
            cell.configure(
                title: "Tabs layout",
                options: ["Tabs", "Dropdown list"],
                selectedIndex: prefs.tabsLayout == .tabs ? 0 : 1,
                palette: palette
            ) { [weak self] idx in
                self?.prefs.tabsLayout = (idx == 0) ? .tabs : .list
            }
            return cell

        case .toolbarLabelsSwitch:
            let cell = tableView.dequeueReusableCell(withIdentifier: "switch", for: indexPath) as! SwitchRowCell
            cell.configure(
                title: "Show text under icons",
                isOn: prefs.toolbarLabels,
                palette: palette
            ) { [weak self] on in
                self?.prefs.toolbarLabels = on
            }
            return cell

        case .toolbarRowsSegment:
            let cell = tableView.dequeueReusableCell(withIdentifier: "segment", for: indexPath) as! SegmentedRowCell
            cell.configure(
                title: "Toolbar rows",
                options: ["1 row", "2 rows"],
                selectedIndex: prefs.toolbarRows == .single ? 0 : 1,
                palette: palette
            ) { [weak self] idx in
                self?.prefs.toolbarRows = (idx == 0) ? .single : .double
            }
            return cell

        case .accessoryRowsSegment:
            let cell = tableView.dequeueReusableCell(withIdentifier: "segment", for: indexPath) as! SegmentedRowCell
            cell.configure(
                title: "Keyboard accessory rows",
                options: ["1 row", "2 rows"],
                selectedIndex: prefs.accessoryRows == .single ? 0 : 1,
                palette: palette
            ) { [weak self] idx in
                self?.prefs.accessoryRows = (idx == 0) ? .single : .double
            }
            return cell

        case .layoutModeSegment:
            let cell = tableView.dequeueReusableCell(withIdentifier: "segment", for: indexPath) as! SegmentedRowCell
            cell.configure(
                title: "Layout mode",
                options: ["Mobile", "Classic"],
                selectedIndex: prefs.layoutMode == .mobile ? 0 : 1,
                palette: palette
            ) { [weak self] idx in
                self?.prefs.layoutMode = (idx == 0) ? .mobile : .classic
            }
            return cell

        case .starterContentSegment:
            let cell = tableView.dequeueReusableCell(withIdentifier: "segment", for: indexPath) as! SegmentedRowCell
            cell.configure(
                title: "New documents",
                options: ["Welcome scratchpad", "Blank page"],
                selectedIndex: prefs.starterContent == .welcome ? 0 : 1,
                palette: palette
            ) { [weak self] idx in
                self?.prefs.starterContent = (idx == 0) ? .welcome : .blank
            }
            return cell

        case .customPaletteButton:
            let cell = tableView.dequeueReusableCell(withIdentifier: "row", for: indexPath)
            var cfg = cell.defaultContentConfiguration()
            cfg.text = "Open custom palette builder"
            cfg.secondaryText = prefs.customPalette.isEmpty
                ? "No overrides yet"
                : "\(prefs.customPalette.count) color\(prefs.customPalette.count == 1 ? "" : "s") overridden"
            cfg.image = UIImage(systemName: "paintpalette")
            cfg.textProperties.color = palette.foreground
            cfg.secondaryTextProperties.color = palette.mutedForeground
            cfg.imageProperties.tintColor = palette.primary
            cell.contentConfiguration = cfg
            cell.accessoryType = .disclosureIndicator
            cell.backgroundColor = palette.card
            cell.tintColor = palette.primary
            cell.selectionStyle = .default
            return cell
        }
    }

    // MARK: - Delegate

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch sections[indexPath.section].rows[indexPath.row] {
        case .themePreference(let pref, _, _):
            themes.setPreference(pref)
            reload()
        case .customPaletteButton:
            let builder = CustomPaletteBuilderViewController()
            if navigationController != nil {
                navigationController?.pushViewController(builder, animated: true)
            } else {
                let nav = UINavigationController(rootViewController: builder)
                nav.modalPresentationStyle = .formSheet
                present(nav, animated: true)
            }
        default:
            break // segmented / switch rows handle their own selection
        }
    }

    // MARK: - Labels

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

    private func hint(for name: ThemeName) -> String? {
        switch name {
        case .classic:   return "Aero-era window chrome"
        case .light:     return "Clean and bright"
        case .dark:      return "Easy on the eyes"
        case .retro:     return "Windows 95 chrome"
        case .modern:    return "Soft, rounded, indigo"
        case .cyberpunk: return "Neon magenta and cyan"
        case .sunset:    return "Orange, turquoise and hot pink"
        case .custom:    return "Your own palette"
        }
    }
}

// MARK: - Segmented row cell

/// Two-line layout: title on top, full-width `UISegmentedControl` below.
/// Uses a closure for change callbacks so the owner doesn't need to manage
/// tags across row dequeues.
private final class SegmentedRowCell: UITableViewCell {
    private let titleLabel = UILabel()
    private var segmented = UISegmentedControl(items: [])
    private var onChange: ((Int) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none

        titleLabel.font = .preferredFont(forTextStyle: .subheadline)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.numberOfLines = 1

        segmented.translatesAutoresizingMaskIntoConstraints = false
        segmented.addTarget(self, action: #selector(changed), for: .valueChanged)

        contentView.addSubview(titleLabel)
        contentView.addSubview(segmented)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),

            segmented.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            segmented.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            segmented.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            segmented.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor),
        ])
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    func configure(
        title: String,
        options: [String],
        selectedIndex: Int,
        palette: Palette,
        onChange: @escaping (Int) -> Void
    ) {
        titleLabel.text = title
        titleLabel.textColor = palette.foreground

        // Replace segments in-place to avoid constraint thrash.
        segmented.removeAllSegments()
        for (i, opt) in options.enumerated() {
            segmented.insertSegment(withTitle: opt, at: i, animated: false)
        }
        segmented.selectedSegmentIndex = selectedIndex
        segmented.selectedSegmentTintColor = palette.primary
        segmented.setTitleTextAttributes([.foregroundColor: palette.foreground], for: .normal)
        segmented.setTitleTextAttributes([.foregroundColor: palette.primaryForeground], for: .selected)

        backgroundColor = palette.card
        self.onChange = onChange
    }

    @objc private func changed() {
        onChange?(segmented.selectedSegmentIndex)
    }
}

// MARK: - Switch row cell

private final class SwitchRowCell: UITableViewCell {
    private let titleLabel = UILabel()
    private let toggle = UISwitch()
    private var onChange: ((Bool) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none

        titleLabel.font = .preferredFont(forTextStyle: .body)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        titleLabel.numberOfLines = 1

        toggle.translatesAutoresizingMaskIntoConstraints = false
        toggle.addTarget(self, action: #selector(changed), for: .valueChanged)

        contentView.addSubview(titleLabel)
        contentView.addSubview(toggle)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            titleLabel.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: toggle.leadingAnchor, constant: -12),

            toggle.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            toggle.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
        ])
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    func configure(
        title: String,
        isOn: Bool,
        palette: Palette,
        onChange: @escaping (Bool) -> Void
    ) {
        titleLabel.text = title
        titleLabel.textColor = palette.foreground
        toggle.isOn = isOn
        toggle.onTintColor = palette.primary
        backgroundColor = palette.card
        self.onChange = onChange
    }

    @objc private func changed() {
        onChange?(toggle.isOn)
    }
}
