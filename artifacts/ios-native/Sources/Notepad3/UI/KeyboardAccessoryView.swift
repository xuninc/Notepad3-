import UIKit

/// Classic-mode bottom toolbar. It follows the keyboard when shown, remains
/// visible when the keyboard is hidden, and mirrors the native Android toolbar:
/// fixed editing keys on the left, scrollable actions on the right.
/// When `rows == .double`, scrolling items are split across two stacked rows.
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
    var keyboardHidden: Bool = false {
        didSet {
            hideButton?.isActive = keyboardHidden
            hideButton?.setSymbol(keyboardHidden ? "keyboard" : "keyboard.chevron.compact.down")
            hideButton?.setTitle(keyboardHidden ? "Show" : "Hide")
            applyPaletteToButtons()
        }
    }
    var readMode: Bool = false {
        didSet { readButton?.setSymbol(readMode ? "eye" : "eye.slash"); readButton?.isActive = readMode; applyPaletteToButtons() }
    }
    var canUndo: Bool = true {
        didSet { updateUndoRedoEnabled() }
    }
    var canRedo: Bool = true {
        didSet { updateUndoRedoEnabled() }
    }
    var hasSelection: Bool = false {
        didSet { cutButton?.isDisabled = !hasSelection; applyPaletteToButtons() }
    }
    var findActive: Bool = false {
        didSet { findButton?.isActive = findActive; applyPaletteToButtons() }
    }
    var compareActive: Bool = false {
        didSet { compareButton?.isActive = compareActive; applyPaletteToButtons() }
    }
    var shiftActive: Bool = false {
        didSet {
            clusterShift.isActive = shiftActive
            clusterShift.setSymbol(shiftActive ? "shift.fill" : "shift")
            shiftButton?.isActive = shiftActive
            shiftButton?.setSymbol(shiftActive ? "shift.fill" : "shift")
            applyPaletteToButtons()
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
    var onEnter: (() -> Void)?
    var onTab: (() -> Void)?
    var onHome: (() -> Void)?
    var onEnd: (() -> Void)?
    var onPageUp: (() -> Void)?
    var onPageDown: (() -> Void)?
    var onInsertText: ((String) -> Void)?
    var onBonusKeysVisibilityChange: ((Bool) -> Void)?
    var onPreferredHeightChange: (() -> Void)?
    var onFind: (() -> Void)?
    var onInsertDate: (() -> Void)?
    var onOpenDocs: (() -> Void)?
    var onCompare: (() -> Void)?
    var onMore: (() -> Void)?
    var onDuplicateLine: (() -> Void)?
    var onDeleteLine: (() -> Void)?
    var onSortLines: (() -> Void)?
    var onTrimSpaces: (() -> Void)?
    var onGotoLine: (() -> Void)?

    // MARK: - Subviews

    private let topScroll = AccessoryToolbarScrollView()
    private let bottomScroll = AccessoryToolbarScrollView()
    private let topStack = UIStackView()
    private let bottomStack = UIStackView()
    private let topBorder = UIView()
    private let middleBorder = UIView()
    private let modeSwitchButton: KbButton

    // Static "virtual D-pad" cluster pinned to the leading edge. Always
    // visible regardless of accessoryRows, scrolling, or whatever the rest
    // of the bar is up to. Undo/Redo is a separate fixed button after the
    // divider so it has room and does not sit under the arrow-key thumb path.
    private let clusterContainer = UIView()
    private let clusterGridContainer = UIView()
    private let clusterDivider = UIView()
    private let staticActionDivider = UIView()
    private let clusterShift: KbButton
    private let clusterUp: KbHoldButton
    private let clusterDelete: KbHoldButton
    private let clusterUndoRedo: KbButton
    private let clusterLeft: KbHoldButton
    private let clusterDown: KbHoldButton
    private let clusterRight: KbHoldButton
    private var clusterWidthConstraint: NSLayoutConstraint?
    private var clusterDividerWidthConstraint: NSLayoutConstraint?
    private var staticActionDividerWidthConstraint: NSLayoutConstraint?

    private var palette: Palette = .light

    private let bonusPanel = UIView()
    private let bonusLeftStack = UIStackView()
    private let bonusGridStack = UIStackView()
    private let bonusRightStack = UIStackView()
    private let bonusPageButton: KbButton
    private var bonusButtons: [KbButton] = []
    private var bonusPageIndex = 0
    private var bonusKeysVisible = false

    // Button references we toggle in the scrolling part.
    private weak var hideButton: KbButton?
    private weak var readButton: KbButton?
    private weak var undoRedoButton: KbButton?
    private weak var cutButton: KbButton?
    private weak var findButton: KbButton?
    private weak var shiftButton: KbButton?
    private weak var compareButton: KbButton?

    private var allButtons: [KbButton] = []
    private var allSeparators: [UIView] = []
    private var undoRedoFlyout: UIView?

    // MARK: - Init

    override init(frame: CGRect) {
        // Cluster buttons are owned by self; built here so we can store strong
        // references that survive `rebuildLayout()` (the cluster never rebuilds).
        clusterShift  = KbButton(symbol: "shift", label: "Shift") { }
        clusterUp     = KbHoldButton(symbol: "arrow.up", label: "Up") { }
        clusterDelete = KbHoldButton(symbol: "delete.left", label: "Delete", repeatBehavior: .delete) { }
        clusterUndoRedo = KbButton(symbol: "arrow.uturn.backward", label: "Undo/Redo", customImage: KeyboardAccessoryView.makeUndoRedoImage()) { }
        clusterLeft   = KbHoldButton(symbol: "arrow.left", label: "Left") { }
        clusterDown   = KbHoldButton(symbol: "arrow.down", label: "Down") { }
        clusterRight  = KbHoldButton(symbol: "arrow.right", label: "Right") { }
        modeSwitchButton = KbButton(symbol: "arrow.left.arrow.right", label: "Keys") { }
        bonusPageButton = KbButton(symbol: "ellipsis", label: "1/4") { }
        super.init(frame: frame)
        autoresizingMask = [.flexibleWidth]
        setupBase()
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
        modeSwitchButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(modeSwitchButton)

        // Build the fixed edit cluster: a 3x2 arrow/edit grid.
        clusterContainer.translatesAutoresizingMaskIntoConstraints = false
        addSubview(clusterContainer)
        clusterGridContainer.translatesAutoresizingMaskIntoConstraints = false
        clusterContainer.addSubview(clusterGridContainer)

        let topCluster = UIStackView(arrangedSubviews: [clusterShift, clusterUp, clusterDelete])
        let botCluster = UIStackView(arrangedSubviews: [clusterLeft, clusterDown, clusterRight])
        for st in [topCluster, botCluster] {
            st.translatesAutoresizingMaskIntoConstraints = false
            st.axis = .horizontal
            st.alignment = .center
            st.distribution = .fillEqually
            st.spacing = 2
        }
        clusterGridContainer.addSubview(topCluster)
        clusterGridContainer.addSubview(botCluster)
        clusterUndoRedo.translatesAutoresizingMaskIntoConstraints = false
        addSubview(clusterUndoRedo)

        clusterDivider.translatesAutoresizingMaskIntoConstraints = false
        addSubview(clusterDivider)
        staticActionDivider.translatesAutoresizingMaskIntoConstraints = false
        addSubview(staticActionDivider)

        bonusPanel.translatesAutoresizingMaskIntoConstraints = false
        bonusPanel.isHidden = true
        addSubview(bonusPanel)
        for stack in [bonusLeftStack, bonusGridStack, bonusRightStack] {
            stack.translatesAutoresizingMaskIntoConstraints = false
            stack.axis = .vertical
            stack.alignment = .fill
            stack.distribution = .fillEqually
            stack.spacing = 6
            bonusPanel.addSubview(stack)
        }

        let clusterWidth = clusterContainer.widthAnchor.constraint(equalToConstant: 134)
        let dividerWidth = clusterDivider.widthAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale)
        let trailingDividerWidth = staticActionDivider.widthAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale)
        clusterWidthConstraint = clusterWidth
        clusterDividerWidthConstraint = dividerWidth
        staticActionDividerWidthConstraint = trailingDividerWidth

        NSLayoutConstraint.activate([
            topBorder.topAnchor.constraint(equalTo: topAnchor),
            topBorder.leadingAnchor.constraint(equalTo: leadingAnchor),
            topBorder.trailingAnchor.constraint(equalTo: trailingAnchor),
            topBorder.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale),

            // Cluster — fixed arrow/edit block, fills the bar's height.
            clusterContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            clusterContainer.topAnchor.constraint(equalTo: topAnchor, constant: 2),
            clusterContainer.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2),
            clusterWidth,

            // Vertical divider between cluster and the scrolling part.
            clusterDivider.leadingAnchor.constraint(equalTo: clusterContainer.trailingAnchor, constant: 4),
            clusterDivider.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            clusterDivider.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
            dividerWidth,

            clusterUndoRedo.leadingAnchor.constraint(equalTo: clusterDivider.trailingAnchor, constant: 8),
            clusterUndoRedo.topAnchor.constraint(equalTo: topAnchor, constant: 2),
            clusterUndoRedo.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2),
            clusterUndoRedo.widthAnchor.constraint(equalToConstant: 88),

            staticActionDivider.leadingAnchor.constraint(equalTo: clusterUndoRedo.trailingAnchor, constant: 8),
            staticActionDivider.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            staticActionDivider.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
            trailingDividerWidth,

            clusterGridContainer.leadingAnchor.constraint(equalTo: clusterContainer.leadingAnchor),
            clusterGridContainer.topAnchor.constraint(equalTo: clusterContainer.topAnchor),
            clusterGridContainer.bottomAnchor.constraint(equalTo: clusterContainer.bottomAnchor),
            clusterGridContainer.widthAnchor.constraint(equalToConstant: 132),

            topCluster.topAnchor.constraint(equalTo: clusterGridContainer.topAnchor),
            topCluster.leadingAnchor.constraint(equalTo: clusterGridContainer.leadingAnchor),
            topCluster.trailingAnchor.constraint(equalTo: clusterGridContainer.trailingAnchor),
            topCluster.heightAnchor.constraint(equalTo: clusterGridContainer.heightAnchor, multiplier: 0.5, constant: -1),

            botCluster.topAnchor.constraint(equalTo: topCluster.bottomAnchor, constant: 2),
            botCluster.leadingAnchor.constraint(equalTo: clusterGridContainer.leadingAnchor),
            botCluster.trailingAnchor.constraint(equalTo: clusterGridContainer.trailingAnchor),
            botCluster.bottomAnchor.constraint(equalTo: clusterGridContainer.bottomAnchor),

        ])
        updateStaticClusterVisibility()
    }

    private func wireClusterCallbacks() {
        clusterShift.onTap  = { [weak self] in self?.onShiftToggle?() }
        clusterUp.tickHandler     = { [weak self] in self?.onArrow?(.up) }
        clusterDelete.tickHandler = { [weak self] in self?.onDelete?() }
        clusterUndoRedo.onTap = { [weak self, weak clusterUndoRedo] in
            guard let clusterUndoRedo else { return }
            self?.showUndoRedoFlyout(from: clusterUndoRedo)
        }
        clusterLeft.tickHandler   = { [weak self] in self?.onArrow?(.left) }
        clusterDown.tickHandler   = { [weak self] in self?.onArrow?(.down) }
        clusterRight.tickHandler  = { [weak self] in self?.onArrow?(.right) }
        modeSwitchButton.onTap = { [weak self] in self?.toggleBonusKeys() }
        bonusPageButton.onTap = { [weak self] in self?.advanceBonusPage() }
    }

    private var staticClusterButtonIds: Set<AccessoryToolbarButton> {
        Set(AccessoryToolbarButton.staticCandidates).subtracting([.undoRedo])
    }

    private func isPinnedToStaticCluster(_ button: AccessoryToolbarButton) -> Bool {
        staticClusterButtonIds.contains(button) && staticButtons.contains(button) && !hiddenButtons.contains(button)
    }

    private func isPinnedToAnyStaticSlot(_ button: AccessoryToolbarButton) -> Bool {
        AccessoryToolbarButton.staticCandidates.contains(button)
            && staticButtons.contains(button)
            && !hiddenButtons.contains(button)
    }

    private func isPinnedUndoRedoButton() -> Bool {
        isPinnedToAnyStaticSlot(.undoRedo)
    }

    private func isAvailableInScrollingToolbar(_ button: AccessoryToolbarButton) -> Bool {
        !hiddenButtons.contains(button) && !isPinnedToAnyStaticSlot(button)
    }

    private func updateStaticClusterVisibility() {
        if bonusKeysVisible {
            for view in [clusterShift, clusterUp, clusterDelete, clusterLeft, clusterDown, clusterRight] {
                view.isHidden = true
            }
            clusterUndoRedo.isHidden = true
            clusterContainer.isHidden = true
            clusterDivider.isHidden = true
            staticActionDivider.isHidden = true
            clusterWidthConstraint?.constant = 0
            clusterDividerWidthConstraint?.constant = 0
            staticActionDividerWidthConstraint?.constant = 0
            updateUndoRedoEnabled()
            return
        }

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
        let undoRedoVisible = isPinnedUndoRedoButton()
        clusterUndoRedo.isHidden = !undoRedoVisible
        clusterContainer.isHidden = !anyVisible
        clusterDivider.isHidden = !anyVisible
        staticActionDivider.isHidden = !undoRedoVisible
        clusterWidthConstraint?.constant = anyVisible ? 134 : 0
        clusterDividerWidthConstraint?.constant = anyVisible ? (1 / UIScreen.main.scale) : 0
        staticActionDividerWidthConstraint?.constant = undoRedoVisible ? (1 / UIScreen.main.scale) : 0
        updateUndoRedoEnabled()
    }

    private func updateUndoRedoEnabled() {
        let disabled = !canUndo && !canRedo
        undoRedoButton?.isDisabled = disabled
        clusterUndoRedo.isDisabled = disabled
        applyPaletteToButtons()
    }

    // MARK: - Intrinsic size

    var preferredHeight: CGFloat { intrinsicContentSize.height }

    override var intrinsicContentSize: CGSize {
        // The static cluster is two rows tall even when the scrolling toolbar
        // is single-row. Grow for Large buttons so controls do not clip.
        let compactHeight = max(88, accessoryRowHeight * 2)
        let height = bonusKeysVisible
            ? accessoryRowHeight + (1 / UIScreen.main.scale) + bonusPanelHeight
            : compactHeight
        return CGSize(width: UIView.noIntrinsicMetric, height: height)
    }

    // MARK: - Layout

    private var activeConstraints: [NSLayoutConstraint] = []

    private func rebuildLayout() {
        dismissUndoRedoFlyout(animated: false)
        updateStaticClusterVisibility()
        updateModeSwitchButton()
        // Tear down existing button subviews / constraints.
        NSLayoutConstraint.deactivate(activeConstraints)
        activeConstraints.removeAll()
        topStack.arrangedSubviews.forEach { topStack.removeArrangedSubview($0); $0.removeFromSuperview() }
        bottomStack.arrangedSubviews.forEach { bottomStack.removeArrangedSubview($0); $0.removeFromSuperview() }
        allButtons.removeAll()
        allSeparators.removeAll()
        hideButton = nil; readButton = nil; undoRedoButton = nil; cutButton = nil
        findButton = nil; shiftButton = nil; compareButton = nil

        // Build the full ordered list of items.
        let items = makeItems()

        if bonusKeysVisible {
            install(items: items, into: topStack)
            bottomScroll.isHidden = true
            bonusPanel.isHidden = false
            middleBorder.isHidden = false
            rebuildBonusPanel()

            let rowHeight = accessoryRowHeight
            activeConstraints = [
                topScroll.topAnchor.constraint(equalTo: topAnchor),
                topScroll.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
                topScroll.trailingAnchor.constraint(equalTo: modeSwitchButton.leadingAnchor, constant: -4),
                topScroll.heightAnchor.constraint(equalToConstant: rowHeight),

                modeSwitchButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
                modeSwitchButton.centerYAnchor.constraint(equalTo: topScroll.centerYAnchor),
                modeSwitchButton.widthAnchor.constraint(equalToConstant: 58),
                modeSwitchButton.heightAnchor.constraint(equalToConstant: max(34, rowHeight - 8)),

                middleBorder.topAnchor.constraint(equalTo: topScroll.bottomAnchor),
                middleBorder.leadingAnchor.constraint(equalTo: leadingAnchor),
                middleBorder.trailingAnchor.constraint(equalTo: trailingAnchor),
                middleBorder.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale),

                bonusPanel.topAnchor.constraint(equalTo: middleBorder.bottomAnchor),
                bonusPanel.leadingAnchor.constraint(equalTo: leadingAnchor),
                bonusPanel.trailingAnchor.constraint(equalTo: trailingAnchor),
                bonusPanel.bottomAnchor.constraint(equalTo: bottomAnchor),

                topStack.topAnchor.constraint(equalTo: topScroll.contentLayoutGuide.topAnchor, constant: 4),
                topStack.leadingAnchor.constraint(equalTo: topScroll.contentLayoutGuide.leadingAnchor, constant: 4),
                topStack.trailingAnchor.constraint(equalTo: topScroll.contentLayoutGuide.trailingAnchor, constant: -4),
                topStack.bottomAnchor.constraint(equalTo: topScroll.contentLayoutGuide.bottomAnchor, constant: -4),
                topStack.heightAnchor.constraint(equalTo: topScroll.frameLayoutGuide.heightAnchor, constant: -8),

                bonusLeftStack.topAnchor.constraint(equalTo: bonusPanel.topAnchor, constant: 8),
                bonusLeftStack.leadingAnchor.constraint(equalTo: bonusPanel.leadingAnchor, constant: 8),
                bonusLeftStack.bottomAnchor.constraint(equalTo: bonusPanel.bottomAnchor, constant: -8),
                bonusLeftStack.widthAnchor.constraint(equalToConstant: bonusSideColumnWidth),

                bonusRightStack.topAnchor.constraint(equalTo: bonusPanel.topAnchor, constant: 8),
                bonusRightStack.trailingAnchor.constraint(equalTo: bonusPanel.trailingAnchor, constant: -8),
                bonusRightStack.bottomAnchor.constraint(equalTo: bonusPanel.bottomAnchor, constant: -8),
                bonusRightStack.widthAnchor.constraint(equalToConstant: bonusSideColumnWidth),

                bonusGridStack.topAnchor.constraint(equalTo: bonusPanel.topAnchor, constant: 8),
                bonusGridStack.leadingAnchor.constraint(equalTo: bonusLeftStack.trailingAnchor, constant: 8),
                bonusGridStack.trailingAnchor.constraint(equalTo: bonusRightStack.leadingAnchor, constant: -8),
                bonusGridStack.bottomAnchor.constraint(equalTo: bonusPanel.bottomAnchor, constant: -8),
            ]
            NSLayoutConstraint.activate(activeConstraints)
            notifyPreferredHeightChanged()
            applyDisplayOptionsToButtons()
            applyPaletteToButtons()
            return
        }

        bonusPanel.isHidden = true

        // Split across rows if requested.
        // Scrolling part starts after the cluster + divider.
        let scrollLeading = isPinnedUndoRedoButton() ? staticActionDivider.trailingAnchor : clusterDivider.trailingAnchor

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
                topScroll.trailingAnchor.constraint(equalTo: modeSwitchButton.leadingAnchor, constant: -4),
                topScroll.heightAnchor.constraint(equalToConstant: rowHeight),

                modeSwitchButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
                modeSwitchButton.centerYAnchor.constraint(equalTo: centerYAnchor),
                modeSwitchButton.widthAnchor.constraint(equalToConstant: 58),
                modeSwitchButton.heightAnchor.constraint(equalToConstant: max(34, accessoryRowHeight)),

                middleBorder.topAnchor.constraint(equalTo: topScroll.bottomAnchor),
                middleBorder.leadingAnchor.constraint(equalTo: scrollLeading, constant: 4),
                middleBorder.trailingAnchor.constraint(equalTo: modeSwitchButton.leadingAnchor, constant: -4),
                middleBorder.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale),

                bottomScroll.topAnchor.constraint(equalTo: middleBorder.bottomAnchor),
                bottomScroll.leadingAnchor.constraint(equalTo: scrollLeading, constant: 4),
                bottomScroll.trailingAnchor.constraint(equalTo: modeSwitchButton.leadingAnchor, constant: -4),
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
                topScroll.trailingAnchor.constraint(equalTo: modeSwitchButton.leadingAnchor, constant: -4),

                modeSwitchButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
                modeSwitchButton.centerYAnchor.constraint(equalTo: centerYAnchor),
                modeSwitchButton.widthAnchor.constraint(equalToConstant: 58),
                modeSwitchButton.heightAnchor.constraint(equalToConstant: max(34, accessoryRowHeight)),

                topStack.topAnchor.constraint(equalTo: topScroll.contentLayoutGuide.topAnchor, constant: 4),
                topStack.leadingAnchor.constraint(equalTo: topScroll.contentLayoutGuide.leadingAnchor, constant: 4),
                topStack.trailingAnchor.constraint(equalTo: topScroll.contentLayoutGuide.trailingAnchor, constant: -4),
                topStack.bottomAnchor.constraint(equalTo: topScroll.contentLayoutGuide.bottomAnchor, constant: -4),
                topStack.heightAnchor.constraint(equalTo: topScroll.frameLayoutGuide.heightAnchor, constant: -8),
            ]
        }
        NSLayoutConstraint.activate(activeConstraints)
        notifyPreferredHeightChanged()
        applyDisplayOptionsToButtons()
        applyPaletteToButtons()
    }

    private var accessoryRowHeight: CGFloat {
        switch buttonSize {
        case .small: return 40
        case .medium: return 44
        case .large: return 52
        }
    }

    private var bonusPanelHeight: CGFloat {
        max(244, accessoryRowHeight * 4 + 68)
    }

    private var bonusSideColumnWidth: CGFloat {
        switch buttonSize {
        case .small: return 48
        case .medium: return 54
        case .large: return 62
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
        // Hide/Show is leftmost so keyboard visibility is always discoverable.
        // It suppresses the keyboard while leaving the document editable,
        // distinct from Read mode which locks the buffer.
        let hide = KbButton(
            symbol: keyboardHidden ? "keyboard" : "keyboard.chevron.compact.down",
            label: keyboardHidden ? "Show" : "Hide"
        ) { [weak self] in self?.onHide?() }
        hide.isActive = keyboardHidden
        hideButton = hide
        let read = KbButton(symbol: readMode ? "eye" : "eye.slash", label: "Read") { [weak self] in self?.onReadToggle?() }
        read.isActive = readMode
        readButton = read

        let undoRedo = KbButton(
            symbol: "arrow.uturn.backward",
            label: "Undo/Redo",
            customImage: Self.makeUndoRedoImage()
        ) { }
        undoRedo.onTap = { [weak self, weak undoRedo] in
            guard let undoRedo else { return }
            self?.showUndoRedoFlyout(from: undoRedo)
        }
        undoRedo.isDisabled = !canUndo && !canRedo
        undoRedoButton = undoRedo

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
        appendGroup([buttonItem(.undoRedo, undoRedo)])
        appendGroup([buttonItem(.readMode, read), buttonItem(.find, find)])
        appendGroup([
            buttonItem(.insertDate, date),
            buttonItem(.openDocuments, open),
            buttonItem(.compare, compare),
            buttonItem(.more, more),
        ])
        return result
    }

    func setBonusKeysVisible(_ visible: Bool, notify: Bool = false) {
        guard bonusKeysVisible != visible else { return }
        bonusKeysVisible = visible
        rebuildLayout()
        if notify {
            onBonusKeysVisibilityChange?(visible)
        }
    }

    private func toggleBonusKeys() {
        setBonusKeysVisible(!bonusKeysVisible, notify: true)
        Haptics.selectionChanged()
    }

    private func advanceBonusPage() {
        bonusPageIndex = (bonusPageIndex + 1) % bonusPages.count
        rebuildBonusPanel()
        applyDisplayOptionsToButtons()
        applyPaletteToButtons()
        Haptics.selectionChanged()
    }

    private func updateModeSwitchButton() {
        modeSwitchButton.setSymbol(bonusKeysVisible ? "keyboard" : "arrow.left.arrow.right")
        modeSwitchButton.setTitle(bonusKeysVisible ? "Kbd" : "Keys")
        modeSwitchButton.isActive = bonusKeysVisible
    }

    private func notifyPreferredHeightChanged() {
        invalidateIntrinsicContentSize()
        onPreferredHeightChange?()
    }

    private func rebuildBonusPanel() {
        for stack in [bonusLeftStack, bonusGridStack, bonusRightStack] {
            stack.arrangedSubviews.forEach { stack.removeArrangedSubview($0); $0.removeFromSuperview() }
        }
        bonusButtons.removeAll()
        bonusPageIndex = max(0, min(bonusPageIndex, bonusPages.count - 1))
        bonusPageButton.setTitle("\(bonusPageIndex + 1)/\(bonusPages.count)")

        let leftButtons: [KbButton] = [
            makeBonusButton(symbol: "doc.on.doc", label: "Copy") { [weak self] in self?.onCopy?() },
            makeBonusButton(symbol: "scissors", label: "Cut") { [weak self] in self?.onCut?() },
            makeBonusButton(symbol: "doc.on.clipboard", label: "Paste") { [weak self] in self?.onPaste?() },
            bonusPageButton,
        ]
        leftButtons.forEach { bonusLeftStack.addArrangedSubview($0) }

        let rows = bonusPages[bonusPageIndex]
        for row in rows {
            let rowStack = UIStackView()
            rowStack.translatesAutoresizingMaskIntoConstraints = false
            rowStack.axis = .horizontal
            rowStack.alignment = .fill
            rowStack.distribution = .fillEqually
            rowStack.spacing = 6
            for spec in row {
                rowStack.addArrangedSubview(makeBonusButton(spec))
            }
            bonusGridStack.addArrangedSubview(rowStack)
        }

        let backspace = makeBonusHoldButton(
            symbol: "delete.left",
            label: "Delete",
            repeatBehavior: .delete
        ) { [weak self] in self?.onDelete?() }
        let enter = makeBonusButton(symbol: "return", label: "Enter") { [weak self] in self?.onEnter?() }
        bonusRightStack.addArrangedSubview(backspace)
        bonusRightStack.addArrangedSubview(enter)
    }

    private struct BonusKeySpec {
        let symbol: String
        let label: String
        let contentMode: AccessoryToolbarContentMode
        let repeatBehavior: KbHoldButton.RepeatBehavior?
        let action: (KeyboardAccessoryView) -> Void
    }

    private var bonusPages: [[[BonusKeySpec]]] {
        [
            [
                key("house", "Home") { $0.onHome?() },
                holdKey("arrow.up", "Up") { $0.onArrow?(.up) },
                key("arrow.up.to.line", "Pg Up") { $0.onPageUp?() },
                key("line.3.horizontal", "End") { $0.onEnd?() },
                holdKey("arrow.left", "Left") { $0.onArrow?(.left) },
                holdKey("arrow.down", "Down") { $0.onArrow?(.down) },
                holdKey("arrow.right", "Right") { $0.onArrow?(.right) },
                key("arrow.right.to.line", "Tab") { $0.onTab?() },
                key("textformat.abc", "Word") { $0.onSelectWord?() },
                key("text.line.first.and.arrowtriangle.forward", "Line") { $0.onSelectLine?() },
                key("character.textbox", "All") { $0.onSelectAll?() },
                key("arrow.uturn.backward", "Undo/Redo") { view in
                    view.showUndoRedoFlyout(from: view.bonusPageButton)
                },
                key("magnifyingglass", "Find") { $0.onFind?() },
                key("eye", "Read") { $0.onReadToggle?() },
                key("clock", "Date") { $0.onInsertDate?() },
                key("ellipsis.circle", "More") { $0.onMore?() },
            ],
            [
                textKey("/", "/") { $0.onInsertText?("/") },
                textKey("7", "7") { $0.onInsertText?("7") },
                textKey("8", "8") { $0.onInsertText?("8") },
                textKey("9", "9") { $0.onInsertText?("9") },
                textKey("*", "*") { $0.onInsertText?("*") },
                textKey("4", "4") { $0.onInsertText?("4") },
                textKey("5", "5") { $0.onInsertText?("5") },
                textKey("6", "6") { $0.onInsertText?("6") },
                textKey("-", "-") { $0.onInsertText?("-") },
                textKey("1", "1") { $0.onInsertText?("1") },
                textKey("2", "2") { $0.onInsertText?("2") },
                textKey("3", "3") { $0.onInsertText?("3") },
                textKey("+", "+") { $0.onInsertText?("+") },
                textKey("0", "0") { $0.onInsertText?("0") },
                textKey(".", ".") { $0.onInsertText?(".") },
                textKey(",", ",") { $0.onInsertText?(",") },
            ],
            [
                textKey("(", "(") { $0.onInsertText?("(") },
                textKey(")", ")") { $0.onInsertText?(")") },
                textKey("[", "[") { $0.onInsertText?("[") },
                textKey("]", "]") { $0.onInsertText?("]") },
                textKey("{", "{") { $0.onInsertText?("{") },
                textKey("}", "}") { $0.onInsertText?("}") },
                textKey("<", "<") { $0.onInsertText?("<") },
                textKey(">", ">") { $0.onInsertText?(">") },
                textKey("\"", "\"") { $0.onInsertText?("\"") },
                textKey("'", "'") { $0.onInsertText?("'") },
                textKey("=", "=") { $0.onInsertText?("=") },
                textKey("_", "_") { $0.onInsertText?("_") },
                textKey(":", ":") { $0.onInsertText?(":") },
                textKey(";", ";") { $0.onInsertText?(";") },
                textKey("\\", "\\") { $0.onInsertText?("\\") },
                textKey("|", "|") { $0.onInsertText?("|") },
            ],
            [
                key("plus.square.on.square", "Duplicate") { $0.onDuplicateLine?() },
                key("minus.square", "Delete line") { $0.onDeleteLine?() },
                key("arrow.up.arrow.down", "Sort") { $0.onSortLines?() },
                key("scissors.circle", "Trim") { $0.onTrimSpaces?() },
                key("arrow.down.to.line", "Go to") { $0.onGotoLine?() },
                key("folder", "Open") { $0.onOpenDocs?() },
                key("rectangle.split.1x2", "Compare") { $0.onCompare?() },
                key("doc.text.magnifyingglass", "Docs") { $0.onOpenDocs?() },
                key("shift", "Shift") { $0.onShiftToggle?() },
                key("eye.slash", "Read") { $0.onReadToggle?() },
                key("keyboard", "Kbd") { $0.setBonusKeysVisible(false, notify: true) },
                key("ellipsis.circle", "More") { $0.onMore?() },
                key("textformat.abc", "Word") { $0.onSelectWord?() },
                key("text.line.first.and.arrowtriangle.forward", "Line") { $0.onSelectLine?() },
                key("character.textbox", "All") { $0.onSelectAll?() },
                key("magnifyingglass", "Find") { $0.onFind?() },
            ],
        ].map { page in
            stride(from: 0, to: page.count, by: 4).map { start in
                Array(page[start..<min(start + 4, page.count)])
            }
        }
    }

    private func key(
        _ symbol: String,
        _ label: String,
        action: @escaping (KeyboardAccessoryView) -> Void
    ) -> BonusKeySpec {
        BonusKeySpec(
            symbol: symbol,
            label: label,
            contentMode: .iconAndText,
            repeatBehavior: nil,
            action: action
        )
    }

    private func holdKey(
        _ symbol: String,
        _ label: String,
        action: @escaping (KeyboardAccessoryView) -> Void
    ) -> BonusKeySpec {
        BonusKeySpec(
            symbol: symbol,
            label: label,
            contentMode: .iconAndText,
            repeatBehavior: .navigation,
            action: action
        )
    }

    private func textKey(
        _ symbol: String,
        _ label: String,
        action: @escaping (KeyboardAccessoryView) -> Void
    ) -> BonusKeySpec {
        BonusKeySpec(
            symbol: symbol,
            label: label,
            contentMode: .textOnly,
            repeatBehavior: nil,
            action: action
        )
    }

    private func makeBonusButton(_ spec: BonusKeySpec) -> KbButton {
        if let repeatBehavior = spec.repeatBehavior {
            return makeBonusHoldButton(
                symbol: spec.symbol,
                label: spec.label,
                contentMode: spec.contentMode,
                repeatBehavior: repeatBehavior
            ) { [weak self] in
                guard let self else { return }
                spec.action(self)
            }
        }
        return makeBonusButton(
            symbol: spec.symbol,
            label: spec.label,
            contentMode: spec.contentMode
        ) { [weak self] in
            guard let self else { return }
            spec.action(self)
        }
    }

    private func makeBonusButton(
        symbol: String,
        label: String,
        contentMode: AccessoryToolbarContentMode = .iconAndText,
        action: @escaping () -> Void
    ) -> KbButton {
        let button = KbButton(symbol: symbol, label: label, onTap: action)
        button.forcedContentMode = contentMode
        button.configureDisplay(size: buttonSize, contentMode: accessoryContentMode)
        bonusButtons.append(button)
        return button
    }

    private func makeBonusHoldButton(
        symbol: String,
        label: String,
        contentMode: AccessoryToolbarContentMode = .iconAndText,
        repeatBehavior: KbHoldButton.RepeatBehavior = .navigation,
        action: @escaping () -> Void
    ) -> KbHoldButton {
        let button = KbHoldButton(symbol: symbol, label: label, repeatBehavior: repeatBehavior, onTick: action)
        button.forcedContentMode = contentMode
        button.configureDisplay(size: buttonSize, contentMode: accessoryContentMode)
        bonusButtons.append(button)
        return button
    }

    private static func makeUndoRedoImage() -> UIImage? {
        let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        guard
            let undo = UIImage(systemName: "arrow.uturn.backward", withConfiguration: config),
            let redo = UIImage(systemName: "arrow.uturn.forward", withConfiguration: config)
        else {
            return UIImage(systemName: "arrow.uturn.backward", withConfiguration: config)
        }

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 26, height: 20))
        let image = renderer.image { _ in
            UIColor.black.setFill()
            undo.withTintColor(.black, renderingMode: .alwaysOriginal)
                .draw(in: CGRect(x: 0, y: 1, width: 15, height: 15))
            redo.withTintColor(.black, renderingMode: .alwaysOriginal)
                .draw(in: CGRect(x: 11, y: 4, width: 15, height: 15))
        }
        return image.withRenderingMode(.alwaysTemplate)
    }

    // MARK: - Palette

    func applyPalette(_ p: Palette) {
        palette = p
        backgroundColor = p.card
        bonusPanel.backgroundColor = p.card
        topBorder.backgroundColor = p.border
        middleBorder.backgroundColor = p.border
        clusterDivider.backgroundColor = p.border
        staticActionDivider.backgroundColor = p.border
        applyPaletteToButtons()
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        if super.point(inside: point, with: event) {
            return true
        }
        guard let flyout = undoRedoFlyout, !flyout.isHidden else {
            return false
        }
        let localPoint = flyout.convert(point, from: self)
        return flyout.point(inside: localPoint, with: event)
    }

    private func showUndoRedoFlyout(from source: UIView) {
        if undoRedoFlyout != nil {
            dismissUndoRedoFlyout(animated: false)
        }

        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = true
        container.backgroundColor = palette.card
        container.layer.cornerRadius = 8
        container.layer.borderWidth = 1 / UIScreen.main.scale
        container.layer.borderColor = palette.border.cgColor
        container.layer.shadowColor = UIColor.black.cgColor
        container.layer.shadowOpacity = 0.18
        container.layer.shadowRadius = 8
        container.layer.shadowOffset = CGSize(width: 0, height: 3)
        container.alpha = 0
        container.transform = CGAffineTransform(scaleX: 0.94, y: 0.94)

        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.alignment = .fill
        stack.distribution = .fillEqually
        stack.spacing = 4
        container.addSubview(stack)

        let undo = KbButton(symbol: "arrow.uturn.backward", label: "Undo") { [weak self] in
            self?.dismissUndoRedoFlyout(animated: true)
            self?.onUndo?()
        }
        undo.isDisabled = !canUndo
        let redo = KbButton(symbol: "arrow.uturn.forward", label: "Redo") { [weak self] in
            self?.dismissUndoRedoFlyout(animated: true)
            self?.onRedo?()
        }
        redo.isDisabled = !canRedo
        for button in [undo, redo] {
            button.configureDisplay(size: buttonSize, contentMode: .iconAndText)
            button.applyPalette(palette)
            stack.addArrangedSubview(button)
        }

        addSubview(container)
        undoRedoFlyout = container

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 5),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 5),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -5),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -5),
        ])

        layoutIfNeeded()
        let sourceFrame = source.convert(source.bounds, to: self)
        let width: CGFloat = 124
        let height: CGFloat = 50
        let x = max(4, min(bounds.width - width - 4, sourceFrame.midX - width / 2))
        let y = sourceFrame.minY - height - 6
        container.frame = CGRect(x: x, y: y, width: width, height: height)

        UIView.animate(withDuration: 0.09, delay: 0, options: [.curveEaseOut, .beginFromCurrentState]) {
            container.alpha = 1
            container.transform = .identity
        }
    }

    private func dismissUndoRedoFlyout(animated: Bool) {
        guard let flyout = undoRedoFlyout else { return }
        undoRedoFlyout = nil
        let remove = { flyout.removeFromSuperview() }
        guard animated else {
            remove()
            return
        }
        UIView.animate(withDuration: 0.08, delay: 0, options: [.curveEaseIn, .beginFromCurrentState]) {
            flyout.alpha = 0
            flyout.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
        } completion: { _ in
            remove()
        }
    }

    private func applyDisplayOptionsToButtons() {
        for btn in allButtons {
            btn.configureDisplay(size: buttonSize, contentMode: accessoryContentMode)
        }
        for btn in [clusterShift, clusterUp, clusterDelete, clusterUndoRedo, clusterLeft, clusterDown, clusterRight, modeSwitchButton, bonusPageButton] {
            btn.configureDisplay(size: buttonSize, contentMode: accessoryContentMode)
        }
        for btn in bonusButtons {
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
        for btn in [clusterShift, clusterUp, clusterDelete, clusterUndoRedo, clusterLeft, clusterDown, clusterRight, modeSwitchButton, bonusPageButton] {
            btn.applyPalette(palette)
        }
        for btn in bonusButtons {
            btn.applyPalette(palette)
        }
    }
}

