import UIKit

/// Top/bottom split comparison view. Two read-only UITextViews stacked with a
/// 1pt separator. Top shows the active note; bottom shows a user-selected
/// "other" note from the store. When one pane scrolls, the other mirrors the
/// proportional offset so the reader can follow the same relative position in
/// both documents. Mirrors the RN `compareOpen` / `topCompareRef` / `bottomCompareRef`
/// surface.
///
/// Each line's background is coloured to reflect the line-diff status against
/// the other pane (unchanged / added / removed / changed). A small header strip
/// above the two panes summarises the percent-similar plus add/remove/change
/// counts. The diff itself is an LCS-based line diff (see `Diff.compute`); a
/// post-pass pairs adjacent add/remove entries whose normalised Levenshtein
/// similarity is ≥ 0.5 and reclassifies them as `changed`.
final class CompareViewController: UIViewController, UITextViewDelegate {
    var onClose: (() -> Void)?

    private let store: NotesStore
    private var palette: Palette

    private let summaryLabel = UILabel()
    private let topTextView = UITextView()
    private let bottomTextView = UITextView()
    private let separator = UIView()
    private let emptyLabel = UILabel()

    private var comparableNotes: [Note] = []
    private var bottomNoteId: String?
    private var isSyncing = false

    // Muted yellow used for both panes on `changed` lines. 25% alpha so the
    // text stays readable over the editor background.
    private static let changedColor = UIColor(red: 1.0, green: 0.85, blue: 0.3, alpha: 0.25)
    private static let addRemoveAlpha: CGFloat = 0.18
    private static let summaryHeight: CGFloat = 24

    init(store: NotesStore, palette: Palette) {
        self.store = store
        self.palette = palette
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()

        configureSummaryLabel()
        configureTextViews()
        configureSeparator()
        configureEmptyLabel()
        layoutSubviews()
        configureNavBar()

        refreshComparableNotes()
        applyPalette()
        reloadContent()
    }

    // MARK: - Configuration

    private func configureSummaryLabel() {
        summaryLabel.translatesAutoresizingMaskIntoConstraints = false
        summaryLabel.font = .systemFont(ofSize: 12, weight: .regular)
        summaryLabel.textAlignment = .center
        summaryLabel.adjustsFontSizeToFitWidth = true
        summaryLabel.minimumScaleFactor = 0.85
        summaryLabel.lineBreakMode = .byTruncatingTail
        summaryLabel.numberOfLines = 1
        view.addSubview(summaryLabel)
    }

    private func configureTextViews() {
        for tv in [topTextView, bottomTextView] {
            tv.translatesAutoresizingMaskIntoConstraints = false
            tv.isEditable = false
            tv.isSelectable = true
            tv.alwaysBounceVertical = true
            tv.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
            tv.autocapitalizationType = .none
            tv.autocorrectionType = .no
            tv.spellCheckingType = .no
            tv.smartQuotesType = .no
            tv.smartDashesType = .no
            tv.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
            tv.delegate = self
            view.addSubview(tv)
        }
    }

    private func configureSeparator() {
        separator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(separator)
    }

    private func configureEmptyLabel() {
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.numberOfLines = 0
        emptyLabel.textAlignment = .center
        emptyLabel.font = .systemFont(ofSize: 14, weight: .regular)
        emptyLabel.text = "Open another document to compare.\nImport a file or duplicate this document, edit one copy, then return here."
        emptyLabel.isHidden = true
        view.addSubview(emptyLabel)
    }

