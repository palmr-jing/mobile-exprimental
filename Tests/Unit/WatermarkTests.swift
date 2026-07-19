import Testing
import UIKit
import CoreGraphics
@testable import MobileCommander

// Pixel-level tests of the burned-in watermark. These assert on rendered output
// rather than on "the function was called", because the thing that actually
// matters — did Palmr branding land in the frame, in the right corner — is only
// observable in pixels.
struct WatermarkTests {

    /// manage's warm white, the only colour in the LogoPair asset.
    static let warmWhite = Pixels.Color(r: 241, g: 237, b: 227)

    // The mark has to be manage's actual asset, not a re-creation of it — a
    // burned-in pipeline reel and an app overlay get seen side by side. If the
    // asset ever falls out of the catalog this fails here rather than shipping an
    // approximate fallback wordmark to TestFlight. (#1072)
    @Test func shipsManagesCombinedLogoAndWordmarkAsset() throws {
        let logo = try #require(PalmrWatermark.asset,
                                "the PalmrLogoPair asset is missing from the bundle")
        // 3115 × 624 — the leaf glyph AND the "Palmr" wordmark in one raster.
        #expect(abs(logo.size.width / logo.size.height - PalmrWatermark.aspect) < 0.01,
                "asset aspect \(logo.size.width / logo.size.height) isn't the LogoPair's")
    }

    @Test func burnsIntoTheBottomRightAndLeavesTheRestUntouched() throws {
        let size = CGSize(width: 320, height: 568)
        let img = Pixels.render(size: size, background: .red) {
            PalmrWatermark.drawBurnIn(canvasSize: size)
        }
        let probe = try Pixels.probe(img)
        let bg = Pixels.Color(r: 255, g: 0, b: 0)

        let bottomRight = probe.fractionDiffering(from: bg, in: probe.quadrant(.bottomRight))
        #expect(bottomRight > 0.005,
                "expected the watermark in the bottom-right, only \(bottomRight * 100)% of pixels changed")

        // Nothing may bleed into the frame the user is actually watching.
        for corner in [Pixels.Quadrant.topLeft, .topRight, .bottomLeft] {
            let changed = probe.fractionDiffering(from: bg, in: probe.quadrant(corner))
            #expect(changed < 0.001, "watermark bled into \(corner): \(changed * 100)% changed")
        }
    }

    // The pixels are manage's warm white (#F1EDE3), not the plain white the
    // #1067 mark used — the tell that we're stamping the real asset.
    @Test func stampsInManagesWarmWhite() throws {
        let size = CGSize(width: 1080, height: 1920)
        let img = Pixels.render(size: size, background: .black) {
            PalmrWatermark.drawBurnIn(canvasSize: size)
        }
        let probe = try Pixels.probe(img)
        let rect = try #require(PalmrWatermark.burnInRect(canvasSize: size))
        let matching = probe.fractionMatching(Self.warmWhite, in: rect, tolerance: 12)
        #expect(matching > 0.1,
                "only \(matching * 100)% of the mark is manage's warm white — wrong asset or recoloured")
    }

    // The regression this task exists for on the drawing side: #1067 drew a
    // filled black pill behind system-font text. manage stamps a transparent
    // PNG with no plate, so most of the mark's box must still be the frame
    // underneath it.
    @Test func drawsNoBackgroundPlateBehindTheMark() throws {
        let size = CGSize(width: 1080, height: 1920)
        let img = Pixels.render(size: size, background: .red) {
            PalmrWatermark.drawBurnIn(canvasSize: size)
        }
        let probe = try Pixels.probe(img)
        let rect = try #require(PalmrWatermark.burnInRect(canvasSize: size))
        let covered = probe.fractionDiffering(from: Pixels.Color(r: 255, g: 0, b: 0), in: rect)
        #expect(covered > 0.05, "nothing was drawn into the mark's rect")
        #expect(covered < 0.6,
                "\(covered * 100)% of the mark's box is opaque — that's a background plate, which manage doesn't stamp")
    }

    // Geometry is manage's `watermarkRect` (components/watermark.js): width is
    // 14% of the frame clamped to [96, 240], margin 2% clamped to [12, 32], both
    // measured from the bottom-right. Asserted on the rect directly so a drift in
    // placement fails loudly instead of hiding inside a coverage ratio.
    @Test(arguments: [
        // frame,                       expected width, expected margin
        (CGSize(width: 1080, height: 1920), CGFloat(151.2), CGFloat(21.6)),
        (CGSize(width: 1920, height: 1080), CGFloat(240),   CGFloat(32)),   // both clamped high
        (CGSize(width: 320, height: 568),   CGFloat(96),    CGFloat(12)),   // both clamped low
    ])
    func burnInGeometryMatchesManage(frame: CGSize, expectedWidth: CGFloat, expectedMargin: CGFloat) throws {
        let rect = try #require(PalmrWatermark.burnInRect(canvasSize: frame))
        #expect(abs(rect.width - expectedWidth) < 0.5, "width \(rect.width) ≠ \(expectedWidth)")
        #expect(abs(rect.height - expectedWidth / PalmrWatermark.aspect) < 0.5, "aspect not preserved")
        #expect(abs(frame.width - rect.maxX - expectedMargin) < 0.5, "trailing inset wrong")
        #expect(abs(frame.height - rect.maxY - expectedMargin) < 0.5, "bottom inset wrong")
    }

    // The displayed overlay scales with the surface it brands, so one call site
    // serves a ~107pt angle tile and a 1024pt iPad player. Below ~400pt the
    // fraction would be illegible, so it floors instead.
    @Test func displayWidthFloorsOnSmallTilesAndScalesOnLargeOnes() {
        let tile = PalmrWatermark.width(forSurfaceWidth: 107)     // Released angle tile
        #expect(tile == 56, "the mark should hold its legibility floor on a tile, got \(tile)")
        #expect(tile < 107, "the mark must not be wider than the tile it brands")

        // Above the floor it tracks manage's 14%.
        #expect(PalmrWatermark.width(forSurfaceWidth: 820) == 820 * 0.14)
        // And caps, so it can't dominate a large iPad player.
        #expect(PalmrWatermark.width(forSurfaceWidth: 4000) == 240)
    }

    @Test func skipsFramesTooSmallToHoldItRatherThanDrawingItClipped() throws {
        let size = CGSize(width: 40, height: 30)
        #expect(PalmrWatermark.burnInRect(canvasSize: size) == nil)

        let img = Pixels.render(size: size, background: .red) {
            PalmrWatermark.drawBurnIn(canvasSize: size)
        }
        let probe = try Pixels.probe(img)
        let changed = probe.fractionDiffering(from: Pixels.Color(r: 255, g: 0, b: 0),
                                              in: CGRect(origin: .zero, size: size))
        #expect(changed == 0, "a frame too small for the mark should be left alone")
    }

    @Test func zeroSizedCanvasIsANoOp() {
        // Guards the divide-by-nothing path; must not trap.
        PalmrWatermark.drawBurnIn(canvasSize: .zero)
        #expect(PalmrWatermark.burnInRect(canvasSize: .zero) == nil)
    }

    @Test func exportOverlayRendersAtTheRequestedSize() throws {
        let size = CGSize(width: 320, height: 568)
        let overlay = try #require(ReelExport.makeOverlay(renderSize: size, text: "", pos: CGPoint(x: 0.5, y: 0.82)))
        #expect(overlay.extent.width == size.width)
        #expect(overlay.extent.height == size.height)
    }

    @Test func exportOverlayIsNilForAnEmptyFrame() {
        #expect(ReelExport.makeOverlay(renderSize: .zero, text: "hi", pos: CGPoint(x: 0.5, y: 0.5)) == nil)
    }
}

