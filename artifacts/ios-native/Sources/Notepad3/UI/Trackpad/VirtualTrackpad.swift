import UIKit

/// Simulated on-screen trackpad. Ported 1-for-1 from the RN `MouseOverlay`
/// pan surface in `artifacts/mobile/app/index.tsx`. The pad is a rounded card
/// (~200x120pt) that sits in the bottom-right corner, above the MobileFAB-style
/// position. Dragging on the surface moves a pointer elsewhere in the window
/// (reported via `onPointerMoved`); tapping the surface without moving fires
/// a click at the current pointer (reported via `onClick`). Resolving the
/// click to a target is the host's job — this view only reports positions.
///
/// Unlike the RN version which needed an explicit `MouseRegistry` because RN
/// has no built-in view hit-testing from JS, the native port lets the host
/// call `UIView.hitTest(_:with:)` on `rootHitTestView` with the reported point.
final class VirtualTrackpad: UIView {
    // MARK: Public API

    /// The view in whose coordinate space the fake clicks should resolve.
    /// Typically the window's root view controller view. Retained weakly so
    /// the trackpad can't accidentally keep the root view alive.
    weak var rootHitTestView: UIView?

    /// Fires whenever the virtual pointer position changes.
    /// Point is in window coordinates.
    var onPointerMoved: ((CGPoint) -> Void)?

    /// Fires when the user taps the pad (or the Click button). The host
    /// should forward this to `rootHitTestView.hitTest(point, with: nil)`.
    /// Point is in window coordinates.
    var onClick: ((CGPoint) -> Void)?

    // MARK: Constants

    /// Drag sensitivity multiplier, matched to the RN source (`SENS = 1.8`).
    private let sensitivity: CGFloat = 1.8

    // MARK: Subviews

    private let card = UIView()
    private let header = GradientView()
    private let headerIcon = UIImageView()
    private let headerLabel = UILabel()
    private let closeButton = UIButton(type: .system)
    private let surface = UIView()
    private let gridView = GridView()
    private let hintStack = UIStackView()
    private let hintLabel = UILabel()
    private let hintSubLabel = UILabel()
    private let fingerView = UIView()
    private let buttonsRow = UIStackView()
    private let clickButton = UIButton(type: .system)
    private let clickIcon = UIImageView()
    private let clickLabel = UILabel()
    private let hideButton = UIButton(type: .system)

    // MARK: State

    private var palette: Palette = .light
    /// Current virtual pointer position in window coordinates. Starts at the
    /// center of the main screen, matching the RN behavior where the pointer
    /// starts at `{ x: width/2, y: height/2 }`.
    private var pointerPos: CGPoint = {
        let b = UIScreen.main.bounds
        return CGPoint(x: (b.width / 2).rounded(), y: (b.height / 2).rounded())
    }()

    /// Last cumulative translation we emitted from, so we can apply
    /// incremental deltas scaled by `sensitivity`.
    private var lastTranslation: CGPoint = .zero
    /// Whether the current drag has crossed the move threshold. If not, the
    /// gesture is treated as a tap on release.
    private var movedDuringPan: Bool = false

    // MARK: Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupHierarchy()
        setupGestures()
        // Default palette to .light until the host calls applyPalette.
        applyPalette(palette)
        // Emit the initial pointer position so the overlay can place itself
        // correctly even before the user has touched the pad.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.onPointerMoved?(self.pointerPos)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    // MARK: Layout

    private func setupHierarchy() {
        backgroundColor = .clear
        translatesAutoresizingMaskIntoConstraints = false

        card.translatesAutoresizingMaskIntoConstraints = false
        card.layer.borderWidth = 2
        card.layer.masksToBounds = true
        addSubview(card)

        // Header (gradient bar with title + close)
        header.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(header)

        headerIcon.translatesAutoresizingMaskIntoConstraints = false
        headerIcon.image = UIImage(systemName: "cursorarrow",
                                   withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .regular))
        headerIcon.contentMode = .scaleAspectFit
        header.addSubview(headerIcon)

        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        headerLabel.text = "Trackpad  drag here, pointer moves above"
        headerLabel.font = .systemFont(ofSize: 11, weight: .medium)
        headerLabel.numberOfLines = 1
        headerLabel.lineBreakMode = .byTruncatingTail
        header.addSubview(headerLabel)