    private func layoutSubviews() {
        NSLayoutConstraint.activate([
            summaryLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            summaryLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            summaryLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            summaryLabel.heightAnchor.constraint(equalToConstant: Self.summaryHeight),

            topTextView.topAnchor.constraint(equalTo: summaryLabel.bottomAnchor),
            topTextView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topTextView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topTextView.bottomAnchor.constraint(equalTo: separator.topAnchor),

            separator.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            separator.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor, constant: Self.summaryHeight / 2),
            separator.heightAnchor.constraint(equalToConstant: 1),

            bottomTextView.topAnchor.constraint(equalTo: separator.bottomAnchor),
            bottomTextView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomTextView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomTextView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            emptyLabel.centerXAnchor.constraint(equalTo: bottomTextView.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: bottomTextView.centerYAnchor),
            emptyLabel.leadingAnchor.constraint(equalTo: bottomTextView.leadingAnchor, constant: 24),
            emptyLabel.trailingAnchor.constraint(equalTo: bottomTextView.trailingAnchor, constant: -24),
        ])
    }

    private func configureNavBar() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Done",
            style: .done,
            target: self,
            action: #selector(doneTapped)
        )
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Pick",
            style: .plain,
            target: self,
            action: #selector(pickTapped)
        )
        updateTitle()
        updatePickEnabled()
    }

    // MARK: - Palette

    private func applyPalette() {
        view.backgroundColor = palette.editorBackground
        topTextView.backgroundColor = palette.editorBackground
        topTextView.textColor = palette.foreground
        bottomTextView.backgroundColor = palette.editorBackground
        bottomTextView.textColor = palette.foreground
        separator.backgroundColor = palette.border
        emptyLabel.textColor = palette.mutedForeground
        summaryLabel.textColor = palette.mutedForeground
        summaryLabel.backgroundColor = palette.editorBackground

        let nav = UINavigationBarAppearance()
        nav.configureWithDefaultBackground()
        nav.backgroundColor = palette.card
        nav.titleTextAttributes = [.foregroundColor: palette.foreground]
        navigationItem.standardAppearance = nav
        navigationItem.scrollEdgeAppearance = nav
        navigationController?.navigationBar.tintColor = palette.primary
    }

    // MARK: - Data

    private func refreshComparableNotes() {
        let active = store.activeId
        comparableNotes = store.notes.filter { $0.id != active }
        if bottomNoteId == nil || !comparableNotes.contains(where: { $0.id == bottomNoteId }) {
            bottomNoteId = comparableNotes.first?.id
        }
    }

    private func reloadContent() {
        let topBody = store.activeNote.body
        let bottomNote = bottomNoteId.flatMap { id in comparableNotes.first(where: { $0.id == id }) }

        if let bottom = bottomNote {
            let diff = Diff.compute(top: topBody, bottom: bottom.body)
            topTextView.attributedText = makeAttributedBody(lines: diff.topLines, statuses: diff.topStatuses, pane: .top)
            bottomTextView.attributedText = makeAttributedBody(lines: diff.bottomLines, statuses: diff.bottomStatuses, pane: .bottom)
            summaryLabel.text = Self.formatSummary(diff.summary)
            bottomTextView.isHidden = false
            emptyLabel.isHidden = true
        } else {
            // No comparison target: show just the active body, no highlighting.
            topTextView.attributedText = makeAttributedBody(
                lines: topBody.isEmpty ? [""] : topBody.components(separatedBy: "\n"),
                statuses: nil,
                pane: .top
            )
            bottomTextView.attributedText = NSAttributedString(string: "")
            summaryLabel.text = ""
            bottomTextView.isHidden = true
            emptyLabel.isHidden = false
        }
        updateTitle()
        updatePickEnabled()
    }

    private enum Pane { case top, bottom }

    /// Build an attributed string for one pane by joining `lines` with `\n`
    /// and applying a per-line `.backgroundColor`. `statuses` may be `nil` when
    /// no comparison target is set (e.g. first launch with only one note).
    private func makeAttributedBody(lines: [String], statuses: [Diff.Status]?, pane: Pane) -> NSAttributedString {
        let joined = lines.joined(separator: "\n")
        let attr = NSMutableAttributedString(string: joined, attributes: [
            .font: UIFont.monospacedSystemFont(ofSize: 14, weight: .regular),
            .foregroundColor: palette.foreground,
        ])
        guard let statuses = statuses, statuses.count == lines.count else { return attr }

        let nsString = joined as NSString
        var cursor = 0
        for (index, line) in lines.enumerated() {
            let lineLength = (line as NSString).length
            // Include the trailing newline in the colored range so the full row
            // strip reads as highlighted, not just the character run.
            let includeNewline = index < lines.count - 1
            let rangeLength = lineLength + (includeNewline ? 1 : 0)
            let range = NSRange(location: cursor, length: rangeLength)
            if range.location + range.length <= nsString.length,
               let color = background(for: statuses[index], pane: pane) {
                attr.addAttribute(.backgroundColor, value: color, range: range)
            }
            cursor += rangeLength
        }
        return attr
    }

    private func background(for status: Diff.Status, pane: Pane) -> UIColor? {
        switch status {
        case .unchanged:
            return nil
        case .added:
            return pane == .bottom ? palette.success.withAlphaComponent(Self.addRemoveAlpha) : nil
        case .removed:
            return pane == .top ? palette.destructive.withAlphaComponent(Self.addRemoveAlpha) : nil
        case .changed:
            return Self.changedColor
        }
    }

    private static func formatSummary(_ s: Diff.Summary) -> String {
        return "\(s.percentSimilar)% similar · \(s.added) added · \(s.removed) removed · \(s.changed) changed"
    }

    private func updateTitle() {
        title = "Compare: \(store.activeNote.title)"
    }

    private func updatePickEnabled() {
        navigationItem.rightBarButtonItem?.isEnabled = !comparableNotes.isEmpty
    }

    // MARK: - Actions

    @objc private func doneTapped() {
        onClose?()
    }

    @objc private func pickTapped() {
        guard !comparableNotes.isEmpty else { return }
        let sheet = UIAlertController(title: "Bottom pane", message: nil, preferredStyle: .actionSheet)
        for note in comparableNotes {
            let prefix = note.id == bottomNoteId ? "\u{2713} " : ""
            sheet.addAction(UIAlertAction(title: prefix + note.title, style: .default) { [weak self] _ in
                self?.bottomNoteId = note.id
                self?.reloadContent()
            })
        }
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let pop = sheet.popoverPresentationController {
            pop.barButtonItem = navigationItem.rightBarButtonItem
        }
        present(sheet, animated: true)
    }

    // MARK: - Synced scrolling

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView === topTextView || scrollView === bottomTextView else { return }
        guard !isSyncing else { return }
        let other: UIScrollView = (scrollView === topTextView) ? bottomTextView : topTextView
        let srcMax = max(scrollView.contentSize.height - scrollView.bounds.height, 1)
        let dstMax = max(other.contentSize.height - other.bounds.height, 0)
        let ratio = min(max(scrollView.contentOffset.y / srcMax, 0), 1)
        let targetY = ratio * dstMax
        if abs(other.contentOffset.y - targetY) < 0.5 { return }
        isSyncing = true
        other.setContentOffset(CGPoint(x: other.contentOffset.x, y: targetY), animated: false)
        isSyncing = false
    }
}