// MARK: - pixel probing

enum Pixels {
    struct Color { let r: Int, g: Int, b: Int }

    enum Quadrant { case topLeft, topRight, bottomLeft, bottomRight }

    /// An RGBA8 readback of an image, with helpers to ask "what changed where".
    struct Probe {
        let data: [UInt8]
        let width: Int
        let height: Int

        func color(x: Int, y: Int) -> Color {
            let i = (y * width + x) * 4
            return Color(r: Int(data[i]), g: Int(data[i + 1]), b: Int(data[i + 2]))
        }

        func quadrant(_ q: Quadrant) -> CGRect {
            let w = CGFloat(width) / 2, h = CGFloat(height) / 2
            switch q {
            case .topLeft:     return CGRect(x: 0, y: 0, width: w, height: h)
            case .topRight:    return CGRect(x: w, y: 0, width: w, height: h)
            case .bottomLeft:  return CGRect(x: 0, y: h, width: w, height: h)
            case .bottomRight: return CGRect(x: w, y: h, width: w, height: h)
            }
        }

        /// Share of pixels in `rect` that differ from `reference` by more than
        /// `tolerance` on any channel. The tolerance absorbs H.264/YUV rounding
        /// when this is run against a decoded video frame.
        func fractionDiffering(from reference: Color, in rect: CGRect, tolerance: Int = 40) -> Double {
            let x0 = max(0, Int(rect.minX)), x1 = min(width, Int(rect.maxX))
            let y0 = max(0, Int(rect.minY)), y1 = min(height, Int(rect.maxY))
            guard x1 > x0, y1 > y0 else { return 0 }
            var changed = 0
            for y in y0..<y1 {
                for x in x0..<x1 {
                    let c = color(x: x, y: y)
                    let d = max(abs(c.r - reference.r), max(abs(c.g - reference.g), abs(c.b - reference.b)))
                    if d > tolerance { changed += 1 }
                }
            }
            return Double(changed) / Double((x1 - x0) * (y1 - y0))
        }

