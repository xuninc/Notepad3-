import UIKit

/// Slide-in find/replace bar. Two compact rows — find (with prev/next/close),
/// and replace (with replace/replace-all). Replace row hides when the user
/// is only searching. All mutations go through the editor's callbacks; the
/// bar owns no text state beyond the field contents.
final class FindReplaceBar: UIView {
    var onFindChanged: ((String) -> Void)?
    var onNext: (() -> Void)?
    var onPrevious: (() -> Void)?
    var onClose: (() -> Void)?
    var onReplaceOne: ((String) -> Void)?
    var onReplaceAll: ((String) -> Void)?
    var onOptionsChanged: (() -> Void)?

    /// Search options, toggled via the trailing buttons on the find row.
    struct Options {
        var caseSensitive: Bool = false
        var wholeWord: Bool = false
        var regex: Bool = false
    }
    private(set) var options = Options()

    let findField = UITextField()
    let replaceField = UITextField()
    private let findRow = UIView()
    private let replaceRow = UIView()
    private let separator = UIView()

    private let prevBtn = UIButton(type: .system)
    private let nextBtn = UIButton(type: .system)
    private let closeBtn = UIButton(type: .system)
    private let toggleReplaceBtn = UIButton(type: .system)
    private let caseBtn = UIButton(type: .system)
    private let wordBtn = UIButton(type: .system)
    private let regexBtn = UIButton(type: .system)
    private let replaceBtn = UIButton(type: .system)
    private let replaceAllBtn = UIButton(type: .system)

    private var palette: Palette = .light
    private(set) var showsReplace: Bool = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false

