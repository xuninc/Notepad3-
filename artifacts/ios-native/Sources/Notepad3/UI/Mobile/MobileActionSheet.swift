import UIKit

/// One tappable row inside a `MobileActionSheet` section. Mirrors the RN
/// `SheetRow` — an SF Symbol on the left, a title + optional hint in the
/// middle, and an optional right-side checkmark for toggle state. The
/// sheet dismisses itself automatically before invoking `action`.
struct SheetRow {
    var icon: String?
    var title: String
    var subtitle: String?
    var checked: Bool
    var destructive: Bool
    var action: () -> Void

    init(
        icon: String? = nil,
        title: String,
        subtitle: String? = nil,
        checked: Bool = false,
        destructive: Bool = false,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.checked = checked
        self.destructive = destructive
        self.action = action
    }
}

/// Grouped block of `SheetRow`s with a small uppercase header, matching
/// the RN `SheetSection`. Pass an array of these to `MobileActionSheet.init`.
struct SheetSection {
    var title: String
    var rows: [SheetRow]

    init(title: String, rows: [SheetRow]) {
        self.title = title
        self.rows = rows
    }
}

/// Bottom-sheet modal presented from the mobile "More" button. Uses
/// `UISheetPresentationController` for the native drag/dismiss behavior
/// and renders grouped rows via a plain `UITableView`. Tapping a row
/// dismisses the sheet first, then invokes the row's action closure —
/// callers don't have to remember to do either.
final class MobileActionSheet: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private let sections: [SheetSection]
    private var palette: Palette
    private let tableView = UITableView(frame: .zero, style: .grouped)
    private let grabber = UIView()

    private static let rowReuseId = "MobileActionSheet.row"

    init(sections: [SheetSection], palette: Palette) {
        self.sections = sections
        self.palette = palette
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .pageSheet
        if let sheet = sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 16
            sheet.prefersEdgeAttachedInCompactHeight = true
            sheet.widthFollowsPreferredContentSizeWhenEdgeAttached = true
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.separatorStyle = .singleLine
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 52, bottom: 0, right: 0)
        tableView.sectionHeaderTopPadding = 8
        tableView.register(SheetRowCell.self, forCellReuseIdentifier: Self.rowReuseId)
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        applyPalette()
    }

    private func applyPalette() {
        view.backgroundColor = palette.card
        tableView.backgroundColor = palette.card
        tableView.separatorColor = palette.border
        tableView.reloadData()
    }

    // MARK: - Data source

    func numberOfSections(in tableView: UITableView) -> Int { sections.count }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].rows.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        sections[section].title.uppercased()
    }

    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        guard let header = view as? UITableViewHeaderFooterView else { return }
        var cfg = header.defaultContentConfiguration()
        cfg.text = sections[section].title.uppercased()
        cfg.textProperties.color = palette.mutedForeground
        cfg.textProperties.font = .systemFont(ofSize: 11, weight: .bold)
        header.contentConfiguration = cfg
        header.backgroundConfiguration = {
            var bg = UIBackgroundConfiguration.listGroupedHeaderFooter()
            bg.backgroundColor = palette.card
            return bg
        }()
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = sections[indexPath.section].rows[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: Self.rowReuseId, for: indexPath) as! SheetRowCell
        cell.configure(row: row, palette: palette)
        return cell
    }

    // MARK: - Delegate

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let row = sections[indexPath.section].rows[indexPath.row]
        // Dismiss first so the row's action — which may present another
        // screen — doesn't collide with our own presentation controller.
        dismiss(animated: true) {
            row.action()
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        56
    }
}

/// Custom cell so the icon column has a fixed width and the subtitle
/// can sit flush under the title with tight vertical padding. Using the
/// stock default content configuration would push the checkmark off to
/// the accessory column and waste horizontal space.
private final class SheetRowCell: UITableViewCell {
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let checkView = UIImageView()
    private let labelStack = UIStackView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .default, reuseIdentifier: reuseIdentifier)

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.contentMode = .scaleAspectFit
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 18, weight: .regular)
        contentView.addSubview(iconView)

        titleLabel.font = .systemFont(ofSize: 16, weight: .medium)
        titleLabel.numberOfLines = 1
        subtitleLabel.font = .systemFont(ofSize: 12, weight: .regular)
        subtitleLabel.numberOfLines = 2

        labelStack.translatesAutoresizingMaskIntoConstraints = false
        labelStack.axis = .vertical
        labelStack.spacing = 2
        labelStack.alignment = .fill
        labelStack.addArrangedSubview(titleLabel)
        labelStack.addArrangedSubview(subtitleLabel)
        contentView.addSubview(labelStack)

        checkView.translatesAutoresizingMaskIntoConstraints = false
        checkView.contentMode = .scaleAspectFit
        checkView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        checkView.image = UIImage(systemName: "checkmark")
        contentView.addSubview(checkView)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            iconView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),

            labelStack.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            labelStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            labelStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
            labelStack.trailingAnchor.constraint(lessThanOrEqualTo: checkView.leadingAnchor, constant: -8),

            checkView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            checkView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            checkView.widthAnchor.constraint(equalToConstant: 18),
            checkView.heightAnchor.constraint(equalToConstant: 18),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(row: SheetRow, palette: Palette) {
        let titleColor = row.destructive ? palette.destructive : palette.foreground
        let iconColor  = row.destructive ? palette.destructive : palette.foreground

        if let symbol = row.icon {
            iconView.image = UIImage(systemName: symbol)
            iconView.isHidden = false
        } else {
            iconView.image = nil
            iconView.isHidden = true
        }
        iconView.tintColor = iconColor

        titleLabel.text = row.title
        titleLabel.textColor = titleColor

        if let subtitle = row.subtitle, !subtitle.isEmpty {
            subtitleLabel.text = subtitle
            subtitleLabel.textColor = palette.mutedForeground
            subtitleLabel.isHidden = false
        } else {
            subtitleLabel.text = nil
            subtitleLabel.isHidden = true
        }

        checkView.isHidden = !row.checked
        checkView.tintColor = palette.primary

        backgroundColor = palette.card
        let selected = UIView()
        selected.backgroundColor = palette.secondary
        selectedBackgroundView = selected
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        iconView.image = nil
        titleLabel.text = nil
        subtitleLabel.text = nil
        checkView.isHidden = true
    }
}
