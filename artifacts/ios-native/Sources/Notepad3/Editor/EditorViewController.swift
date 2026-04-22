import UIKit
import UniformTypeIdentifiers

/// Top-level editor. Hosts BOTH layouts (mobile chrome + classic chrome);
/// visibility is driven by `Preferences.layoutMode`. All state lives in the
/// stores (`NotesStore`, `ThemeController`, `Preferences`) — this VC is a
/// view over them that observes and reacts.
final class EditorViewController: UIViewController, UITextViewDelegate {
    private let store: NotesStore
    private let themes = ThemeController.shared
    private let prefs = Preferences.shared

    // Shared chrome (both modes)
    private let findBar = FindReplaceBar()
    private let tabStrip = TabStripView()
    private let separator = UIView()
    private let textView = UITextView()

    // Mobile-only chrome
    private let mobileBottomBar = MobileBottomBar()
    private let mobileFab = MobileFAB()

    // Classic-only chrome
    private let classicTitleBar = ClassicTitleBar()
    private let aeroMenuBar = AeroMenuBar()
    private let classicToolbar = ClassicToolbar()
    private let statusBar = StatusBar()
    private let lineGutter = LineGutter()

    // Keyboard accessory — always attached to the text input
    private let keyboardAccessory = KeyboardAccessoryView()

    // Markdown preview — shown in-place when previewMode is on for .markdown docs
    private let markdownPreview = MarkdownPreviewView()
    private let markdownPreviewScroll = UIScrollView()
    private var previewMode = false

    // Pointer overlay + optional trackpad
    private let pointerOverlay = PointerOverlay()
    private var virtualTrackpad: VirtualTrackpad?

    // Mode state (not persisted)
    private var zenMode = false
    private var readMode = false { didSet { textView.isEditable = !readMode; keyboardAccessory.readMode = readMode } }
    private var toolbarOpen = true

    // Observer tokens
    private var notesToken: UUID?
    private var themeToken: UUID?
    private var prefsToken: UUID?

    // Dynamic constraints
    private var findBarHeight: NSLayoutConstraint?
    private var mobileConstraints: [NSLayoutConstraint] = []
    private var classicConstraints: [NSLayoutConstraint] = []
    private var sharedConstraints: [NSLayoutConstraint] = []

    // Highlighting cache (cheap short-circuit when nothing changed)
    private var lastHighlightedBody: String = ""
    private var lastHighlightedLanguage: NoteLanguage = .plain

    init(store: NotesStore) {
        self.store = store
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        configureTextView()
        configureMarkdownPreview()
        configureFindBar()
        configureTabStrip()
        configureMobileChrome()
        configureClassicChrome()
        configureKeyboardAccessory()

        // Pointer overlay sits on top of everything, ignores touches.
        pointerOverlay.translatesAutoresizingMaskIntoConstraints = false
        pointerOverlay.isVisible = false
        view.addSubview(pointerOverlay)

        buildConstraints()
        applyLayoutMode(animated: false)
        applyPalette()

        // Seed the view from the store
        textView.text = store.activeNote.body
        title = store.activeNote.title
        tabStrip.layout = prefs.tabsLayout == .list ? .list : .tabs
        tabStrip.reload(notes: store.notes, activeId: store.activeId)
        classicToolbar.setLabelsVisible(prefs.toolbarLabels)
        classicToolbar.setRows(prefs.toolbarRows == .double ? 2 : 1)
        rehighlight(force: true)
        refreshStatusBar()

        notesToken = store.observe { [weak self] in self?.syncFromStore() }
        themeToken = themes.observe { [weak self] in self?.applyPalette() }
        prefsToken = prefs.observe { [weak self] in self?.onPreferencesChanged() }

        configureNavBar()
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
        if let t = prefsToken { prefs.unobserve(t) }
    }

    // MARK: - Subview configuration