// MARK: - KbButton

private class KbButton: UIControl {
    let symbolName: String
    private(set) var label: String?
    var onTap: (() -> Void)?
    var forcedContentMode: AccessoryToolbarContentMode?

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
    private var customImage: UIImage?

    init(symbol: String, label: String? = nil, customImage: UIImage? = nil, onTap: @escaping () -> Void) {
        self.symbolName = symbol
        self.label = label
        self.onTap = onTap
        self.displayedSymbolName = symbol
        self.customImage = customImage
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
        contentStack.isUserInteractionEnabled = false
        contentStack.axis = .vertical
        contentStack.alignment = .center
        contentStack.distribution = .fill
        contentStack.spacing = 1
        addSubview(contentStack)

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.isUserInteractionEnabled = false
        imageView.contentMode = .scaleAspectFit
        imageView.image = UIImage(systemName: symbolName,
                                  withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .regular))
        contentStack.addArrangedSubview(imageView)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.isUserInteractionEnabled = false
        titleLabel.font = .systemFont(ofSize: 9, weight: .medium)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 1
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.75
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

    @objc private func tapped() {
        guard !isDisabled, let onTap else { return }
        Haptics.selectionChanged()
        onTap()
    }

    func setSymbol(_ name: String) {
        displayedSymbolName = name
        customImage = nil
        imageView.image = UIImage(systemName: name,
                                  withConfiguration: UIImage.SymbolConfiguration(pointSize: symbolPointSize(for: currentSize), weight: .regular))
    }

