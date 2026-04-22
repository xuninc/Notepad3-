import UIKit

/// Horizontal scrolling strip of document tabs. One cell per open note.
/// Tap a cell to switch active note, tap the × to close, long-press for a
/// context menu (rename / duplicate / close others). The strip owns no state
/// — it rerenders from `reload(notes:activeId:)` every time the store changes.
final class TabStripView: UIView {
    var onSelect: ((String) -> Void)?
    var onClose: ((String) -> Void)?
    var onRename: ((String) -> Void)?
    var onDuplicate: ((String) -> Void)?
    var onCloseOthers: ((String) -> Void)?

    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    private var palette: Palette = .light
    private var currentActiveId: String?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    private func setup() {
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

    /// Rebuild the tab list. Keeps the active tab visible by scrolling to it.
    func reload(notes: [Note], activeId: String) {
        currentActiveId = activeId
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

    func applyPalette(_ p: Palette) {
        palette = p
        backgroundColor = p.card
        stack.arrangedSubviews.compactMap { $0 as? TabCell }.forEach { $0.applyPalette(p) }
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

            heightAnchor.constraint(equalToConstant: 32),
            widthAnchor.constraint(greaterThanOrEqualToConstant: 80),
            widthAnchor.constraint(lessThanOrEqualToConstant: 240),
        ])

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