        closeButton.translatesAutoresizingMaskIntoConstraints = false
        var closeCfg = UIButton.Configuration.plain()
        closeCfg.image = UIImage(systemName: "xmark",
                                 withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold))
        closeCfg.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4)
        closeButton.configuration = closeCfg
        closeButton.accessibilityLabel = "Hide trackpad"
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        header.addSubview(closeButton)

        // Surface (draggable pad)
        surface.translatesAutoresizingMaskIntoConstraints = false
        surface.layer.borderWidth = 1
        card.addSubview(surface)

        gridView.translatesAutoresizingMaskIntoConstraints = false
        gridView.isUserInteractionEnabled = false
        surface.addSubview(gridView)

        hintStack.translatesAutoresizingMaskIntoConstraints = false
        hintStack.axis = .vertical
        hintStack.alignment = .center
        hintStack.spacing = 4
        hintStack.isUserInteractionEnabled = false
        surface.addSubview(hintStack)

        hintLabel.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        hintLabel.textAlignment = .center
        hintLabel.alpha = 0.55
        hintLabel.text = "Drag anywhere here to move the pointer"
        hintStack.addArrangedSubview(hintLabel)

        hintSubLabel.font = .monospacedSystemFont(ofSize: 10, weight: .regular)
        hintSubLabel.textAlignment = .center
        hintSubLabel.alpha = 0.4
        hintSubLabel.text = "Tap = click at pointer  finger stays here"
        hintStack.addArrangedSubview(hintSubLabel)

        fingerView.translatesAutoresizingMaskIntoConstraints = false
        fingerView.layer.borderWidth = 2
        fingerView.layer.cornerRadius = 19
        fingerView.isUserInteractionEnabled = false
        fingerView.isHidden = true
        surface.addSubview(fingerView)

        // Button row (Click at pointer + Hide)
        buttonsRow.translatesAutoresizingMaskIntoConstraints = false
        buttonsRow.axis = .horizontal
        buttonsRow.spacing = 8
        buttonsRow.distribution = .fill
        buttonsRow.alignment = .fill
        card.addSubview(buttonsRow)

        clickButton.translatesAutoresizingMaskIntoConstraints = false
        clickButton.layer.borderWidth = 1
        clickButton.addTarget(self, action: #selector(clickButtonTapped), for: .touchUpInside)
        clickButton.accessibilityLabel = "Click at pointer"

        clickIcon.translatesAutoresizingMaskIntoConstraints = false
        clickIcon.image = UIImage(systemName: "cursorarrow",
                                  withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .regular))
        clickIcon.contentMode = .scaleAspectFit
        clickIcon.isUserInteractionEnabled = false
        clickButton.addSubview(clickIcon)

        clickLabel.translatesAutoresizingMaskIntoConstraints = false
        clickLabel.font = .systemFont(ofSize: 12, weight: .bold)
        clickLabel.text = "Click at pointer"
        clickLabel.isUserInteractionEnabled = false
        clickButton.addSubview(clickLabel)

        hideButton.translatesAutoresizingMaskIntoConstraints = false
        hideButton.layer.borderWidth = 1
        var hideCfg = UIButton.Configuration.plain()
        hideCfg.title = "Hide"
        hideCfg.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 14)
        hideCfg.attributedTitle = AttributedString("Hide", attributes: AttributeContainer([
            .font: UIFont.systemFont(ofSize: 12, weight: .bold)
        ]))
        hideButton.configuration = hideCfg
        hideButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)

        buttonsRow.addArrangedSubview(clickButton)
        buttonsRow.addArrangedSubview(hideButton)

        // Constraints: card fills self, header on top, surface fills middle,
        // buttons on the bottom. The whole thing is ~200x120.
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: topAnchor),
            card.leadingAnchor.constraint(equalTo: leadingAnchor),
            card.trailingAnchor.constraint(equalTo: trailingAnchor),
            card.bottomAnchor.constraint(equalTo: bottomAnchor),

            header.topAnchor.constraint(equalTo: card.topAnchor),
            header.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            header.heightAnchor.constraint(equalToConstant: 26),

            headerIcon.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 10),
            headerIcon.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            headerIcon.widthAnchor.constraint(equalToConstant: 14),
            headerIcon.heightAnchor.constraint(equalToConstant: 14),

            headerLabel.leadingAnchor.constraint(equalTo: headerIcon.trailingAnchor, constant: 6),
            headerLabel.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            headerLabel.trailingAnchor.constraint(lessThanOrEqualTo: closeButton.leadingAnchor, constant: -4),

            closeButton.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -4),
            closeButton.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 24),
            closeButton.heightAnchor.constraint(equalToConstant: 24),

            surface.topAnchor.constraint(equalTo: header.bottomAnchor),
            surface.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            surface.trailingAnchor.constraint(equalTo: card.trailingAnchor),

            gridView.topAnchor.constraint(equalTo: surface.topAnchor),
            gridView.leadingAnchor.constraint(equalTo: surface.leadingAnchor),
            gridView.trailingAnchor.constraint(equalTo: surface.trailingAnchor),
            gridView.bottomAnchor.constraint(equalTo: surface.bottomAnchor),

            hintStack.centerXAnchor.constraint(equalTo: surface.centerXAnchor),
            hintStack.centerYAnchor.constraint(equalTo: surface.centerYAnchor),
            hintStack.leadingAnchor.constraint(greaterThanOrEqualTo: surface.leadingAnchor, constant: 8),
            hintStack.trailingAnchor.constraint(lessThanOrEqualTo: surface.trailingAnchor, constant: -8),

            fingerView.widthAnchor.constraint(equalToConstant: 38),
            fingerView.heightAnchor.constraint(equalToConstant: 38),

            buttonsRow.topAnchor.constraint(equalTo: surface.bottomAnchor, constant: 8),
            buttonsRow.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 8),
            buttonsRow.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -8),
            buttonsRow.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -8),

            clickButton.heightAnchor.constraint(equalToConstant: 36),
            hideButton.heightAnchor.constraint(equalToConstant: 36),

            clickIcon.leadingAnchor.constraint(greaterThanOrEqualTo: clickButton.leadingAnchor, constant: 10),
            clickIcon.centerYAnchor.constraint(equalTo: clickButton.centerYAnchor),
            clickIcon.widthAnchor.constraint(equalToConstant: 14),
            clickIcon.heightAnchor.constraint(equalToConstant: 14),

            clickLabel.leadingAnchor.constraint(equalTo: clickIcon.trailingAnchor, constant: 6),
            clickLabel.centerYAnchor.constraint(equalTo: clickButton.centerYAnchor),
            clickLabel.trailingAnchor.constraint(lessThanOrEqualTo: clickButton.trailingAnchor, constant: -10),
            clickIcon.leadingAnchor.constraint(equalTo: clickButton.leadingAnchor, constant: 12),
        ])
    }

    // MARK: Gestures

    private func setupGestures() {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.maximumNumberOfTouches = 1
        pan.cancelsTouchesInView = false
        surface.addGestureRecognizer(pan)

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        surface.addGestureRecognizer(tap)
        // The pan always wins when movement happens; the tap fires only when
        // the finger doesn't move enough for the pan to activate.
    }

    @objc private func handlePan(_ gr: UIPanGestureRecognizer) {
        switch gr.state {
        case .began:
            lastTranslation = .zero
            movedDuringPan = false
            let location = gr.location(in: surface)
            showFinger(at: location)
        case .changed:
            let translation = gr.translation(in: surface)
            let dx = (translation.x - lastTranslation.x) * sensitivity
            let dy = (translation.y - lastTranslation.y) * sensitivity
            lastTranslation = translation
            if abs(translation.x) > 4 || abs(translation.y) > 4 {
                movedDuringPan = true
            }
            let location = gr.location(in: surface)
            showFinger(at: location)

            // Clamp pointer to the screen bounds so it doesn't escape the
            // visible area. Matches the RN clamp `[0, width-1] x [0, height-1]`.
            let screen = UIScreen.main.bounds
            var next = CGPoint(x: pointerPos.x + dx, y: pointerPos.y + dy)
            next.x = max(0, min(screen.width - 1, next.x))
            next.y = max(0, min(screen.height - 1, next.y))
            pointerPos = next
            onPointerMoved?(pointerPos)
        case .ended:
            let translation = gr.translation(in: surface)
            hideFinger()
            if !movedDuringPan && abs(translation.x) < 4 && abs(translation.y) < 4 {
                fireClickAtPointer()
            }
        case .cancelled, .failed:
            hideFinger()
        default:
            break
        }
    }

    @objc private func handleTap(_ gr: UITapGestureRecognizer) {
        fireClickAtPointer()
    }

    @objc private func clickButtonTapped() {
        fireClickAtPointer()
    }

    @objc private func closeTapped() {
        // The host owns visibility (it added us to the view tree), so expose
        // the "close" intent by hiding self. A parent VC can observe this or
        // wire its own UI; for parity with the RN Close button we just go
        // hidden, which matches the mounted-only-when-on RN pattern.
        isHidden = true
    }

    private func fireClickAtPointer() {
        let selection = UISelectionFeedbackGenerator()
        selection.selectionChanged()
        onClick?(pointerPos)
    }

    // MARK: Finger indicator

    private func showFinger(at point: CGPoint) {
        fingerView.isHidden = false
        hintStack.isHidden = true
        // The RN version positions the finger with `left: x - 19, top: y - 19`,
        // centering the 38pt circle on the touch point.
        fingerView.frame = CGRect(x: point.x - 19, y: point.y - 19, width: 38, height: 38)
    }

    private func hideFinger() {
        fingerView.isHidden = true
        hintStack.isHidden = false
    }

    // MARK: Palette

    func applyPalette(_ p: Palette) {
        palette = p
        card.backgroundColor = p.card
        card.layer.borderColor = p.primary.cgColor
        card.layer.cornerRadius = p.radius

        header.setColors(start: p.titleGradientStart, end: p.titleGradientEnd)
        headerIcon.tintColor = p.primaryForeground
        headerLabel.textColor = p.primaryForeground
        closeButton.tintColor = p.primaryForeground

        surface.backgroundColor = p.muted
        surface.layer.borderColor = p.border.cgColor
        gridView.lineColor = p.foreground
        gridView.setNeedsDisplay()

        hintLabel.textColor = p.mutedForeground
        hintSubLabel.textColor = p.mutedForeground

        fingerView.layer.borderColor = p.primary.cgColor
        fingerView.backgroundColor = p.primary.withAlphaComponent(0.2)

        let buttonRadius = min(p.radius, 4)
        clickButton.backgroundColor = p.primary
        clickButton.layer.borderColor = p.border.cgColor
        clickButton.layer.cornerRadius = buttonRadius
        clickIcon.tintColor = p.primaryForeground
        clickLabel.textColor = p.primaryForeground

        hideButton.backgroundColor = p.muted
        hideButton.layer.borderColor = p.border.cgColor
        hideButton.layer.cornerRadius = buttonRadius
        hideButton.tintColor = p.foreground
        var hideCfg = hideButton.configuration ?? UIButton.Configuration.plain()
        hideCfg.attributedTitle = AttributedString("Hide", attributes: AttributeContainer([
            .font: UIFont.systemFont(ofSize: 12, weight: .bold),
            .foregroundColor: p.foreground
        ]))
        hideButton.configuration = hideCfg
    }
}

