import SwiftUI
import UIKit
import CoreImage

// The Palmr watermark — one definition shared by every surface that shows or
// produces video, so the branding can't drift between what the app displays and
// what it writes to a file.
//
// The mark is manage.everbot.org's, not a re-creation of it. manage and the
// video-pipe reel pipeline both stamp a single combined "LogoPair" raster —
// leaf glyph AND the "Palmr" wordmark in one warm-white (#F1EDE3) PNG, bottom
// right, fully opaque, on no background plate. The asset here is a byte-for-byte
// copy of `everbot-manage/public/palmr-watermark.png`. Do NOT substitute a
// system-font "Palmr" or redraw the leaf: a burned-in reel from the pipeline and
// an app-side overlay are regularly seen side by side, and any drift shows.
// (#1072 — the #1067 mark was a semibold system font on a black pill, which is
// not what manage stamps.)
//
// Geometry is manage's `components/watermark.js` verbatim: width is a fraction
// of the frame, clamped; margin likewise; both axes equal.
//
// Two consumers, deliberately kept side by side:
//   • `PalmrWatermark` (SwiftUI) overlays the mark on video the app *displays*
//     (Released angle tiles, the Released full-screen viewer, the reel player).
//   • `PalmrWatermark.drawBurnIn(...)` draws the same mark with UIKit so
//     `ReelExport` can burn it into the pixels of video the app *produces*.
//
// The display overlay is presentation only — it lives in the view layer, so it
// is not present in the underlying file. Only the burn-in survives export and
// sharing. Anything rendered upstream (the released class recordings streamed
// from Storage) has to be watermarked by the pipeline that renders it; the app
// can only brand its own playback surface for those.
struct PalmrWatermark: View {
    /// The combined mark's aspect, from the asset's pixel dimensions (3115 × 624).
    static let aspect: CGFloat = 3115.0 / 624.0

    /// The width of the branded surface. The mark is sized from it, so the same
    /// view reads correctly on a ~107pt angle tile and a 1024pt iPad player.
    let surfaceWidth: CGFloat

    var body: some View {
        let w = Self.width(forSurfaceWidth: surfaceWidth)
        logo
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fit)
            .frame(width: w, height: w / Self.aspect)
            // manage stamps at full opacity with no plate and no shadow. Matching
            // that is the point of this task, so resist adding either back for
            // contrast — it would no longer be the same mark.
            .opacity(1)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Palmr")
            .accessibilityIdentifier("palmr-watermark")
    }

    // Concrete `Image`, not a `some View`: `.resizable()`/`.interpolation()` are
    // Image-only modifiers, so an erased or conditional view wouldn't compile.
    private var logo: Image {
        Self.asset.map(Image.init(uiImage:)) ?? Image("PalmrLogoPair")
    }

    // MARK: - asset

    /// Resolves the LogoPair from the bundle that actually carries it.
    ///
    /// `UIImage(named:)` searches `Bundle.main`, which is the app when the app is
    /// running but the *xctest runner* under the host-less unit-test bundle — so
    /// a main-bundle-only lookup silently returns nil there and the pixel tests
    /// would end up asserting on the fallback wordmark instead of the real mark.
    /// Falling back to the bundle this code was compiled into keeps the tests
    /// honest without changing production behaviour.
    static let asset: UIImage? = UIImage(named: "PalmrLogoPair")
        ?? UIImage(named: "PalmrLogoPair", in: Bundle(for: BundleToken.self), compatibleWith: nil)

    private final class BundleToken {}

    // MARK: - geometry (manage's `watermarkRect`, in points)

    static let widthFraction: CGFloat = 0.14
    static let marginFraction: CGFloat = 0.02

    /// Mark width for a displayed surface, in points.
    ///
    /// manage clamps to [96, 240] *video pixels* on a ≥1080-wide frame. Carrying
    /// those numbers into point space would make the mark 90% as wide as a 107pt
    /// angle tile, so the display floor is the smallest width at which the
    /// wordmark still reads (56pt ⇒ 11.2pt tall, the height the #1067 mark-only
    /// badge occupied). The fraction is manage's and takes over above ~400pt.
    static func width(forSurfaceWidth surfaceWidth: CGFloat) -> CGFloat {
        min(max(surfaceWidth * widthFraction, 56), 240)
    }

    /// Inset from the trailing and bottom edges, in points.
    static func margin(forSurfaceWidth surfaceWidth: CGFloat) -> CGFloat {
        min(max(surfaceWidth * marginFraction, 6), 32)
    }
}

