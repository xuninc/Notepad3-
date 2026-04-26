import UIKit

/// Bottom-sheet modal listing every currently open document. Mirrors the RN
/// `tabListOpen` / "Open documents" modal: a grouped table with a small
/// actions header (`+ New blank`, `Open from Files…`) followed by one row
/// per open note. The active note is bolded, each row has a trailing close
/// (×) button, and a long-press context menu offers rename / duplicate /
/// close-others / close.
///
/// This VC is purely presentational — every destructive or state-mutating
/// action is routed back to its owner through the `on*` closures. The host
/// applies the change to `NotesStore`; we subscribe to the store so the
/// visible list updates immediately when that happens (e.g. tapping ×
/// removes the row without waiting for a re-present).
final class DocsListViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    // MARK: - Public API

    var onSelect:         ((String) -> Void)?
    var onClose:          ((String) -> Void)?
    var onRename:         ((String) -> Void)?
    var onDuplicate:      ((String) -> Void)?
    var onCloseOthers:    ((String) -> Void)?
    var onNewBlank:       (() -> Void)?
    var onOpenFromFiles:  (() -> Void)?
    var onDismiss:        (() -> Void)?

    // MARK: - Private state

    private let store: NotesStore
    private var palette: Palette
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f
    }()
    private var observerToken: UUID?

    /// Local snapshot of the store so indexPath lookups stay coherent across
    /// a single render pass. Refreshed in `reload()`.
    private var notes: [Note] = []
    private var activeId: String = ""

    private static let actionReuseId = "DocsListViewController.actionRow"
    private static let docReuseId    = "DocsListViewController.docRow"

    // Section layout: 0 = New/Open actions, 1 = open docs.
    private enum Section: Int, CaseIterable {
        case actions
        case docs
    }

    private enum ActionRow: Int, CaseIterable {
        case newBlank
        case openFromFiles
    }

    // MARK: - Init

    init(store: NotesStore, palette: Palette) {
        self.store = store
        self.palette = palette
        super.init(nibName: nil, bundle: nil)

        // Same sheet configuration as MobileActionSheet.
        modalPresentationStyle = .pageSheet
        if let sheet = sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 16
            sheet.prefersEdgeAttachedInCompactHeight = true
            sheet.widthFollowsPreferredContentSizeWhenEdgeAttached = true
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    deinit {
        if let token = observerToken { store.unobserve(token) }
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Documents"

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Done",
            style: .done,
            target: self,
            action: #selector(doneTapped)
        )

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: Self.actionReuseId)
        tableView.register(DocRowCell.self, forCellReuseIdentifier: Self.docReuseId)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 56
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        reload()
        observerToken = store.observe { [weak self] in
            self?.reload()
        }

        applyPalette()
    }

    // MARK: - State sync

    /// Pull a fresh snapshot from the store and reload the table. Called on
    /// init and every time the store fires an observer event.
    private func reload() {
        notes = store.notes
        activeId = store.activeId
        tableView.reloadData()
    }

    private func applyPalette() {
        view.backgroundColor = palette.background
        tableView.backgroundColor = palette.background
        tableView.separatorColor = palette.border
        let nav = UINavigationBarAppearance()
        nav.configureWithDefaultBackground()
        nav.backgroundColor = palette.card
        nav.titleTextAttributes = [.foregroundColor: palette.foreground]
        navigationItem.standardAppearance = nav
        navigationItem.scrollEdgeAppearance = nav
        navigationController?.navigationBar.tintColor = palette.primary
        tableView.reloadData()
    }

    // MARK: - Actions

    @objc private func doneTapped() {
        onDismiss?()
    }

    // MARK: - UITableViewDataSource

    func numberOfSections(in tableView: UITableView) -> Int { Section.allCases.count }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section) {
        case .actions: return ActionRow.allCases.count
        case .docs:    return notes.count
        case .none:    return 0
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section) {
        case .actions: return nil
        case .docs:    return "Open documents"
        case .none:    return nil
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section) {
        case .actions:
            let cell = tableView.dequeueReusableCell(withIdentifier: Self.actionReuseId, for: indexPath)
            var cfg = cell.defaultContentConfiguration()
            switch ActionRow(rawValue: indexPath.row) {
            case .newBlank:
                cfg.text = "New blank"
                cfg.image = UIImage(systemName: "doc.badge.plus")
            case .openFromFiles:
                cfg.text = "Open from Files\u{2026}"
                cfg.image = UIImage(systemName: "folder")
            case .none:
                break
            }
            cfg.textProperties.color = palette.foreground
            cfg.textProperties.font = .systemFont(ofSize: 16, weight: .medium)
            cfg.imageProperties.tintColor = palette.primary
            cell.contentConfiguration = cfg
            cell.backgroundColor = palette.card
            cell.tintColor = palette.primary
            let selected = UIView()
            selected.backgroundColor = palette.secondary
            cell.selectedBackgroundView = selected
            cell.accessoryType = .disclosureIndicator
            return cell

        case .docs:
            let cell = tableView.dequeueReusableCell(withIdentifier: Self.docReuseId, for: indexPath) as! DocRowCell
            let note = notes[indexPath.row]
            let isActive = note.id == activeId
            let subtitle = "\(note.language.rawValue) \u{00B7} Last edited \(relativeFormatter.localizedString(for: note.updatedAt, relativeTo: Date()))"
            cell.configure(
                title: note.title,
                subtitle: subtitle,
                isActive: isActive,
                palette: palette
            )
            cell.onCloseTapped = { [weak self] in
                guard let self else { return }
                self.onClose?(note.id)
            }
            return cell

        case .none:
            return UITableViewCell()
        }
    }

    // MARK: - UITableViewDelegate

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch Section(rawValue: indexPath.section) {
        case .actions:
            switch ActionRow(rawValue: indexPath.row) {
            case .newBlank:      onNewBlank?()
            case .openFromFiles: onOpenFromFiles?()
            case .none:          break
            }
        case .docs:
            guard indexPath.row < notes.count else { return }
            let note = notes[indexPath.row]
            onSelect?(note.id)
            onDismiss?()
        case .none:
            break
        }
    }

    // Long-press context menu — only meaningful for the docs section.
    func tableView(
        _ tableView: UITableView,
        contextMenuConfigurationForRowAt indexPath: IndexPath,
        point: CGPoint
    ) -> UIContextMenuConfiguration? {
        guard Section(rawValue: indexPath.section) == .docs,
              indexPath.row < notes.count else { return nil }
        let note = notes[indexPath.row]
        let canCloseOthers = notes.count > 1
        return UIContextMenuConfiguration(identifier: note.id as NSString, previewProvider: nil) { [weak self] _ in
            guard let self else { return nil }
            let rename = UIAction(title: "Rename", image: UIImage(systemName: "pencil")) { [weak self] _ in
                self?.onRename?(note.id)
            }
            let duplicate = UIAction(title: "Duplicate", image: UIImage(systemName: "plus.square.on.square")) { [weak self] _ in
                self?.onDuplicate?(note.id)
            }
            let closeOthers = UIAction(
                title: "Close Others",
                image: UIImage(systemName: "xmark.square"),
                attributes: canCloseOthers ? [] : .disabled
            ) { [weak self] _ in
                self?.onCloseOthers?(note.id)
            }
            let close = UIAction(
                title: "Close",
                image: UIImage(systemName: "xmark"),
                attributes: .destructive
            ) { [weak self] _ in
                self?.onClose?(note.id)
            }
            return UIMenu(title: note.title, children: [rename, duplicate, closeOthers, close])
        }
    }
}

