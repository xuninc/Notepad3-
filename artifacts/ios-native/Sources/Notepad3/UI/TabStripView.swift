import UIKit

/// Horizontal scrolling strip of document tabs, or a compact one-line "list"
/// bar that opens a full modal list of all open docs. The mode is selected by
/// `layout` which mirrors the React Native `tabsLayout` preference.
///
/// In `.tabs` mode (the original behavior) the view renders one `TabCell` per
/// note inside a horizontal `UIStackView` wrapped in a `UIScrollView`. Tap a
/// cell to switch, tap × to close, long-press for a context menu.
///
/// In `.list` mode the view renders a single compact bar showing a folder
/// glyph, the active note title, an "N open" count and a chevron. Tapping it
/// fires `onOpenListModal` and the caller is expected to present the docs
/// list modal (rename/duplicate/close-others/close live in there).
///
/// The strip owns no state — it rerenders from `reload(notes:activeId:)`
/// every time the store changes.
final class TabStripView: UIView {
    // MARK: - Public types

    enum Layout { case tabs, list }

    // MARK: - Public callbacks

    var onSelect: ((String) -> Void)?
    var onClose: ((String) -> Void)?
    var onRename: ((String) -> Void)?
    var onDuplicate: ((String) -> Void)?
    var onCloseOthers: ((String) -> Void)?
    /// Fires when the user taps the compact list bar in `.list` mode. The
    /// caller is expected to present the full docs list modal.
    var onOpenListModal: (() -> Void)?

    // MARK: - Public state

    var layout: Layout = .tabs {
        didSet {
            guard oldValue != layout else { return }
            applyLayoutVisibility()
            rerenderCurrent()
        }
    }

    // MARK: - Tabs-mode subviews

    private let scrollView = UIScrollView()
    private let stack = UIStackView()

    // MARK: - List-mode subviews

    private let listBar = UIControl()
    private let listIcon = UIImageView()
    private let listTitleLabel = UILabel()
    private let listCountLabel = UILabel()
    private let listChevron = UIImageView()

    // MARK: - Model cache

    private var palette: Palette = .light
    private var currentNotes: [Note] = []
    private var currentActiveId: String?

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    private func setup() {
        setupTabsMode()
        setupListMode()
        applyLayoutVisibility()
    }

