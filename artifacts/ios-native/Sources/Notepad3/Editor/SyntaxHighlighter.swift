import UIKit

/// Applies syntax coloring to a `UITextView`'s underlying text storage by
/// mutating only foreground color attributes — the text content and user
/// cursor stay untouched. Re-run on every store-driven body change.
///
/// Tokenizer is deliberately simple: line-based regex passes for comments,
/// strings, numbers, and identifiers (classified as keyword/register via
/// `NoteLanguage`'s sets). Claimed ranges prevent later passes from
/// recoloring comment/string interiors.
enum SyntaxHighlighter {
    static func apply(to textView: UITextView, language: NoteLanguage, palette: Palette) {
        let storage = textView.textStorage
        let nsText = storage.string as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)

        storage.beginEditing()
        storage.removeAttribute(.foregroundColor, range: fullRange)
        storage.addAttribute(.foregroundColor, value: palette.foreground, range: fullRange)

        for token in tokens(in: nsText, language: language) {
            storage.addAttribute(.foregroundColor, value: color(token.kind, in: palette), range: token.range)
        }
        storage.endEditing()
    }

    // MARK: - Tokenization

    private struct Token {
        enum Kind { case keyword, register, string, comment, number }
        let range: NSRange
        let kind: Kind
    }

    private static func tokens(in text: NSString, language: NoteLanguage) -> [Token] {
        let full = NSRange(location: 0, length: text.length)
        var out: [Token] = []
        var claimed: [NSRange] = []

        // 1. Comments — claim from prefix to end of line
        for prefix in language.commentPrefixes {
            let pattern = "\(NSRegularExpression.escapedPattern(for: prefix))[^\\n]*"
            guard let re = try? NSRegularExpression(pattern: pattern) else { continue }
            re.enumerateMatches(in: text as String, range: full) { match, _, _ in
                guard let r = match?.range else { return }
                out.append(Token(range: r, kind: .comment))
                claimed.append(r)
            }
        }

        // 2. Strings — double- and single-quoted, not spanning newlines
        let stringPattern = #""(?:[^"\\\n]|\\.)*"|'(?:[^'\\\n]|\\.)*'"#
        if let re = try? NSRegularExpression(pattern: stringPattern) {
            re.enumerateMatches(in: text as String, range: full) { match, _, _ in
                guard let r = match?.range, !isClaimed(r, in: claimed) else { return }
                out.append(Token(range: r, kind: .string))
                claimed.append(r)
            }
        }

        // 3. Numbers
        if let re = try? NSRegularExpression(pattern: "\\b\\d+(\\.\\d+)?\\b") {
            re.enumerateMatches(in: text as String, range: full) { match, _, _ in
                guard let r = match?.range, !isClaimed(r, in: claimed) else { return }
                out.append(Token(range: r, kind: .number))
            }
        }

        // 4. Identifiers → classify against language sets
        let kw = language.keywords
        let reg = language.registers
        if !kw.isEmpty || !reg.isEmpty, let re = try? NSRegularExpression(pattern: "\\b[a-zA-Z_][a-zA-Z0-9_]*\\b") {
            re.enumerateMatches(in: text as String, range: full) { match, _, _ in
                guard let r = match?.range, !isClaimed(r, in: claimed) else { return }
                let word = text.substring(with: r)
                if kw.contains(word) {
                    out.append(Token(range: r, kind: .keyword))
                } else if reg.contains(word) {
                    out.append(Token(range: r, kind: .register))
                }
            }
        }

        return out
    }

    private static func isClaimed(_ r: NSRange, in claimed: [NSRange]) -> Bool {
        for c in claimed where NSIntersectionRange(r, c).length > 0 { return true }
        return false
    }

    // MARK: - Colors

    /// Derive token colors from the palette so highlighting works in any theme.
    /// Light palettes get darker/saturated accents; dark palettes get brighter.
    private static func color(_ kind: Token.Kind, in palette: Palette) -> UIColor {
        switch kind {
        case .keyword:  return palette.primary
        case .register: return palette.accent
        case .string:   return palette.success
        case .comment:  return palette.mutedForeground
        case .number:   return palette.accent
        }
    }
}
