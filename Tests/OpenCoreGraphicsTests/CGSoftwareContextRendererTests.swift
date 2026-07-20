import Foundation
import Testing
@testable import OpenCoreGraphics

@Suite("CG software bitmap renderer")
struct CGSoftwareContextRendererTests {
    @Test("Fill writes pixels and preserves untouched pixels")
    func fillWritesPixels() throws {
        let context = try #require(CGContext(
            data: nil,
            width: 8,
            height: 8,
            bitsPerComponent: 8,
            bytesPerRow: 32,
            space: .deviceRGB,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        ))
        context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 2, y: 2, width: 4, height: 4))

        let image = try #require(context.makeImage())
        let data = try #require(image.data ?? image.dataProvider?.data)
        #expect(pixel(data, bytesPerRow: image.bytesPerRow, x: 3, y: 3) == [255, 0, 0, 255])
        #expect(pixel(data, bytesPerRow: image.bytesPerRow, x: 0, y: 0) == [0, 0, 0, 0])
    }

    @Test("Path clip restricts subsequent fill")
    func pathClip() throws {
        let context = try #require(CGContext(
            data: nil,
            width: 8,
            height: 8,
            bitsPerComponent: 8,
            bytesPerRow: 32,
            space: .deviceRGB,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        ))
        context.clip(to: CGRect(x: 0, y: 0, width: 4, height: 8))
        context.setFillColor(CGColor(red: 0, green: 1, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))

        let image = try #require(context.makeImage())
        let data = try #require(image.data ?? image.dataProvider?.data)
        #expect(pixel(data, bytesPerRow: image.bytesPerRow, x: 2, y: 4) == [0, 255, 0, 255])
        #expect(pixel(data, bytesPerRow: image.bytesPerRow, x: 6, y: 4) == [0, 0, 0, 0])
    }

    @Test("Image drawing samples source pixels")
    func imageDrawing() throws {
        let sourceData = Data([
            255, 0, 0, 255,
            0, 255, 0, 255,
        ])
        let source = try #require(CGImage(
            width: 2,
            height: 1,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: 8,
            space: .deviceRGB,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: CGDataProvider(data: sourceData),
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        ))
        let context = try #require(CGContext(
            data: nil,
            width: 4,
            height: 2,
            bitsPerComponent: 8,
            bytesPerRow: 16,
            space: .deviceRGB,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        ))
        context.setInterpolationQuality(.none)
        context.draw(source, in: CGRect(x: 0, y: 0, width: 4, height: 2))

        let image = try #require(context.makeImage())
        let data = try #require(image.data ?? image.dataProvider?.data)
        #expect(pixel(data, bytesPerRow: image.bytesPerRow, x: 0, y: 0) == [255, 0, 0, 255])
        #expect(pixel(data, bytesPerRow: image.bytesPerRow, x: 3, y: 0) == [0, 255, 0, 255])
    }

    @Test("Dashed stroke leaves gap pixels untouched")
    func dashedStroke() throws {
        let context = try #require(CGContext(
            data: nil,
            width: 12,
            height: 5,
            bitsPerComponent: 8,
            bytesPerRow: 48,
            space: .deviceRGB,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        ))
        context.setStrokeColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        context.setLineWidth(2)
        context.setLineDash(phase: 0, lengths: [3, 3])
        context.move(to: CGPoint(x: 1, y: 2.5))
        context.addLine(to: CGPoint(x: 11, y: 2.5))
        context.strokePath()

        let image = try #require(context.makeImage())
        let data = try #require(image.data ?? image.dataProvider?.data)
        #expect(pixel(data, bytesPerRow: image.bytesPerRow, x: 2, y: 2) == [255, 0, 0, 255])
        #expect(pixel(data, bytesPerRow: image.bytesPerRow, x: 5, y: 2) == [0, 0, 0, 0])
        #expect(pixel(data, bytesPerRow: image.bytesPerRow, x: 8, y: 2) == [255, 0, 0, 255])
    }

    private func pixel(_ data: Data, bytesPerRow: Int, x: Int, y: Int) -> [UInt8] {
        let offset = y * bytesPerRow + x * 4
        return Array(data[offset..<(offset + 4)])
    }
}