    private func setupTabsMode() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.alwaysBounceHorizontal = false
        scrollView.contentInset = .zero
        addSubview(scrollView)

        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.spacing = 4
        stack.alignment = .center
        stack.distribution = .fill
        scrollView.addSubview(stack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),

            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 6),
            stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -8),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -6),
            stack.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor, constant: -12),
        ])
    }

    private func setupListMode() {
        listBar.translatesAutoresizingMaskIntoConstraints = false
        listBar.layer.cornerRadius = 4
        listBar.layer.borderWidth = 1
        listBar.isAccessibilityElement = true
        listBar.accessibilityTraits = .button
        listBar.accessibilityIdentifier = "tabs-list-bar"
        listBar.addTarget(self, action: #selector(listBarTapped), for: .touchUpInside)
        addSubview(listBar)

        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 11, weight: .regular)
        listIcon.translatesAutoresizingMaskIntoConstraints = false
        listIcon.image = UIImage(systemName: "folder", withConfiguration: symbolConfig)
        listIcon.contentMode = .scaleAspectFit
        listIcon.setContentHuggingPriority(.required, for: .horizontal)
        listIcon.setContentCompressionResistancePriority(.required, for: .horizontal)
        listBar.addSubview(listIcon)

        listTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        listTitleLabel.font = .systemFont(ofSize: 12, weight: .bold)
        listTitleLabel.lineBreakMode = .byTruncatingMiddle
        listTitleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        listBar.addSubview(listTitleLabel)

        listCountLabel.translatesAutoresizingMaskIntoConstraints = false
        listCountLabel.font = .monospacedSystemFont(ofSize: 10, weight: .regular)
        listCountLabel.setContentHuggingPriority(.required, for: .horizontal)
        listCountLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        listBar.addSubview(listCountLabel)

        listChevron.translatesAutoresizingMaskIntoConstraints = false
        listChevron.image = UIImage(systemName: "chevron.down", withConfiguration: symbolConfig)
        listChevron.contentMode = .scaleAspectFit
        listChevron.setContentHuggingPriority(.required, for: .horizontal)
        listChevron.setContentCompressionResistancePriority(.required, for: .horizontal)
        listBar.addSubview(listChevron)

        NSLayoutConstraint.activate([
            listBar.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            listBar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            listBar.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            listBar.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -4),
            listBar.heightAnchor.constraint(equalToConstant: 28),

            listIcon.leadingAnchor.constraint(equalTo: listBar.leadingAnchor, constant: 10),
            listIcon.centerYAnchor.constraint(equalTo: listBar.centerYAnchor),
            listIcon.widthAnchor.constraint(equalToConstant: 14),
            listIcon.heightAnchor.constraint(equalToConstant: 14),

            listTitleLabel.leadingAnchor.constraint(equalTo: listIcon.trailingAnchor, constant: 8),
            listTitleLabel.centerYAnchor.constraint(equalTo: listBar.centerYAnchor),

            listCountLabel.leadingAnchor.constraint(equalTo: listTitleLabel.trailingAnchor, constant: 8),
            listCountLabel.centerYAnchor.constraint(equalTo: listBar.centerYAnchor),

            listChevron.leadingAnchor.constraint(equalTo: listCountLabel.trailingAnchor, constant: 8),
            listChevron.trailingAnchor.constraint(equalTo: listBar.trailingAnchor, constant: -10),
            listChevron.centerYAnchor.constraint(equalTo: listBar.centerYAnchor),
            listChevron.widthAnchor.constraint(equalToConstant: 14),
            listChevron.heightAnchor.constraint(equalToConstant: 14),
        ])
    }

    @objc private func listBarTapped() {
        onOpenListModal?()
    }

    private func applyLayoutVisibility() {
        switch layout {
        case .tabs:
            scrollView.isHidden = false
            listBar.isHidden = true
        case .list:
            scrollView.isHidden = true
            listBar.isHidden = false
        }
    }

    // MARK: - Public API

    /// Rebuild the tab list. Keeps the active tab visible by scrolling to it.
    /// In `.list` mode just updates the compact bar's title + count.
    func reload(notes: [Note], activeId: String) {
        currentNotes = notes
        currentActiveId = activeId
        renderCurrent()
    }

    func applyPalette(_ p: Palette) {
        palette = p
        backgroundColor = p.card
        stack.arrangedSubviews.compactMap { $0 as? TabCell }.forEach { $0.applyPalette(p) }
        applyListPalette()
    }

    // MARK: - Rendering

    /// Invoked when `layout` changes and we need to redraw against the cached
    /// notes without a fresh `reload(notes:activeId:)` call.
    private func rerenderCurrent() {
        renderCurrent()
    }

    private func renderCurrent() {
        switch layout {
        case .tabs:
            renderTabs()
        case .list:
            renderListBar()
        }
    }

    private func renderTabs() {
        let notes = currentNotes
        let activeId = currentActiveId ?? ""
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        var activeCell: TabCell?
        for note in notes {
            let cell = TabCell(note: note, active: note.id == activeId, palette: palette)
            cell.onSelect = { [weak self] id in self?.onSelect?(id) }
            cell.onClose = { [weak self] id in self?.onClose?(id) }
            cell.onRename = { [weak self] id in self?.onRename?(id) }
            cell.onDuplicate = { [weak self] id in self?.onDuplicate?(id) }
            cell.onCloseOthers = { [weak self] id in self?.onCloseOthers?(id) }
            stack.addArrangedSubview(cell)
            if note.id == activeId { activeCell = cell }
        }

        if let activeCell {
            // After layout pass, scroll to keep the active tab visible.
            DispatchQueue.main.async { [weak self] in
                guard let self, let sv = self.scrollView as UIScrollView? else { return }
                let frameInScroll = activeCell.convert(activeCell.bounds, to: sv)
                sv.scrollRectToVisible(frameInScroll.insetBy(dx: -16, dy: 0), animated: true)
            }
        }
    }

    private func renderListBar() {
        let notes = currentNotes
        let activeId = currentActiveId
        let activeTitle = notes.first(where: { $0.id == activeId })?.title
            ?? notes.first?.title
            ?? ""
        listTitleLabel.text = activeTitle
        listCountLabel.text = "\(notes.count) open"
        listBar.accessibilityLabel = activeTitle.isEmpty
            ? "Open document list"
            : "\(activeTitle), \(notes.count) open. Double tap to see all documents."
        applyListPalette()
    }

    private func applyListPalette() {
        listBar.backgroundColor = palette.background
        listBar.layer.borderColor = palette.border.cgColor
        listTitleLabel.textColor = palette.foreground
        listCountLabel.textColor = palette.mutedForeground
        listIcon.tintColor = palette.mutedForeground
        listChevron.tintColor = palette.mutedForeground
    }
}