        /// Share of pixels in `rect` within `tolerance` of `reference` on every
        /// channel — the inverse of `fractionDiffering`, for asserting that the
        /// mark landed in a specific colour rather than merely "not the
        /// background".
        func fractionMatching(_ reference: Color, in rect: CGRect, tolerance: Int = 12) -> Double {
            let x0 = max(0, Int(rect.minX)), x1 = min(width, Int(rect.maxX))
            let y0 = max(0, Int(rect.minY)), y1 = min(height, Int(rect.maxY))
            guard x1 > x0, y1 > y0 else { return 0 }
            var hits = 0
            for y in y0..<y1 {
                for x in x0..<x1 {
                    let c = color(x: x, y: y)
                    let d = max(abs(c.r - reference.r), max(abs(c.g - reference.g), abs(c.b - reference.b)))
                    if d <= tolerance { hits += 1 }
                }
            }
            return Double(hits) / Double((x1 - x0) * (y1 - y0))
        }

        /// Share of near-white pixels in `rect` — the mark and wordmark are drawn
        /// white, and the generated test frames are fully saturated hues (always
        /// one channel at zero), so white is an unambiguous "the mark is here"
        /// signal that doesn't depend on which hue the frame happened to be.
        func fractionNearWhite(in rect: CGRect, floor: Int = 180) -> Double {
            let x0 = max(0, Int(rect.minX)), x1 = min(width, Int(rect.maxX))
            let y0 = max(0, Int(rect.minY)), y1 = min(height, Int(rect.maxY))
            guard x1 > x0, y1 > y0 else { return 0 }
            var white = 0
            for y in y0..<y1 {
                for x in x0..<x1 {
                    let c = color(x: x, y: y)
                    if c.r > floor && c.g > floor && c.b > floor { white += 1 }
                }
            }
            return Double(white) / Double((x1 - x0) * (y1 - y0))
        }

        /// The dominant colour of a region, used to learn a video frame's flat
        /// background without hardcoding which frame the generator handed back.
        func averageColor(in rect: CGRect) -> Color {
            let x0 = max(0, Int(rect.minX)), x1 = min(width, Int(rect.maxX))
            let y0 = max(0, Int(rect.minY)), y1 = min(height, Int(rect.maxY))
            var r = 0, g = 0, b = 0, n = 0
            for y in y0..<y1 {
                for x in x0..<x1 {
                    let c = color(x: x, y: y)
                    r += c.r; g += c.g; b += c.b; n += 1
                }
            }
            guard n > 0 else { return Color(r: 0, g: 0, b: 0) }
            return Color(r: r / n, g: g / n, b: b / n)
        }
    }

    /// Draw into an opaque canvas of a known colour so any change is the
    /// subject under test.
    static func render(size: CGSize, background: UIColor, _ draw: () -> Void) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            background.setFill()
            UIRectFill(CGRect(origin: .zero, size: size))
            draw()
        }
    }

    static func probe(_ image: UIImage) throws -> Probe {
        try probe(#require(image.cgImage))
    }

    /// Redraw into a known RGBA8 layout — a CGImage straight from a decoder can
    /// be any pixel format, so reading its raw bytes directly is not portable.
    static func probe(_ cg: CGImage) throws -> Probe {
        let w = cg.width, h = cg.height
        var data = [UInt8](repeating: 0, count: w * h * 4)
        let ctx = try #require(CGContext(
            data: &data, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        return Probe(data: data, width: w, height: h)
    }
}