// MARK: - GradientView

/// Vertical two-stop gradient used for the trackpad header, matching the
/// RN `palette.titleGradient` used in the source.
private final class GradientView: UIView {
    override class var layerClass: AnyClass { CAGradientLayer.self }
    private var gradient: CAGradientLayer { layer as! CAGradientLayer }

    override init(frame: CGRect) {
        super.init(frame: frame)
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 0, y: 1)
    }

    required init?(coder: NSCoder) { fatalError() }

    func setColors(start: UIColor, end: UIColor) {
        gradient.colors = [start.cgColor, end.cgColor]
    }
}

// MARK: - GridView

/// Faint 4x4 grid overlay inside the trackpad surface. The 25/50/75% lines
/// match the RN source which places three horizontal and three vertical
/// lines at those fractions.
private final class GridView: UIView {
    var lineColor: UIColor = .label {
        didSet { setNeedsDisplay() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        ctx.setStrokeColor(lineColor.withAlphaComponent(0.08).cgColor)
        ctx.setLineWidth(1)
        let fractions: [CGFloat] = [0.25, 0.5, 0.75]
        for f in fractions {
            let y = (rect.height * f).rounded()
            ctx.move(to: CGPoint(x: 0, y: y))
            ctx.addLine(to: CGPoint(x: rect.width, y: y))
            let x = (rect.width * f).rounded()
            ctx.move(to: CGPoint(x: x, y: 0))
            ctx.addLine(to: CGPoint(x: x, y: rect.height))
        }
        ctx.strokePath()
    }
}