// MARK: - Line diff

/// Pure line-diff computation. Kept private-but-file-scoped so other compare-
/// related work in this namespace could reach it, but not exposed to the wider
/// app. The algorithm is an LCS (longest common subsequence) table over the
/// two `\n`-split line arrays, then a backtrack emits an op stream of
/// `.equal` / `.add` / `.remove`. A second pass walks the op stream and pairs
/// adjacent `.remove` + `.add` runs — when two opposing lines are "similar
/// enough" (normalised Levenshtein ≥ 0.5) they are reclassified as `.changed`
/// so the UI can colour the row yellow on both panes.
///
/// Complexity: O(n·m) time and space for the LCS table, which the spec caps
/// at "a few thousand lines" worst case. Short-circuits on empty input.
enum Diff {
    enum Status { case unchanged, added, removed, changed }

    struct Summary {
        let unchanged: Int
        let added: Int
        let removed: Int
        let changed: Int
        let percentSimilar: Int
    }

    struct Result {
        let topLines: [String]
        let bottomLines: [String]
        let topStatuses: [Diff.Status]
        let bottomStatuses: [Diff.Status]
        let summary: Summary
    }

    static func compute(top: String, bottom: String) -> Result {
        let topLines = top.components(separatedBy: "\n")
        let bottomLines = bottom.components(separatedBy: "\n")

        let ops = lcsOps(a: topLines, b: bottomLines)
        let reconciled = reconcileChanges(ops: ops, a: topLines, b: bottomLines)

        var topStatuses: [Diff.Status] = []
        var bottomStatuses: [Diff.Status] = []
        topStatuses.reserveCapacity(topLines.count)
        bottomStatuses.reserveCapacity(bottomLines.count)

        var unchanged = 0
        var added = 0
        var removed = 0
        var changed = 0

        for op in reconciled {
            switch op {
            case .equal:
                topStatuses.append(.unchanged)
                bottomStatuses.append(.unchanged)
                unchanged += 1
            case .add:
                bottomStatuses.append(.added)
                added += 1
            case .remove:
                topStatuses.append(.removed)
                removed += 1
            case .changePair:
                topStatuses.append(.changed)
                bottomStatuses.append(.changed)
                changed += 1
            }
        }

        // Defensive: if the op stream somehow underproduces statuses (shouldn't,
        // but guards against future refactors), pad with `.unchanged`.
        while topStatuses.count < topLines.count { topStatuses.append(.unchanged) }
        while bottomStatuses.count < bottomLines.count { bottomStatuses.append(.unchanged) }

        let denom = max(topLines.count, bottomLines.count)
        let percent: Int = denom == 0 ? 100 : Int((Double(unchanged) / Double(denom)) * 100.0)

        return Result(
            topLines: topLines,
            bottomLines: bottomLines,
            topStatuses: topStatuses,
            bottomStatuses: bottomStatuses,
            summary: Summary(
                unchanged: unchanged,
                added: added,
                removed: removed,
                changed: changed,
                percentSimilar: percent
            )
        )
    }

