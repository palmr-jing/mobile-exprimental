import SwiftUI
import UIKit
import CoreImage

// The Palmr watermark — one definition shared by every surface that shows or
// produces video, so the branding can't drift between what the app displays and
// what it writes to a file.
//
// Two consumers, deliberately kept side by side:
//   • `PalmrWatermark` (SwiftUI) overlays the mark on video the app *displays*
//     (Released angle tiles, the full-screen reel player).
//   • `PalmrWatermark.drawBurnIn(...)` draws the same mark with UIKit so
//     `ReelExport` can burn it into the pixels of video the app *produces*.
//
// The display overlay is presentation only — it lives in the view layer, so it
// is not present in the underlying file. Only the burn-in survives export and
// sharing. Anything rendered upstream (the released class recordings streamed
// from Storage) has to be watermarked by the pipeline that renders it; the app
// can only brand its own playback surface for those.
struct PalmrWatermark: View {
    enum Style {
        case compact   // mark only — for tiles too small to read a wordmark
        case regular   // mark + "Palmr"
    }

    var style: Style = .regular

    // The glyph's own aspect, from the asset's viewBox (198.7 × 149.55).
    static let markAspect: CGFloat = 198.7 / 149.55

    private var markHeight: CGFloat { style == .compact ? 11 : 15 }

    var body: some View {
        HStack(spacing: style == .compact ? 0 : 5) {
            Image("PalmrMark")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: markHeight * Self.markAspect, height: markHeight)
            if style == .regular {
                Text("Palmr")
                    .font(.system(size: 13, weight: .semibold))
            }
        }
        .foregroundStyle(.white.opacity(0.95))
        .shadow(color: .black.opacity(0.5), radius: 2, y: 1)
        .padding(.horizontal, style == .compact ? 5 : 8)
        .padding(.vertical, style == .compact ? 4 : 5)
        .background(.black.opacity(0.3), in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Palmr")
        .accessibilityIdentifier("palmr-watermark")
    }
}

extension View {
    /// Brand a video surface: pins the watermark to the bottom-trailing corner,
    /// clear of centred play affordances and leading-aligned caption overlays.
    func palmrWatermark(_ style: PalmrWatermark.Style = .regular,
                        inset: CGFloat = 8,
                        bottomInset: CGFloat? = nil) -> some View {
        overlay(alignment: .bottomTrailing) {
            PalmrWatermark(style: style)
                .padding(.trailing, inset)
                .padding(.bottom, bottomInset ?? inset)
                // Never intercept a tap meant for the player underneath.
                .allowsHitTesting(false)
        }
    }
}

// MARK: - Burn-in (export)

extension PalmrWatermark {
    /// Draw the watermark into the bottom-right of a `canvasSize` UIKit canvas.
    /// Sized relative to the frame so it reads the same on a 320-wide test clip
    /// and a 1080-wide reel. No-ops when the frame is too small to hold it
    /// legibly rather than drawing a clipped mark.
    static func drawBurnIn(canvasSize: CGSize) {
        guard canvasSize.width > 0, canvasSize.height > 0 else { return }

        let unit = max(18, min(canvasSize.width, canvasSize.height) * 0.055)
        let font = UIFont.systemFont(ofSize: unit * 0.86, weight: .semibold)
        let word = "PALMR" as NSString
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.white.withAlphaComponent(0.95),
        ]
        let wordSize = word.size(withAttributes: attrs)

        // The mark is optional: if the asset can't be resolved we still burn in
        // the wordmark, so an export is never left unbranded.
        let mark = whiteMark(height: unit)
        let markW = mark.map { $0.size.width } ?? 0
        let gap: CGFloat = mark == nil ? 0 : unit * 0.35
        let padX = unit * 0.5, padY = unit * 0.34

        let plateW = padX * 2 + markW + gap + wordSize.width
        let plateH = padY * 2 + max(unit, wordSize.height)
        let inset = min(canvasSize.width, canvasSize.height) * 0.035
        let plate = CGRect(x: canvasSize.width - inset - plateW,
                           y: canvasSize.height - inset - plateH,
                           width: plateW, height: plateH)
        guard plate.minX >= 0, plate.minY >= 0 else { return }

        UIColor.black.withAlphaComponent(0.32).setFill()
        UIBezierPath(roundedRect: plate, cornerRadius: plateH / 2).fill()

        var cursor = plate.minX + padX
        if let mark {
            mark.draw(in: CGRect(x: cursor, y: plate.midY - mark.size.height / 2,
                                 width: mark.size.width, height: mark.size.height),
                      blendMode: .normal, alpha: 0.95)
            cursor += mark.size.width + gap
        }
        word.draw(at: CGPoint(x: cursor, y: plate.midY - wordSize.height / 2), withAttributes: attrs)
    }

    /// The template glyph recoloured white, rendered into its own transparent
    /// canvas. It has to be isolated: a `.sourceAtop` tint applied straight to
    /// the shared canvas would repaint the plate drawn underneath it too.
    private static func whiteMark(height: CGFloat) -> UIImage? {
        guard let base = UIImage(named: "PalmrMark") else { return nil }
        let size = CGSize(width: height * markAspect, height: height)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            base.draw(in: CGRect(origin: .zero, size: size))
            ctx.cgContext.setBlendMode(.sourceAtop)
            UIColor.white.setFill()
            ctx.cgContext.fill(CGRect(origin: .zero, size: size))
        }
    }
}