private final class TabCell: UIControl {
    let noteId: String
    private let label = UILabel()
    private let closeButton = UIButton(type: .system)
    private let separator = UIView()
    private var palette: Palette
    private var active: Bool

    var onSelect: ((String) -> Void)?
    var onClose: ((String) -> Void)?
    var onRename: ((String) -> Void)?
    var onDuplicate: ((String) -> Void)?
    var onCloseOthers: ((String) -> Void)?

    init(note: Note, active: Bool, palette: Palette) {
        self.noteId = note.id
        self.palette = palette
        self.active = active
        super.init(frame: .zero)
        setup(title: note.title)
        applyPalette(palette)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup(title: String) {
        layer.cornerRadius = 6
        layer.borderWidth = 1
        translatesAutoresizingMaskIntoConstraints = false
        isAccessibilityElement = true
        accessibilityTraits = .button

        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 13, weight: active ? .semibold : .regular)
        label.text = title
        label.lineBreakMode = .byTruncatingMiddle
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        accessibilityLabel = title
        addSubview(label)

        closeButton.translatesAutoresizingMaskIntoConstraints = false
        var closeConfig = UIButton.Configuration.plain()
        closeConfig.image = UIImage(systemName: "xmark", withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold))
        closeConfig.contentInsets = NSDirectionalEdgeInsets(top: 2, leading: 4, bottom: 2, trailing: 4)
        closeButton.configuration = closeConfig
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        closeButton.accessibilityLabel = "Close \(title)"
        addSubview(closeButton)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.trailingAnchor.constraint(lessThanOrEqualTo: closeButton.leadingAnchor, constant: -4),

            closeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            closeButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 22),
            closeButton.heightAnchor.constraint(equalToConstant: 22),

            widthAnchor.constraint(greaterThanOrEqualToConstant: 80),
            widthAnchor.constraint(lessThanOrEqualToConstant: 240),
        ])

        // Cell wants to be 32pt tall but the parent stack inside the tab
        // strip's scroll view is forced to (scrollHeight − 12); making this
        // .defaultHigh lets auto-layout pick the parent's value gracefully.
        let cellHeight = heightAnchor.constraint(equalToConstant: 32)
        cellHeight.priority = .defaultHigh
        cellHeight.isActive = true

        addTarget(self, action: #selector(tapped), for: .touchUpInside)
        addInteraction(UIContextMenuInteraction(delegate: self))
    }

    @objc private func tapped() { onSelect?(noteId) }
    @objc private func closeTapped() { onClose?(noteId) }

    func applyPalette(_ p: Palette) {
        palette = p
        backgroundColor = active ? p.primary : p.muted
        label.textColor = active ? p.primaryForeground : p.foreground
        closeButton.tintColor = active ? p.primaryForeground.withAlphaComponent(0.75) : p.mutedForeground
        layer.borderColor = (active ? p.primary : p.border).cgColor
    }

    // MARK: - Context menu

    override func contextMenuInteraction(_ interaction: UIContextMenuInteraction,
                                         configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
        UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
            guard let self else { return nil }
            let rename = UIAction(title: "Rename", image: UIImage(systemName: "pencil")) { _ in
                self.onRename?(self.noteId)
            }
            let duplicate = UIAction(title: "Duplicate", image: UIImage(systemName: "plus.square.on.square")) { _ in
                self.onDuplicate?(self.noteId)
            }
            let closeOthers = UIAction(title: "Close Others", image: UIImage(systemName: "xmark.rectangle")) { _ in
                self.onCloseOthers?(self.noteId)
            }
            let close = UIAction(title: "Close", image: UIImage(systemName: "xmark"), attributes: .destructive) { _ in
                self.onClose?(self.noteId)
            }
            return UIMenu(children: [rename, duplicate, closeOthers, close])
        }
    }
}