    private func configureMarkdownPreview() {
        markdownPreviewScroll.translatesAutoresizingMaskIntoConstraints = false
        markdownPreviewScroll.alwaysBounceVertical = true
        markdownPreviewScroll.isHidden = true
        view.addSubview(markdownPreviewScroll)

        markdownPreview.translatesAutoresizingMaskIntoConstraints = false
        markdownPreview.isActive = false
        markdownPreviewScroll.addSubview(markdownPreview)

        NSLayoutConstraint.activate([
            markdownPreview.topAnchor.constraint(equalTo: markdownPreviewScroll.contentLayoutGuide.topAnchor),
            markdownPreview.leadingAnchor.constraint(equalTo: markdownPreviewScroll.contentLayoutGuide.leadingAnchor),
            markdownPreview.trailingAnchor.constraint(equalTo: markdownPreviewScroll.contentLayoutGuide.trailingAnchor),
            markdownPreview.bottomAnchor.constraint(equalTo: markdownPreviewScroll.contentLayoutGuide.bottomAnchor),
            markdownPreview.widthAnchor.constraint(equalTo: markdownPreviewScroll.frameLayoutGuide.widthAnchor),

            markdownPreviewScroll.leadingAnchor.constraint(equalTo: textView.leadingAnchor),
            markdownPreviewScroll.trailingAnchor.constraint(equalTo: textView.trailingAnchor),
            markdownPreviewScroll.topAnchor.constraint(equalTo: textView.topAnchor),
            markdownPreviewScroll.bottomAnchor.constraint(equalTo: textView.bottomAnchor),
        ])
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

    private func configureFindBar() {
        findBar.translatesAutoresizingMaskIntoConstraints = false
        findBar.clipsToBounds = true
        findBar.onNext = { [weak self] in self?.findNext(backwards: false) }
        findBar.onPrevious = { [weak self] in self?.findNext(backwards: true) }
        findBar.onClose = { [weak self] in self?.setFindBarVisible(false) }
        findBar.onReplaceOne = { [weak self] replacement in self?.replaceCurrent(with: replacement) }
        findBar.onReplaceAll = { [weak self] replacement in self?.replaceAll(with: replacement) }
        view.addSubview(findBar)
    }

    private func configureTabStrip() {
        tabStrip.translatesAutoresizingMaskIntoConstraints = false
        tabStrip.onSelect = { [weak self] id in Haptics.selectionChanged(); self?.store.setActive(id) }
        tabStrip.onClose = { [weak self] id in self?.confirmClose(id) }
        tabStrip.onRename = { [weak self] id in self?.promptRename(id) }
        tabStrip.onDuplicate = { [weak self] id in Haptics.impact(.light); self?.store.duplicate(id: id) }
        tabStrip.onCloseOthers = { [weak self] id in Haptics.impact(.medium); self?.store.closeOthers(keep: id) }
        tabStrip.onOpenListModal = { [weak self] in Haptics.selectionChanged(); self?.presentDocsList() }
        view.addSubview(tabStrip)
    }

    private func configureMobileChrome() {
        mobileBottomBar.translatesAutoresizingMaskIntoConstraints = false
        mobileBottomBar.onOpen = { [weak self] in Haptics.selectionChanged(); self?.presentOpenMenu() }
        mobileBottomBar.onFind = { [weak self] in Haptics.selectionChanged(); self?.toggleFind() }
        mobileBottomBar.onCompare = { [weak self] in Haptics.selectionChanged(); self?.presentCompare() }
        mobileBottomBar.onNew = { [weak self] in Haptics.impact(.light); self?.store.createBlank() }
        mobileBottomBar.onMore = { [weak self] in Haptics.selectionChanged(); self?.presentMobileMore() }
        view.addSubview(mobileBottomBar)

        mobileFab.onTap = { [weak self] in Haptics.impact(.medium); self?.store.createBlank() }
        view.addSubview(mobileFab)
    }

    private func configureClassicChrome() {
        classicTitleBar.translatesAutoresizingMaskIntoConstraints = false
        classicTitleBar.setTitle(store.activeNote.title)
        view.addSubview(classicTitleBar)

        aeroMenuBar.translatesAutoresizingMaskIntoConstraints = false
        wireAeroMenuBar()
        view.addSubview(aeroMenuBar)

        classicToolbar.translatesAutoresizingMaskIntoConstraints = false
        wireClassicToolbar()
        view.addSubview(classicToolbar)

        statusBar.translatesAutoresizingMaskIntoConstraints = false
        statusBar.onLanguageTap = { [weak self] in self?.presentLanguagePicker() }
        statusBar.onThemeTap = { [weak self] in self?.presentSettings() }
        view.addSubview(statusBar)

        lineGutter.translatesAutoresizingMaskIntoConstraints = false
        lineGutter.attach(to: textView)
        view.addSubview(lineGutter)
    }

    private func wireAeroMenuBar() {
        aeroMenuBar.onNew = { [weak self] in self?.store.createBlank() }
        aeroMenuBar.onOpen = { [weak self] in self?.presentFileOpen() }
        aeroMenuBar.onSave = { /* notes auto-save to disk; no explicit action */ }
        aeroMenuBar.onDuplicateDoc = { [weak self] in guard let self else { return }; self.store.duplicate(id: self.store.activeId) }
        aeroMenuBar.onClose = { [weak self] in guard let self else { return }; self.confirmClose(self.store.activeId) }
        aeroMenuBar.onCloseOthers = { [weak self] in guard let self else { return }; self.store.closeOthers(keep: self.store.activeId) }

        aeroMenuBar.onUndo = { [weak self] in self?.textView.undoManager?.undo() }
        aeroMenuBar.onRedo = { [weak self] in self?.textView.undoManager?.redo() }
        aeroMenuBar.onCut = { [weak self] in self?.cutSelection() }
        aeroMenuBar.onCopy = { [weak self] in self?.copySelection() }
        aeroMenuBar.onPaste = { [weak self] in self?.pasteFromClipboard() }
        aeroMenuBar.onSelectAll = { [weak self] in self?.selectAll(nil) }
        aeroMenuBar.onFind = { [weak self] in self?.toggleFind() }
        aeroMenuBar.onGotoLine = { [weak self] in self?.presentGotoLine() }
        aeroMenuBar.onInsertDateTime = { [weak self] in self?.insertText(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short)) }
        aeroMenuBar.onSortLines = { [weak self] in self?.sortLines() }
        aeroMenuBar.onTrimSpaces = { [weak self] in self?.trimTrailingSpaces() }
        aeroMenuBar.onDuplicateLine = { [weak self] in self?.duplicateCurrentLine() }
        aeroMenuBar.onDeleteLine = { [weak self] in self?.deleteCurrentLine() }

        aeroMenuBar.onToggleToolbar = { [weak self] in self?.toolbarOpen.toggle(); self?.classicToolbar.isHidden = !(self?.toolbarOpen ?? true) }
        aeroMenuBar.onToggleToolbarLabels = { [weak self] in
            guard let self else { return }
            self.prefs.toolbarLabels.toggle()
            self.classicToolbar.setLabelsVisible(self.prefs.toolbarLabels)
        }
        aeroMenuBar.onSetToolbarRowsSingle = { [weak self] in self?.prefs.toolbarRows = .single; self?.classicToolbar.setRows(1) }
        aeroMenuBar.onSetToolbarRowsDouble = { [weak self] in self?.prefs.toolbarRows = .double; self?.classicToolbar.setRows(2) }
        aeroMenuBar.onToggleZen = { [weak self] in self?.setZenMode(!(self?.zenMode ?? false)) }
        aeroMenuBar.onToggleCompare = { [weak self] in self?.presentCompare() }
        aeroMenuBar.onSwitchToMobileLayout = { [weak self] in self?.prefs.layoutMode = .mobile }
        aeroMenuBar.onPreferences = { [weak self] in self?.presentSettings() }
        aeroMenuBar.onPickTheme = { [weak self] name in self?.themes.setPreference(.named(name)) }
        aeroMenuBar.onAbout = { [weak self] in self?.presentAbout() }
        aeroMenuBar.onVersion = { [weak self] in self?.presentAbout() }

        // Live check-state providers
        aeroMenuBar.isToolbarOpen = { [weak self] in self?.toolbarOpen ?? true }
        aeroMenuBar.isToolbarLabelsVisible = { [weak self] in self?.prefs.toolbarLabels ?? false }
        aeroMenuBar.isToolbarRowsDouble = { [weak self] in (self?.prefs.toolbarRows ?? .single) == .double }
        aeroMenuBar.isZenMode = { [weak self] in self?.zenMode ?? false }
        aeroMenuBar.isCompareOpen = { false /* compare is modal, never "open" in-place */ }
        aeroMenuBar.currentTheme = { [weak self] in self?.themes.resolvedTheme ?? .light }
    }

