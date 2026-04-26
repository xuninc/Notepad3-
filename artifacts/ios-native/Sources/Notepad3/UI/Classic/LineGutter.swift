import UIKit

/// Line-number gutter that sits to the left of an external `UITextView`.
/// Redraws its line numbers whenever the text view's text changes or its
/// content scroll offset changes. Uses the same monospaced font as the
/// editor so numbers line up visually with their corresponding lines.
///
/// Mirrors the RN `EditorGutter`: a narrow column with right-aligned
/// line numbers over the `editorGutter` background.
final class LineGutter: UIView {
    private weak var textView: UITextView?
    private var textObservation: NSObjectProtocol?
    private var contentOffsetObservation: NSKeyValueObservation?
    private var textContainerObservation: NSObjectProtocol?
    private var palette: Palette = .classic
    private var font: UIFont = .monospacedSystemFont(ofSize: 16, weight: .regular)

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    deinit {
        if let token = textObservation { NotificationCenter.default.removeObserver(token) }
        contentOffsetObservation = nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        setNeedsDisplay()
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: 40, height: UIView.noIntrinsicMetric)
    }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        contentMode = .redraw
        isUserInteractionEnabled = false
        backgroundColor = palette.editorGutter
    }

    // MARK: - Public API

    /// Bind this gutter to a text view. The gutter watches its text and
    /// scroll offset; the caller is responsible for positioning the gutter
    /// itself (typically leading-edge of the editor container).
    func attach(to textView: UITextView) {
        // Clean up any prior attachment.
        if let token = textObservation { NotificationCenter.default.removeObserver(token) }
        contentOffsetObservation = nil

        self.textView = textView
        // Match the gutter font to the editor so line heights align.
        if let f = textView.font { self.font = f }

        textObservation = NotificationCenter.default.addObserver(
            forName: UITextView.textDidChangeNotification,
            object: textView,
            queue: .main
        ) { [weak self] _ in self?.setNeedsDisplay() }

        contentOffsetObservation = textView.observe(\.contentOffset, options: [.new]) { [weak self] _, _ in
            // Coalesce to the main queue so we don't stall scroll.
            DispatchQueue.main.async { self?.setNeedsDisplay() }
        }

        setNeedsDisplay()
    }

    func applyPalette(_ p: Palette) {
        palette = p
        backgroundColor = p.editorGutter
        setNeedsDisplay()
    }

    // MARK: - Drawing

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        guard let textView = textView else { return }

        // Right border to echo the RN `borderRight` on the gutter.
        ctx.setFillColor(palette.border.cgColor)
        ctx.fill(CGRect(x: bounds.width - 1 / UIScreen.main.scale,
                        y: 0,
                        width: 1 / UIScreen.main.scale,
                        height: bounds.height))

        let layoutManager = textView.layoutManager
        let textContainer = textView.textContainer
        let text = textView.text ?? ""
        let nsText = text as NSString
        let storage = textView.textStorage

        let lineHeight = font.lineHeight
        let baselineOffset: CGFloat = textView.textContainerInset.top - textView.contentOffset.y
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedSystemFont(ofSize: font.pointSize * 0.78, weight: .regular),
            .foregroundColor: palette.mutedForeground,
            .paragraphStyle: rightAlignedStyle(),
        ]

        // For empty storage still show "1".
        if nsText.length == 0 {
            let rect = CGRect(x: 0, y: baselineOffset + 4, width: bounds.width - 6, height: lineHeight)
            ("1" as NSString).draw(in: rect, withAttributes: attrs)
            return
        }

        // Enumerate line fragments to handle wrapped lines: the gutter only
        // labels the *first* visual line of each logical line.
        var lineNumber = 0
        var lastLineStart = -1
        layoutManager.enumerateLineFragments(forGlyphRange: NSRange(location: 0, length: layoutManager.numberOfGlyphs)) { [weak self] _, usedRect, _, glyphRange, _ in
            guard let self = self else { return }
            let charRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
            let lineStartInStorage = (storage.string as NSString).lineRange(for: NSRange(location: charRange.location, length: 0)).location

            if lineStartInStorage != lastLineStart {
                lineNumber += 1
                lastLineStart = lineStartInStorage

                let y = usedRect.minY + self.textView!.textContainerInset.top - self.textView!.contentOffset.y
                // Skip frames that are entirely above/below the visible area.
                if y + usedRect.height < 0 || y > self.bounds.height { return }
                let rect = CGRect(x: 0, y: y, width: self.bounds.width - 6, height: usedRect.height)
                ("\(lineNumber)" as NSString).draw(in: rect, withAttributes: attrs)
            }
        }

        // Enumerate doesn't visit the trailing implicit-empty-line if the
        // text ends in "\n"; account for it so the final blank line is numbered.
        if nsText.length > 0, nsText.character(at: nsText.length - 1) == 0x0A {
            let extraY: CGFloat
            if let lastFragment = lastLineFragmentRect(in: layoutManager, container: textContainer) {
                extraY = lastFragment.maxY + textView.textContainerInset.top - textView.contentOffset.y
            } else {
                extraY = textView.textContainerInset.top - textView.contentOffset.y
            }
            if extraY + lineHeight > 0, extraY < bounds.height {
                let rect = CGRect(x: 0, y: extraY, width: bounds.width - 6, height: lineHeight)
                ("\(lineNumber + 1)" as NSString).draw(in: rect, withAttributes: attrs)
            }
        }
    }

    private func lastLineFragmentRect(in layoutManager: NSLayoutManager, container: NSTextContainer) -> CGRect? {
        let glyphs = layoutManager.numberOfGlyphs
        guard glyphs > 0 else { return nil }
        var effectiveRange = NSRange(location: 0, length: 0)
        let rect = layoutManager.lineFragmentUsedRect(forGlyphAt: glyphs - 1, effectiveRange: &effectiveRange)
        return rect
    }

    private func rightAlignedStyle() -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.alignment = .right
        return style
    }
}
