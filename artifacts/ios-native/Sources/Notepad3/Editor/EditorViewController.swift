import UIKit
import UniformTypeIdentifiers

/// Top-level editor surface. Hosts a horizontal tab strip above a UITextView,
/// plus navigation-bar buttons for new / open / theme / more. All content
/// flows through `NotesStore`; visuals flow through `ThemeController`.
final class EditorViewController: UIViewController, UITextViewDelegate {
    private let store: NotesStore
    private let themes = ThemeController.shared
    private let tabStrip = TabStripView()
    private let separator = UIView()
    private let textView = UITextView()
    private var notesToken: UUID?
    private var themeToken: UUID?
    private var lastHighlightedBody: String = ""
    private var lastHighlightedLanguage: NoteLanguage = .plain

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
        rehighlight(force: true)

        notesToken = store.observe { [weak self] in self?.syncFromStore() }
        themeToken = themes.observe { [weak self] in self?.applyPalette() }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        themes.updateSystemStyle(isDark: traitCollection.userInterfaceStyle == .dark)
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        themes.updateSystemStyle(isDark: traitCollection.userInterfaceStyle == .dark)
    }

    deinit {
        if let t = notesToken { store.unobserve(t) }
        if let t = themeToken { themes.unobserve(t) }
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

        let themeButton = UIBarButtonItem(
            image: themeIconForCurrentMode(),
            style: .plain,
            target: self,
            action: #selector(toggleTheme)
        )
        themeButton.accessibilityLabel = "Toggle light / dark"

        let moreButton = UIBarButtonItem(
            image: UIImage(systemName: "ellipsis.circle"),
            primaryAction: nil,
            menu: moreMenu()
        )
        moreButton.accessibilityLabel = "More actions"

        navigationItem.rightBarButtonItems = [moreButton, themeButton, newButton]
    }

    private func themeIconForCurrentMode() -> UIImage? {
        // Show the inverse icon — sun when dark (to flip to light), moon when light.
        UIImage(systemName: themes.resolvedTheme == .dark ? "sun.max" : "moon")
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
        let prefs = UIAction(title: "Preferences…", image: UIImage(systemName: "gear")) { [weak self] _ in
            self?.presentSettings()
        }
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
        return UIMenu(title: "", children: [prefs, duplicate, rename, close])
    }

    @objc private func toggleTheme() {
        themes.quickToggleDarkLight()
    }

    private func presentSettings() {
        let settings = SettingsViewController()
        let nav = UINavigationController(rootViewController: settings)
        present(nav, animated: true)
    }

    // MARK: - Theme

    private func applyPalette() {
        let palette = themes.palette

        view.backgroundColor = palette.background
        textView.backgroundColor = palette.editorBackground
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

        // Sun/moon icon flips with resolved mode
        if let items = navigationItem.rightBarButtonItems, items.count >= 2 {
            items[1].image = themeIconForCurrentMode()
        }

        // Repaint the existing text with the new palette colors
        rehighlight(force: true)
    }

    // MARK: - Store sync

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
        rehighlight(force: true)
    }

    // MARK: - Highlighting

    /// Re-run the highlighter. `force` forgets the last-highlighted cache so
    /// theme/palette changes re-paint even if body/language are unchanged.
    private func rehighlight(force: Bool = false) {
        let body = textView.text ?? ""
        let language = store.activeNote.language
        if !force && body == lastHighlightedBody && language == lastHighlightedLanguage {
            return
        }
        SyntaxHighlighter.apply(to: textView, language: language, palette: themes.palette)
        lastHighlightedBody = body
        lastHighlightedLanguage = language
    }

    // MARK: - UITextViewDelegate

    func textViewDidChange(_ textView: UITextView) {
        store.updateActive(body: textView.text)
        rehighlight()
    }

    // MARK: - Actions

    private func confirmClose(_ id: String) {
        guard let note = store.notes.first(where: { $0.id == id }) else { return }
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
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item], asCopy: true)
        picker.delegate = self
        picker.allowsMultipleSelection = false
        present(picker, animated: true)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        do {
            let data = try Data(contentsOf: url)
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