extension View {
    /// Brand a video surface: pins the watermark to the bottom-trailing corner,
    /// clear of centred play affordances and leading-aligned caption overlays —
    /// the same corner manage and the reel pipeline stamp.
    ///
    /// `bottomInset` overrides only the bottom edge, for surfaces with their own
    /// chrome down there (the full-screen reel player's home indicator).
    func palmrWatermark(bottomInset: CGFloat? = nil) -> some View {
        overlay {
            // GeometryReader, not a fixed size: the mark scales with the surface
            // it brands, so one call site works on an angle tile and on an iPad
            // full-screen player. It reads the overlay's size and never feeds
            // back into the parent's layout.
            GeometryReader { proxy in
                let inset = PalmrWatermark.margin(forSurfaceWidth: proxy.size.width)
                PalmrWatermark(surfaceWidth: proxy.size.width)
                    .padding(.trailing, inset)
                    .padding(.bottom, bottomInset ?? inset)
                    .frame(width: proxy.size.width, height: proxy.size.height,
                           alignment: .bottomTrailing)
            }
            // Never intercept a tap meant for the player underneath.
            .allowsHitTesting(false)
        }
    }
}

// MARK: - Burn-in (export)

extension PalmrWatermark {
    /// Draw the watermark into the bottom-right of a `canvasSize` UIKit canvas,
    /// using manage's pixel-space geometry so an app-exported reel and a
    /// pipeline-published one carry the mark at the same size and inset.
    /// No-ops when the frame is too small to hold it legibly rather than drawing
    /// a clipped mark.
    static func drawBurnIn(canvasSize: CGSize) {
        guard canvasSize.width > 0, canvasSize.height > 0 else { return }
        guard let rect = burnInRect(canvasSize: canvasSize) else { return }

        // The mark is optional: if the asset can't be resolved we still burn in a
        // wordmark, so an export is never left unbranded.
        if let logo = asset {
            logo.draw(in: rect, blendMode: .normal, alpha: 1)
        } else {
            drawFallbackWordmark(in: rect)
        }
    }

    /// Where the mark lands on a `canvasSize` canvas, or nil if the canvas is too
    /// small to hold it. Split out from the drawing so the geometry contract can
    /// be asserted directly rather than inferred from pixels.
    static func burnInRect(canvasSize: CGSize) -> CGRect? {
        guard canvasSize.width > 0, canvasSize.height > 0 else { return nil }

        // manage's clamps, in the canvas's own pixel space.
        let w = min(max(canvasSize.width * widthFraction, 96), 240)
        let h = w / aspect
        let margin = min(max(canvasSize.width * marginFraction, 12), 32)

        let rect = CGRect(x: canvasSize.width - w - margin,
                          y: canvasSize.height - h - margin,
                          width: w, height: h)
        guard rect.minX >= 0, rect.minY >= 0 else { return nil }
        return rect
    }

    /// Last resort when the asset is missing from the bundle: the wordmark alone,
    /// in the same warm white, fitted to the rect the raster would have filled.
    /// An unbranded export is worse than an approximate mark.
    private static func drawFallbackWordmark(in rect: CGRect) {
        let word = "Palmr" as NSString
        // The asset's cap height is ~81% of its height; match it so the fallback
        // occupies the same optical space.
        let font = UIFont.systemFont(ofSize: rect.height * 0.81, weight: .semibold)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor(red: 241 / 255, green: 237 / 255, blue: 227 / 255, alpha: 1),
        ]
        let size = word.size(withAttributes: attrs)
        word.draw(at: CGPoint(x: rect.maxX - size.width, y: rect.midY - size.height / 2),
                  withAttributes: attrs)
    }
}
