import UIKit

/// Modal syntax-language picker. Single-select table of `NoteLanguage.allCases`
/// with a checkmark on the currently active language. Mirrors the RN
/// `langOpen` / "Change syntax" modal. Calls `onPick` when the user chooses a
/// language, or `onCancel` when they tap Done/Cancel.
final class LanguagePickerViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    var onPick: ((NoteLanguage) -> Void)?
    var onCancel: (() -> Void)?

    private let palette: Palette
    private var current: NoteLanguage
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let languages: [NoteLanguage] = NoteLanguage.allCases

    init(current: NoteLanguage, palette: Palette) {
        self.current = current
        self.palette = palette
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Change syntax"

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Cancel",
            style: .plain,
            target: self,
            action: #selector(cancelTapped)
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

    @objc private func cancelTapped() {
        onCancel?()
    }

    private func applyPalette() {
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

    func numberOfSections(in tableView: UITableView) -> Int { 1 }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        "Language"
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        languages.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "row", for: indexPath)
        let language = languages[indexPath.row]

        var cfg = cell.defaultContentConfiguration()
        cfg.text = language.rawValue
        cfg.textProperties.color = palette.foreground
        cell.contentConfiguration = cfg
        cell.accessoryType = (language == current) ? .checkmark : .none
        cell.backgroundColor = palette.card
        cell.tintColor = palette.primary
        return cell
    }

    // MARK: - Delegate

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let language = languages[indexPath.row]
        current = language
        tableView.reloadData()
        onPick?(language)
    }
}
