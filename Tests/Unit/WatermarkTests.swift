import Testing
import UIKit
import CoreGraphics
@testable import MobileCommander

// Pixel-level tests of the burned-in watermark. These assert on rendered output
// rather than on "the function was called", because the thing that actually
// matters — did Palmr branding land in the frame, in the right corner — is only
// observable in pixels.
struct WatermarkTests {

    @Test func burnsIntoTheBottomRightAndLeavesTheRestUntouched() throws {
        let size = CGSize(width: 320, height: 568)
        let img = Pixels.render(size: size, background: .red) {
            PalmrWatermark.drawBurnIn(canvasSize: size)
        }
        let probe = try Pixels.probe(img)
        let bg = Pixels.Color(r: 255, g: 0, b: 0)

        let bottomRight = probe.fractionDiffering(from: bg, in: probe.quadrant(.bottomRight))
        #expect(bottomRight > 0.02,
                "expected the watermark in the bottom-right, only \(bottomRight * 100)% of pixels changed")

        // Nothing may bleed into the frame the user is actually watching.
        for corner in [Pixels.Quadrant.topLeft, .topRight, .bottomLeft] {
            let changed = probe.fractionDiffering(from: bg, in: probe.quadrant(corner))
            #expect(changed < 0.001, "watermark bled into \(corner): \(changed * 100)% changed")
        }
    }

    @Test func scalesWithTheFrameSoItReadsAtAnyResolution() throws {
        // The mark should occupy roughly the same share of a small frame and a
        // large one — a fixed pixel size would be a speck on a 1080p reel.
        func coverage(_ size: CGSize) throws -> Double {
            let img = Pixels.render(size: size, background: .red) {
                PalmrWatermark.drawBurnIn(canvasSize: size)
            }
            let probe = try Pixels.probe(img)
            return probe.fractionDiffering(from: Pixels.Color(r: 255, g: 0, b: 0),
                                           in: CGRect(origin: .zero, size: size))
        }
        let small = try coverage(CGSize(width: 320, height: 568))
        let large = try coverage(CGSize(width: 1080, height: 1920))
        #expect(small > 0.005 && large > 0.005, "watermark missing at one of the sizes")
        // Same order of magnitude — proportional, not fixed.
        #expect(large > small * 0.4 && large < small * 2.5,
                "coverage should track frame size: small \(small), large \(large)")
    }

    @Test func skipsFramesTooSmallToHoldItRatherThanDrawingItClipped() throws {
        let size = CGSize(width: 40, height: 30)
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
    }

    @Test func exportOverlayRendersAtTheRequestedSize() throws {
        let size = CGSize(width: 320, height: 568)
        let overlay = try #require(VideoWatermark.makeOverlay(renderSize: size, text: "", pos: CGPoint(x: 0.5, y: 0.82)))
        #expect(overlay.extent.width == size.width)
        #expect(overlay.extent.height == size.height)
    }

    @Test func exportOverlayIsNilForAnEmptyFrame() {
        #expect(VideoWatermark.makeOverlay(renderSize: .zero, text: "hi", pos: CGPoint(x: 0.5, y: 0.5)) == nil)
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
