import UIKit
import UniformTypeIdentifiers

/// Top-level editor surface. Hosts a horizontal tab strip above a UITextView,
/// plus navigation-bar buttons for new / open / more. All content flows through
/// `NotesStore` — the VC is a view over store state and reacts to mutations via
/// the observer token.
final class EditorViewController: UIViewController, UITextViewDelegate {
    private let store: NotesStore
    private let tabStrip = TabStripView()
    private let separator = UIView()
    private let textView = UITextView()
    private var observerToken: UUID?
    private var palette: Palette = .light

    init(store: NotesStore) {
        self.store = store
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()

        configureTabStrip()
        configureTextView()
        layoutSubviews()
        configureNavBar()
        applyPalette()

        textView.text = store.activeNote.body
        title = store.activeNote.title
        tabStrip.reload(notes: store.notes, activeId: store.activeId)

        observerToken = store.observe { [weak self] in
            self?.syncFromStore()
        }
    }

    deinit {
        if let token = observerToken { store.unobserve(token) }
    }

    // MARK: - Configuration

    private func configureTabStrip() {
        tabStrip.translatesAutoresizingMaskIntoConstraints = false
        tabStrip.onSelect = { [weak self] id in self?.store.setActive(id) }
        tabStrip.onClose = { [weak self] id in self?.confirmClose(id) }
        tabStrip.onRename = { [weak self] id in self?.promptRename(id) }
        tabStrip.onDuplicate = { [weak self] id in self?.store.duplicate(id: id) }
        tabStrip.onCloseOthers = { [weak self] id in self?.store.closeOthers(keep: id) }
        view.addSubview(tabStrip)
    }

    private func configureTextView() {
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.delegate = self
        textView.font = .monospacedSystemFont(ofSize: 16, weight: .regular)
        textView.autocapitalizationType = .none
        textView.autocorrectionType = .no
        textView.spellCheckingType = .no
        textView.smartQuotesType = .no
        textView.smartDashesType = .no
        textView.alwaysBounceVertical = true
        textView.keyboardDismissMode = .interactive
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        view.addSubview(textView)

        separator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(separator)
    }

    private func layoutSubviews() {
        NSLayoutConstraint.activate([
            tabStrip.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tabStrip.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tabStrip.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tabStrip.heightAnchor.constraint(equalToConstant: 44),

            separator.topAnchor.constraint(equalTo: tabStrip.bottomAnchor),
            separator.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale),

            textView.topAnchor.constraint(equalTo: separator.bottomAnchor),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func configureNavBar() {
        navigationItem.largeTitleDisplayMode = .never

        let newButton = UIBarButtonItem(
            image: UIImage(systemName: "square.and.pencil"),
            primaryAction: nil,
            menu: newDocumentMenu()
        )
        newButton.accessibilityLabel = "New document"

        let moreButton = UIBarButtonItem(
            image: UIImage(systemName: "ellipsis.circle"),
            primaryAction: nil,
            menu: moreMenu()
        )
        moreButton.accessibilityLabel = "More actions"

        navigationItem.rightBarButtonItems = [moreButton, newButton]
    }

    private func newDocumentMenu() -> UIMenu {
        let blank = UIAction(title: "New Blank", image: UIImage(systemName: "doc")) { [weak self] _ in
            self?.store.createBlank()
        }
        let open = UIAction(title: "Open from Files…", image: UIImage(systemName: "folder")) { [weak self] _ in
            self?.presentFileOpen()
        }
        return UIMenu(title: "", children: [blank, open])
    }

    private func moreMenu() -> UIMenu {
        let duplicate = UIAction(title: "Duplicate current", image: UIImage(systemName: "plus.square.on.square")) { [weak self] _ in
            guard let self else { return }
            self.store.duplicate(id: self.store.activeId)
        }
        let rename = UIAction(title: "Rename current", image: UIImage(systemName: "pencil")) { [weak self] _ in
            guard let self else { return }
            self.promptRename(self.store.activeId)
        }
        let close = UIAction(title: "Close current", image: UIImage(systemName: "xmark"), attributes: .destructive) { [weak self] _ in
            guard let self else { return }
            self.confirmClose(self.store.activeId)
        }
        return UIMenu(title: "", children: [duplicate, rename, close])
    }

    // MARK: - Theme

    private func applyPalette() {
        view.backgroundColor = palette.background
        textView.backgroundColor = palette.editorBackground
        textView.textColor = palette.foreground
        textView.tintColor = palette.primary
        separator.backgroundColor = palette.border
        tabStrip.applyPalette(palette)

        let nav = UINavigationBarAppearance()
        nav.configureWithDefaultBackground()
        nav.backgroundColor = palette.card
        nav.titleTextAttributes = [.foregroundColor: palette.foreground]
        navigationItem.standardAppearance = nav
        navigationItem.scrollEdgeAppearance = nav
        navigationController?.navigationBar.tintColor = palette.primary
    }

    // MARK: - Store sync

    /// Pull state into the view after a store change. Never overwrite the
    /// text view while the user is mid-typing (matches body already means
    /// the textViewDidChange->updateActive round-trip just happened).
    private func syncFromStore() {
        let note = store.activeNote
        if textView.text != note.body {
            let old = textView.selectedRange
            textView.text = note.body
            let len = (note.body as NSString).length
            textView.selectedRange = NSRange(location: min(old.location, len), length: 0)
        }
        title = note.title
        tabStrip.reload(notes: store.notes, activeId: store.activeId)
    }

    // MARK: - UITextViewDelegate

    func textViewDidChange(_ textView: UITextView) {
        store.updateActive(body: textView.text)
    }

    // MARK: - Actions

    private func confirmClose(_ id: String) {
        guard let note = store.notes.first(where: { $0.id == id }) else { return }
        // Skip the confirm when the doc is empty — nothing to lose.
        if note.body.isEmpty {
            store.delete(id: id)
            return
        }
        let alert = UIAlertController(
            title: "Close \(note.title)?",
            message: "This document will be removed. You can't undo this.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Close", style: .destructive) { [weak self] _ in
            self?.store.delete(id: id)
        })
        present(alert, animated: true)
    }

    private func promptRename(_ id: String) {
        guard let note = store.notes.first(where: { $0.id == id }) else { return }
        let alert = UIAlertController(title: "Rename document", message: nil, preferredStyle: .alert)
        alert.addTextField { tf in
            tf.text = note.title
            tf.autocapitalizationType = .none
            tf.autocorrectionType = .no
            tf.clearButtonMode = .whileEditing
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Rename", style: .default) { [weak self, weak alert] _ in
            guard let newName = alert?.textFields?.first?.text else { return }
            self?.store.rename(id: id, title: newName)
        })
        present(alert, animated: true)
    }
}

// MARK: - File open

extension EditorViewController: UIDocumentPickerDelegate {
    fileprivate func presentFileOpen() {
        // `.item` = any file type. `asCopy: true` copies into our sandbox so we
        // don't have to juggle security-scoped URLs after the picker dismisses.
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item], asCopy: true)
        picker.delegate = self
        picker.allowsMultipleSelection = false
        present(picker, animated: true)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        do {
            let data = try Data(contentsOf: url)
            // Try UTF-8 first, fall back to Latin-1 which decodes any byte sequence
            // — so "open any file type" produces something readable even for binary.
            let text = String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .isoLatin1)
                ?? ""
            let language = NoteLanguage.detect(fromFileName: url.lastPathComponent)
            store.importNote(title: url.lastPathComponent, body: text, language: language)
        } catch {
            let alert = UIAlertController(
                title: "Couldn't open file",
                message: error.localizedDescription,
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
    }
}
