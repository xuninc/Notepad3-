import UIKit

/// Custom palette builder — one row per palette field, each tapping into a
/// `UIColorPickerViewController`. Mirrors the RN modal's custom-palette
/// section (`app/index.tsx`: `CUSTOM_PALETTE_KEYS`, `customPaletteLabels`,
/// `setCustomColor`, `resetCustomPalette`).
///
/// Selections write through to `Preferences.shared.customPalette` as hex
/// strings so they round-trip cleanly and can be serialized to UserDefaults.
final class CustomPaletteBuilderViewController: UIViewController,
    UITableViewDataSource, UITableViewDelegate,
    UIColorPickerViewControllerDelegate
{
    // MARK: - Palette field metadata

    /// The user-editable palette fields, in display order.
    ///
    /// This set intentionally mirrors the subset of iOS `Palette` that's most
    /// useful to override (everything the RN port exposes plus a couple the
    /// iOS chrome actively uses). The full list is load-bearing — changing it
    /// invalidates stored overrides for removed keys, so treat it as API.
    static let fields: [Field] = [
        .init(key: "background",         label: "Background",        hint: "Main app surface"),
        .init(key: "foreground",         label: "Text",              hint: "Primary text color"),
        .init(key: "card",               label: "Card",              hint: "Navigation and cell fills"),
        .init(key: "primary",            label: "Primary",           hint: "Buttons, active tab"),
        .init(key: "primaryForeground",  label: "Primary text",      hint: "Text on primary fills"),
        .init(key: "secondary",          label: "Secondary",         hint: "Soft button fills"),
        .init(key: "muted",              label: "Muted",             hint: "Subtle backgrounds"),
        .init(key: "mutedForeground",    label: "Muted text",        hint: "Secondary text"),
        .init(key: "accent",             label: "Accent",            hint: "Highlight and stamps"),
        .init(key: "border",             label: "Borders",           hint: "Frames and dividers"),
        .init(key: "editorBackground",   label: "Editor",            hint: "Text editing surface"),
        .init(key: "editorGutter",       label: "Editor gutter",     hint: "Line number column"),
    ]

    struct Field {
        let key: String
        let label: String
        let hint: String
    }

    // MARK: - State

    private let prefs = Preferences.shared
    private let themes = ThemeController.shared

    /// Live working copy. `viewDidLoad` seeds this from persisted overrides
    /// and the color picker writes to it. `Done` commits to `Preferences`.
    private var working: [String: String] = [:]

    /// Field currently being edited by the presented color picker.
    private var editingKey: String?

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Custom Palette"

        working = prefs.customPalette

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "arrow.counterclockwise"),
            style: .plain,
            target: self,
            action: #selector(resetTapped)
        )
        navigationItem.leftBarButtonItem?.accessibilityLabel = "Reset to defaults"

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(doneTapped)
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

    // MARK: - Chrome

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

    // MARK: - Actions

    @objc private func doneTapped() {
        prefs.customPalette = working
        dismiss(animated: true)
    }

    @objc private func resetTapped() {
        let alert = UIAlertController(
            title: "Reset to defaults?",
            message: "This clears all custom color overrides.",
            preferredStyle: .actionSheet
        )
        alert.addAction(UIAlertAction(title: "Reset", style: .destructive) { [weak self] _ in
            guard let self = self else { return }
            self.working = [:]
            self.tableView.reloadData()
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let pop = alert.popoverPresentationController {
            pop.barButtonItem = navigationItem.leftBarButtonItem
        }
        present(alert, animated: true)
    }

    // MARK: - Default lookup

    /// Falls back to the currently-resolved theme's value for a field. This
    /// gives the user a sensible starting color when they tap a row that
    /// hasn't been overridden yet.
    private func defaultColor(for key: String) -> UIColor {
        let p = themes.palette
        switch key {
        case "background":         return p.background
        case "foreground":         return p.foreground
        case "card":               return p.card
        case "primary":            return p.primary
        case "primaryForeground":  return p.primaryForeground
        case "secondary":          return p.secondary
        case "muted":              return p.muted
        case "mutedForeground":    return p.mutedForeground
        case "accent":             return p.accent
        case "border":             return p.border
        case "editorBackground":   return p.editorBackground
        case "editorGutter":       return p.editorGutter
        default:                   return .magenta
        }
    }

    private func color(for key: String) -> UIColor {
        if let hex = working[key], let c = UIColor(hexString: hex) { return c }
        return defaultColor(for: key)
    }

    // MARK: - Data source

    func numberOfSections(in tableView: UITableView) -> Int { 1 }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        Self.fields.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        "Colors"
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        "Colors apply as you pick them. Tap Done to save or use the reset icon to clear."
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "row", for: indexPath)
        let field = Self.fields[indexPath.row]
        let palette = themes.palette

        var cfg = cell.defaultContentConfiguration()
        cfg.text = field.label
        cfg.secondaryText = field.hint
        cfg.textProperties.color = palette.foreground
        cfg.secondaryTextProperties.color = palette.mutedForeground
        cell.contentConfiguration = cfg
        cell.backgroundColor = palette.card

        // Right-side swatch showing current value.
        let swatch = UIView(frame: CGRect(x: 0, y: 0, width: 26, height: 26))
        swatch.backgroundColor = color(for: field.key)
        swatch.layer.cornerRadius = 6
        swatch.layer.borderWidth = 1
        swatch.layer.borderColor = palette.border.cgColor
        cell.accessoryView = swatch
        cell.tintColor = palette.primary
        return cell
    }

    // MARK: - Delegate

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let field = Self.fields[indexPath.row]
        editingKey = field.key

        let picker = UIColorPickerViewController()
        picker.delegate = self
        picker.supportsAlpha = false
        picker.selectedColor = color(for: field.key)
        picker.title = field.label
        present(picker, animated: true)
    }

    // MARK: - UIColorPickerViewControllerDelegate

    func colorPickerViewControllerDidSelectColor(_ viewController: UIColorPickerViewController) {
        guard let key = editingKey else { return }
        let hex = viewController.selectedColor.toHexString()
        working[key] = hex
        // Live preview: write through to prefs so any observer (editor chrome,
        // etc.) can react. We still require Done to "commit" in the sense that
        // tapping the reset icon or swiping down cancels un-kept intermediate
        // picks — but the picker delta is the user's intent so we publish it.
        prefs.customPalette = working
        tableView.reloadData()
    }

    func colorPickerViewControllerDidFinish(_ viewController: UIColorPickerViewController) {
        editingKey = nil
    }
}

// MARK: - UIColor hex helpers

extension UIColor {
    /// Best-effort hex parser matching the RN `hex()` helper.
    convenience init?(hexString: String) {
        var s = hexString
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let n = UInt32(s, radix: 16) else { return nil }
        self.init(
            red: CGFloat((n >> 16) & 0xFF) / 255,
            green: CGFloat((n >> 8) & 0xFF) / 255,
            blue: CGFloat(n & 0xFF) / 255,
            alpha: 1
        )
    }

    func toHexString() -> String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        let ri = Int((max(0, min(1, r)) * 255).rounded())
        let gi = Int((max(0, min(1, g)) * 255).rounded())
        let bi = Int((max(0, min(1, b)) * 255).rounded())
        return String(format: "#%02x%02x%02x", ri, gi, bi)
    }
}