// MARK: - DocRowCell

/// Table cell for a single open document. Title gets bolded when the note
/// is the currently active one; the subtitle sits directly under it with
/// muted styling; a trailing × button fires `onCloseTapped`. The layout is
/// hand-rolled (rather than using `UIListContentConfiguration`) because we
/// need the close button to live inside the row while still letting the
/// whole row act as a single tap target for row selection.
private final class DocRowCell: UITableViewCell {
    var onCloseTapped: (() -> Void)?

    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let closeButton = UIButton(type: .system)
    private let labelStack = UIStackView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .default, reuseIdentifier: reuseIdentifier)

        titleLabel.font = .systemFont(ofSize: 16, weight: .regular)
        titleLabel.numberOfLines = 1
        titleLabel.lineBreakMode = .byTruncatingTail
        subtitleLabel.font = .systemFont(ofSize: 12, weight: .regular)
        subtitleLabel.numberOfLines = 1

        labelStack.translatesAutoresizingMaskIntoConstraints = false
        labelStack.axis = .vertical
        labelStack.spacing = 2
        labelStack.alignment = .fill
        labelStack.addArrangedSubview(titleLabel)
        labelStack.addArrangedSubview(subtitleLabel)
        contentView.addSubview(labelStack)

        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.setImage(
            UIImage(systemName: "xmark.circle.fill",
                    withConfiguration: UIImage.SymbolConfiguration(pointSize: 20, weight: .regular)),
            for: .normal
        )
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        // Generous hit target; wider than the icon so tapping the × never
        // accidentally selects the row.
        closeButton.contentEdgeInsets = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        contentView.addSubview(closeButton)

        NSLayoutConstraint.activate([
            labelStack.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            labelStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            labelStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
            labelStack.trailingAnchor.constraint(lessThanOrEqualTo: closeButton.leadingAnchor, constant: -8),

            closeButton.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            closeButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    @objc private func closeTapped() {
        onCloseTapped?()
    }

    func configure(title: String, subtitle: String, isActive: Bool, palette: Palette) {
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 16, weight: isActive ? .semibold : .regular)
        titleLabel.textColor = isActive ? palette.primary : palette.foreground

        subtitleLabel.text = subtitle
        subtitleLabel.textColor = palette.mutedForeground

        closeButton.tintColor = palette.mutedForeground

        backgroundColor = palette.card
        let selectedBg = UIView()
        selectedBg.backgroundColor = palette.secondary
        selectedBackgroundView = selectedBg
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onCloseTapped = nil
        titleLabel.text = nil
        subtitleLabel.text = nil
    }
}