    func setTitle(_ text: String?) {
        label = text
        titleLabel.text = text
        accessibilityLabel = text ?? displayedSymbolName
        configureDisplay(size: currentSize, contentMode: currentContentMode)
    }

    func configureDisplay(size: AccessoryToolbarButtonSize, contentMode: AccessoryToolbarContentMode) {
        currentSize = size
        currentContentMode = contentMode
        let effectiveContentMode = forcedContentMode ?? contentMode
        minWidthConstraint?.constant = minWidth(for: size)
        minHeightConstraint?.constant = minHeight(for: size)
        if let customImage {
            imageView.image = customImage
        } else {
            imageView.image = UIImage(
                systemName: displayedSymbolName,
                withConfiguration: UIImage.SymbolConfiguration(pointSize: symbolPointSize(for: size), weight: .regular)
            )
        }
        titleLabel.font = .systemFont(ofSize: fontSize(for: size), weight: .medium)

        let hasText = !(label ?? "").isEmpty
        switch effectiveContentMode {
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

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        bounds.contains(point)
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard isUserInteractionEnabled, !isHidden, alpha > 0.01, bounds.contains(point) else {
            return nil
        }
        return self
    }

    func containsInteractivePoint(_ point: CGPoint) -> Bool {
        trackingBounds.contains(point)
    }

    private var trackingBounds: CGRect {
        bounds.insetBy(dx: -8, dy: -8)
    }

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

        layer.borderWidth = (isHighlighted || isActive) ? (1 / UIScreen.main.scale) : 0
        layer.borderColor = (isHighlighted ? p.primary : p.border).cgColor

        if isHighlighted {
            backgroundColor = p.primary.withAlphaComponent(0.18)
            alpha = isDisabled ? 0.35 : 1.0
        } else if isActive {
            backgroundColor = p.primary.withAlphaComponent(0.12)
            alpha = isDisabled ? 0.35 : 1.0
        } else {
            backgroundColor = .clear
            alpha = isDisabled ? 0.35 : 1.0
        }
    }
}