        findField.translatesAutoresizingMaskIntoConstraints = false
        findField.placeholder = "Find"
        findField.borderStyle = .roundedRect
        findField.returnKeyType = .search
        findField.autocapitalizationType = .none
        findField.autocorrectionType = .no
        findField.clearButtonMode = .whileEditing
        findField.addTarget(self, action: #selector(findChanged), for: .editingChanged)
        findField.addTarget(self, action: #selector(findSubmitted), for: .editingDidEndOnExit)

        replaceField.translatesAutoresizingMaskIntoConstraints = false
        replaceField.placeholder = "Replace"
        replaceField.borderStyle = .roundedRect
        replaceField.returnKeyType = .default
        replaceField.autocapitalizationType = .none
        replaceField.autocorrectionType = .no
        replaceField.clearButtonMode = .whileEditing

        configureIcon(prevBtn, systemName: "chevron.up", accessibility: "Previous match")
        configureIcon(nextBtn, systemName: "chevron.down", accessibility: "Next match")
        configureIcon(closeBtn, systemName: "xmark", accessibility: "Close find bar")
        configureIcon(toggleReplaceBtn, systemName: "pencil.tip.crop.circle", accessibility: "Toggle replace")
        configureIcon(caseBtn, systemName: "textformat", accessibility: "Match case")
        configureIcon(wordBtn, systemName: "textformat.abc.dottedunderline", accessibility: "Whole word")
        configureIcon(regexBtn, systemName: "curlybraces", accessibility: "Regex")
        caseBtn.addTarget(self, action: #selector(caseTapped), for: .touchUpInside)
        wordBtn.addTarget(self, action: #selector(wordTapped), for: .touchUpInside)
        regexBtn.addTarget(self, action: #selector(regexTapped), for: .touchUpInside)

        replaceBtn.setTitle("Replace", for: .normal)
        replaceBtn.accessibilityLabel = "Replace next"
        replaceAllBtn.setTitle("All", for: .normal)
        replaceAllBtn.accessibilityLabel = "Replace all"

        prevBtn.addTarget(self, action: #selector(prevTapped), for: .touchUpInside)
        nextBtn.addTarget(self, action: #selector(nextTapped), for: .touchUpInside)
        closeBtn.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        toggleReplaceBtn.addTarget(self, action: #selector(toggleReplaceTapped), for: .touchUpInside)
        replaceBtn.addTarget(self, action: #selector(replaceTapped), for: .touchUpInside)
        replaceAllBtn.addTarget(self, action: #selector(replaceAllTapped), for: .touchUpInside)

        findRow.translatesAutoresizingMaskIntoConstraints = false
        replaceRow.translatesAutoresizingMaskIntoConstraints = false
        separator.translatesAutoresizingMaskIntoConstraints = false

        addSubview(findRow)
        addSubview(replaceRow)
        addSubview(separator)

        // Find row layout: [toggleReplace] [findField] [Aa] [ab] [.*] [prev] [next] [close]
        let findStack = UIStackView(arrangedSubviews: [toggleReplaceBtn, findField, caseBtn, wordBtn, regexBtn, prevBtn, nextBtn, closeBtn])
        findStack.translatesAutoresizingMaskIntoConstraints = false
        findStack.axis = .horizontal
        findStack.spacing = 8
        findStack.alignment = .center
        findStack.distribution = .fill
        findField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        findField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        findRow.addSubview(findStack)

        // Replace row layout: [replaceField] [replace] [replaceAll]
        let replaceStack = UIStackView(arrangedSubviews: [replaceField, replaceBtn, replaceAllBtn])
        replaceStack.translatesAutoresizingMaskIntoConstraints = false
        replaceStack.axis = .horizontal
        replaceStack.spacing = 8
        replaceStack.alignment = .center
        replaceStack.distribution = .fill
        replaceField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        replaceField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        replaceRow.addSubview(replaceStack)

        NSLayoutConstraint.activate([
            findRow.topAnchor.constraint(equalTo: topAnchor),
            findRow.leadingAnchor.constraint(equalTo: leadingAnchor),
            findRow.trailingAnchor.constraint(equalTo: trailingAnchor),
            findRow.heightAnchor.constraint(equalToConstant: 44),

            findStack.topAnchor.constraint(equalTo: findRow.topAnchor, constant: 4),
            findStack.leadingAnchor.constraint(equalTo: findRow.leadingAnchor, constant: 8),
            findStack.trailingAnchor.constraint(equalTo: findRow.trailingAnchor, constant: -8),
            findStack.bottomAnchor.constraint(equalTo: findRow.bottomAnchor, constant: -4),

            replaceRow.topAnchor.constraint(equalTo: findRow.bottomAnchor),
            replaceRow.leadingAnchor.constraint(equalTo: leadingAnchor),
            replaceRow.trailingAnchor.constraint(equalTo: trailingAnchor),

            replaceStack.topAnchor.constraint(equalTo: replaceRow.topAnchor, constant: 4),
            replaceStack.leadingAnchor.constraint(equalTo: replaceRow.leadingAnchor, constant: 8),
            replaceStack.trailingAnchor.constraint(equalTo: replaceRow.trailingAnchor, constant: -8),
            replaceStack.bottomAnchor.constraint(equalTo: replaceRow.bottomAnchor, constant: -4),

            separator.topAnchor.constraint(equalTo: replaceRow.bottomAnchor),
            separator.leadingAnchor.constraint(equalTo: leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: trailingAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale),
            separator.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        setShowsReplace(false)
    }

    private func configureIcon(_ button: UIButton, systemName: String, accessibility: String) {
        var cfg = UIButton.Configuration.plain()
        cfg.image = UIImage(systemName: systemName, withConfiguration: UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold))
        cfg.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 6, bottom: 4, trailing: 6)
        button.configuration = cfg
        button.accessibilityLabel = accessibility
    }

    func setShowsReplace(_ shows: Bool) {
        showsReplace = shows
        replaceRow.isHidden = !shows
        replaceRow.alpha = shows ? 1 : 0
    }

    func applyPalette(_ p: Palette) {
        palette = p
        backgroundColor = p.card
        separator.backgroundColor = p.border
        [prevBtn, nextBtn, closeBtn, toggleReplaceBtn].forEach { $0.tintColor = p.primary }
        [replaceBtn, replaceAllBtn].forEach { $0.tintColor = p.primary }
        [findField, replaceField].forEach { $0.textColor = p.foreground }
        refreshOptionTints()
    }

    private func refreshOptionTints() {
        caseBtn.tintColor = options.caseSensitive ? palette.primary : palette.mutedForeground
        wordBtn.tintColor = options.wholeWord ? palette.primary : palette.mutedForeground
        regexBtn.tintColor = options.regex ? palette.primary : palette.mutedForeground
    }

    func focusFind() {
        findField.becomeFirstResponder()
    }

    @objc private func findChanged() {
        onFindChanged?(findField.text ?? "")
    }
    @objc private func findSubmitted() { onNext?() }
    @objc private func prevTapped() { onPrevious?() }
    @objc private func nextTapped() { onNext?() }
    @objc private func closeTapped() { onClose?() }
    @objc private func toggleReplaceTapped() { setShowsReplace(!showsReplace) }
    @objc private func replaceTapped() { onReplaceOne?(replaceField.text ?? "") }
    @objc private func replaceAllTapped() { onReplaceAll?(replaceField.text ?? "") }

    @objc private func caseTapped() {
        options.caseSensitive.toggle()
        refreshOptionTints()
        onOptionsChanged?()
    }
    @objc private func wordTapped() {
        options.wholeWord.toggle()
        refreshOptionTints()
        onOptionsChanged?()
    }
    @objc private func regexTapped() {
        options.regex.toggle()
        refreshOptionTints()
        onOptionsChanged?()
    }
}
