import UIKit

/// First pass: a single full-screen UITextView bound to the active note.
/// Successive commits will add tabs, action sheet, find/replace, syntax
/// coloring, etc. The point of this stub is that the project compiles and
/// runs end-to-end so we can iterate visually.
final class EditorViewController: UIViewController, UITextViewDelegate {
    private let store: NotesStore
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
        applyPalette()

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
        textView.text = store.activeNote.body

        view.addSubview(textView)
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        observerToken = store.observe { [weak self] in
            self?.syncFromStoreIfNeeded()
        }
    }

    deinit {
        if let token = observerToken { store.unobserve(token) }
    }

    // MARK: - Theme

    private func applyPalette() {
        view.backgroundColor = palette.background
        textView.backgroundColor = palette.editorBackground
        textView.textColor = palette.foreground
        textView.tintColor = palette.primary
    }

    // MARK: - Store sync

    /// Pull text into the view if the active note changed externally
    /// (e.g., the user switched notes via a tab tap or imported a file).
    /// Don't touch text if the body matches what's already on screen —
    /// avoids interrupting the user mid-typing.
    private func syncFromStoreIfNeeded() {
        let note = store.activeNote
        if textView.text != note.body {
            // Preserve selection if we can map it.
            let oldSelection = textView.selectedRange
            textView.text = note.body
            let len = (note.body as NSString).length
            textView.selectedRange = NSRange(location: min(oldSelection.location, len), length: 0)
        }
        title = note.title
    }

    // MARK: - UITextViewDelegate

    func textViewDidChange(_ textView: UITextView) {
        store.updateActive(body: textView.text)
    }
}
