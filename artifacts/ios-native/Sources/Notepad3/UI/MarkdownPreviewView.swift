import UIKit

/// Live Markdown preview rendered with Apple's built-in `NSAttributedString(markdown:)`
/// parser (iOS 15+). Intended to be placed below the editor for notes whose
/// language is `.markdown`, and mirrors the parity list the RN reference supports:
/// headings (#, ##, ###), **bold**, *italic*, `inline code`, fenced code blocks
/// (```…```), unordered lists, ordered lists, hyperlinks, and blockquotes.
///
/// The view is a non-scrolling `UITextView` that should be embedded in a parent
/// scroll view when long. Fenced code blocks — which Apple's parser does not
/// recognise as a block construct — are handled by pre-extracting them from the
/// source, rendering the remainder with the system parser, then re-inserting the
/// original code with a monospaced, tinted treatment. Headings are post-processed
/// by walking the `.presentationIntent` attribute and bumping font size/weight.
final class MarkdownPreviewView: UIView {
    // MARK: - Public API

    /// When `false` the view hides itself so the host can keep layout simple
    /// (e.g. during Zen mode or when the active note is not Markdown).
    var isActive: Bool = true {
        didSet { isHidden = !isActive }
    }

    /// Replace the rendered content. Typically called on every `textViewDidChange`.
    func setMarkdown(_ markdown: String) {
        currentMarkdown = markdown
        rebuild()
    }

    /// Update chrome colors. Re-renders with the cached markdown source.
    func applyPalette(_ p: Palette) {
        palette = p
        backgroundColor = p.background
        textView.backgroundColor = p.background
        textView.textColor = p.foreground
        rebuild()
    }

    // MARK: - Private state

    private let textView = UITextView()
    private var palette: Palette = .light
    private var currentMarkdown: String = ""

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false

        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.isEditable = false
        textView.isSelectable = true
        textView.isScrollEnabled = false
        textView.dataDetectorTypes = []
        textView.adjustsFontForContentSizeCategory = true
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        textView.textContainer.lineFragmentPadding = 0
        textView.backgroundColor = .clear

