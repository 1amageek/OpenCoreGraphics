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

    @Test("Premultiplied contexts store premultiplied color components")
    func premultipliedStorageContract() throws {
        let context = try #require(CGContext(
            data: nil,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: .deviceRGB,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        ))
        context.setFillColor(CGColor(red: 1, green: 0.5, blue: 0.25, alpha: 0.5))
        context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))

        let image = try #require(context.makeImage())
        let data = try #require(image.data ?? image.dataProvider?.data)

        #expect(Array(data.prefix(4)) == [128, 64, 32, 128])
    }

    @Test("Extended half-float contexts preserve values and snapshot headroom")
    func extendedHalfFloatStorage() throws {
        let colorSpace = try #require(CGColorSpace(name: CGColorSpace.extendedLinearSRGB))
        let context = try #require(CGContext(
            data: nil,
            width: 1,
            height: 1,
            bitsPerComponent: 16,
            bytesPerRow: 8,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(
                alpha: .premultipliedLast,
                component: .float,
                byteOrder: .order16Little
            )
        ))
        #expect(context.setEDRTargetHeadroom(4))
        context.setFillColor(try #require(CGColor(
            colorSpace: colorSpace,
            components: [2, 0.5, 0.25, 0.5]
        )))
        context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))

        let image = try #require(context.makeImage())
        let data = try #require(image.data ?? image.dataProvider?.data)

        #expect(image.contentHeadroom == 4)
        #expect(halfFloatComponents(in: data) == [1, 0.25, 0.125, 0.5])
    }

    @Test("Gray8 contexts write monochrome samples")
    func gray8Storage() throws {
        let context = try #require(CGContext(
            data: nil,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 1,
            space: .deviceGray,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)
        ))
        context.setFillColor(CGColor(gray: 0.5, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))

        let image = try #require(context.makeImage())
        let data = try #require(image.data ?? image.dataProvider?.data)

        #expect(data.first == 128)
    }

    @Test("Alpha-only contexts write source alpha without color storage")
    func alphaOnlyStorage() throws {
        let context = try #require(CGContext(
            data: nil,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 1,
            space: .deviceRGB,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.alphaOnly.rawValue)
        ))
        context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 0.5))
        context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))

        let image = try #require(context.makeImage())
        let data = try #require(image.data ?? image.dataProvider?.data)

        #expect(data.first == 128)
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

    @Test("Image drawing preserves extended half-float source pixels")
    func extendedHalfFloatImageDrawing() throws {
        let colorSpace = try #require(CGColorSpace(name: CGColorSpace.extendedLinearSRGB))
        let bitmapInfo = CGBitmapInfo(
            alpha: .premultipliedLast,
            component: .float,
            byteOrder: .order16Little
        )
        let source = try #require(CGImage(
            headroom: 4,
            width: 1,
            height: 1,
            bitsPerComponent: 16,
            bitsPerPixel: 64,
            bytesPerRow: 8,
            space: colorSpace,
            bitmapInfo: bitmapInfo,
            provider: CGDataProvider(data: halfFloatData([1, 0.25, 0.125, 0.5])),
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        ))
        let context = try #require(CGContext(
            data: nil,
            width: 1,
            height: 1,
            bitsPerComponent: 16,
            bytesPerRow: 8,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ))
        #expect(context.setEDRTargetHeadroom(4))
        context.setInterpolationQuality(.none)
        context.draw(source, in: CGRect(x: 0, y: 0, width: 1, height: 1))

        let image = try #require(context.makeImage())
        let data = try #require(image.data ?? image.dataProvider?.data)

        #expect(halfFloatComponents(in: data) == [1, 0.25, 0.125, 0.5])
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

    private func halfFloatComponents(in data: Data) -> [Float16] {
        data.withUnsafeBytes { bytes in
            (0..<(data.count / 2)).map { index in
                let offset = index * 2
                let bits = UInt16(bytes[offset]) | UInt16(bytes[offset + 1]) << 8
                return Float16(bitPattern: bits)
            }
        }
    }

    private func halfFloatData(_ components: [Float16]) -> Data {
        var result = Data()
        result.reserveCapacity(components.count * 2)
        for component in components {
            let bits = component.bitPattern
            result.append(UInt8(truncatingIfNeeded: bits))
            result.append(UInt8(truncatingIfNeeded: bits >> 8))
        }
        return result
    }
}
