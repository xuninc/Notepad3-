import UIKit

/// Input accessory bar that sits above the software keyboard. Mirrors the
/// RN toolbar: Hide, Read, Undo, Redo, Cut, Copy, Paste, Word, Line, All,
/// ← ↑ ↓ →, Find, Date, Open, Compare, More. Buttons live in a
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
    private enum DeckPage: Int, CaseIterable { case navigation, edit, numeric }
    private enum DeckAction {
        case openDocuments
        case hideKeyboard
        case shift
        case ctrl
        case alt
        case enter
        case copy
        case cut
        case paste
        case switchDeck
        case backspace
        case undo
        case redo
        case find
        case selectWord
        case selectLine
        case selectAll
        case insertDate
        case readMode
        case compare
        case more
        case home
        case end
        case pageUp
        case pageDown
        case moveLeft
        case moveUp
        case moveDown
        case moveRight
        case tab
        case inert
        case insertText(String)
    }

    private struct DeckKeySpec {
        let action: DeckAction
        let title: String?
        let symbol: String?
        let visualText: String?
        let isHoldable: Bool
        let isDarkKey: Bool

        init(
            _ action: DeckAction,
            title: String? = nil,
            symbol: String? = nil,
            visualText: String? = nil,
            hold: Bool = false,
            dark: Bool = false
        ) {
            self.action = action
            self.title = title
            self.symbol = symbol
            self.visualText = visualText
            self.isHoldable = hold
            self.isDarkKey = dark
        }
    }

    // MARK: - Public flags

    var rows: Rows = .single {
        didSet { if rows != oldValue { rebuildLayout() } }
    }
    var usesKeyboardDeck: Bool = true {
        didSet { if usesKeyboardDeck != oldValue { rebuildLayout() } }
    }
    var buttonSize: AccessoryToolbarButtonSize = .medium {
        didSet { if buttonSize != oldValue { rebuildLayout() } }
    }
    var accessoryContentMode: AccessoryToolbarContentMode = .iconAndText {
        didSet { applyDisplayOptionsToButtons() }
    }
    var staticButtons: Set<AccessoryToolbarButton> = AccessoryToolbarButton.defaultStaticButtons {
        didSet { rebuildLayout() }
    }
    var hiddenButtons: Set<AccessoryToolbarButton> = [] {
        didSet { rebuildLayout() }
    }
    var readMode: Bool = false {
        didSet {
            readButton?.setSymbol(readMode ? "eye" : "eye.slash")
            readButton?.isActive = readMode
            applyPaletteToButtons()
            applyDeckState()
        }
    }
    var canUndo: Bool = true {
        didSet { undoButton?.isDisabled = !canUndo; applyPaletteToButtons(); applyDeckState() }
    }
    var canRedo: Bool = true {
        didSet { redoButton?.isDisabled = !canRedo; applyPaletteToButtons(); applyDeckState() }
    }
    var hasSelection: Bool = false {
        didSet { cutButton?.isDisabled = !hasSelection; applyPaletteToButtons(); applyDeckState() }
    }
    var findActive: Bool = false {
        didSet { findButton?.isActive = findActive; applyPaletteToButtons(); applyDeckState() }
    }
    var compareActive: Bool = false {
        didSet { compareButton?.isActive = compareActive; applyPaletteToButtons(); applyDeckState() }
    }
    var shiftActive: Bool = false {
        didSet {
            clusterShift.isActive = shiftActive
            clusterShift.setSymbol(shiftActive ? "shift.fill" : "shift")
            shiftButton?.isActive = shiftActive
            shiftButton?.setSymbol(shiftActive ? "shift.fill" : "shift")
            applyPaletteToButtons()
            applyDeckState()
        }
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
    var onShiftToggle: (() -> Void)?
    var onArrow: ((Arrow) -> Void)?
    var onDelete: (() -> Void)?
    var onInsertText: ((String) -> Void)?
    var onMoveHome: (() -> Void)?
    var onMoveEnd: (() -> Void)?
    var onPageUp: (() -> Void)?
    var onPageDown: (() -> Void)?
    var onFind: (() -> Void)?
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

    private let deckContainer = UIView()
    private let deckModifierStack = UIStackView()
    private let deckBodyStack = UIStackView()
    private let deckLeftRail = UIStackView()
    private let deckGrid = UIStackView()
    private let deckRightRail = UIStackView()
    private let deckHandle = UIView()
    private var deckPage: DeckPage = .navigation
    private var deckButtons: [DeckKeyButton] = []
    private var deckButtonRecords: [(DeckAction, DeckKeyButton)] = []
    private var deckCtrlActive = false
    private var deckAltActive = false

    // Static "virtual D-pad" cluster pinned to the leading edge. Always
    // visible regardless of accessoryRows, scrolling, or whatever the rest
    // of the bar is up to. 3 columns × 2 rows:
    //   top: [Shift] [↑]  [Delete]
    //   bot: [ ←  ] [↓]  [  →   ]
    private let clusterContainer = UIView()
    private let clusterDivider = UIView()
    private let clusterShift: KbButton
    private let clusterUp: KbHoldButton
    private let clusterDelete: KbHoldButton
    private let clusterLeft: KbHoldButton
    private let clusterDown: KbHoldButton
    private let clusterRight: KbHoldButton
    private var clusterWidthConstraint: NSLayoutConstraint?
    private var clusterDividerWidthConstraint: NSLayoutConstraint?

    private var palette: Palette = .light

    // Button references we toggle in the scrolling part.
    private weak var readButton: KbButton?
    private weak var undoButton: KbButton?
    private weak var redoButton: KbButton?
    private weak var cutButton: KbButton?
    private weak var findButton: KbButton?
    private weak var shiftButton: KbButton?
    private weak var compareButton: KbButton?

    private var allButtons: [KbButton] = []
    private var allSeparators: [UIView] = []

    // MARK: - Init

    override init(frame: CGRect) {
        // Cluster buttons are owned by self; built here so we can store strong
        // references that survive `rebuildLayout()` (the cluster never rebuilds).
        clusterShift  = KbButton(symbol: "shift", label: "Shift") { }
        clusterUp     = KbHoldButton(symbol: "arrow.up", label: "Up") { }
        clusterDelete = KbHoldButton(symbol: "delete.left", label: "Delete") { }
        clusterLeft   = KbHoldButton(symbol: "arrow.left", label: "Left") { }
        clusterDown   = KbHoldButton(symbol: "arrow.down", label: "Down") { }
        clusterRight  = KbHoldButton(symbol: "arrow.right", label: "Right") { }
        super.init(frame: frame)
        autoresizingMask = [.flexibleWidth]
        setupBase()
        setupDeck()
        wireClusterCallbacks()
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

        // Build the 3×2 cluster.
        clusterContainer.translatesAutoresizingMaskIntoConstraints = false
        addSubview(clusterContainer)

        let topCluster = UIStackView(arrangedSubviews: [clusterShift, clusterUp, clusterDelete])
        let botCluster = UIStackView(arrangedSubviews: [clusterLeft, clusterDown, clusterRight])
        for st in [topCluster, botCluster] {
            st.translatesAutoresizingMaskIntoConstraints = false
            st.axis = .horizontal
            st.alignment = .center
            st.distribution = .fillEqually
            st.spacing = 2
        }
        clusterContainer.addSubview(topCluster)
        clusterContainer.addSubview(botCluster)

        clusterDivider.translatesAutoresizingMaskIntoConstraints = false
        addSubview(clusterDivider)

        let clusterWidth = clusterContainer.widthAnchor.constraint(equalToConstant: 132)
        let dividerWidth = clusterDivider.widthAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale)
        clusterWidthConstraint = clusterWidth
        clusterDividerWidthConstraint = dividerWidth

        NSLayoutConstraint.activate([
            topBorder.topAnchor.constraint(equalTo: topAnchor),
            topBorder.leadingAnchor.constraint(equalTo: leadingAnchor),
            topBorder.trailingAnchor.constraint(equalTo: trailingAnchor),
            topBorder.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale),

            // Cluster — fixed 132pt wide, fills the bar's height.
            clusterContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            clusterContainer.topAnchor.constraint(equalTo: topAnchor, constant: 2),
            clusterContainer.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2),
            clusterWidth,

            // Vertical divider between cluster and the scrolling part.
            clusterDivider.leadingAnchor.constraint(equalTo: clusterContainer.trailingAnchor, constant: 4),
            clusterDivider.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            clusterDivider.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
            dividerWidth,

            topCluster.topAnchor.constraint(equalTo: clusterContainer.topAnchor),
            topCluster.leadingAnchor.constraint(equalTo: clusterContainer.leadingAnchor),
            topCluster.trailingAnchor.constraint(equalTo: clusterContainer.trailingAnchor),
            topCluster.heightAnchor.constraint(equalTo: clusterContainer.heightAnchor, multiplier: 0.5, constant: -1),

            botCluster.topAnchor.constraint(equalTo: topCluster.bottomAnchor, constant: 2),
            botCluster.leadingAnchor.constraint(equalTo: clusterContainer.leadingAnchor),
            botCluster.trailingAnchor.constraint(equalTo: clusterContainer.trailingAnchor),
            botCluster.bottomAnchor.constraint(equalTo: clusterContainer.bottomAnchor),
        ])
        updateStaticClusterVisibility()
    }

    private func setupDeck() {
        deckContainer.translatesAutoresizingMaskIntoConstraints = false
        deckContainer.layer.masksToBounds = true
        addSubview(deckContainer)

        deckModifierStack.translatesAutoresizingMaskIntoConstraints = false
        deckModifierStack.axis = .horizontal
        deckModifierStack.alignment = .fill
        deckModifierStack.distribution = .fillEqually
        deckModifierStack.spacing = 8

        deckBodyStack.translatesAutoresizingMaskIntoConstraints = false
        deckBodyStack.axis = .horizontal
        deckBodyStack.alignment = .fill
        deckBodyStack.distribution = .fill
        deckBodyStack.spacing = 8

        deckLeftRail.translatesAutoresizingMaskIntoConstraints = false
        deckLeftRail.axis = .vertical
        deckLeftRail.alignment = .fill
        deckLeftRail.distribution = .fillEqually
        deckLeftRail.spacing = 8

        deckGrid.translatesAutoresizingMaskIntoConstraints = false
        deckGrid.axis = .vertical
        deckGrid.alignment = .fill
        deckGrid.distribution = .fillEqually
        deckGrid.spacing = 8

        deckRightRail.translatesAutoresizingMaskIntoConstraints = false
        deckRightRail.axis = .vertical
        deckRightRail.alignment = .fill
        deckRightRail.distribution = .fill
        deckRightRail.spacing = 8

        deckHandle.translatesAutoresizingMaskIntoConstraints = false
        deckHandle.layer.cornerRadius = 2

        deckContainer.addSubview(deckModifierStack)
        deckContainer.addSubview(deckBodyStack)
        deckContainer.addSubview(deckHandle)
        deckBodyStack.addArrangedSubview(deckLeftRail)
        deckBodyStack.addArrangedSubview(deckGrid)
        deckBodyStack.addArrangedSubview(deckRightRail)

        let leftWidth = deckLeftRail.widthAnchor.constraint(equalToConstant: 48)
        let rightWidth = deckRightRail.widthAnchor.constraint(equalToConstant: 64)
        leftWidth.priority = .required
        rightWidth.priority = .required

        NSLayoutConstraint.activate([
            deckContainer.topAnchor.constraint(equalTo: topAnchor),
            deckContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            deckContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
            deckContainer.bottomAnchor.constraint(equalTo: bottomAnchor),

            deckModifierStack.topAnchor.constraint(equalTo: deckContainer.topAnchor, constant: 10),
            deckModifierStack.leadingAnchor.constraint(equalTo: deckContainer.leadingAnchor, constant: 12),
            deckModifierStack.trailingAnchor.constraint(equalTo: deckContainer.trailingAnchor, constant: -12),
            deckModifierStack.heightAnchor.constraint(equalToConstant: 50),

            deckBodyStack.topAnchor.constraint(equalTo: deckModifierStack.bottomAnchor, constant: 10),
            deckBodyStack.leadingAnchor.constraint(equalTo: deckContainer.leadingAnchor, constant: 12),
            deckBodyStack.trailingAnchor.constraint(equalTo: deckContainer.trailingAnchor, constant: -12),
            deckBodyStack.bottomAnchor.constraint(equalTo: deckHandle.topAnchor, constant: -10),

            leftWidth,
            rightWidth,

            deckHandle.centerXAnchor.constraint(equalTo: deckContainer.centerXAnchor),
            deckHandle.bottomAnchor.constraint(equalTo: deckContainer.bottomAnchor, constant: -8),
            deckHandle.widthAnchor.constraint(equalToConstant: 120),
            deckHandle.heightAnchor.constraint(equalToConstant: 5),
        ])

        let leftSwipe = UISwipeGestureRecognizer(target: self, action: #selector(nextDeckPageGesture))
        leftSwipe.direction = .left
        deckContainer.addGestureRecognizer(leftSwipe)
        let rightSwipe = UISwipeGestureRecognizer(target: self, action: #selector(previousDeckPageGesture))
        rightSwipe.direction = .right
        deckContainer.addGestureRecognizer(rightSwipe)
    }

    private func wireClusterCallbacks() {
        clusterShift.onTap  = { [weak self] in self?.onShiftToggle?() }
        clusterUp.tickHandler     = { [weak self] in self?.onArrow?(.up) }
        clusterDelete.tickHandler = { [weak self] in self?.onDelete?() }
        clusterLeft.tickHandler   = { [weak self] in self?.onArrow?(.left) }
        clusterDown.tickHandler   = { [weak self] in self?.onArrow?(.down) }
        clusterRight.tickHandler  = { [weak self] in self?.onArrow?(.right) }
    }

    private var staticClusterButtonIds: Set<AccessoryToolbarButton> {
        Set(AccessoryToolbarButton.staticCandidates)
    }

    private func isPinnedToStaticCluster(_ button: AccessoryToolbarButton) -> Bool {
        staticClusterButtonIds.contains(button) && staticButtons.contains(button) && !hiddenButtons.contains(button)
    }

    private func isAvailableInScrollingToolbar(_ button: AccessoryToolbarButton) -> Bool {
        !hiddenButtons.contains(button) && !isPinnedToStaticCluster(button)
    }

    private func updateStaticClusterVisibility() {
        let clusterPairs: [(AccessoryToolbarButton, UIView)] = [
            (.shift, clusterShift),
            (.moveUp, clusterUp),
            (.deleteBackward, clusterDelete),
            (.moveLeft, clusterLeft),
            (.moveDown, clusterDown),
            (.moveRight, clusterRight),
        ]
        var anyVisible = false
        for (button, view) in clusterPairs {
            let visible = isPinnedToStaticCluster(button)
            view.isHidden = !visible
            anyVisible = anyVisible || visible
        }
        clusterContainer.isHidden = !anyVisible
        clusterDivider.isHidden = !anyVisible
        clusterWidthConstraint?.constant = anyVisible ? 132 : 0
        clusterDividerWidthConstraint?.constant = anyVisible ? (1 / UIScreen.main.scale) : 0
    }

    // MARK: - Intrinsic size

    var preferredHeight: CGFloat { intrinsicContentSize.height }

    override var intrinsicContentSize: CGSize {
        if usesKeyboardDeck {
            return CGSize(width: UIView.noIntrinsicMetric, height: 318)
        }
        // The static cluster is two rows tall even when the scrolling toolbar
        // is single-row. Grow for Large buttons so controls do not clip.
        return CGSize(width: UIView.noIntrinsicMetric, height: max(88, accessoryRowHeight * 2))
    }

    // MARK: - Layout

    private var activeConstraints: [NSLayoutConstraint] = []

    private func rebuildLayout() {
        if usesKeyboardDeck {
            installDeckLayout()
            return
        }

        deckContainer.isHidden = true
        topScroll.isHidden = false
        updateStaticClusterVisibility()
        // Tear down existing button subviews / constraints.
        NSLayoutConstraint.deactivate(activeConstraints)
        activeConstraints.removeAll()
        topStack.arrangedSubviews.forEach { topStack.removeArrangedSubview($0); $0.removeFromSuperview() }
        bottomStack.arrangedSubviews.forEach { bottomStack.removeArrangedSubview($0); $0.removeFromSuperview() }
        allButtons.removeAll()
        allSeparators.removeAll()
        readButton = nil; undoButton = nil; redoButton = nil; cutButton = nil
        findButton = nil; shiftButton = nil; compareButton = nil

        // Build the full ordered list of items.
        let items = makeItems()

        // Split across rows if requested.
        // Scrolling part starts after the cluster + divider.
        let scrollLeading = clusterDivider.trailingAnchor

        let rowHeight = accessoryRowHeight
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
                topScroll.leadingAnchor.constraint(equalTo: scrollLeading, constant: 4),
                topScroll.trailingAnchor.constraint(equalTo: trailingAnchor),
                topScroll.heightAnchor.constraint(equalToConstant: rowHeight),

                middleBorder.topAnchor.constraint(equalTo: topScroll.bottomAnchor),
                middleBorder.leadingAnchor.constraint(equalTo: scrollLeading, constant: 4),
                middleBorder.trailingAnchor.constraint(equalTo: trailingAnchor),
                middleBorder.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale),

                bottomScroll.topAnchor.constraint(equalTo: middleBorder.bottomAnchor),
                bottomScroll.leadingAnchor.constraint(equalTo: scrollLeading, constant: 4),
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

            // Single-row scrolling part is vertically centered next to the
            // two-row cluster, leaving the other half empty.
            activeConstraints = [
                topScroll.centerYAnchor.constraint(equalTo: centerYAnchor),
                topScroll.heightAnchor.constraint(equalToConstant: rowHeight),
                topScroll.leadingAnchor.constraint(equalTo: scrollLeading, constant: 4),
                topScroll.trailingAnchor.constraint(equalTo: trailingAnchor),

                topStack.topAnchor.constraint(equalTo: topScroll.contentLayoutGuide.topAnchor, constant: 4),
                topStack.leadingAnchor.constraint(equalTo: topScroll.contentLayoutGuide.leadingAnchor, constant: 4),
                topStack.trailingAnchor.constraint(equalTo: topScroll.contentLayoutGuide.trailingAnchor, constant: -4),
                topStack.bottomAnchor.constraint(equalTo: topScroll.contentLayoutGuide.bottomAnchor, constant: -4),
                topStack.heightAnchor.constraint(equalTo: topScroll.frameLayoutGuide.heightAnchor, constant: -8),
            ]
        }
        NSLayoutConstraint.activate(activeConstraints)
        invalidateIntrinsicContentSize()
        applyDisplayOptionsToButtons()
        applyPaletteToButtons()
    }

    private func installDeckLayout() {
        NSLayoutConstraint.deactivate(activeConstraints)
        activeConstraints.removeAll()

        topScroll.isHidden = true
        bottomScroll.isHidden = true
        middleBorder.isHidden = true
        clusterContainer.isHidden = true
        clusterDivider.isHidden = true
        deckContainer.isHidden = false

        clearArrangedSubviews(deckModifierStack)
        clearArrangedSubviews(deckLeftRail)
        clearArrangedSubviews(deckGrid)
        clearArrangedSubviews(deckRightRail)
        deckButtons.removeAll()
        deckButtonRecords.removeAll()

        installDeckModifierStrip()
        installDeckRails()
        installDeckGrid(page: deckPage)

        invalidateIntrinsicContentSize()
        applyDeckState()
    }

    private func clearArrangedSubviews(_ stack: UIStackView) {
        stack.arrangedSubviews.forEach {
            stack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
    }

    private func installDeckModifierStrip() {
        let specs: [DeckKeySpec] = [
            DeckKeySpec(.openDocuments, title: "Tabs", symbol: "rectangle.on.rectangle"),
            DeckKeySpec(.hideKeyboard, title: "esc"),
            DeckKeySpec(.shift, title: "shift"),
            DeckKeySpec(.ctrl, title: "ctrl"),
            DeckKeySpec(.alt, title: "alt"),
            DeckKeySpec(.enter, title: "enter"),
        ]
        specs.map(makeDeckButton).forEach { deckModifierStack.addArrangedSubview($0) }
    }

    private func installDeckRails() {
        let leftSpecs: [DeckKeySpec] = [
            DeckKeySpec(.copy, symbol: "doc.on.doc"),
            DeckKeySpec(.cut, symbol: "scissors"),
            DeckKeySpec(.paste, symbol: "doc.on.clipboard"),
            DeckKeySpec(.switchDeck, visualText: deckPageDots()),
        ]
        leftSpecs.map(makeDeckButton).forEach { deckLeftRail.addArrangedSubview($0) }

        let backspace = makeDeckButton(DeckKeySpec(.backspace, symbol: "delete.left.fill", hold: true))
        deckRightRail.addArrangedSubview(backspace)
        backspace.heightAnchor.constraint(equalToConstant: 58).isActive = true

        let spacer = UIView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        deckRightRail.addArrangedSubview(spacer)

        let enter = makeDeckButton(DeckKeySpec(.enter, title: "Enter"))
        deckRightRail.addArrangedSubview(enter)
        enter.heightAnchor.constraint(greaterThanOrEqualToConstant: 108).isActive = true
    }

    private func installDeckGrid(page: DeckPage) {
        let rows = deckRows(for: page)
        for row in rows {
            let stack = UIStackView()
            stack.translatesAutoresizingMaskIntoConstraints = false
            stack.axis = .horizontal
            stack.alignment = .fill
            stack.distribution = .fillEqually
            stack.spacing = 8
            row.map(makeDeckButton).forEach { stack.addArrangedSubview($0) }
            deckGrid.addArrangedSubview(stack)
        }
    }

    private func deckRows(for page: DeckPage) -> [[DeckKeySpec]] {
        switch page {
        case .edit:
            return [
                [
                    DeckKeySpec(.undo, symbol: "arrow.uturn.backward"),
                    DeckKeySpec(.redo, symbol: "arrow.uturn.forward"),
                    DeckKeySpec(.find, symbol: "magnifyingglass"),
                ],
                [
                    DeckKeySpec(.selectWord, title: "Word"),
                    DeckKeySpec(.selectLine, title: "Line"),
                    DeckKeySpec(.selectAll, title: "All"),
                ],
                [
                    DeckKeySpec(.insertDate, symbol: "clock"),
                    DeckKeySpec(.openDocuments, symbol: "folder"),
                    DeckKeySpec(.readMode, symbol: readMode ? "eye" : "eye.slash"),
                ],
                [
                    DeckKeySpec(.compare, symbol: "rectangle.split.1x2"),
                    DeckKeySpec(.more, symbol: "ellipsis"),
                    DeckKeySpec(.hideKeyboard, title: usesKeyboardDeck ? "ABC" : "Hide", symbol: "keyboard"),
                ],
            ]
        case .navigation:
            return [
                [
                    DeckKeySpec(.home, title: "Home", hold: true),
                    DeckKeySpec(.moveUp, symbol: "chevron.up", hold: true),
                    DeckKeySpec(.pageUp, title: "Pg Up", hold: true),
                ],
                [
                    DeckKeySpec(.end, title: "End", hold: true),
                    DeckKeySpec(.moveDown, symbol: "chevron.down", hold: true),
                    DeckKeySpec(.pageDown, title: "Pg Dn", hold: true),
                ],
                [
                    DeckKeySpec(.moveLeft, symbol: "chevron.left", hold: true),
                    DeckKeySpec(.moveRight, symbol: "chevron.right", hold: true),
                    DeckKeySpec(.tab, title: "Tab"),
                ],
            ]
        case .numeric:
            return [
                [
                    DeckKeySpec(.insertText("/"), title: "/", dark: true),
                    DeckKeySpec(.insertText("7"), title: "7", dark: true),
                    DeckKeySpec(.insertText("8"), title: "8", dark: true),
                    DeckKeySpec(.insertText("9"), title: "9", dark: true),
                ],
                [
                    DeckKeySpec(.insertText("*"), title: "*", dark: true),
                    DeckKeySpec(.insertText("4"), title: "4", dark: true),
                    DeckKeySpec(.insertText("5"), title: "5", dark: true),
                    DeckKeySpec(.insertText("6"), title: "6", dark: true),
                ],
                [
                    DeckKeySpec(.insertText("-"), title: "-", dark: true),
                    DeckKeySpec(.insertText("1"), title: "1", dark: true),
                    DeckKeySpec(.insertText("2"), title: "2", dark: true),
                    DeckKeySpec(.insertText("3"), title: "3", dark: true),
                ],
                [
                    DeckKeySpec(.insertText("+"), title: "+", dark: true),
                    DeckKeySpec(.insertText("0"), title: "0", dark: true),
                    DeckKeySpec(.insertText("."), title: ".", dark: true),
                    DeckKeySpec(.inert, title: "", dark: true),
                ],
            ]
        }
    }

    private func makeDeckButton(_ spec: DeckKeySpec) -> DeckKeyButton {
        let button = DeckKeyButton(
            title: spec.title,
            symbol: spec.symbol,
            visualText: spec.visualText,
            isHoldable: spec.isHoldable,
            isDarkKey: spec.isDarkKey
        ) { [weak self] in
            self?.performDeckAction(spec.action)
        }
        deckButtons.append(button)
        deckButtonRecords.append((spec.action, button))
        return button
    }

    private func performDeckAction(_ action: DeckAction) {
        guard !isDeckActionDisabled(action) else { return }
        switch action {
        case .openDocuments: onOpenDocs?()
        case .hideKeyboard: onHide?()
        case .shift: onShiftToggle?()
        case .ctrl:
            deckCtrlActive.toggle()
            applyDeckState()
        case .alt:
            deckAltActive.toggle()
            applyDeckState()
        case .enter: onInsertText?("\n")
        case .copy: onCopy?()
        case .cut: onCut?()
        case .paste: onPaste?()
        case .switchDeck: nextDeckPage()
        case .backspace: onDelete?()
        case .undo: onUndo?()
        case .redo: onRedo?()
        case .find: onFind?()
        case .selectWord: onSelectWord?()
        case .selectLine: onSelectLine?()
        case .selectAll: onSelectAll?()
        case .insertDate: onInsertDate?()
        case .readMode: onReadToggle?()
        case .compare: onCompare?()
        case .more: onMore?()
        case .home: onMoveHome?()
        case .end: onMoveEnd?()
        case .pageUp: onPageUp?()
        case .pageDown: onPageDown?()
        case .moveLeft: onArrow?(.left)
        case .moveUp: onArrow?(.up)
        case .moveDown: onArrow?(.down)
        case .moveRight: onArrow?(.right)
        case .tab: onInsertText?("\t")
        case .insertText(let value): onInsertText?(value)
        case .inert: break
        }
    }

    private func isDeckActionDisabled(_ action: DeckAction) -> Bool {
        switch action {
        case .cut:
            return readMode || !hasSelection
        case .copy:
            return !hasSelection
        case .paste, .backspace, .insertDate, .tab, .enter, .insertText(_):
            return readMode
        case .undo:
            return readMode || !canUndo
        case .redo:
            return readMode || !canRedo
        case .inert:
            return true
        default:
            return false
        }
    }

    private func isDeckActionActive(_ action: DeckAction) -> Bool {
        switch action {
        case .shift: return shiftActive
        case .ctrl: return deckCtrlActive
        case .alt: return deckAltActive
        case .readMode: return readMode
        case .find: return findActive
        case .compare: return compareActive
        default: return false
        }
    }

    private func applyDeckState() {
        guard usesKeyboardDeck else { return }
        deckContainer.backgroundColor = UIColor(white: 0.22, alpha: 1)
        deckHandle.backgroundColor = UIColor(white: 0.76, alpha: 1)
        topBorder.backgroundColor = UIColor(white: 0.14, alpha: 1)
        for (action, button) in deckButtonRecords {
            button.isDisabled = isDeckActionDisabled(action)
            button.isActive = isDeckActionActive(action)
            button.applyDeckStyle()
        }
    }

    private func deckPageDots() -> String {
        switch deckPage {
        case .navigation: return "•··"
        case .edit: return "·•·"
        case .numeric: return "··•"
        }
    }

    @objc private func nextDeckPageGesture() {
        nextDeckPage()
    }

    @objc private func previousDeckPageGesture() {
        previousDeckPage()
    }

    private func nextDeckPage() {
        let nextIndex = (deckPage.rawValue + 1) % DeckPage.allCases.count
        setDeckPage(DeckPage(rawValue: nextIndex) ?? .navigation, animated: true)
    }

    private func previousDeckPage() {
        let nextIndex = (deckPage.rawValue + DeckPage.allCases.count - 1) % DeckPage.allCases.count
        setDeckPage(DeckPage(rawValue: nextIndex) ?? .navigation, animated: true)
    }

    private func setDeckPage(_ page: DeckPage, animated: Bool) {
        deckPage = page
        guard animated, usesKeyboardDeck, window != nil else {
            installDeckLayout()
            return
        }
        UIView.transition(
            with: deckContainer,
            duration: 0.16,
            options: [.transitionCrossDissolve, .allowUserInteraction, .beginFromCurrentState]
        ) {
            self.installDeckLayout()
        }
    }

    private var accessoryRowHeight: CGFloat {
        switch buttonSize {
        case .small: return 40
        case .medium: return 44
        case .large: return 52
        }
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
                b.configureDisplay(size: buttonSize, contentMode: accessoryContentMode)
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
        let hide = KbButton(symbol: "keyboard", label: "Hide") { [weak self] in self?.onHide?() }
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

        let find = KbButton(symbol: "magnifyingglass", label: "Find") { [weak self] in self?.onFind?() }
        find.isActive = findActive
        findButton = find

        let date = KbButton(symbol: "clock", label: "Date") { [weak self] in self?.onInsertDate?() }
        let open = KbButton(symbol: "folder", label: "Open") { [weak self] in self?.onOpenDocs?() }
        let compare = KbButton(symbol: "rectangle.split.1x2", label: "Compare") { [weak self] in self?.onCompare?() }
        compare.isActive = compareActive
        compareButton = compare
        let more = KbButton(symbol: "ellipsis", label: "More") { [weak self] in self?.onMore?() }

        let shift = KbButton(symbol: shiftActive ? "shift.fill" : "shift", label: "Shift") { [weak self] in self?.onShiftToggle?() }
        shift.isActive = shiftActive
        shiftButton = shift
        let up = KbHoldButton(symbol: "arrow.up", label: "Up") { [weak self] in self?.onArrow?(.up) }
        let delete = KbHoldButton(symbol: "delete.left", label: "Delete") { [weak self] in self?.onDelete?() }
        let left = KbHoldButton(symbol: "arrow.left", label: "Left") { [weak self] in self?.onArrow?(.left) }
        let down = KbHoldButton(symbol: "arrow.down", label: "Down") { [weak self] in self?.onArrow?(.down) }
        let right = KbHoldButton(symbol: "arrow.right", label: "Right") { [weak self] in self?.onArrow?(.right) }

        func buttonItem(_ id: AccessoryToolbarButton, _ button: KbButton) -> Item? {
            isAvailableInScrollingToolbar(id) ? .button(button) : nil
        }

        var result: [Item] = []
        func appendGroup(_ items: [Item?]) {
            let visible = items.compactMap { $0 }
            guard !visible.isEmpty else { return }
            if !result.isEmpty { result.append(.separator) }
            result.append(contentsOf: visible)
        }

        // Arrow keys, Shift, and Delete now live in the static cluster on the
        // leading edge by default. If the user unpins one, it drops back into
        // this scrolling list instead of disappearing.
        appendGroup([buttonItem(.hideKeyboard, hide)])
        appendGroup([
            buttonItem(.shift, shift),
            buttonItem(.moveUp, up),
            buttonItem(.deleteBackward, delete),
            buttonItem(.moveLeft, left),
            buttonItem(.moveDown, down),
            buttonItem(.moveRight, right),
        ])
        appendGroup([buttonItem(.cut, cut), buttonItem(.copy, copy), buttonItem(.paste, paste)])
        appendGroup([buttonItem(.selectWord, word), buttonItem(.selectLine, line), buttonItem(.selectAll, all)])
        appendGroup([buttonItem(.undo, undo), buttonItem(.redo, redo)])
        appendGroup([buttonItem(.readMode, read), buttonItem(.find, find)])
        appendGroup([
            buttonItem(.insertDate, date),
            buttonItem(.openDocuments, open),
            buttonItem(.compare, compare),
            buttonItem(.more, more),
        ])
        return result
    }

    // MARK: - Palette

    func applyPalette(_ p: Palette) {
        palette = p
        backgroundColor = p.card
        topBorder.backgroundColor = p.border
        middleBorder.backgroundColor = p.border
        clusterDivider.backgroundColor = p.border
        applyPaletteToButtons()
        applyDeckState()
    }

    private func applyDisplayOptionsToButtons() {
        for btn in allButtons {
            btn.configureDisplay(size: buttonSize, contentMode: accessoryContentMode)
        }
        for btn in [clusterShift, clusterUp, clusterDelete, clusterLeft, clusterDown, clusterRight] {
            btn.configureDisplay(size: buttonSize, contentMode: accessoryContentMode)
        }
        invalidateIntrinsicContentSize()
    }

    private func applyPaletteToButtons() {
        for btn in allButtons {
            btn.applyPalette(palette)
        }
        for sep in allSeparators {
            sep.backgroundColor = palette.border
        }
        // Cluster buttons live outside `allButtons` (they're never rebuilt).
        for btn in [clusterShift, clusterUp, clusterDelete, clusterLeft, clusterDown, clusterRight] {
            btn.applyPalette(palette)
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
    private let contentStack = UIStackView()
    private var minWidthConstraint: NSLayoutConstraint?
    private var minHeightConstraint: NSLayoutConstraint?
    private var currentSize: AccessoryToolbarButtonSize = .medium
    private var currentContentMode: AccessoryToolbarContentMode = .iconAndText
    private var displayedSymbolName: String

    init(symbol: String, label: String? = nil, onTap: @escaping () -> Void) {
        self.symbolName = symbol
        self.label = label
        self.onTap = onTap
        self.displayedSymbolName = symbol
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

        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .vertical
        contentStack.alignment = .center
        contentStack.distribution = .fill
        contentStack.spacing = 1
        addSubview(contentStack)

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.image = UIImage(systemName: symbolName,
                                  withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .regular))
        contentStack.addArrangedSubview(imageView)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 9, weight: .medium)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 1
        titleLabel.text = label
        contentStack.addArrangedSubview(titleLabel)

        let minWidth = widthAnchor.constraint(greaterThanOrEqualToConstant: 44)
        let minHeight = heightAnchor.constraint(greaterThanOrEqualToConstant: 34)
        minWidthConstraint = minWidth
        minHeightConstraint = minHeight
        NSLayoutConstraint.activate([
            minWidth,
            minHeight,
            contentStack.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: 3),
            contentStack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 4),
            contentStack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -4),
            contentStack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -3),
            contentStack.centerXAnchor.constraint(equalTo: centerXAnchor),
            contentStack.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        addTarget(self, action: #selector(tapped), for: .touchUpInside)
        configureDisplay(size: .medium, contentMode: .iconAndText)
    }

    func setSymbol(_ name: String) {
        displayedSymbolName = name
        imageView.image = UIImage(systemName: name,
                                  withConfiguration: UIImage.SymbolConfiguration(pointSize: symbolPointSize(for: currentSize), weight: .regular))
    }

    func configureDisplay(size: AccessoryToolbarButtonSize, contentMode: AccessoryToolbarContentMode) {
        currentSize = size
        currentContentMode = contentMode
        minWidthConstraint?.constant = minWidth(for: size)
        minHeightConstraint?.constant = minHeight(for: size)
        imageView.image = UIImage(
            systemName: displayedSymbolName,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: symbolPointSize(for: size), weight: .regular)
        )
        titleLabel.font = .systemFont(ofSize: fontSize(for: size), weight: .medium)

        let hasText = !(label ?? "").isEmpty
        switch contentMode {
        case .iconAndText:
            imageView.isHidden = false
            titleLabel.isHidden = !hasText
        case .iconOnly:
            imageView.isHidden = false
            titleLabel.isHidden = true
        case .textOnly:
            imageView.isHidden = true
            titleLabel.isHidden = !hasText
        }
    }

    private func minWidth(for size: AccessoryToolbarButtonSize) -> CGFloat {
        switch size {
        case .small: return 34
        case .medium: return 44
        case .large: return 58
        }
    }

    private func minHeight(for size: AccessoryToolbarButtonSize) -> CGFloat {
        switch size {
        case .small: return 30
        case .medium: return 34
        case .large: return 42
        }
    }

    private func symbolPointSize(for size: AccessoryToolbarButtonSize) -> CGFloat {
        switch size {
        case .small: return 15
        case .medium: return 18
        case .large: return 22
        }
    }

    private func fontSize(for size: AccessoryToolbarButtonSize) -> CGFloat {
        switch size {
        case .small: return 8
        case .medium: return 9
        case .large: return 11
        }
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
    var tickHandler: () -> Void

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

// MARK: - DeckKeyButton

private final class DeckKeyButton: UIControl {
    var isActive: Bool = false
    var isDisabled: Bool = false {
        didSet { isEnabled = !isDisabled }
    }

    private let action: () -> Void
    private let isHoldable: Bool
    private let isDarkKey: Bool
    private let imageView = UIImageView()
    private let titleLabel = UILabel()
    private let stack = UIStackView()
    private var initialDelayTimer: Timer?
    private var holdTimer: Timer?
    private var repeatCount = 0

    init(
        title: String?,
        symbol: String?,
        visualText: String?,
        isHoldable: Bool,
        isDarkKey: Bool,
        action: @escaping () -> Void
    ) {
        self.action = action
        self.isHoldable = isHoldable
        self.isDarkKey = isDarkKey
        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false
        layer.cornerRadius = 12
        layer.borderWidth = 1
        clipsToBounds = true
        isAccessibilityElement = true
        accessibilityTraits = .button
        accessibilityLabel = title ?? visualText ?? symbol ?? "Key"

        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.alignment = .center
        stack.distribution = .fill
        stack.spacing = 2
        addSubview(stack)

        if let symbol {
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.contentMode = .scaleAspectFit
            imageView.image = UIImage(
                systemName: symbol,
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold)
            )
            stack.addArrangedSubview(imageView)
        }

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: visualText == nil ? 19 : 22, weight: .semibold)
        titleLabel.textAlignment = .center
        titleLabel.text = visualText ?? title
        titleLabel.numberOfLines = 1
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.72
        if titleLabel.text?.isEmpty == false {
            stack.addArrangedSubview(titleLabel)
        }

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: 4),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -4),
            heightAnchor.constraint(greaterThanOrEqualToConstant: 46),
        ])

        if isHoldable {
            addTarget(self, action: #selector(pressDown), for: .touchDown)
            addTarget(self, action: #selector(pressUp), for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])
        } else {
            addTarget(self, action: #selector(tapped), for: .touchUpInside)
        }
        applyDeckStyle()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    func applyDeckStyle() {
        let base = isDarkKey ? UIColor(white: 0.07, alpha: 1) : UIColor(white: 0.20, alpha: 1)
        let active = UIColor(red: 0.23, green: 0.43, blue: 0.70, alpha: 1)
        let highlighted = UIColor(white: 0.28, alpha: 1)
        backgroundColor = isActive ? active : (isHighlighted ? highlighted : base)
        layer.borderColor = UIColor(white: isActive ? 0.48 : 0.27, alpha: 1).cgColor
        let text = isDisabled ? UIColor(white: 0.62, alpha: 1) : UIColor.white
        titleLabel.textColor = text
        imageView.tintColor = text
        alpha = isDisabled ? 0.38 : 1.0
    }

    @objc private func tapped() {
        guard !isDisabled else { return }
        action()
    }

    @objc private func pressDown() {
        guard !isDisabled else { return }
        action()
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
            guard let self, !self.isDisabled else { return }
            self.action()
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

    override var isHighlighted: Bool {
        didSet { applyDeckStyle() }
    }

    deinit {
        stopAllTimers()
    }
}
