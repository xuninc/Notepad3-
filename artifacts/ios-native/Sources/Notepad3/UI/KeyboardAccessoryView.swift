import UIKit

/// Input accessory bar that sits above the software keyboard. Mirrors the
/// RN toolbar: Hide, Read, Undo, Redo, Cut, Copy, Paste, Word, Line, All,
/// ← ↑ ↓ →, Find, Replace, Date, Open, Compare, More. Buttons live in a
/// horizontal scroll view; when `rows == .double` the items are split
/// across two stacked scroll views for a chunkier, less scrolly layout.
///
/// The view owns no state beyond button flags (active/disabled) and the
/// palette; everything else flows through the action callbacks. Arrow
/// keys auto-repeat while held, ramping from 220 ms → 120 ms → 60 ms to
/// mirror the RN `KbHoldBtn` behaviour.
final class KeyboardAccessoryView: UIView {

    enum Rows { case single, double }
    enum Arrow { case left, right, up, down }

    // MARK: - Public flags

    var rows: Rows = .single {
        didSet { if rows != oldValue { rebuildLayout() } }
    }
    var readMode: Bool = false {
        didSet { readButton?.setSymbol(readMode ? "eye" : "eye.slash"); readButton?.isActive = readMode; applyPaletteToButtons() }
    }
    var canUndo: Bool = true {
        didSet { undoButton?.isDisabled = !canUndo; applyPaletteToButtons() }
    }
    var canRedo: Bool = true {
        didSet { redoButton?.isDisabled = !canRedo; applyPaletteToButtons() }
    }
    var hasSelection: Bool = false {
        didSet { cutButton?.isDisabled = !hasSelection; applyPaletteToButtons() }
    }
    var findActive: Bool = false {
        didSet { findButton?.isActive = findActive; applyPaletteToButtons() }
    }
    var replaceActive: Bool = false {
        didSet { replaceButton?.isActive = replaceActive; applyPaletteToButtons() }
    }
    var compareActive: Bool = false {
        didSet { compareButton?.isActive = compareActive; applyPaletteToButtons() }
    }

    // MARK: - Callbacks

    var onHide: (() -> Void)?
    var onReadToggle: (() -> Void)?
    var onUndo: (() -> Void)?
    var onRedo: (() -> Void)?
    var onCut: (() -> Void)?
    var onCopy: (() -> Void)?
    var onPaste: (() -> Void)?
    var onSelectWord: (() -> Void)?
    var onSelectLine: (() -> Void)?
    var onSelectAll: (() -> Void)?
    var onArrow: ((Arrow) -> Void)?
    var onFind: (() -> Void)?
    var onReplace: (() -> Void)?
    var onInsertDate: (() -> Void)?
    var onOpenDocs: (() -> Void)?
    var onCompare: (() -> Void)?
    var onMore: (() -> Void)?

    // MARK: - Subviews

    private let topScroll = UIScrollView()
    private let bottomScroll = UIScrollView()
    private let topStack = UIStackView()
    private let bottomStack = UIStackView()
    private let topBorder = UIView()
    private let middleBorder = UIView()

    private var palette: Palette = .light

    // Button references we toggle.
    private weak var readButton: KbButton?
    private weak var undoButton: KbButton?
    private weak var redoButton: KbButton?
    private weak var cutButton: KbButton?
    private weak var findButton: KbButton?
    private weak var replaceButton: KbButton?
    private weak var compareButton: KbButton?

