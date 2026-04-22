import UIKit

/// Full-window pointer cursor rendered on top of the app. Ported from the RN
/// `MouseOverlay` floating pointer layer. This view is pass-through: it never
/// intercepts touches so the host can still interact normally. The host
/// drives the pointer by setting `pointerPosition` (in window coordinates);
/// the host also calls the trackpad's `onClick` handler to synthesize a
/// click at that same point via `rootHitTestView.hitTest(_:with:)`.
///
/// Pointer-tip accuracy: prior work on the RN side fixed a bug where the
/// drawn arrow tip was offset from the click target — the fix there was
/// `{ left: pos.x - 3, top: pos.y - 3 }`, i.e. shift the Feather glyph by
/// 3pt so its visual tip aligned with `pos`. For the native port we use the
/// SF Symbol `cursorarrow`, whose visual tip coincides with the image's
/// top-left corner (no internal leading padding at the tip). That means we
/// place the image view with its `origin` AT the target point: no negative
/// offset needed. The image is rendered `.topLeft` aligned so the symbol is
/// painted starting from (0,0) of its frame, keeping the arrow tip
/// pixel-accurate regardless of frame size.
final class PointerOverlay: UIView {
    // MARK: Public API

    /// Current pointer position in window coordinates. Setting this updates
    /// the cursor location immediately; no animation.
    var pointerPosition: CGPoint = .zero {
        didSet { updatePointerFrame() }
    }

    /// Whether the pointer image is visible. Independent from `isHidden` on
    /// this container (the container stays in the hierarchy to avoid
    /// relayout churn — only the cursor glyph toggles visibility).
    var isVisible: Bool = true {
        didSet {
            pointerImageView.isHidden = !isVisible
        }
    }

    // MARK: Private

    /// SF Symbol `cursorarrow` rendered at a fixed point size. Picking an
    /// exact size means the symbol's drawn tip stays at the same pixel
    /// offset regardless of theme; we size the image view to the symbol's
    /// intrinsic size so the tip aligns with the frame's top-left corner.
    private let pointerImageView = UIImageView()

    /// The visual arrow tip of `cursorarrow` sits at (0, 0) of the rendered
    /// image's bounding box. We keep this as a constant so any future
    /// symbol swap only has to update this one place.
    private static let tipOffset = CGPoint(x: 0, y: 0)

    /// Point size used when rasterizing the symbol. A non-default weight is
    /// specified so the symbol has enough line thickness to be visible on
    /// both dark and light themes; 22pt matches the RN source's `size={22}`.
    private static let symbolPointSize: CGFloat = 22

    // MARK: Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    private func setup() {
        // The overlay must never intercept touches. The parent hit-tests on
        // its own view tree; this layer is purely decorative.
        isUserInteractionEnabled = false
        backgroundColor = .clear

        pointerImageView.isUserInteractionEnabled = false
        pointerImageView.contentMode = .topLeft
        // Use .alwaysTemplate so tint color drives the stroke color; that
        // way the pointer respects the theme's `primary` color.
        let config = UIImage.SymbolConfiguration(pointSize: Self.symbolPointSize, weight: .semibold)
        let raw = UIImage(systemName: "cursorarrow", withConfiguration: config)
        pointerImageView.image = raw?.withRenderingMode(.alwaysTemplate)
        pointerImageView.tintColor = .label
        pointerImageView.sizeToFit()
        addSubview(pointerImageView)
    }

    // MARK: Positioning

    private func updatePointerFrame() {
        // Place the image so its top-left origin (== arrow tip for
        // `cursorarrow`) is exactly at the reported point. Subtracting
        // `tipOffset` leaves room for a future symbol whose tip is not at
        // (0,0); today the offset is zero so the frame origin equals the
        // reported point.
        let size = pointerImageView.bounds.size == .zero
            ? pointerImageView.intrinsicContentSize
            : pointerImageView.bounds.size
        let origin = CGPoint(
            x: pointerPosition.x - Self.tipOffset.x,
            y: pointerPosition.y - Self.tipOffset.y
        )
        pointerImageView.frame = CGRect(origin: origin, size: size)
    }

    // MARK: Palette

    func applyPalette(_ p: Palette) {
        pointerImageView.tintColor = p.primary
    }

    // MARK: Hit testing

    /// Belt-and-braces guarantee that this view never swallows touches even
    /// if some parent flips `isUserInteractionEnabled` back on by accident.
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        return nil
    }
}
