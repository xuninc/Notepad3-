import UIKit

/// Minimal settings screen. Currently exposes theme selection; future commits
/// will add starter-content, accessory-rows, layout-mode, etc. Presented
/// modally by the editor; applies changes live via ThemeController.
final class SettingsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private let themes = ThemeController.shared
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)

    private struct Section { let title: String; let rows: [Row] }
    private enum Row {
        case themePreference(ThemePreference, label: String, hint: String?)
    }

    private var sections: [Section] {
        let explicit: [Row] = ThemeName.allCases.map { name in
            .themePreference(.named(name), label: label(for: name), hint: hint(for: name))
        }
        let system: Row = .themePreference(.system, label: "Match system", hint: "Flip light ↔ dark with the OS")
        return [
            Section(title: "Theme", rows: [system] + explicit)
        ]
    }

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
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        applyPalette()
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

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].rows.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "row", for: indexPath)
        let row = sections[indexPath.section].rows[indexPath.row]
        let palette = themes.palette

        switch row {
        case .themePreference(let pref, let label, let hint):
            var cfg = cell.defaultContentConfiguration()
            cfg.text = label
            cfg.secondaryText = hint
            cfg.textProperties.color = palette.foreground
            cfg.secondaryTextProperties.color = palette.mutedForeground
            cell.contentConfiguration = cfg
            cell.accessoryType = (pref == themes.preference) ? .checkmark : .none
            cell.backgroundColor = palette.card
            cell.tintColor = palette.primary
        }

        return cell
    }

    // MARK: - Delegate

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch sections[indexPath.section].rows[indexPath.row] {
        case .themePreference(let pref, _, _):
            themes.setPreference(pref)
            applyPalette()
            tableView.reloadData()
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
        case .sunset:    return "Sunset"
        case .custom:    return "Custom"
        }
    }

    private func hint(for name: ThemeName) -> String? {
        switch name {
        case .classic:   return "Aero-era window chrome"
        case .light:     return "Clean and bright"
        case .dark:      return "Easy on the eyes"
        case .retro:     return "Windows 95 chrome"
        case .modern:    return "Soft contemporary"
        case .cyberpunk: return "Neon on black"
        case .sunset:    return "Warm gradient"
        case .custom:    return "Your own palette"
        }
    }
}
