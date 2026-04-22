import UIKit

/// Top/bottom split comparison view. Two read-only UITextViews stacked with a
/// 1pt separator. Top shows the active note; bottom shows a user-selected
/// "other" note from the store. When one pane scrolls, the other mirrors the
/// proportional offset so the reader can follow the same relative position in
/// both documents. Mirrors the RN `compareOpen` / `topCompareRef` / `bottomCompareRef`
/// surface.
final class CompareViewController: UIViewController, UITextViewDelegate {
    var onClose: (() -> Void)?

    private let store: NotesStore
    private var palette: Palette

    private let topTextView = UITextView()
    private let bottomTextView = UITextView()
    private let separator = UIView()
    private let emptyLabel = UILabel()

    private var comparableNotes: [Note] = []
    private var bottomNoteId: String?
    private var isSyncing = false

    init(store: NotesStore, palette: Palette) {
        self.store = store
        self.palette = palette
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()

        configureTextViews()
        configureSeparator()
        configureEmptyLabel()
        layoutSubviews()
        configureNavBar()

        refreshComparableNotes()
        applyPalette()
        reloadContent()
    }

    // MARK: - Configuration

    private func configureTextViews() {
        for tv in [topTextView, bottomTextView] {
            tv.translatesAutoresizingMaskIntoConstraints = false
            tv.isEditable = false
            tv.isSelectable = true
            tv.alwaysBounceVertical = true
            tv.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
            tv.autocapitalizationType = .none
            tv.autocorrectionType = .no
            tv.spellCheckingType = .no
            tv.smartQuotesType = .no
            tv.smartDashesType = .no
            tv.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
            tv.delegate = self
            view.addSubview(tv)
        }
    }

    private func configureSeparator() {
        separator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(separator)
    }

    private func configureEmptyLabel() {
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.numberOfLines = 0
        emptyLabel.textAlignment = .center
        emptyLabel.font = .systemFont(ofSize: 14, weight: .regular)
        emptyLabel.text = "Open another document to compare.\nImport a file or duplicate this document, edit one copy, then return here."
        emptyLabel.isHidden = true
        view.addSubview(emptyLabel)
    }

    private func layoutSubviews() {
        NSLayoutConstraint.activate([
            topTextView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            topTextView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topTextView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topTextView.bottomAnchor.constraint(equalTo: separator.topAnchor),

            separator.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            separator.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1),

            bottomTextView.topAnchor.constraint(equalTo: separator.bottomAnchor),
            bottomTextView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomTextView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomTextView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            emptyLabel.centerXAnchor.constraint(equalTo: bottomTextView.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: bottomTextView.centerYAnchor),
            emptyLabel.leadingAnchor.constraint(equalTo: bottomTextView.leadingAnchor, constant: 24),
            emptyLabel.trailingAnchor.constraint(equalTo: bottomTextView.trailingAnchor, constant: -24),
        ])
    }

    private func configureNavBar() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Done",
            style: .done,
            target: self,
            action: #selector(doneTapped)
        )
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Pick",
            style: .plain,
            target: self,
            action: #selector(pickTapped)
        )
        updateTitle()
        updatePickEnabled()
    }

    // MARK: - Palette

    private func applyPalette() {
        view.backgroundColor = palette.editorBackground
        topTextView.backgroundColor = palette.editorBackground
        topTextView.textColor = palette.foreground
        bottomTextView.backgroundColor = palette.editorBackground
        bottomTextView.textColor = palette.foreground
        separator.backgroundColor = palette.border
        emptyLabel.textColor = palette.mutedForeground

        let nav = UINavigationBarAppearance()
        nav.configureWithDefaultBackground()
        nav.backgroundColor = palette.card
        nav.titleTextAttributes = [.foregroundColor: palette.foreground]
        navigationItem.standardAppearance = nav
        navigationItem.scrollEdgeAppearance = nav
        navigationController?.navigationBar.tintColor = palette.primary
    }

    // MARK: - Data

    private func refreshComparableNotes() {
        let active = store.activeId
        comparableNotes = store.notes.filter { $0.id != active }
        if bottomNoteId == nil || !comparableNotes.contains(where: { $0.id == bottomNoteId }) {
            bottomNoteId = comparableNotes.first?.id
        }
    }

    private func reloadContent() {
        let top = store.activeNote
        topTextView.text = top.body

        if let id = bottomNoteId, let bottom = comparableNotes.first(where: { $0.id == id }) {
            bottomTextView.text = bottom.body
            bottomTextView.isHidden = false
            emptyLabel.isHidden = true
        } else {
            bottomTextView.text = ""
            bottomTextView.isHidden = true
            emptyLabel.isHidden = false
        }
        updateTitle()
        updatePickEnabled()
    }

    private func updateTitle() {
        title = "Compare: \(store.activeNote.title)"
    }

    private func updatePickEnabled() {
        navigationItem.rightBarButtonItem?.isEnabled = !comparableNotes.isEmpty
    }

    // MARK: - Actions

    @objc private func doneTapped() {
        onClose?()
    }

    @objc private func pickTapped() {
        guard !comparableNotes.isEmpty else { return }
        let sheet = UIAlertController(title: "Bottom pane", message: nil, preferredStyle: .actionSheet)
        for note in comparableNotes {
            let prefix = note.id == bottomNoteId ? "\u{2713} " : ""
            sheet.addAction(UIAlertAction(title: prefix + note.title, style: .default) { [weak self] _ in
                self?.bottomNoteId = note.id
                self?.reloadContent()
            })
        }
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let pop = sheet.popoverPresentationController {
            pop.barButtonItem = navigationItem.rightBarButtonItem
        }
        present(sheet, animated: true)
    }

    // MARK: - Synced scrolling

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView === topTextView || scrollView === bottomTextView else { return }
        guard !isSyncing else { return }
        let other: UIScrollView = (scrollView === topTextView) ? bottomTextView : topTextView
        let srcMax = max(scrollView.contentSize.height - scrollView.bounds.height, 1)
        let dstMax = max(other.contentSize.height - other.bounds.height, 0)
        let ratio = min(max(scrollView.contentOffset.y / srcMax, 0), 1)
        let targetY = ratio * dstMax
        if abs(other.contentOffset.y - targetY) < 0.5 { return }
        isSyncing = true
        other.setContentOffset(CGPoint(x: other.contentOffset.x, y: targetY), animated: false)
        isSyncing = false
    }
}