        addSubview(textView)
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: topAnchor),
            textView.leadingAnchor.constraint(equalTo: leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    // MARK: - Rendering pipeline

    private func rebuild() {
        let attributed = render(currentMarkdown)
        textView.attributedText = attributed
    }

    /// Produce the styled attributed string by:
    ///   1. Extracting fenced code blocks and substituting opaque placeholders.
    ///   2. Running the rest through `NSAttributedString(markdown:)`.
    ///   3. Post-processing heading presentation intents to bump font weight/size.
    ///   4. Styling inline code, block quotes, and links with the palette.
    ///   5. Re-inserting each fenced code block as a monospaced, tinted span.
    private func render(_ markdown: String) -> NSAttributedString {
        let bodyFont = UIFont.preferredFont(forTextStyle: .body)
        let baseAttributes: [NSAttributedString.Key: Any] = [
            .font: bodyFont,
            .foregroundColor: palette.foreground,
        ]
        guard !markdown.isEmpty else {
            return NSAttributedString(string: "", attributes: baseAttributes)
        }

        let (stripped, fences) = extractFencedCodeBlocks(from: markdown)

        // Apple's parser: full markdown with soft-break → newline to preserve layout.
        let parsed: NSAttributedString
        do {
            var options = AttributedString.MarkdownParsingOptions()
            options.interpretedSyntax = .inlineOnlyPreservingWhitespace
            options.allowsExtendedAttributes = true
            // `inlineOnlyPreservingWhitespace` keeps newlines, which we need so
            // our placeholder tokens land on their own lines. We then rebuild
            // block styling (headings/lists/blockquotes) manually below.
            let attr = try AttributedString(markdown: stripped, options: options)
            parsed = NSAttributedString(attr)
        } catch {
            // Graceful fallback: show the raw text.
            return NSAttributedString(string: markdown, attributes: baseAttributes)
        }

        let mutable = NSMutableAttributedString(attributedString: parsed)
        let full = NSRange(location: 0, length: mutable.length)

        // Ensure a base font + foreground colour everywhere so subsequent passes
        // can layer on top. Apple's parser leaves unset foreground colours in
        // some builds, producing invisible text on dark palettes.
        mutable.addAttributes(baseAttributes, range: full)

        // Apply block-level styling line by line. Inline markdown (bold/italic/
        // links/inline-code) has already been resolved by Apple's parser.
        applyBlockStyling(to: mutable)
        applyInlineCodeStyling(to: mutable)
        applyLinkStyling(to: mutable)

        // Re-insert fenced code blocks at their placeholder positions.
        insertFencedCodeBlocks(into: mutable, fences: fences)

        return mutable
    }

    // MARK: - Fenced code extraction

    private struct FenceInfo {
        let token: String
        let code: String
    }

    /// Replace ```…``` blocks with unique single-line placeholders. Returns the
    /// transformed text plus an ordered list of extracted blocks.
    private func extractFencedCodeBlocks(from source: String) -> (String, [FenceInfo]) {
        var fences: [FenceInfo] = []
        var out = ""
        out.reserveCapacity(source.count)

        let lines = source.components(separatedBy: "\n")
        var i = 0
        var index = 0
        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") {
                // Consume until the closing fence or EOF.
                var body: [String] = []
                i += 1
                while i < lines.count {
                    let inner = lines[i]
                    if inner.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                        i += 1
                        break
                    }
                    body.append(inner)
                    i += 1
                }
                let token = "\u{FFFC}NP3_FENCE_\(index)\u{FFFC}"
                fences.append(FenceInfo(token: token, code: body.joined(separator: "\n")))
                out.append(token)
                if i < lines.count { out.append("\n") }
                index += 1
            } else {
                out.append(line)
                if i < lines.count - 1 { out.append("\n") }
                i += 1
            }
        }
        return (out, fences)
    }

    private func insertFencedCodeBlocks(into mutable: NSMutableAttributedString, fences: [FenceInfo]) {
        for fence in fences {
            let ns = mutable.string as NSString
            let range = ns.range(of: fence.token)
            guard range.location != NSNotFound else { continue }

            let block = makeCodeBlock(fence.code)
            mutable.replaceCharacters(in: range, with: block)
        }
    }

    private func makeCodeBlock(_ code: String) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.paragraphSpacingBefore = 6
        paragraph.paragraphSpacing = 6
        paragraph.firstLineHeadIndent = 8
        paragraph.headIndent = 8
        paragraph.tailIndent = -8

        let mono = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: mono,
            .foregroundColor: palette.foreground,
            .backgroundColor: palette.editorGutter,
            .paragraphStyle: paragraph,
        ]
        // Pad with a blank line top & bottom to visually separate the block.
        let text = "\n\(code)\n"
        return NSAttributedString(string: text, attributes: attrs)
    }

    // MARK: - Block styling (headings, lists, blockquotes)

    /// Walk the source line-by-line to recover block structure that Apple's
    /// `inlineOnlyPreservingWhitespace` parser doesn't express structurally.
    /// We look at the raw characters at the start of each paragraph to decide
    /// how to format that paragraph.
    private func applyBlockStyling(to mutable: NSMutableAttributedString) {
        let text = mutable.string as NSString
        var lineStart = 0
        while lineStart < text.length {
            var lineEnd = 0
            var contentsEnd = 0
            text.getLineStart(nil, end: &lineEnd, contentsEnd: &contentsEnd,
                              for: NSRange(location: lineStart, length: 0))
            let range = NSRange(location: lineStart, length: contentsEnd - lineStart)
            if range.length > 0 {
                let line = text.substring(with: range)
                styleLine(line, at: range, in: mutable)
            }
            lineStart = lineEnd
            if lineEnd == 0 { break }
        }
    }

    private func styleLine(_ line: String, at range: NSRange, in mutable: NSMutableAttributedString) {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        // Heading: up to three leading '#' characters followed by a space.
        if let heading = headingLevel(for: trimmed) {
            let (size, weight): (CGFloat, UIFont.Weight) = {
                switch heading {
                case 1: return (22, .semibold)
                case 2: return (18, .semibold)
                default: return (15, .semibold)
                }
            }()
            mutable.addAttribute(.font, value: UIFont.systemFont(ofSize: size, weight: weight), range: range)
            mutable.addAttribute(.foregroundColor, value: palette.foreground, range: range)
            let paragraph = NSMutableParagraphStyle()
            paragraph.paragraphSpacingBefore = 8
            paragraph.paragraphSpacing = 4
            mutable.addAttribute(.paragraphStyle, value: paragraph, range: range)
            return
        }

        // Blockquote.
        if trimmed.hasPrefix(">") {
            let paragraph = NSMutableParagraphStyle()
            paragraph.firstLineHeadIndent = 14
            paragraph.headIndent = 14
            paragraph.paragraphSpacingBefore = 2
            paragraph.paragraphSpacing = 2
            mutable.addAttribute(.paragraphStyle, value: paragraph, range: range)
            mutable.addAttribute(.foregroundColor, value: palette.mutedForeground, range: range)
            let italic = UIFont.italicSystemFont(ofSize: UIFont.preferredFont(forTextStyle: .body).pointSize)
            mutable.addAttribute(.font, value: italic, range: range)
            return
        }

        // Unordered list.
        if isUnorderedListMarker(trimmed) {
            let paragraph = NSMutableParagraphStyle()
            paragraph.firstLineHeadIndent = 4
            paragraph.headIndent = 20
            paragraph.paragraphSpacingBefore = 1
            paragraph.paragraphSpacing = 1
            mutable.addAttribute(.paragraphStyle, value: paragraph, range: range)
            return
        }

        // Ordered list.
        if isOrderedListMarker(trimmed) {
            let paragraph = NSMutableParagraphStyle()
            paragraph.firstLineHeadIndent = 4
            paragraph.headIndent = 24
            paragraph.paragraphSpacingBefore = 1
            paragraph.paragraphSpacing = 1
            mutable.addAttribute(.paragraphStyle, value: paragraph, range: range)
            return
        }
    }

    private func headingLevel(for trimmed: String) -> Int? {
        var count = 0
        for ch in trimmed {
            if ch == "#" { count += 1 } else { break }
            if count > 3 { break }
        }
        guard count >= 1, count <= 3 else { return nil }
        let afterHashIndex = trimmed.index(trimmed.startIndex, offsetBy: count)
        guard afterHashIndex < trimmed.endIndex else { return nil }
        return trimmed[afterHashIndex] == " " ? count : nil
    }

    private func isUnorderedListMarker(_ trimmed: String) -> Bool {
        guard let first = trimmed.first else { return false }
        if first == "-" || first == "*" || first == "+" {
            let after = trimmed.index(after: trimmed.startIndex)
            if after < trimmed.endIndex, trimmed[after] == " " { return true }
        }
        return false
    }

    private func isOrderedListMarker(_ trimmed: String) -> Bool {
        // digits, then '.' or ')', then space.
        var index = trimmed.startIndex
        var digits = 0
        while index < trimmed.endIndex, trimmed[index].isNumber {
            digits += 1
            index = trimmed.index(after: index)
        }
        guard digits > 0, index < trimmed.endIndex else { return false }
        let sep = trimmed[index]
        guard sep == "." || sep == ")" else { return false }
        let afterSep = trimmed.index(after: index)
        guard afterSep < trimmed.endIndex else { return false }
        return trimmed[afterSep] == " "
    }

    // MARK: - Inline code & link styling

    /// Apple's parser preserves `.inlinePresentationIntent = .code` on inline
    /// code spans — recolour and remonospace them with the palette.
    private func applyInlineCodeStyling(to mutable: NSMutableAttributedString) {
        let full = NSRange(location: 0, length: mutable.length)
        mutable.enumerateAttribute(.init("NSInlinePresentationIntent"), in: full) { value, range, _ in
            let raw: UInt
            if let u = value as? UInt { raw = u }
            else if let i = value as? Int { raw = UInt(truncatingIfNeeded: i) }
            else { return }
            let intent = InlinePresentationIntent(rawValue: raw)
            if intent.contains(.code) {
                let size = UIFont.preferredFont(forTextStyle: .body).pointSize
                mutable.addAttribute(.font, value: UIFont.monospacedSystemFont(ofSize: size, weight: .regular), range: range)
                mutable.addAttribute(.foregroundColor, value: palette.accent, range: range)
            }
            if intent.contains(.emphasized) {
                let size = UIFont.preferredFont(forTextStyle: .body).pointSize
                mutable.addAttribute(.font, value: UIFont.italicSystemFont(ofSize: size), range: range)
            }
            if intent.contains(.stronglyEmphasized) {
                let size = UIFont.preferredFont(forTextStyle: .body).pointSize
                mutable.addAttribute(.font, value: UIFont.systemFont(ofSize: size, weight: .bold), range: range)
            }
        }
    }

    private func applyLinkStyling(to mutable: NSMutableAttributedString) {
        let full = NSRange(location: 0, length: mutable.length)
        mutable.enumerateAttribute(.link, in: full) { value, range, _ in
            guard value != nil else { return }
            mutable.addAttribute(.foregroundColor, value: palette.primary, range: range)
            mutable.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
        }
    }
}