    private var allButtons: [KbButton] = []
    private var allSeparators: [UIView] = []

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        autoresizingMask = [.flexibleWidth]
        setupBase()
        rebuildLayout()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    private func setupBase() {
        topBorder.translatesAutoresizingMaskIntoConstraints = false
        middleBorder.translatesAutoresizingMaskIntoConstraints = false
        addSubview(topBorder)
        addSubview(middleBorder)

        for sv in [topScroll, bottomScroll] {
            sv.translatesAutoresizingMaskIntoConstraints = false
            sv.showsHorizontalScrollIndicator = false
            sv.alwaysBounceHorizontal = false
            sv.keyboardDismissMode = .none
            addSubview(sv)
        }
        for st in [topStack, bottomStack] {
            st.translatesAutoresizingMaskIntoConstraints = false
            st.axis = .horizontal
            st.alignment = .center
            st.distribution = .fill
            st.spacing = 2
        }
        topScroll.addSubview(topStack)
        bottomScroll.addSubview(bottomStack)

        NSLayoutConstraint.activate([
            topBorder.topAnchor.constraint(equalTo: topAnchor),
            topBorder.leadingAnchor.constraint(equalTo: leadingAnchor),
            topBorder.trailingAnchor.constraint(equalTo: trailingAnchor),
            topBorder.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale),
        ])
    }

    // MARK: - Intrinsic size

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: rows == .double ? 88 : 44)
    }

    // MARK: - Layout

    private var activeConstraints: [NSLayoutConstraint] = []

    private func rebuildLayout() {
        // Tear down existing button subviews / constraints.
        NSLayoutConstraint.deactivate(activeConstraints)
        activeConstraints.removeAll()
        topStack.arrangedSubviews.forEach { topStack.removeArrangedSubview($0); $0.removeFromSuperview() }
        bottomStack.arrangedSubviews.forEach { bottomStack.removeArrangedSubview($0); $0.removeFromSuperview() }
        allButtons.removeAll()
        allSeparators.removeAll()
        readButton = nil; undoButton = nil; redoButton = nil; cutButton = nil
        findButton = nil; replaceButton = nil; compareButton = nil

        // Build the full ordered list of items.
        let items = makeItems()

        // Split across rows if requested.
        if rows == .double {
            let half = Int((Double(items.count) / 2.0).rounded(.up))
            let top = Array(items.prefix(half))
            let bot = Array(items.suffix(from: half))
            install(items: top, into: topStack)
            install(items: bot, into: bottomStack)

            bottomScroll.isHidden = false
            middleBorder.isHidden = false

            activeConstraints = [
                topScroll.topAnchor.constraint(equalTo: topAnchor),
                topScroll.leadingAnchor.constraint(equalTo: leadingAnchor),
                topScroll.trailingAnchor.constraint(equalTo: trailingAnchor),
                topScroll.heightAnchor.constraint(equalToConstant: 44),

                middleBorder.topAnchor.constraint(equalTo: topScroll.bottomAnchor),
                middleBorder.leadingAnchor.constraint(equalTo: leadingAnchor),
                middleBorder.trailingAnchor.constraint(equalTo: trailingAnchor),
                middleBorder.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale),

                bottomScroll.topAnchor.constraint(equalTo: middleBorder.bottomAnchor),
                bottomScroll.leadingAnchor.constraint(equalTo: leadingAnchor),
                bottomScroll.trailingAnchor.constraint(equalTo: trailingAnchor),
                bottomScroll.bottomAnchor.constraint(equalTo: bottomAnchor),

                topStack.topAnchor.constraint(equalTo: topScroll.contentLayoutGuide.topAnchor, constant: 4),
                topStack.leadingAnchor.constraint(equalTo: topScroll.contentLayoutGuide.leadingAnchor, constant: 4),
                topStack.trailingAnchor.constraint(equalTo: topScroll.contentLayoutGuide.trailingAnchor, constant: -4),
                topStack.bottomAnchor.constraint(equalTo: topScroll.contentLayoutGuide.bottomAnchor, constant: -4),
                topStack.heightAnchor.constraint(equalTo: topScroll.frameLayoutGuide.heightAnchor, constant: -8),

                bottomStack.topAnchor.constraint(equalTo: bottomScroll.contentLayoutGuide.topAnchor, constant: 4),
                bottomStack.leadingAnchor.constraint(equalTo: bottomScroll.contentLayoutGuide.leadingAnchor, constant: 4),
                bottomStack.trailingAnchor.constraint(equalTo: bottomScroll.contentLayoutGuide.trailingAnchor, constant: -4),
                bottomStack.bottomAnchor.constraint(equalTo: bottomScroll.contentLayoutGuide.bottomAnchor, constant: -4),
                bottomStack.heightAnchor.constraint(equalTo: bottomScroll.frameLayoutGuide.heightAnchor, constant: -8),
            ]
        } else {
            install(items: items, into: topStack)
            bottomScroll.isHidden = true
            middleBorder.isHidden = true

            activeConstraints = [
                topScroll.topAnchor.constraint(equalTo: topAnchor),
                topScroll.leadingAnchor.constraint(equalTo: leadingAnchor),
                topScroll.trailingAnchor.constraint(equalTo: trailingAnchor),
                topScroll.bottomAnchor.constraint(equalTo: bottomAnchor),

                topStack.topAnchor.constraint(equalTo: topScroll.contentLayoutGuide.topAnchor, constant: 4),
                topStack.leadingAnchor.constraint(equalTo: topScroll.contentLayoutGuide.leadingAnchor, constant: 4),
                topStack.trailingAnchor.constraint(equalTo: topScroll.contentLayoutGuide.trailingAnchor, constant: -4),
                topStack.bottomAnchor.constraint(equalTo: topScroll.contentLayoutGuide.bottomAnchor, constant: -4),
                topStack.heightAnchor.constraint(equalTo: topScroll.frameLayoutGuide.heightAnchor, constant: -8),
            ]
        }
        NSLayoutConstraint.activate(activeConstraints)
        invalidateIntrinsicContentSize()
        applyPaletteToButtons()
    }

    private func install(items: [Item], into stack: UIStackView) {
        for it in items {
            switch it {
            case .separator:
                let sep = UIView()
                sep.translatesAutoresizingMaskIntoConstraints = false
                sep.widthAnchor.constraint(equalToConstant: 1).isActive = true
                sep.heightAnchor.constraint(equalToConstant: 22).isActive = true
                allSeparators.append(sep)
                stack.addArrangedSubview(sep)
            case .button(let b):
                allButtons.append(b)
                stack.addArrangedSubview(b)
            }
        }
    }

    private enum Item {
        case button(KbButton)
        case separator
    }

    private func makeItems() -> [Item] {
        // Hide is leftmost and rides the primary tint full-time so it reads
        // as an always-available escape hatch — tapping it dismisses the
        // keyboard while leaving the document editable, distinct from Read
        // mode which locks the buffer. `isActive` is how KbButton renders
        // "emphasised, palette.primary-tinted."
        let hide = KbButton(symbol: "keyboard.chevron.compact.down", label: "Hide") { [weak self] in self?.onHide?() }
        hide.isActive = true
        let read = KbButton(symbol: readMode ? "eye" : "eye.slash", label: "Read") { [weak self] in self?.onReadToggle?() }
        read.isActive = readMode
        readButton = read

        let undo = KbButton(symbol: "arrow.uturn.backward", label: "Undo") { [weak self] in self?.onUndo?() }
        undo.isDisabled = !canUndo
        undoButton = undo
        let redo = KbButton(symbol: "arrow.uturn.forward", label: "Redo") { [weak self] in self?.onRedo?() }
        redo.isDisabled = !canRedo
        redoButton = redo

        let cut = KbButton(symbol: "scissors", label: "Cut") { [weak self] in self?.onCut?() }
        cut.isDisabled = !hasSelection
        cutButton = cut
        let copy = KbButton(symbol: "doc.on.doc", label: "Copy") { [weak self] in self?.onCopy?() }
        let paste = KbButton(symbol: "doc.on.clipboard", label: "Paste") { [weak self] in self?.onPaste?() }

        let word = KbButton(symbol: "textformat.abc", label: "Word") { [weak self] in self?.onSelectWord?() }
        let line = KbButton(symbol: "minus", label: "Line") { [weak self] in self?.onSelectLine?() }
        let all = KbButton(symbol: "character.textbox", label: "All") { [weak self] in self?.onSelectAll?() }

        let left  = KbHoldButton(symbol: "arrow.left")  { [weak self] in self?.onArrow?(.left) }
        let up    = KbHoldButton(symbol: "arrow.up")    { [weak self] in self?.onArrow?(.up) }
        let down  = KbHoldButton(symbol: "arrow.down")  { [weak self] in self?.onArrow?(.down) }
        let right = KbHoldButton(symbol: "arrow.right") { [weak self] in self?.onArrow?(.right) }

        let find = KbButton(symbol: "magnifyingglass", label: "Find") { [weak self] in self?.onFind?() }
        find.isActive = findActive
        findButton = find
        let replace = KbButton(symbol: "arrow.triangle.2.circlepath", label: "Replace") { [weak self] in self?.onReplace?() }
        replace.isActive = replaceActive
        replaceButton = replace

        let date = KbButton(symbol: "clock", label: "Date") { [weak self] in self?.onInsertDate?() }
        let open = KbButton(symbol: "folder", label: "Open") { [weak self] in self?.onOpenDocs?() }
        let compare = KbButton(symbol: "rectangle.split.1x2", label: "Compare") { [weak self] in self?.onCompare?() }
        compare.isActive = compareActive
        compareButton = compare
        let more = KbButton(symbol: "ellipsis", label: "More") { [weak self] in self?.onMore?() }

        return [
            .button(hide), .button(read),
            .separator,
            .button(undo), .button(redo),
            .separator,
            .button(cut), .button(copy), .button(paste),
            .separator,
            .button(word), .button(line), .button(all),
            .separator,
            .button(left), .button(up), .button(down), .button(right),
            .separator,
            .button(find), .button(replace),
            .separator,
            .button(date), .button(open), .button(compare), .button(more),
        ]
    }

    // MARK: - Palette

    func applyPalette(_ p: Palette) {
        palette = p
        backgroundColor = p.card
        topBorder.backgroundColor = p.border
        middleBorder.backgroundColor = p.border
        applyPaletteToButtons()
    }

    private func applyPaletteToButtons() {
        for btn in allButtons {
            btn.applyPalette(palette)
        }
        for sep in allSeparators {
            sep.backgroundColor = palette.border
        }
    }
}

