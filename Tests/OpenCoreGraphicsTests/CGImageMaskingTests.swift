//
//  CGImageMaskingTests.swift
//  OpenCoreGraphics
//

import Foundation
import Testing
@testable import OpenCoreGraphics

@Suite("CGImage Masking Tests")
struct CGImageMaskingTests {
    private let rgbaInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

    @Test("Image masks apply inverse alpha and scale to the image")
    func imageMaskUsesInverseAlpha() throws {
        let image = try #require(makeRGBAImage(
            width: 2,
            height: 1,
            bytes: [255, 0, 0, 255, 0, 255, 0, 255]
        ))
        let mask = try #require(CGImage(
            maskWidth: 1,
            height: 1,
            bitsPerComponent: 8,
            bitsPerPixel: 8,
            bytesPerRow: 1,
            provider: CGDataProvider(data: Data([64])),
            decode: nil,
            shouldInterpolate: false
        ))

        let result = try #require(image.masking(mask))
        let bytes = try #require(result.data).map { $0 }
        #expect(bytes == [191, 0, 0, 191, 0, 191, 0, 191])
    }

    @Test("DeviceGray images apply direct alpha")
    func grayImageUsesDirectAlpha() throws {
        let image = try #require(makeRGBAImage(
            width: 2,
            height: 1,
            bytes: [255, 0, 0, 255, 0, 0, 255, 255]
        ))
        let graySpace = CGColorSpace.deviceGray
        let grayMask = try #require(CGImage(
            width: 2,
            height: 1,
            bitsPerComponent: 8,
            bitsPerPixel: 8,
            bytesPerRow: 2,
            space: graySpace,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
            provider: CGDataProvider(data: Data([0, 255])),
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        ))

        let result = try #require(image.masking(grayMask))
        let bytes = try #require(result.data).map { $0 }
        #expect(bytes == [0, 0, 0, 0, 0, 0, 255, 255])
    }

    @Test("Color component masking clears only matching pixels")
    func colorComponentMasking() throws {
        let image = try #require(makeRGBAImage(
            width: 2,
            height: 1,
            bytes: [255, 0, 0, 255, 0, 0, 255, 255]
        ))

        let result = try #require(image.copy(maskingColorComponents: [
            0.9, 1.0,
            0.0, 0.1,
            0.0, 0.1
        ]))
        let bytes = try #require(result.data).map { $0 }
        #expect(bytes == [0, 0, 0, 0, 0, 0, 255, 255])
    }

    @Test("Invalid mask inputs fail")
    func invalidInputsFail() throws {
        let image = try #require(makeRGBAImage(width: 1, height: 1, bytes: [255, 0, 0, 255]))
        let nonMask = try #require(makeRGBAImage(width: 1, height: 1, bytes: [255, 255, 255, 255]))

        #expect(image.masking(nonMask) == nil)
        #expect(image.copy(maskingColorComponents: [0, 1]) == nil)
        #expect(image.copy(maskingColorComponents: [1, 0, 0, 1, 0, 1]) == nil)
    }

    private func makeRGBAImage(width: Int, height: Int, bytes: [UInt8]) -> CGImage? {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: space,
            bitmapInfo: rgbaInfo,
            provider: CGDataProvider(data: Data(bytes)),
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }
}