    private func wireClassicToolbar() {
        classicToolbar.onNew = { [weak self] in self?.store.createBlank() }
        classicToolbar.onOpen = { [weak self] in self?.presentFileOpen() }
        classicToolbar.onSave = { /* notes auto-save to disk */ }
        classicToolbar.onCut = { [weak self] in self?.cutSelection() }
        classicToolbar.onCopy = { [weak self] in self?.copySelection() }
        classicToolbar.onPaste = { [weak self] in self?.pasteFromClipboard() }
        classicToolbar.onUndo = { [weak self] in self?.textView.undoManager?.undo() }
        classicToolbar.onRedo = { [weak self] in self?.textView.undoManager?.redo() }
        classicToolbar.onFind = { [weak self] in self?.toggleFind() }
        classicToolbar.onReplace = { [weak self] in self?.toggleFind(showReplace: true) }
        classicToolbar.onTrim = { [weak self] in self?.trimTrailingSpaces() }
        classicToolbar.onSort = { [weak self] in self?.sortLines() }
        classicToolbar.onDocs = { [weak self] in self?.presentDocsList() }
        classicToolbar.onCompare = { [weak self] in self?.presentCompare() }
        classicToolbar.onMore = { [weak self] in self?.presentMobileMore() }

        // New (expanded) buttons
        classicToolbar.onSelectAll = { [weak self] in self?.selectAll(nil) }
        classicToolbar.onSelectLine = { [weak self] in self?.selectLine() }
        classicToolbar.onSelectParagraph = { [weak self] in self?.selectParagraph() }
        classicToolbar.onInsertDateTime = { [weak self] in
            self?.insertText(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short))
        }
        classicToolbar.onDuplicateLine = { [weak self] in self?.duplicateCurrentLine() }
        classicToolbar.onDeleteLine = { [weak self] in self?.deleteCurrentLine() }
        classicToolbar.onGotoLine = { [weak self] in self?.presentGotoLine() }
        classicToolbar.onToggleReadMode = { [weak self] in self?.readMode.toggle(); self?.classicToolbar.refresh() }
        classicToolbar.onToggleZenMode = { [weak self] in self?.setZenMode(!(self?.zenMode ?? false)); self?.classicToolbar.refresh() }
        classicToolbar.onToggleTrackpad = { [weak self] in self?.toggleTrackpad(); self?.classicToolbar.refresh() }
        classicToolbar.onPreferences = { [weak self] in self?.presentSettings() }
        classicToolbar.onDeleteDoc = { [weak self] in
            guard let self else { return }; self.confirmClose(self.store.activeId)
        }