// MARK: - KbHoldButton

/// Auto-repeating toolbar button. A quick tap fires once on release unless
/// the selected repeat behavior fires on press. A held press starts repeating
/// after a short intent threshold and accelerates until release/cancellation.
private final class KbHoldButton: KbButton {
    struct RepeatBehavior {
        let firesOnPress: Bool
        let holdDelay: TimeInterval
        let initialInterval: TimeInterval
        let secondInterval: TimeInterval
        let finalInterval: TimeInterval
        let secondIntervalAfterTicks: Int
        let finalIntervalAfterTicks: Int

        static let navigation = RepeatBehavior(
            firesOnPress: false,
            holdDelay: 0.180,
            initialInterval: 0.120,
            secondInterval: 0.090,
            finalInterval: 0.060,
            secondIntervalAfterTicks: 3,
            finalIntervalAfterTicks: 8
        )

        static let delete = RepeatBehavior(
            firesOnPress: true,
            holdDelay: 0.220,
            initialInterval: 0.070,
            secondInterval: 0.045,
            finalInterval: 0.030,
            secondIntervalAfterTicks: 8,
            finalIntervalAfterTicks: 24
        )
    }

    private var holdTimer: Timer?
    private var initialDelayTimer: Timer?
    private var repeatCount: Int = 0
    private var hasFiredDuringTracking = false
    private let repeatBehavior: RepeatBehavior
    var tickHandler: () -> Void