    // MARK: - LCS op stream

    private enum Op {
        case equal       // present in both
        case add         // only in b (bottom)
        case remove      // only in a (top)
        case changePair  // top+bottom pair after similarity merge
    }

    /// Classic two-row LCS dp over `a` and `b`, with a back-pointer matrix so
    /// we can reconstruct a single op sequence. We build the full `n*m` table
    /// of back-pointers (not just two rows) so the backtrack can walk it; the
    /// cost tables themselves use two rolling rows to save memory on the
    /// (larger) cost dimension.
    private static func lcsOps(a: [String], b: [String]) -> [Op] {
        let n = a.count
        let m = b.count

        if n == 0 {
            return Array(repeating: .add, count: m)
        }
        if m == 0 {
            return Array(repeating: .remove, count: n)
        }

        // back[i][j] encodes which move led to cell (i,j):
        //  0 = diagonal (equal), 1 = up (remove from a), 2 = left (add from b).
        // Using a flat Int8 array keeps the allocation compact.
        var back = [Int8](repeating: 0, count: (n + 1) * (m + 1))
        var prev = [Int](repeating: 0, count: m + 1)
        var curr = [Int](repeating: 0, count: m + 1)

        @inline(__always)
        func bIdx(_ i: Int, _ j: Int) -> Int { i * (m + 1) + j }

        for i in 1...n {
            for j in 1...m {
                if a[i - 1] == b[j - 1] {
                    curr[j] = prev[j - 1] + 1
                    back[bIdx(i, j)] = 0
                } else if prev[j] >= curr[j - 1] {
                    curr[j] = prev[j]
                    back[bIdx(i, j)] = 1
                } else {
                    curr[j] = curr[j - 1]
                    back[bIdx(i, j)] = 2
                }
            }
            swap(&prev, &curr)
            // prev now holds row i; zero curr for the next pass.
            for k in 0...m { curr[k] = 0 }
        }

        // Backtrack from (n, m). We walk to the origin, emitting ops for cells
        // "outside" the LCS frontier. Any leftover indices at the edges produce
        // pure remove (from a) or add (from b) runs.
        var ops: [Op] = []
        ops.reserveCapacity(n + m)
        var i = n
        var j = m
        while i > 0 && j > 0 {
            let move = back[bIdx(i, j)]
            if move == 0 {
                ops.append(.equal)
                i -= 1
                j -= 1
            } else if move == 1 {
                ops.append(.remove)
                i -= 1
            } else {
                ops.append(.add)
                j -= 1
            }
        }
        while i > 0 {
            ops.append(.remove)
            i -= 1
        }
        while j > 0 {
            ops.append(.add)
            j -= 1
        }

        return ops.reversed()
    }

    // MARK: - Adjacent add/remove pairing → `.changePair`