        // Live check-state for toggleable icons
        classicToolbar.isReadMode = { [weak self] in self?.readMode ?? false }
        classicToolbar.isZenMode = { [weak self] in self?.zenMode ?? false }
        classicToolbar.isTrackpadOn = { [weak self] in self?.virtualTrackpad != nil }
    }

    /// Select the paragraph (blank-line-delimited block) around the caret.
    private func selectParagraph() {
        let ns = (textView.text ?? "") as NSString
        let at = min(textView.selectedRange.location, ns.length)
        var start = at
        // Walk backwards until we hit a blank line or start of text.
        while start > 0 {
            let (ls, le) = lineRange(in: ns, at: start - 1)
            if ls == le { break } // empty line
            start = ls
            if ls == 0 { break }
        }
        var end = at
        while end < ns.length {
            let (ls, le) = lineRange(in: ns, at: end)
            if ls == le { break }
            end = le + (le < ns.length ? 1 : 0)
            if end >= ns.length { end = ns.length; break }
        }
        if end > start { textView.selectedRange = NSRange(location: start, length: end - start) }
    }

    private func configureKeyboardAccessory() {
        let accessory = keyboardAccessory
        accessory.autoresizingMask = [.flexibleWidth]
        accessory.frame = CGRect(x: 0, y: 0, width: 320, height: 44)
        accessory.rows = prefs.accessoryRows == .double ? .double : .single
        accessory.onHide = { [weak self] in self?.textView.resignFirstResponder() }
        accessory.onReadToggle = { [weak self] in self?.readMode.toggle() }
        accessory.onUndo = { [weak self] in self?.textView.undoManager?.undo() }
        accessory.onRedo = { [weak self] in self?.textView.undoManager?.redo() }
        accessory.onCut = { [weak self] in self?.cutSelection() }
        accessory.onCopy = { [weak self] in self?.copySelection() }
        accessory.onPaste = { [weak self] in self?.pasteFromClipboard() }
        accessory.onSelectWord = { [weak self] in self?.selectWord() }
        accessory.onSelectLine = { [weak self] in self?.selectLine() }
        accessory.onSelectAll = { [weak self] in self?.selectAll(nil) }
        accessory.onArrow = { [weak self] dir in self?.moveCursor(direction: dir) }
        accessory.onFind = { [weak self] in self?.toggleFind() }
        accessory.onReplace = { [weak self] in self?.toggleFind(showReplace: true) }
        accessory.onInsertDate = { [weak self] in self?.insertText(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short)) }
        accessory.onOpenDocs = { [weak self] in self?.presentDocsList() }
        accessory.onCompare = { [weak self] in self?.presentCompare() }
        accessory.onMore = { [weak self] in self?.presentMobileMore() }
        textView.inputAccessoryView = accessory
    }

    // MARK: - Constraint stacks

    private func buildConstraints() {
        let guide = view.safeAreaLayoutGuide
        let findHeight = findBar.heightAnchor.constraint(equalToConstant: 0)
        findBarHeight = findHeight

        // Shared: find bar pinned to safe top, separator/textView anchors set per mode.
        sharedConstraints = [
            findBar.topAnchor.constraint(equalTo: guide.topAnchor),
            findBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            findBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            findHeight,

            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            pointerOverlay.topAnchor.constraint(equalTo: view.topAnchor),
            pointerOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pointerOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            pointerOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            separator.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale),
        ]

        // Mobile mode: [findBar] [tabStrip] [separator] [textView] [mobileBottomBar@bottom]
        //              mobileFab floats bottom-right above the bottom bar.
        mobileConstraints = [
            tabStrip.topAnchor.constraint(equalTo: findBar.bottomAnchor),
            tabStrip.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tabStrip.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tabStrip.heightAnchor.constraint(equalToConstant: 44),

            separator.topAnchor.constraint(equalTo: tabStrip.bottomAnchor),

            textView.topAnchor.constraint(equalTo: separator.bottomAnchor),
            textView.bottomAnchor.constraint(equalTo: mobileBottomBar.topAnchor),

            mobileBottomBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mobileBottomBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mobileBottomBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            // Explicit height. MobileBottomBar has no intrinsic content size
            // and its internal stack anchors to its own safeAreaLayoutGuide,
            // which doesn't constrain the outer frame — the solver was free to
            // let the bar fill all remaining space and collapse the text view
            // to zero height. 54pt of chrome + the 34pt home-indicator inset.
            mobileBottomBar.heightAnchor.constraint(equalToConstant: 88),

            mobileFab.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            mobileFab.bottomAnchor.constraint(equalTo: mobileBottomBar.topAnchor, constant: -12),
        ]

        // Classic mode: [findBar] [titleBar] [aeroMenu] [classicToolbar] [tabStrip]
        //               [separator] [lineGutter + textView] [statusBar@bottom]
        classicConstraints = [
            classicTitleBar.topAnchor.constraint(equalTo: findBar.bottomAnchor),
            classicTitleBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            classicTitleBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            classicTitleBar.heightAnchor.constraint(equalToConstant: 22),

            aeroMenuBar.topAnchor.constraint(equalTo: classicTitleBar.bottomAnchor),
            aeroMenuBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            aeroMenuBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            aeroMenuBar.heightAnchor.constraint(equalToConstant: 28),

            classicToolbar.topAnchor.constraint(equalTo: aeroMenuBar.bottomAnchor),
            classicToolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            classicToolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            tabStrip.topAnchor.constraint(equalTo: classicToolbar.bottomAnchor),
            tabStrip.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tabStrip.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tabStrip.heightAnchor.constraint(equalToConstant: 36),

            separator.topAnchor.constraint(equalTo: tabStrip.bottomAnchor),

            lineGutter.topAnchor.constraint(equalTo: separator.bottomAnchor),
            lineGutter.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            lineGutter.widthAnchor.constraint(equalToConstant: 40),
            lineGutter.bottomAnchor.constraint(equalTo: statusBar.topAnchor),

            textView.topAnchor.constraint(equalTo: separator.bottomAnchor),
            textView.bottomAnchor.constraint(equalTo: statusBar.topAnchor),

            statusBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            statusBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            statusBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            statusBar.heightAnchor.constraint(equalToConstant: 24),
        ]

        NSLayoutConstraint.activate(sharedConstraints)
    }

    /// Swap the active constraint set based on the current layout mode, then
    /// toggle visibility of the mode-specific chrome.
    private func applyLayoutMode(animated: Bool) {
        let mode = prefs.layoutMode

        NSLayoutConstraint.deactivate(mobileConstraints)
        NSLayoutConstraint.deactivate(classicConstraints)

        // Common hidden defaults; the active mode re-shows its own chrome.
        mobileBottomBar.isHidden = true
        mobileFab.isHidden = true
        classicTitleBar.isHidden = true
        aeroMenuBar.isHidden = true
        classicToolbar.isHidden = true
        statusBar.isHidden = true
        lineGutter.isHidden = true

        switch mode {
        case .mobile:
            mobileBottomBar.isHidden = false
            mobileFab.isHidden = false
            NSLayoutConstraint.activate(mobileConstraints)
            navigationController?.setNavigationBarHidden(false, animated: animated)
        case .classic:
            classicTitleBar.isHidden = false
            aeroMenuBar.isHidden = false
            classicToolbar.isHidden = !toolbarOpen
            statusBar.isHidden = false
            lineGutter.isHidden = false
            NSLayoutConstraint.activate(classicConstraints)
            // Classic mode hides the iOS nav bar — ClassicTitleBar + AeroMenuBar take its place.
            navigationController?.setNavigationBarHidden(true, animated: animated)
        }

        // Tab strip lives in both modes but the height constant differs;
        // rebuilding constraints handles that.
        tabStrip.isHidden = zenMode

        if animated {
            UIView.animate(withDuration: 0.22) { self.view.layoutIfNeeded() }
        } else {
            view.layoutIfNeeded()
        }
    }

    // MARK: - Nav bar (mobile only)

    private func configureNavBar() {
        navigationItem.largeTitleDisplayMode = .never

        let newButton = UIBarButtonItem(image: UIImage(systemName: "square.and.pencil"), primaryAction: nil, menu: newDocumentMenu())
        newButton.accessibilityLabel = "New document"

        let findButton = UIBarButtonItem(image: UIImage(systemName: "magnifyingglass"), style: .plain, target: self, action: #selector(toggleFindAction))
        findButton.accessibilityLabel = "Find"

        let themeButton = UIBarButtonItem(image: themeIconForCurrentMode(), style: .plain, target: self, action: #selector(toggleTheme))
        themeButton.accessibilityLabel = "Toggle light / dark"

        let moreButton = UIBarButtonItem(image: UIImage(systemName: "ellipsis.circle"), primaryAction: nil, menu: moreMenu())
        moreButton.accessibilityLabel = "More"

        navigationItem.rightBarButtonItems = [moreButton, themeButton, findButton, newButton]
    }

    private func themeIconForCurrentMode() -> UIImage? {
        UIImage(systemName: themes.resolvedTheme == .dark ? "sun.max" : "moon")
    }

    private func newDocumentMenu() -> UIMenu {
        let blank = UIAction(title: "New Blank", image: UIImage(systemName: "doc")) { [weak self] _ in self?.store.createBlank() }
        let open = UIAction(title: "Open from Files…", image: UIImage(systemName: "folder")) { [weak self] _ in self?.presentFileOpen() }
        return UIMenu(title: "", children: [blank, open])
    }

    private func moreMenu() -> UIMenu {
        let prefsItem = UIAction(title: "Preferences…", image: UIImage(systemName: "gear")) { [weak self] _ in self?.presentSettings() }
        let compareItem = UIAction(title: "Compare documents", image: UIImage(systemName: "rectangle.split.1x2")) { [weak self] _ in self?.presentCompare() }
        let languageItem = UIAction(title: "Change language", image: UIImage(systemName: "curlybraces")) { [weak self] _ in self?.presentLanguagePicker() }
        let gotoItem = UIAction(title: "Go to line…", image: UIImage(systemName: "arrow.down.to.line")) { [weak self] _ in self?.presentGotoLine() }
        let trackpadItem = UIAction(title: "Virtual trackpad", image: UIImage(systemName: "rectangle.and.hand.point.up.left")) { [weak self] _ in self?.toggleTrackpad() }
        let previewItem = UIAction(
            title: previewMode ? "Edit markdown" : "Preview markdown",
            image: UIImage(systemName: previewMode ? "pencil" : "eye.fill"),
            attributes: store.activeNote.language == .markdown ? [] : .disabled
        ) { [weak self] _ in self?.togglePreviewMode() }
        let readItem = UIAction(title: readMode ? "Exit read mode" : "Read mode", image: UIImage(systemName: readMode ? "eye.slash" : "eye")) { [weak self] _ in self?.readMode.toggle() }
        let zenItem = UIAction(title: zenMode ? "Exit zen" : "Zen mode", image: UIImage(systemName: "rectangle.compress.vertical")) { [weak self] _ in self?.setZenMode(!(self?.zenMode ?? false)) }

        let lineGroup = UIMenu(title: "Line tools", image: UIImage(systemName: "list.bullet"), children: [
            UIAction(title: "Sort lines", image: UIImage(systemName: "arrow.up.arrow.down")) { [weak self] _ in self?.sortLines() },
            UIAction(title: "Trim trailing spaces", image: UIImage(systemName: "scissors")) { [weak self] _ in self?.trimTrailingSpaces() },
            UIAction(title: "Duplicate current line", image: UIImage(systemName: "plus.square.on.square")) { [weak self] _ in self?.duplicateCurrentLine() },
            UIAction(title: "Delete current line", image: UIImage(systemName: "minus.square"), attributes: .destructive) { [weak self] _ in self?.deleteCurrentLine() },
        ])

        let insertDate = UIAction(title: "Insert date/time", image: UIImage(systemName: "clock")) { [weak self] _ in
            self?.insertText(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short))
        }

        let duplicateDoc = UIAction(title: "Duplicate current doc", image: UIImage(systemName: "plus.square.on.square")) { [weak self] _ in
            guard let self else { return }; self.store.duplicate(id: self.store.activeId)
        }
        let renameDoc = UIAction(title: "Rename current doc", image: UIImage(systemName: "pencil")) { [weak self] _ in
            guard let self else { return }; self.promptRename(self.store.activeId)
        }
        let closeDoc = UIAction(title: "Close current doc", image: UIImage(systemName: "xmark"), attributes: .destructive) { [weak self] _ in
            guard let self else { return }; self.confirmClose(self.store.activeId)
        }

        return UIMenu(title: "", children: [
            prefsItem, compareItem, languageItem, gotoItem, trackpadItem, previewItem,
            readItem, zenItem,
            lineGroup, insertDate,
            duplicateDoc, renameDoc, closeDoc,
        ])
    }

    @objc private func toggleTheme() { themes.quickToggleDarkLight() }
    @objc private func toggleFindAction() { toggleFind() }

    // MARK: - Theme / preferences repaint

    private func applyPalette() {
        let palette = themes.palette

        view.backgroundColor = palette.background
        textView.backgroundColor = palette.editorBackground
        textView.tintColor = palette.primary
        separator.backgroundColor = palette.border
        tabStrip.applyPalette(palette)
        findBar.applyPalette(palette)
        markdownPreview.applyPalette(palette)
        markdownPreviewScroll.backgroundColor = palette.editorBackground
        mobileBottomBar.applyPalette(palette)
        mobileFab.applyPalette(palette)
        aeroMenuBar.applyPalette(palette)
        classicToolbar.applyPalette(palette)
        classicTitleBar.applyPalette(palette)
        statusBar.applyPalette(palette)
        lineGutter.applyPalette(palette)
        keyboardAccessory.applyPalette(palette)
        pointerOverlay.applyPalette(palette)

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

    private func onPreferencesChanged() {
        // Layout mode may have flipped — reapply.
        applyLayoutMode(animated: true)
        // Tab strip layout (tabs vs list)
        tabStrip.layout = prefs.tabsLayout == .list ? .list : .tabs
        tabStrip.reload(notes: store.notes, activeId: store.activeId)
        // Toolbar prefs
        classicToolbar.setLabelsVisible(prefs.toolbarLabels)
        classicToolbar.setRows(prefs.toolbarRows == .double ? 2 : 1)
        classicToolbar.isHidden = (prefs.layoutMode == .classic) ? !toolbarOpen : true
        // Keyboard accessory rows
        keyboardAccessory.rows = prefs.accessoryRows == .double ? .double : .single
        // Custom palette may have changed
        applyPalette()
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
        classicTitleBar.setTitle(note.title)
        tabStrip.reload(notes: store.notes, activeId: store.activeId)
        rehighlight(force: true)
        refreshStatusBar()
    }

    private func refreshStatusBar() {
        guard prefs.layoutMode == .classic else { return }
        let body = textView.text ?? ""
        let ns = body as NSString
        let caret = textView.selectedRange.location
        let (line, col) = lineColumn(in: ns, at: caret)
        let lines = body.split(separator: "\n", omittingEmptySubsequences: false).count
        statusBar.update(
            cursorLine: line,
            cursorColumn: col,
            lineCount: lines,
            charCount: ns.length,
            selectionLength: textView.selectedRange.length,
            lineEndings: StatusBar.detectLineEndings(in: body),
            savedAt: store.activeNote.updatedAt,
            language: store.activeNote.language,
            theme: themes.resolvedTheme
        )
    }

    private func lineColumn(in ns: NSString, at location: Int) -> (Int, Int) {
        let clamped = max(0, min(location, ns.length))
        var line = 1
        var lastNewline = -1
        var i = 0
        while i < clamped {
            if ns.character(at: i) == 0x0A { line += 1; lastNewline = i }
            i += 1
        }
        return (line, clamped - lastNewline)
    }

    // MARK: - Highlighting

    private func rehighlight(force: Bool = false) {
        let body = textView.text ?? ""
        let language = store.activeNote.language
        if !force && body == lastHighlightedBody && language == lastHighlightedLanguage { return }
        SyntaxHighlighter.apply(to: textView, language: language, palette: themes.palette)
        lastHighlightedBody = body
        lastHighlightedLanguage = language
    }

    // MARK: - UITextViewDelegate

    func textViewDidChange(_ textView: UITextView) {
        store.updateActive(body: textView.text)
        rehighlight()
        if previewMode { markdownPreview.setMarkdown(textView.text ?? "") }
        keyboardAccessory.canUndo = textView.undoManager?.canUndo ?? false
        keyboardAccessory.canRedo = textView.undoManager?.canRedo ?? false
        refreshStatusBar()
    }

    func textViewDidChangeSelection(_ textView: UITextView) {
        keyboardAccessory.hasSelection = textView.selectedRange.length > 0
        refreshStatusBar()
    }

    // MARK: - Find / replace

    @objc private func toggleFind() { toggleFind(showReplace: false) }
    private func toggleFind(showReplace: Bool) {
        let visible = (findBarHeight?.constant ?? 0) > 0
        let becomingVisible = !visible
        if becomingVisible && showReplace { findBar.setShowsReplace(true) }
        setFindBarVisible(becomingVisible)
    }

    private func setFindBarVisible(_ visible: Bool) {
        let target: CGFloat = visible ? (findBar.showsReplace ? 88 : 44) : 0
        findBarHeight?.constant = target
        UIView.animate(withDuration: 0.2) { self.view.layoutIfNeeded() }
        if visible { findBar.focusFind() }
        else {
            findBar.findField.resignFirstResponder()
            findBar.replaceField.resignFirstResponder()
        }
        keyboardAccessory.findActive = visible && !findBar.showsReplace
        keyboardAccessory.replaceActive = visible && findBar.showsReplace
    }

    private func findNext(backwards: Bool) {
        let needle = findBar.findField.text ?? ""
        guard !needle.isEmpty else { return }
        let ns = (textView.text ?? "") as NSString
        let caret = textView.selectedRange

        // Build NSRegularExpression — regex-mode uses the user's text verbatim,
        // literal-mode escapes then optionally word-bounds, case-insensitive is
        // an option flag. This unifies find across plain/regex/word-boundary.
        let opts = findBar.options
        let pattern: String
        if opts.regex {
            pattern = needle
        } else {
            let escaped = NSRegularExpression.escapedPattern(for: needle)
            pattern = opts.wholeWord ? "\\b\(escaped)\\b" : escaped
        }
        var reOpts: NSRegularExpression.Options = []
        if !opts.caseSensitive { reOpts.insert(.caseInsensitive) }
        guard let re = try? NSRegularExpression(pattern: pattern, options: reOpts) else {
            Haptics.error()
            return
        }

        let full = NSRange(location: 0, length: ns.length)
        let matches = re.matches(in: ns as String, options: [], range: full)
        guard !matches.isEmpty else { Haptics.error(); return }

        let found: NSTextCheckingResult?
        if backwards {
            found = matches.last(where: { $0.range.location < caret.location })
                ?? matches.last
        } else {
            let start = NSMaxRange(caret)
            found = matches.first(where: { $0.range.location >= start })
                ?? matches.first
        }
        guard let r = found?.range else { return }
        textView.selectedRange = r
        textView.scrollRangeToVisible(r)
        Haptics.selectionChanged()
    }

    private func replaceCurrent(with replacement: String) {
        let sel = textView.selectedRange
        guard sel.length > 0 else { findNext(backwards: false); return }
        let ns = (textView.text ?? "") as NSString
        let updated = ns.replacingCharacters(in: sel, with: replacement) as String
        commitReplacement(updated, selectionAfter: NSRange(location: sel.location + (replacement as NSString).length, length: 0), actionName: "Replace")
        findNext(backwards: false)
    }

    private func replaceAll(with replacement: String) {
        let needle = findBar.findField.text ?? ""
        guard !needle.isEmpty else { return }
        let opts = findBar.options
        let pattern: String
        if opts.regex {
            pattern = needle
        } else {
            let escaped = NSRegularExpression.escapedPattern(for: needle)
            pattern = opts.wholeWord ? "\\b\(escaped)\\b" : escaped
        }
        var reOpts: NSRegularExpression.Options = []
        if !opts.caseSensitive { reOpts.insert(.caseInsensitive) }
        guard let re = try? NSRegularExpression(pattern: pattern, options: reOpts) else { Haptics.error(); return }
        let body = textView.text ?? ""
        // $1 etc. work in regex mode; in literal mode the replacement is also
        // passed through the template escaper so users can't accidentally
        // trigger backreferences.
        let template = opts.regex ? replacement : NSRegularExpression.escapedTemplate(for: replacement)
        let updated = re.stringByReplacingMatches(
            in: body,
            options: [],
            range: NSRange(location: 0, length: (body as NSString).length),
            withTemplate: template
        )
        commitReplacement(updated, selectionAfter: NSRange(location: 0, length: 0), actionName: "Replace All")
    }

    private func commitReplacement(_ newBody: String, selectionAfter: NSRange, actionName: String? = nil) {
        let oldBody = textView.text ?? ""
        let oldSelection = textView.selectedRange

        // Register undo so shake-to-undo (and the menu Undo item) reverses
        // programmatic mutations like sort / trim / replace / duplicate line.
        if let undoManager = textView.undoManager {
            undoManager.registerUndo(withTarget: self) { target in
                target.commitReplacement(oldBody, selectionAfter: oldSelection, actionName: actionName)
            }
            if let actionName { undoManager.setActionName(actionName) }
        }

        textView.text = newBody
        let len = (newBody as NSString).length
        let clampedLoc = min(selectionAfter.location, len)
        let clampedLen = min(selectionAfter.length, len - clampedLoc)
        textView.selectedRange = NSRange(location: clampedLoc, length: clampedLen)
        store.updateActive(body: newBody)
        rehighlight(force: true)
        refreshStatusBar()
    }

    // MARK: - Line tools

    private func sortLines() {
        let body = textView.text ?? ""
        let sorted = body.split(separator: "\n", omittingEmptySubsequences: false)
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
            .joined(separator: "\n")
        commitReplacement(sorted, selectionAfter: NSRange(location: 0, length: 0), actionName: "Sort Lines")
        Haptics.impact(.medium)
    }

    private func trimTrailingSpaces() {
        let body = textView.text ?? ""
        let trimmed = body.split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.replacingOccurrences(of: #"[ \t]+$"#, with: "", options: .regularExpression) }
            .joined(separator: "\n")
        commitReplacement(trimmed, selectionAfter: textView.selectedRange, actionName: "Trim Spaces")
        Haptics.impact(.light)
    }

    private func duplicateCurrentLine() {
        let ns = (textView.text ?? "") as NSString
        let caret = textView.selectedRange.location
        let (lineStart, lineEnd) = lineRange(in: ns, at: caret)
        let line = ns.substring(with: NSRange(location: lineStart, length: lineEnd - lineStart))
        let inserted = "\n" + line
        let newBody = ns.replacingCharacters(in: NSRange(location: lineEnd, length: 0), with: inserted)
        commitReplacement(newBody, selectionAfter: NSRange(location: caret + (inserted as NSString).length, length: 0), actionName: "Duplicate Line")
        Haptics.impact(.light)
    }

    private func deleteCurrentLine() {
        let ns = (textView.text ?? "") as NSString
        let caret = textView.selectedRange.location
        let (lineStart, lineEnd) = lineRange(in: ns, at: caret)
        let removeEnd = (lineEnd < ns.length && ns.character(at: lineEnd) == 0x0A) ? lineEnd + 1 : lineEnd
        let newBody = ns.replacingCharacters(in: NSRange(location: lineStart, length: removeEnd - lineStart), with: "")
        commitReplacement(newBody, selectionAfter: NSRange(location: lineStart, length: 0), actionName: "Delete Line")
        Haptics.warning()
    }

    private func insertText(_ value: String) {
        let sel = textView.selectedRange
        let ns = (textView.text ?? "") as NSString
        let newBody = ns.replacingCharacters(in: sel, with: value)
        let nextCaret = sel.location + (value as NSString).length
        commitReplacement(newBody, selectionAfter: NSRange(location: nextCaret, length: 0), actionName: "Insert")
    }

    private func lineRange(in ns: NSString, at location: Int) -> (Int, Int) {
        let clamped = max(0, min(location, ns.length))
        var start = clamped
        while start > 0, ns.character(at: start - 1) != 0x0A { start -= 1 }
        var end = clamped
        while end < ns.length, ns.character(at: end) != 0x0A { end += 1 }
        return (start, end)
    }

    // MARK: - Clipboard / selection helpers

    private func cutSelection() {
        let sel = textView.selectedRange
        guard sel.length > 0 else { return }
        let ns = (textView.text ?? "") as NSString
        UIPasteboard.general.string = ns.substring(with: sel)
        let newBody = ns.replacingCharacters(in: sel, with: "")
        commitReplacement(newBody, selectionAfter: NSRange(location: sel.location, length: 0), actionName: "Cut")
        Haptics.impact(.medium)
    }

    private func copySelection() {
        let sel = textView.selectedRange
        guard sel.length > 0 else { return }
        let ns = (textView.text ?? "") as NSString
        UIPasteboard.general.string = ns.substring(with: sel)
        Haptics.selectionChanged()
    }

    private func pasteFromClipboard() {
        guard let value = UIPasteboard.general.string, !value.isEmpty else { return }
        insertText(value)
        Haptics.impact(.light)
    }

    private func selectWord() {
        let ns = (textView.text ?? "") as NSString
        let at = min(textView.selectedRange.location, ns.length)
        var start = at
        var end = at
        let word = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_'-")
        while start > 0, let sc = UnicodeScalar(ns.character(at: start - 1)), word.contains(sc) { start -= 1 }
        while end < ns.length, let sc = UnicodeScalar(ns.character(at: end)), word.contains(sc) { end += 1 }
        guard start != end else { return }
        textView.selectedRange = NSRange(location: start, length: end - start)
    }

    private func selectLine() {
        let ns = (textView.text ?? "") as NSString
        let (s, e) = lineRange(in: ns, at: textView.selectedRange.location)
        textView.selectedRange = NSRange(location: s, length: e - s)
    }

    private func moveCursor(direction: KeyboardAccessoryView.Arrow) {
        let ns = (textView.text ?? "") as NSString
        let caret = textView.selectedRange.location
        switch direction {
        case .left:
            textView.selectedRange = NSRange(location: max(0, caret - 1), length: 0)
        case .right:
            textView.selectedRange = NSRange(location: min(ns.length, caret + 1), length: 0)
        case .up:
            textView.selectedRange = NSRange(location: caretVerticallyMoved(in: ns, from: caret, direction: -1), length: 0)
        case .down:
            textView.selectedRange = NSRange(location: caretVerticallyMoved(in: ns, from: caret, direction: 1), length: 0)
        }
    }

    private func caretVerticallyMoved(in ns: NSString, from caret: Int, direction: Int) -> Int {
        let (lineStart, lineEnd) = lineRange(in: ns, at: caret)
        let col = caret - lineStart
        if direction < 0 {
            if lineStart == 0 { return 0 }
            let (prevStart, prevEnd) = lineRange(in: ns, at: lineStart - 1)
            return min(prevStart + col, prevEnd)
        } else {
            if lineEnd >= ns.length { return ns.length }
            let (nextStart, nextEnd) = lineRange(in: ns, at: lineEnd + 1)
            return min(nextStart + col, nextEnd)
        }
    }

    // MARK: - Zen / trackpad / modals

    private func togglePreviewMode() {
        guard store.activeNote.language == .markdown else { return }
        previewMode.toggle()
        markdownPreview.isActive = previewMode
        markdownPreviewScroll.isHidden = !previewMode
        textView.isHidden = previewMode
        if previewMode {
            markdownPreview.setMarkdown(textView.text ?? "")
            textView.resignFirstResponder()
        }
        Haptics.selectionChanged()
    }

    private func setZenMode(_ on: Bool) {
        zenMode = on
        // Zen hides chrome; this is a quick approximation — hide tab strip, find bar, bottom bar, aero menu.
        tabStrip.isHidden = on
        findBar.isHidden = on
        mobileBottomBar.isHidden = on || prefs.layoutMode != .mobile
        aeroMenuBar.isHidden = on || prefs.layoutMode != .classic
        classicToolbar.isHidden = on || prefs.layoutMode != .classic || !toolbarOpen
        statusBar.isHidden = on || prefs.layoutMode != .classic
        lineGutter.isHidden = on || prefs.layoutMode != .classic
        UIView.animate(withDuration: 0.22) { self.view.layoutIfNeeded() }
    }

    private func toggleTrackpad() {
        if let existing = virtualTrackpad {
            existing.removeFromSuperview()
            virtualTrackpad = nil
            pointerOverlay.isVisible = false
            return
        }
        let pad = VirtualTrackpad()
        pad.translatesAutoresizingMaskIntoConstraints = false
        pad.rootHitTestView = view
        pad.onPointerMoved = { [weak self] point in self?.pointerOverlay.pointerPosition = point }
        pad.onClick = { [weak self] point in
            guard let self else { return }
            self.pointerOverlay.pointerPosition = point
            self.pointerOverlay.animateClickRipple(at: point)
            Haptics.selectionChanged()
            // Resolve the click to a UI element at that window point.
            if let target = self.view.hitTest(self.view.convert(point, from: self.view.window), with: nil) as? UIControl {
                target.sendActions(for: .touchUpInside)
            }
        }
        pad.applyPalette(themes.palette)
        view.addSubview(pad)
        let barHeight: CGFloat = prefs.layoutMode == .mobile ? 64 : 28
        NSLayoutConstraint.activate([
            pad.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -12),
            pad.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -(barHeight + 16)),
            pad.widthAnchor.constraint(equalToConstant: 200),
            pad.heightAnchor.constraint(equalToConstant: 150),
        ])
        virtualTrackpad = pad
        pointerOverlay.isVisible = true
        view.bringSubviewToFront(pointerOverlay)
    }

    // MARK: - Presentations

    private func presentSettings() {
        let vc = SettingsViewController()
        let nav = UINavigationController(rootViewController: vc)
        present(nav, animated: true)
    }

    private func presentCompare() {
        let compare = CompareViewController(store: store, palette: themes.palette)
        let nav = UINavigationController(rootViewController: compare)
        compare.onClose = { [weak nav] in nav?.dismiss(animated: true) }
        present(nav, animated: true)
    }

    private func presentLanguagePicker() {
        let picker = LanguagePickerViewController(current: store.activeNote.language, palette: themes.palette)
        let nav = UINavigationController(rootViewController: picker)
        picker.onCancel = { [weak nav] in nav?.dismiss(animated: true) }
        picker.onPick = { [weak self, weak nav] language in
            self?.store.updateActive(language: language)
            nav?.dismiss(animated: true)
        }
        present(nav, animated: true)
    }

    private func presentGotoLine() {
        let body = textView.text ?? ""
        let maxLine = body.split(separator: "\n", omittingEmptySubsequences: false).count
        GotoLine.prompt(from: self, maxLine: maxLine) { [weak self] line in
            self?.scrollToLine(line)
        }
    }

    private func scrollToLine(_ line: Int) {
        let ns = (textView.text ?? "") as NSString
        var idx = 0
        var remaining = max(1, line) - 1
        while remaining > 0 && idx < ns.length {
            if ns.character(at: idx) == 0x0A { remaining -= 1 }
            idx += 1
        }
        textView.selectedRange = NSRange(location: idx, length: 0)
        textView.scrollRangeToVisible(NSRange(location: idx, length: 0))
    }

    private func presentDocsList() {
        let docs = DocsListViewController(store: store, palette: themes.palette)
        docs.onSelect = { [weak self, weak docs] id in
            Haptics.selectionChanged()
            self?.store.setActive(id)
            docs?.dismiss(animated: true)
        }
        docs.onClose = { [weak self] id in self?.confirmClose(id) }
        docs.onRename = { [weak self] id in self?.promptRename(id) }
        docs.onDuplicate = { [weak self] id in self?.store.duplicate(id: id) }
        docs.onCloseOthers = { [weak self] id in self?.store.closeOthers(keep: id) }
        docs.onNewBlank = { [weak self, weak docs] in
            Haptics.impact(.light)
            self?.store.createBlank()
            docs?.dismiss(animated: true)
        }
        docs.onOpenFromFiles = { [weak self, weak docs] in
            docs?.dismiss(animated: true) { [weak self] in
                self?.presentFileOpen()
            }
        }
        docs.onDismiss = { [weak docs] in docs?.dismiss(animated: true) }
        present(docs, animated: true)
    }

    /// Small quick-file menu shown when the mobile bottom bar's "Open" is
    /// tapped. One tap away from New blank OR Open-from-Files, plus the
    /// list of already-open docs.
    private func presentOpenMenu() {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "New blank", style: .default) { [weak self] _ in self?.store.createBlank() })
        alert.addAction(UIAlertAction(title: "Open from Files…", style: .default) { [weak self] _ in self?.presentFileOpen() })
        if store.notes.count > 1 {
            for note in store.notes where note.id != store.activeId {
                alert.addAction(UIAlertAction(title: note.title, style: .default) { [weak self] _ in
                    self?.store.setActive(note.id)
                })
            }
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func presentMobileMore() {
        let sections: [SheetSection] = [
            SheetSection(title: "File", rows: [
                SheetRow(icon: "doc", title: "New blank") { [weak self] in self?.store.createBlank() },
                SheetRow(icon: "folder", title: "Open from Files…") { [weak self] in self?.presentFileOpen() },
                SheetRow(icon: "plus.square.on.square", title: "Duplicate current") { [weak self] in
                    guard let self else { return }; self.store.duplicate(id: self.store.activeId)
                },
                SheetRow(icon: "pencil", title: "Rename current") { [weak self] in
                    guard let self else { return }; self.promptRename(self.store.activeId)
                },
                SheetRow(icon: "xmark", title: "Close current", destructive: true) { [weak self] in
                    guard let self else { return }; self.confirmClose(self.store.activeId)
                },
            ]),
            SheetSection(title: "Edit", rows: [
                SheetRow(icon: "arrow.uturn.backward", title: "Undo") { [weak self] in self?.textView.undoManager?.undo() },
                SheetRow(icon: "arrow.uturn.forward", title: "Redo") { [weak self] in self?.textView.undoManager?.redo() },
                SheetRow(icon: "scissors", title: "Cut") { [weak self] in self?.cutSelection() },
                SheetRow(icon: "doc.on.doc", title: "Copy") { [weak self] in self?.copySelection() },
                SheetRow(icon: "doc.on.clipboard", title: "Paste") { [weak self] in self?.pasteFromClipboard() },
                SheetRow(icon: "character.textbox", title: "Select all") { [weak self] in self?.selectAll(nil) },
                SheetRow(icon: "magnifyingglass", title: "Find") { [weak self] in self?.toggleFind() },
                SheetRow(icon: "arrow.triangle.2.circlepath", title: "Find & replace") { [weak self] in self?.toggleFind(showReplace: true) },
                SheetRow(icon: "arrow.down.to.line", title: "Go to line…") { [weak self] in self?.presentGotoLine() },
                SheetRow(icon: "clock", title: "Insert date/time") { [weak self] in
                    self?.insertText(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short))
                },
                SheetRow(icon: "arrow.up.arrow.down", title: "Sort lines") { [weak self] in self?.sortLines() },
                SheetRow(icon: "scissors.circle", title: "Trim trailing spaces") { [weak self] in self?.trimTrailingSpaces() },
                SheetRow(icon: "plus.square.on.square", title: "Duplicate current line") { [weak self] in self?.duplicateCurrentLine() },
                SheetRow(icon: "minus.square", title: "Delete current line", destructive: true) { [weak self] in self?.deleteCurrentLine() },
            ]),
            SheetSection(title: "View", rows: [
                SheetRow(icon: readMode ? "eye.slash" : "eye", title: "Read mode", checked: readMode) { [weak self] in self?.readMode.toggle() },
                SheetRow(icon: "rectangle.compress.vertical", title: "Zen mode", checked: zenMode) { [weak self] in self?.setZenMode(!(self?.zenMode ?? false)) },
                SheetRow(icon: "rectangle.split.1x2", title: "Compare documents") { [weak self] in self?.presentCompare() },
                SheetRow(icon: "rectangle.and.hand.point.up.left", title: "Virtual trackpad", checked: virtualTrackpad != nil) { [weak self] in self?.toggleTrackpad() },
                SheetRow(icon: previewMode ? "pencil" : "eye.fill", title: previewMode ? "Edit markdown" : "Preview markdown", checked: previewMode) { [weak self] in self?.togglePreviewMode() },
                SheetRow(icon: "macwindow", title: "Switch to classic layout") { [weak self] in self?.prefs.layoutMode = .classic },
            ]),
            SheetSection(title: "Tools", rows: [
                SheetRow(icon: "gear", title: "Preferences…") { [weak self] in self?.presentSettings() },
                SheetRow(icon: "curlybraces", title: "Change language") { [weak self] in self?.presentLanguagePicker() },
                SheetRow(icon: "paintpalette", title: "Theme — quick toggle") { [weak self] in self?.themes.quickToggleDarkLight() },
            ]),
            SheetSection(title: "Help", rows: [
                SheetRow(icon: "info.circle", title: "About") { [weak self] in self?.presentAbout() },
            ]),
        ]
        let sheet = MobileActionSheet(sections: sections, palette: themes.palette)
        present(sheet, animated: true)
    }

    private func presentAbout() {
        let alert = UIAlertController(
            title: "Notepad 3++",
            message: """
            A pocket text editor that captures the feel of classic desktop notepad utilities.

            Multi-document tabs, find/replace, top/bottom diff, file import, line tools, syntax coloring, markdown preview, and a simulated trackpad for desktop nostalgia.

            Version 1.1.0
            """,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    // MARK: - Destructive confirmations

    private func confirmClose(_ id: String) {
        guard let note = store.notes.first(where: { $0.id == id }) else { return }
        if note.body.isEmpty { store.delete(id: id); return }
        let alert = UIAlertController(
            title: "Close \(note.title)?",
            message: "This document will be removed. You can't undo this.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Close", style: .destructive) { [weak self] _ in self?.store.delete(id: id) })
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
            Haptics.success()
        } catch {
            Haptics.error()
            let alert = UIAlertController(title: "Couldn't open file", message: error.localizedDescription, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
    }
}