    init(
        symbol: String,
        label: String? = nil,
        repeatBehavior: RepeatBehavior = .navigation,
        onTick: @escaping () -> Void
    ) {
        self.tickHandler = onTick
        self.repeatBehavior = repeatBehavior
        super.init(symbol: symbol, label: label, onTap: {})
        self.onTap = nil
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        guard super.beginTracking(touch, with: event) else { return false }
        isHighlighted = true
        hasFiredDuringTracking = false
        repeatCount = 0
        initialDelayTimer?.invalidate()
        if repeatBehavior.firesOnPress {
            fireTick(withHaptic: true)
            hasFiredDuringTracking = true
        }
        let timer = Timer(timeInterval: repeatBehavior.holdDelay, repeats: false) { [weak self] _ in
            guard let self, self.isHighlighted else { return }
            if !self.hasFiredDuringTracking {
                self.fireTick(withHaptic: true)
                self.hasFiredDuringTracking = true
            }
            self.startRepeating(every: self.repeatBehavior.initialInterval)
        }
        initialDelayTimer = timer
        RunLoop.main.add(timer, forMode: .common)
        return true
    }

    override func continueTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        let isInside = containsInteractivePoint(touch.location(in: self))
        isHighlighted = isInside
        if !isInside {
            stopAllTimers()
        }
        return true
    }

    override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
        let endedInside = touch.map { containsInteractivePoint($0.location(in: self)) } ?? true
        let shouldFireTap = !hasFiredDuringTracking
            && !isDisabled
            && endedInside
        isHighlighted = false
        stopAllTimers()
        if shouldFireTap {
            fireTick(withHaptic: true)
        }
    }

    override func cancelTracking(with event: UIEvent?) {
        isHighlighted = false
        stopAllTimers()
    }

    private func startRepeating(every interval: TimeInterval) {
        holdTimer?.invalidate()
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.fireTick(withHaptic: false)
            self.repeatCount += 1
            if self.repeatCount == self.repeatBehavior.finalIntervalAfterTicks
                && interval > self.repeatBehavior.finalInterval {
                self.startRepeating(every: self.repeatBehavior.finalInterval)
            } else if self.repeatCount == self.repeatBehavior.secondIntervalAfterTicks
                && interval > self.repeatBehavior.secondInterval {
                self.startRepeating(every: self.repeatBehavior.secondInterval)
            }
        }
        holdTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func stopAllTimers() {
        initialDelayTimer?.invalidate()
        initialDelayTimer = nil
        holdTimer?.invalidate()
        holdTimer = nil
        repeatCount = 0
    }

    private func fireTick(withHaptic: Bool) {
        if withHaptic {
            Haptics.selectionChanged()
        }
        tickHandler()
    }

    deinit {
        stopAllTimers()
    }
}

private final class AccessoryToolbarScrollView: UIScrollView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        showsHorizontalScrollIndicator = false
        alwaysBounceHorizontal = false
        delaysContentTouches = true
        canCancelContentTouches = true
        directionalLockEnabled = true
        keyboardDismissMode = .none
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    override func touchesShouldCancel(in view: UIView) -> Bool {
        if view is UIControl {
            return true
        }
        return super.touchesShouldCancel(in: view)
    }
}