// MARK: - KbButton

private class KbButton: UIControl {
    let symbolName: String
    let label: String?
    var onTap: (() -> Void)?

    var isActive: Bool = false
    var isDisabled: Bool = false {
        didSet { isEnabled = !isDisabled }
    }

    private let imageView = UIImageView()
    private let titleLabel = UILabel()

    init(symbol: String, label: String? = nil, onTap: @escaping () -> Void) {
        self.symbolName = symbol
        self.label = label
        self.onTap = onTap
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        layer.cornerRadius = 4
        isAccessibilityElement = true
        accessibilityTraits = .button
        accessibilityLabel = label ?? symbolName

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.image = UIImage(systemName: symbolName,
                                  withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .regular))
        addSubview(imageView)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 9, weight: .medium)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 1
        titleLabel.text = label
        titleLabel.isHidden = (label == nil)
        addSubview(titleLabel)

        var constraints: [NSLayoutConstraint] = [
            widthAnchor.constraint(greaterThanOrEqualToConstant: 38),
            heightAnchor.constraint(greaterThanOrEqualToConstant: 34),
            imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            imageView.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            imageView.widthAnchor.constraint(equalToConstant: 20),
            imageView.heightAnchor.constraint(equalToConstant: 20),
            leadingAnchor.constraint(equalTo: imageView.leadingAnchor, constant: -6),
            trailingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 6),
        ]
        if label == nil {
            constraints.append(imageView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4))
        } else {
            constraints.append(contentsOf: [
                titleLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 1),
                titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
                titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 2),
                titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -2),
                titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
            ])
        }
        NSLayoutConstraint.activate(constraints)

        addTarget(self, action: #selector(tapped), for: .touchUpInside)
    }

    func setSymbol(_ name: String) {
        imageView.image = UIImage(systemName: name,
                                  withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .regular))
    }

    @objc private func tapped() { onTap?() }

    override var isHighlighted: Bool {
        didSet { refreshVisuals() }
    }

    func applyPalette(_ p: Palette) {
        refreshVisuals(using: p)
    }

    private var cachedPalette: Palette?

    private func refreshVisuals(using override: Palette? = nil) {
        let p = override ?? cachedPalette
        if let p { cachedPalette = p }
        guard let p = cachedPalette else { return }

        let tint: UIColor = isDisabled ? p.mutedForeground : (isActive ? p.primary : p.foreground)
        imageView.tintColor = tint
        titleLabel.textColor = tint

        if isHighlighted {
            backgroundColor = p.secondary
            alpha = isDisabled ? 0.35 : 0.55
        } else {
            backgroundColor = .clear
            alpha = isDisabled ? 0.35 : 1.0
        }
    }
}