    /// Scan the op stream and, whenever we see a contiguous run of `.remove`
    /// ops immediately followed by `.add` ops (or vice versa), greedily pair
    /// them into `.changePair` ops when the two lines have similarity ≥ 0.5.
    /// Unpaired leftovers stay as plain remove/add.
    private static func reconcileChanges(ops: [Op], a: [String], b: [String]) -> [Op] {
        var out: [Op] = []
        out.reserveCapacity(ops.count)

        // Track cursors into a and b so we can look up the actual line text
        // that each remove/add refers to.
        var ai = 0
        var bi = 0

        var k = 0
        while k < ops.count {
            switch ops[k] {
            case .equal:
                out.append(.equal)
                ai += 1
                bi += 1
                k += 1
            case .remove, .add:
                // Collect the maximal adjacent run of remove/add (no .equal or
                // .changePair can appear here since we haven't produced any yet).
                let runStart = k
                while k < ops.count, case let op = ops[k], op == .remove || op == .add {
                    k += 1
                }
                let runEnd = k
                // Split into the lines they reference.
                var removeLines: [(String, Int)] = [] // (text, index into a)
                var addLines: [(String, Int)] = []    // (text, index into b)
                for idx in runStart..<runEnd {
                    if case .remove = ops[idx] {
                        removeLines.append((a[ai], ai))
                        ai += 1
                    } else if case .add = ops[idx] {
                        addLines.append((b[bi], bi))
                        bi += 1
                    }
                }
                // Greedy pair by index (position within each run), reclassifying
                // when similar enough.
                let pairCount = min(removeLines.count, addLines.count)
                var paired = [Bool](repeating: false, count: pairCount)
                for p in 0..<pairCount {
                    if similarity(removeLines[p].0, addLines[p].0) >= 0.5 {
                        paired[p] = true
                    }
                }
                // Emit in the original interleaved order: for each pair index
                // that matched, emit a single `.changePair`; unmatched removes
                // stay as `.remove`, unmatched adds as `.add`.
                var emittedPairs = 0
                var emittedRemoves = 0
                var emittedAdds = 0
                var removeIdx = 0
                var addIdx = 0
                for idx in runStart..<runEnd {
                    switch ops[idx] {
                    case .remove:
                        if removeIdx < pairCount && paired[removeIdx] {
                            // Consumes one pair.
                            out.append(.changePair)
                            emittedPairs += 1
                        } else {
                            out.append(.remove)
                            emittedRemoves += 1
                        }
                        removeIdx += 1
                    case .add:
                        if addIdx < pairCount && paired[addIdx] {
                            // Already emitted by the matching .remove above;
                            // skip so we don't double-count.
                            _ = 0
                        } else {
                            out.append(.add)
                            emittedAdds += 1
                        }
                        addIdx += 1
                    default:
                        break
                    }
                }
                // Sanity: each paired index emits exactly one changePair.
                _ = emittedPairs
                _ = emittedRemoves
                _ = emittedAdds
            case .changePair:
                // Shouldn't appear in the input, but pass through if it does.
                out.append(.changePair)
                ai += 1
                bi += 1
                k += 1
            }
        }
        return out
    }

    // MARK: - Similarity

    /// Normalised similarity in [0, 1]: `1 - editDistance / max(len)`.
    /// Empty-on-both returns 1 (identical). Empty-on-one returns 0.
    static func similarity(_ x: String, _ y: String) -> Double {
        if x == y { return 1.0 }
        let xc = Array(x)
        let yc = Array(y)
        if xc.isEmpty && yc.isEmpty { return 1.0 }
        if xc.isEmpty || yc.isEmpty { return 0.0 }
        let d = levenshtein(xc, yc)
        let longest = max(xc.count, yc.count)
        return 1.0 - Double(d) / Double(longest)
    }

    /// Iterative two-row Levenshtein. O(n·m) time, O(min(n, m)) space.
    private static func levenshtein(_ x: [Character], _ y: [Character]) -> Int {
        // Put the shorter string on the inner axis to minimise memory.
        let (shortArr, longArr) = x.count <= y.count ? (x, y) : (y, x)
        let sn = shortArr.count
        let ln = longArr.count

        var prev = [Int](repeating: 0, count: sn + 1)
        var curr = [Int](repeating: 0, count: sn + 1)
        for j in 0...sn { prev[j] = j }

        for i in 1...ln {
            curr[0] = i
            for j in 1...sn {
                let cost = (longArr[i - 1] == shortArr[j - 1]) ? 0 : 1
                let del = prev[j] + 1
                let ins = curr[j - 1] + 1
                let sub = prev[j - 1] + cost
                var best = del
                if ins < best { best = ins }
                if sub < best { best = sub }
                curr[j] = best
            }
            swap(&prev, &curr)
        }
        return prev[sn]
    }
}
