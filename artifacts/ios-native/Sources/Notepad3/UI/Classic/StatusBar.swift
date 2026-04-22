import UIKit

/// Thin status bar pinned to the bottom of the editor in classic layout.
/// Mirrors the RN `styles.statusBar`: a narrow strip (~22pt tall) with
/// a small monospaced font, fields separated by vertical rules.
///
/// Fields, left to right: cursor location, line+character counts, language,
/// theme. Language and theme are tappable; caller handles picker UI.
final class StatusBar: UIView {
    var onLanguageTap: (() -> Void)?
    var onThemeTap: (() -> Void)?

    private let stack = UIStackView()
    private let separatorTop = UIView()
    private let cursorLabel = UILabel()
    private let countsLabel = UILabel()
    private let languageButton = UIButton(type: .system)
    private let themeButton = UIButton(type: .system)
    private var separators: [UIView] = []
    private var palette: Palette = .classic

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false

        separatorTop.translatesAutoresizingMaskIntoConstraints = false
        addSubview(separatorTop)

        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 6
        addSubview(stack)

        for label in [cursorLabel, countsLabel] {
            label.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
            label.setContentHuggingPriority(.required, for: .horizontal)
            label.setContentCompressionResistancePriority(.required, for: .horizontal)
        }

        configureTextButton(languageButton, accessibility: "Change language")
        configureTextButton(themeButton, accessibility: "Change theme")
        languageButton.addTarget(self, action: #selector(languageTapped), for: .touchUpInside)
        themeButton.addTarget(self, action: #selector(themeTapped), for: .touchUpInside)

        // Cursor is also tappable in the RN source (goto line); we treat the
        // caller as owning goto via the menu bar callback, so keep cursor as a
        // plain label — if needed later, swap for a UIButton without breaking API.
        cursorLabel.isUserInteractionEnabled = false

        stack.addArrangedSubview(cursorLabel)
        stack.addArrangedSubview(makeVerticalRule())
        stack.addArrangedSubview(countsLabel)
        stack.addArrangedSubview(makeVerticalRule())
        stack.addArrangedSubview(languageButton)
        stack.addArrangedSubview(makeVerticalRule())
        stack.addArrangedSubview(themeButton)

        let spacer = UIView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        stack.addArrangedSubview(spacer)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: 22),

            separatorTop.leadingAnchor.constraint(equalTo: leadingAnchor),
            separatorTop.trailingAnchor.constraint(equalTo: trailingAnchor),
            separatorTop.topAnchor.constraint(equalTo: topAnchor),
            separatorTop.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale),

            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            stack.topAnchor.constraint(equalTo: separatorTop.bottomAnchor, constant: 3),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -3),
        ])

        // Reasonable defaults before the first update()
        cursorLabel.text = "Ln 1, Col 1"
        countsLabel.text = "1 lines, 0 characters"
        languageButton.setTitle("Plain", for: .normal)
        themeButton.setTitle("Classic", for: .normal)
    }

    private func configureTextButton(_ button: UIButton, accessibility: String) {
        var cfg = UIButton.Configuration.plain()
        cfg.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4)
        cfg.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var out = incoming
            out.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
            return out
        }
        button.configuration = cfg
        button.accessibilityLabel = accessibility
    }

    private func makeVerticalRule() -> UIView {
        let wrapper = UIView()
        wrapper.translatesAutoresizingMaskIntoConstraints = false
        let line = UIView()
        line.translatesAutoresizingMaskIntoConstraints = false
        line.backgroundColor = palette.border
        wrapper.addSubview(line)
        NSLayoutConstraint.activate([
            wrapper.widthAnchor.constraint(equalToConstant: 1),
            wrapper.heightAnchor.constraint(equalToConstant: 12),
            line.widthAnchor.constraint(equalTo: wrapper.widthAnchor),
            line.heightAnchor.constraint(equalTo: wrapper.heightAnchor),
            line.centerXAnchor.constraint(equalTo: wrapper.centerXAnchor),
            line.centerYAnchor.constraint(equalTo: wrapper.centerYAnchor),
        ])
        separators.append(line)
        return wrapper
    }

    // MARK: - Public API

    func update(cursorLine: Int,
                cursorColumn: Int,
                lineCount: Int,
                charCount: Int,
                language: NoteLanguage,
                theme: ThemeName) {
        cursorLabel.text = "Ln \(cursorLine), Col \(cursorColumn)"
        countsLabel.text = "\(lineCount) lines, \(charCount) characters"
        languageButton.setTitle(language.rawValue, for: .normal)
        themeButton.setTitle(themeLabel(for: theme), for: .normal)
    }

    func applyPalette(_ p: Palette) {
        palette = p
        backgroundColor = p.card
        separatorTop.backgroundColor = p.border
        separators.forEach { $0.backgroundColor = p.border }
        cursorLabel.textColor = p.foreground
        countsLabel.textColor = p.foreground
        languageButton.tintColor = p.primary
        themeButton.tintColor = p.primary
        var langCfg = languageButton.configuration
        langCfg?.baseForegroundColor = p.primary
        languageButton.configuration = langCfg
        var themeCfg = themeButton.configuration
        themeCfg?.baseForegroundColor = p.primary
        themeButton.configuration = themeCfg
    }

    @objc private func languageTapped() { onLanguageTap?() }
    @objc private func themeTapped() { onThemeTap?() }

    private func themeLabel(for name: ThemeName) -> String {
        switch name {
        case .classic:   return "Classic"
        case .light:     return "Light"
        case .dark:      return "Dark"
        case .retro:     return "Retro"
        case .modern:    return "Modern"
        case .cyberpunk: return "Cyberpunk"
        case .sunset:    return "Sunset"
        case .custom:    return "Custom"
        }
    }
}
