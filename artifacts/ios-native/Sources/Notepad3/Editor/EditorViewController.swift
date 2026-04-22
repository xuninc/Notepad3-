import UIKit
import UniformTypeIdentifiers

/// Top-level editor surface. Hosts a collapsible find/replace bar, a
/// horizontal tab strip, and a UITextView. Navigation-bar buttons for
/// new / open / theme / find / more. All content flows through `NotesStore`;
/// visuals flow through `ThemeController`.
final class EditorViewController: UIViewController, UITextViewDelegate {
    private let store: NotesStore
    private let themes = ThemeController.shared
    private let findBar = FindReplaceBar()
    private let tabStrip = TabStripView()
    private let separator = UIView()
    private let textView = UITextView()
    private var notesToken: UUID?
    private var themeToken: UUID?
    private var findBarHeight: NSLayoutConstraint?
    private var lastHighlightedBody: String = ""
    private var lastHighlightedLanguage: NoteLanguage = .plain

    init(store: NotesStore) {
        self.store = store
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()

        configureFindBar()
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

    private func configureFindBar() {
        findBar.translatesAutoresizingMaskIntoConstraints = false
        findBar.clipsToBounds = true
        findBar.onFindChanged = { [weak self] _ in /* handled on Next */ _ = self }
        findBar.onNext = { [weak self] in self?.findNext(backwards: false) }
        findBar.onPrevious = { [weak self] in self?.findNext(backwards: true) }
        findBar.onClose = { [weak self] in self?.setFindBarVisible(false) }
        findBar.onReplaceOne = { [weak self] replacement in self?.replaceCurrent(with: replacement) }
        findBar.onReplaceAll = { [weak self] replacement in self?.replaceAll(with: replacement) }
        view.addSubview(findBar)
    }

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
        let h = findBar.heightAnchor.constraint(equalToConstant: 0)
        findBarHeight = h

        NSLayoutConstraint.activate([
            findBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            findBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            findBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            h,

            tabStrip.topAnchor.constraint(equalTo: findBar.bottomAnchor),
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

        let findButton = UIBarButtonItem(
            image: UIImage(systemName: "magnifyingglass"),
            style: .plain,
            target: self,
            action: #selector(toggleFind)
        )
        findButton.accessibilityLabel = "Find"

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

        navigationItem.rightBarButtonItems = [moreButton, themeButton, findButton, newButton]
    }

    private func themeIconForCurrentMode() -> UIImage? {
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

        let lineGroup = UIMenu(title: "Line tools", image: UIImage(systemName: "list.bullet"), children: [
            UIAction(title: "Sort lines", image: UIImage(systemName: "arrow.up.arrow.down")) { [weak self] _ in self?.sortLines() },
            UIAction(title: "Trim trailing spaces", image: UIImage(systemName: "scissors")) { [weak self] _ in self?.trimTrailingSpaces() },
            UIAction(title: "Duplicate current line", image: UIImage(systemName: "plus.square.on.square")) { [weak self] _ in self?.duplicateCurrentLine() },
            UIAction(title: "Delete current line", image: UIImage(systemName: "minus.square"), attributes: .destructive) { [weak self] _ in self?.deleteCurrentLine() },
        ])

        let insertDate = UIAction(title: "Insert date/time", image: UIImage(systemName: "clock")) { [weak self] _ in
            let now = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short)
            self?.insertText(now)
        }

        let duplicate = UIAction(title: "Duplicate current doc", image: UIImage(systemName: "plus.square.on.square")) { [weak self] _ in
            guard let self else { return }
            self.store.duplicate(id: self.store.activeId)
        }
        let rename = UIAction(title: "Rename current doc", image: UIImage(systemName: "pencil")) { [weak self] _ in
            guard let self else { return }
            self.promptRename(self.store.activeId)
        }
        let close = UIAction(title: "Close current doc", image: UIImage(systemName: "xmark"), attributes: .destructive) { [weak self] _ in
            guard let self else { return }
            self.confirmClose(self.store.activeId)
        }

        return UIMenu(title: "", children: [prefs, lineGroup, insertDate, duplicate, rename, close])
    }

    @objc private func toggleTheme() { themes.quickToggleDarkLight() }

    @objc private func toggleFind() {
        let visible = (findBarHeight?.constant ?? 0) > 0
        setFindBarVisible(!visible)
    }

    private func setFindBarVisible(_ visible: Bool) {
        let target: CGFloat = visible ? (findBar.showsReplace ? 88 : 44) : 0
        findBarHeight?.constant = target
        UIView.animate(withDuration: 0.2) { self.view.layoutIfNeeded() }
        if visible {
            findBar.focusFind()
        } else {
            findBar.findField.resignFirstResponder()
            findBar.replaceField.resignFirstResponder()
        }
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
        findBar.applyPalette(palette)

        let nav = UINavigationBarAppearance()
        nav.configureWithDefaultBackground()
        nav.backgroundColor = palette.card
        nav.titleTextAttributes = [.foregroundColor: palette.foreground]
        navigationItem.standardAppearance = nav
        navigationItem.scrollEdgeAppearance = nav
        navigationController?.navigationBar.tintColor = palette.primary

        if let items = navigationItem.rightBarButtonItems, items.count >= 3 {
            items[1].image = themeIconForCurrentMode()
        }

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

    // MARK: - Find / replace

    private func findNext(backwards: Bool) {
        let needle = findBar.findField.text ?? ""
        guard !needle.isEmpty else { return }
        let haystack = textView.text ?? ""
        let ns = haystack as NSString

        let caret = textView.selectedRange
        let searchRange: NSRange
        let options: NSString.CompareOptions = backwards ? [.caseInsensitive, .backwards] : [.caseInsensitive]

        if backwards {
            searchRange = NSRange(location: 0, length: max(0, caret.location))
        } else {
            let start = NSMaxRange(caret)
            searchRange = NSRange(location: min(start, ns.length), length: max(0, ns.length - start))
        }

        var found = ns.range(of: needle, options: options, range: searchRange)
        if found.location == NSNotFound {
            // Wrap around
            found = ns.range(of: needle, options: options, range: NSRange(location: 0, length: ns.length))
        }
        guard found.location != NSNotFound else { return }

        textView.selectedRange = found
        textView.scrollRangeToVisible(found)
    }

    private func replaceCurrent(with replacement: String) {
        let sel = textView.selectedRange
        guard sel.length > 0 else {
            findNext(backwards: false)
            return
        }
        let ns = (textView.text ?? "") as NSString
        let updated = ns.replacingCharacters(in: sel, with: replacement) as String
        commitReplacement(updated, selectionAfter: NSRange(location: sel.location + (replacement as NSString).length, length: 0))
        findNext(backwards: false)
    }

    private func replaceAll(with replacement: String) {
        let needle = findBar.findField.text ?? ""
        guard !needle.isEmpty else { return }
        let ns = (textView.text ?? "") as NSString
        let full = NSRange(location: 0, length: ns.length)
        let updated = ns.replacingOccurrences(of: needle, with: replacement, options: [.caseInsensitive], range: full)
        commitReplacement(updated, selectionAfter: NSRange(location: 0, length: 0))
    }

    /// Writes `newBody` to both the native UITextView (so the user sees it
    /// immediately) and the store (so persistence + observers fire).
    private func commitReplacement(_ newBody: String, selectionAfter: NSRange) {
        textView.text = newBody
        let len = (newBody as NSString).length
        let sel = NSRange(location: min(selectionAfter.location, len), length: min(selectionAfter.length, len - min(selectionAfter.location, len)))
        textView.selectedRange = sel
        store.updateActive(body: newBody)
        rehighlight(force: true)
    }

    // MARK: - Line tools

    private func sortLines() {
        let body = textView.text ?? ""
        let sorted = body.split(separator: "\n", omittingEmptySubsequences: false)
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
            .joined(separator: "\n")
        commitReplacement(sorted, selectionAfter: NSRange(location: 0, length: 0))
    }

    private func trimTrailingSpaces() {
        let body = textView.text ?? ""
        let trimmed = body.split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.replacingOccurrences(of: #"[ \t]+$"#, with: "", options: .regularExpression) }
            .joined(separator: "\n")
        commitReplacement(trimmed, selectionAfter: textView.selectedRange)
    }

    private func duplicateCurrentLine() {
        let body = textView.text ?? ""
        let ns = body as NSString
        let caret = textView.selectedRange.location
        let (lineStart, lineEnd) = lineRange(in: ns, at: caret)
        let line = ns.substring(with: NSRange(location: lineStart, length: lineEnd - lineStart))
        let inserted = "\n" + line
        let newBody = ns.replacingCharacters(in: NSRange(location: lineEnd, length: 0), with: inserted)
        commitReplacement(newBody, selectionAfter: NSRange(location: caret + (inserted as NSString).length, length: 0))
    }

    private func deleteCurrentLine() {
        let body = textView.text ?? ""
        let ns = body as NSString
        let caret = textView.selectedRange.location
        let (lineStart, lineEnd) = lineRange(in: ns, at: caret)
        // Also consume trailing newline if present
        let removeEnd = (lineEnd < ns.length && ns.character(at: lineEnd) == 0x0A /* \n */) ? lineEnd + 1 : lineEnd
        let newBody = ns.replacingCharacters(in: NSRange(location: lineStart, length: removeEnd - lineStart), with: "")
        commitReplacement(newBody, selectionAfter: NSRange(location: lineStart, length: 0))
    }

    private func insertText(_ value: String) {
        let sel = textView.selectedRange
        let ns = (textView.text ?? "") as NSString
        let newBody = ns.replacingCharacters(in: sel, with: value)
        let nextCaret = sel.location + (value as NSString).length
        commitReplacement(newBody, selectionAfter: NSRange(location: nextCaret, length: 0))
    }

    /// Returns (start, end) where start is inclusive (or start-of-text) and
    /// end is exclusive of the trailing newline character.
    private func lineRange(in ns: NSString, at location: Int) -> (Int, Int) {
        let clamped = max(0, min(location, ns.length))
        var start = clamped
        while start > 0, ns.character(at: start - 1) != 0x0A { start -= 1 }
        var end = clamped
        while end < ns.length, ns.character(at: end) != 0x0A { end += 1 }
        return (start, end)
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