// MARK: - KbHoldButton

/// Auto-repeating accessory button. Fires once immediately on press-in,
/// waits 380 ms, then fires every 220 ms. After 3 repeats the cadence
/// tightens to 120 ms; after 6 it drops to 60 ms. Releasing the button
/// (or touch cancelled) cancels all outstanding timers.
private final class KbHoldButton: KbButton {
    private var holdTimer: Timer?
    private var initialDelayTimer: Timer?
    private var repeatCount: Int = 0
    private var tickHandler: () -> Void

    init(symbol: String, label: String? = nil, onTick: @escaping () -> Void) {
        self.tickHandler = onTick
        super.init(symbol: symbol, label: label, onTap: {})
        // Tap handler not used — we drive from touch events instead.
        self.onTap = nil
        removeTarget(self, action: #selector(tappedOverride), for: .touchUpInside)
        // Wire our own touch handlers.
        addTarget(self, action: #selector(pressDown), for: .touchDown)
        addTarget(self, action: #selector(pressUp), for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    @objc private func tappedOverride() { /* unused */ }

    @objc private func pressDown() {
        tickHandler()
        repeatCount = 0
        initialDelayTimer?.invalidate()
        initialDelayTimer = Timer.scheduledTimer(withTimeInterval: 0.380, repeats: false) { [weak self] _ in
            self?.startRepeating(every: 0.220)
        }
    }

    @objc private func pressUp() {
        stopAllTimers()
    }

    private func startRepeating(every interval: TimeInterval) {
        holdTimer?.invalidate()
        holdTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.tickHandler()
            self.repeatCount += 1
            if self.repeatCount == 6 && interval > 0.090 {
                self.startRepeating(every: 0.060)
            } else if self.repeatCount == 3 && interval > 0.150 {
                self.startRepeating(every: 0.120)
            }
        }
    }

    private func stopAllTimers() {
        initialDelayTimer?.invalidate()
        initialDelayTimer = nil
        holdTimer?.invalidate()
        holdTimer = nil
        repeatCount = 0
    }

    deinit {
        stopAllTimers()
    }
}
