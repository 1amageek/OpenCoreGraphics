//
//  CGImageTests.swift
//  OpenCoreGraphics
//
//  Tests for CGImage and related types
//

import Foundation
import Testing
@testable import OpenCoreGraphics

// Type aliases to avoid ambiguity with CoreFoundation types on macOS
private typealias CGFloat = OpenCoreGraphics.CGFloat
private typealias CGImage = OpenCoreGraphics.CGImage
private typealias CGImageAlphaInfo = OpenCoreGraphics.CGImageAlphaInfo
private typealias CGImageByteOrderInfo = OpenCoreGraphics.CGImageByteOrderInfo
private typealias CGImagePixelFormatInfo = OpenCoreGraphics.CGImagePixelFormatInfo
private typealias CGColorSpace = OpenCoreGraphics.CGColorSpace
private typealias CGBitmapInfo = OpenCoreGraphics.CGBitmapInfo
private typealias CGDataProvider = OpenCoreGraphics.CGDataProvider
private typealias CGColorRenderingIntent = OpenCoreGraphics.CGColorRenderingIntent
private typealias CGRect = OpenCoreGraphics.CGRect

// MARK: - CGImageAlphaInfo Tests

@Suite("CGImageAlphaInfo Tests")
struct CGImageAlphaInfoTests {

    @Test("Raw values")
    func rawValues() {
        #expect(CGImageAlphaInfo.none.rawValue == 0)
        #expect(CGImageAlphaInfo.premultipliedLast.rawValue == 1)
        #expect(CGImageAlphaInfo.premultipliedFirst.rawValue == 2)
        #expect(CGImageAlphaInfo.last.rawValue == 3)
        #expect(CGImageAlphaInfo.first.rawValue == 4)
        #expect(CGImageAlphaInfo.noneSkipLast.rawValue == 5)
        #expect(CGImageAlphaInfo.noneSkipFirst.rawValue == 6)
        #expect(CGImageAlphaInfo.alphaOnly.rawValue == 7)
    }

    @Test("Init from raw value")
    func initFromRawValue() {
        #expect(CGImageAlphaInfo(rawValue: 0) == CGImageAlphaInfo.none)
        #expect(CGImageAlphaInfo(rawValue: 1) == .premultipliedLast)
        #expect(CGImageAlphaInfo(rawValue: 7) == .alphaOnly)
        #expect(CGImageAlphaInfo(rawValue: 100) == nil)
    }

    @Test("CaseIterable conformance")
    func caseIterable() {
        let allCases = CGImageAlphaInfo.allCases
        #expect(allCases.count == 8)
    }
}

// MARK: - CGImageByteOrderInfo Tests

@Suite("CGImageByteOrderInfo Tests")
struct CGImageByteOrderInfoTests {

    @Test("Raw values")
    func rawValues() {
        #expect(CGImageByteOrderInfo.orderDefault.rawValue == 0)
        #expect(CGImageByteOrderInfo.order16Little.rawValue == 4096)  // 1 << 12
        #expect(CGImageByteOrderInfo.order32Little.rawValue == 8192)  // 2 << 12
        #expect(CGImageByteOrderInfo.order16Big.rawValue == 12288)    // 3 << 12
        #expect(CGImageByteOrderInfo.order32Big.rawValue == 16384)    // 4 << 12
    }

    @Test("Order mask")
    func orderMask() {
        #expect(CGImageByteOrderInfo.orderMask.rawValue == 0x7000)
    }

    @Test("Init from raw value")
    func initFromRawValue() {
        #expect(CGImageByteOrderInfo(rawValue: 0) == .orderDefault)
        #expect(CGImageByteOrderInfo(rawValue: 4096) == .order16Little)
        #expect(CGImageByteOrderInfo(rawValue: 8192) == .order32Little)
    }
}

// MARK: - CGImagePixelFormatInfo Tests

@Suite("CGImagePixelFormatInfo Tests")
struct CGImagePixelFormatInfoTests {

    @Test("Raw values")
    func rawValues() {
        #expect(CGImagePixelFormatInfo.packed.rawValue == 0)
        #expect(CGImagePixelFormatInfo.RGB555.rawValue == 65536)   // 1 << 16
        #expect(CGImagePixelFormatInfo.RGB565.rawValue == 131072)  // 2 << 16
        #expect(CGImagePixelFormatInfo.RGB101010.rawValue == 196608)  // 3 << 16
        #expect(CGImagePixelFormatInfo.RGBCIF10.rawValue == 262144)   // 4 << 16
    }

    @Test("Pixel format mask")
    func pixelFormatMask() {
        #expect(CGImagePixelFormatInfo.mask.rawValue == 0xF0000)
    }
}

// MARK: - CGImage Tests

@Suite("CGImage Tests")
struct CGImageTests {

    // MARK: - Helper Methods

    fileprivate func createTestDataProvider(width: Int, height: Int, bytesPerPixel: Int = 4) -> CGDataProvider {
        let dataSize = width * height * bytesPerPixel
        let data = Data(repeating: 128, count: dataSize)
        return CGDataProvider(data: data)
    }

    // MARK: - Initialization Tests

    @Suite("Initialization")
    struct InitializationTests {

        fileprivate func createTestDataProvider(width: Int, height: Int, bytesPerPixel: Int = 4) -> CGDataProvider {
            let dataSize = width * height * bytesPerPixel
            let data = Data(repeating: 128, count: dataSize)
            return CGDataProvider(data: data)
        }

        @Test("Init with valid parameters")
        func initWithValidParameters() {
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let provider = createTestDataProvider(width: 100, height: 100)
            let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

            let image = CGImage(
                width: 100,
                height: 100,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: 400,
                space: colorSpace,
                bitmapInfo: bitmapInfo,
                provider: provider,
                decode: nil,
                shouldInterpolate: true,
                intent: .defaultIntent
            )

            #expect(image != nil)
            #expect(image?.width == 100)
            #expect(image?.height == 100)
            #expect(image?.bitsPerComponent == 8)
            #expect(image?.bitsPerPixel == 32)
        }

        @Test("Init with zero width returns nil")
        func initWithZeroWidth() {
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let provider = createTestDataProvider(width: 1, height: 100)
            let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

            let image = CGImage(
                width: 0,
                height: 100,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: bitmapInfo,
                provider: provider,
                decode: nil,
                shouldInterpolate: true,
                intent: .defaultIntent
            )

            #expect(image == nil)
        }

        @Test("Init with zero height returns nil")
        func initWithZeroHeight() {
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let provider = createTestDataProvider(width: 100, height: 1)
            let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

            let image = CGImage(
                width: 100,
                height: 0,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: 400,
                space: colorSpace,
                bitmapInfo: bitmapInfo,
                provider: provider,
                decode: nil,
                shouldInterpolate: true,
                intent: .defaultIntent
            )

            #expect(image == nil)
        }

        @Test("Init with HDR headroom")
        func initWithHDRHeadroom() {
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let provider = createTestDataProvider(width: 100, height: 100)
            let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

            let image = CGImage(
                headroom: 2.0,
                width: 100,
                height: 100,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: 400,
                space: colorSpace,
                bitmapInfo: bitmapInfo,
                provider: provider,
                decode: nil,
                shouldInterpolate: true,
                intent: .defaultIntent
            )

            #expect(image != nil)
            #expect(image?.contentHeadroom == 2.0)
            #expect(image?.shouldToneMap == true)
        }

        @Test("Init with invalid headroom returns nil")
        func initWithInvalidHeadroom() {
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let provider = createTestDataProvider(width: 100, height: 100)
            let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

            let image = CGImage(
                headroom: 0.5,  // Less than 1.0 is invalid
                width: 100,
                height: 100,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: 400,
                space: colorSpace,
                bitmapInfo: bitmapInfo,
                provider: provider,
                decode: nil,
                shouldInterpolate: true,
                intent: .defaultIntent
            )

            #expect(image == nil)
        }

        @Test("Init mask")
        func initMask() {
            let provider = createTestDataProvider(width: 100, height: 100, bytesPerPixel: 1)

            let mask = CGImage(
                maskWidth: 100,
                height: 100,
                bitsPerComponent: 8,
                bitsPerPixel: 8,
                bytesPerRow: 100,
                provider: provider,
                decode: nil,
                shouldInterpolate: true
            )

            #expect(mask != nil)
            #expect(mask?.isMask == true)
            #expect(mask?.colorSpace == nil)
        }
    }

    // MARK: - Properties Tests

    @Suite("Properties")
    struct PropertiesTests {

        fileprivate func createTestImage() -> CGImage? {
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let dataSize = 100 * 100 * 4
            let data = Data(repeating: 128, count: dataSize)
            let provider = CGDataProvider(data: data)
            let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

            return CGImage(
                width: 100,
                height: 100,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: 400,
                space: colorSpace,
                bitmapInfo: bitmapInfo,
                provider: provider,
                decode: nil,
                shouldInterpolate: true,
                intent: .defaultIntent
            )
        }

        @Test("Alpha info property")
        func alphaInfoProperty() {
            let image = createTestImage()
            #expect(image?.alphaInfo == .premultipliedLast)
        }

        @Test("Should interpolate property")
        func shouldInterpolateProperty() {
            let image = createTestImage()
            #expect(image?.shouldInterpolate == true)
        }

        @Test("Rendering intent property")
        func renderingIntentProperty() {
            let image = createTestImage()
            #expect(image?.renderingIntent == .defaultIntent)
        }

        @Test("Is mask property for non-mask")
        func isMaskPropertyForNonMask() {
            let image = createTestImage()
            #expect(image?.isMask == false)
        }

        @Test("Color space property")
        func colorSpaceProperty() {
            let image = createTestImage()
            #expect(image?.colorSpace?.model == .rgb)
        }

        @Test("Content headroom default value")
        func contentHeadroomDefault() {
            let image = createTestImage()
            #expect(image?.contentHeadroom == 1.0)
        }

        @Test("Should tone map for SDR content")
        func shouldToneMapSDR() {
            let image = createTestImage()
            #expect(image?.shouldToneMap == false)
        }
    }

    // MARK: - Copy Tests

    @Suite("Copy Operations")
    struct CopyTests {

        fileprivate func createTestImage() -> CGImage? {
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let dataSize = 100 * 100 * 4
            let data = Data(repeating: 128, count: dataSize)
            let provider = CGDataProvider(data: data)
            let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

            return CGImage(
                width: 100,
                height: 100,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: 400,
                space: colorSpace,
                bitmapInfo: bitmapInfo,
                provider: provider,
                decode: nil,
                shouldInterpolate: true,
                intent: .defaultIntent
            )
        }

        @Test("Copy image")
        func copyImage() {
            let original = createTestImage()
            let copy = original?.copy()

            #expect(copy != nil)
            #expect(copy?.width == original?.width)
            #expect(copy?.height == original?.height)
        }

        @Test("Copy with different color space")
        func copyWithColorSpace() {
            let original = createTestImage()
            let graySpace = CGColorSpaceCreateDeviceGray()
            let copy = original?.copy(colorSpace: graySpace)

            #expect(copy != nil)
            #expect(copy?.colorSpace?.model == .monochrome)
        }

        @Test("Copy mask with color space returns nil")
        func copyMaskWithColorSpace() {
            let dataSize = 100 * 100
            let data = Data(repeating: 128, count: dataSize)
            let provider = CGDataProvider(data: data)

            let mask = CGImage(
                maskWidth: 100,
                height: 100,
                bitsPerComponent: 8,
                bitsPerPixel: 8,
                bytesPerRow: 100,
                provider: provider,
                decode: nil,
                shouldInterpolate: true
            )

            let rgbSpace = CGColorSpaceCreateDeviceRGB()
            let copy = mask?.copy(colorSpace: rgbSpace)

            #expect(copy == nil)
        }

        @Test("Copy with content average light level")
        func copyWithContentAverageLightLevel() {
            let original = createTestImage()
            let copy = original?.copy(contentAverageLightLevel: 150.0)

            #expect(copy != nil)
            #expect(copy?.contentAverageLightLevel == 150.0)
        }
    }

    // MARK: - Cropping Tests

    @Suite("Cropping")
    struct CroppingTests {

        fileprivate func createTestImage() -> CGImage? {
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let dataSize = 100 * 100 * 4
            let data = Data(repeating: 128, count: dataSize)
            let provider = CGDataProvider(data: data)
            let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

            return CGImage(
                width: 100,
                height: 100,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: 400,
                space: colorSpace,
                bitmapInfo: bitmapInfo,
                provider: provider,
                decode: nil,
                shouldInterpolate: true,
                intent: .defaultIntent
            )
        }

        @Test("Crop to valid rect")
        func cropToValidRect() {
            let image = createTestImage()
            let cropRect = CGRect(x: 10, y: 10, width: 50, height: 50)
            let cropped = image?.cropping(to: cropRect)

            #expect(cropped != nil)
            #expect(cropped?.width == 50)
            #expect(cropped?.height == 50)
        }

        @Test("Crop to rect outside bounds returns nil")
        func cropOutsideBounds() {
            let image = createTestImage()
            let cropRect = CGRect(x: 90, y: 90, width: 50, height: 50)
            let cropped = image?.cropping(to: cropRect)

            #expect(cropped == nil)
        }

        @Test("Crop with negative origin returns nil")
        func cropNegativeOrigin() {
            let image = createTestImage()
            let cropRect = CGRect(x: -10, y: 10, width: 50, height: 50)
            let cropped = image?.cropping(to: cropRect)

            #expect(cropped == nil)
        }

        @Test("Crop to zero size returns nil")
        func cropZeroSize() {
            let image = createTestImage()
            let cropRect = CGRect(x: 10, y: 10, width: 0, height: 50)
            let cropped = image?.cropping(to: cropRect)

            #expect(cropped == nil)
        }
    }

    // MARK: - Data Provider Tests

    @Suite("Data Provider")
    struct DataProviderTests {

        @Test("Get data provider from image")
        func getDataProvider() {
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let dataSize = 100 * 100 * 4
            let data = Data(repeating: 128, count: dataSize)
            let provider = CGDataProvider(data: data)
            let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

            let image = CGImage(
                width: 100,
                height: 100,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: 400,
                space: colorSpace,
                bitmapInfo: bitmapInfo,
                provider: provider,
                decode: nil,
                shouldInterpolate: true,
                intent: .defaultIntent
            )

            #expect(image?.dataProvider != nil)
        }
    }

    // MARK: - Equatable Tests

    @Suite("Equatable Conformance")
    struct EquatableTests {

        fileprivate func createTestImage() -> CGImage? {
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let dataSize = 100 * 100 * 4
            let data = Data(repeating: 128, count: dataSize)
            let provider = CGDataProvider(data: data)
            let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

            return CGImage(
                width: 100,
                height: 100,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: 400,
                space: colorSpace,
                bitmapInfo: bitmapInfo,
                provider: provider,
                decode: nil,
                shouldInterpolate: true,
                intent: .defaultIntent
            )
        }

        @Test("Same instance is equal")
        func sameInstanceEqual() {
            let image = createTestImage()
            #expect(image == image)
        }

        @Test("Different instances are not equal")
        func differentInstancesNotEqual() {
            let image1 = createTestImage()
            let image2 = createTestImage()
            #expect(image1 != image2)
        }
    }

    // MARK: - Hashable Tests

    @Suite("Hashable Conformance")
    struct HashableTests {

        fileprivate func createTestImage() -> CGImage? {
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let dataSize = 100 * 100 * 4
            let data = Data(repeating: 128, count: dataSize)
            let provider = CGDataProvider(data: data)
            let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

            return CGImage(
                width: 100,
                height: 100,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: 400,
                space: colorSpace,
                bitmapInfo: bitmapInfo,
                provider: provider,
                decode: nil,
                shouldInterpolate: true,
                intent: .defaultIntent
            )
        }

        @Test("Can be used in Set")
        func setUsage() {
            var set = Set<CGImage>()
            if let image1 = createTestImage(), let image2 = createTestImage() {
                set.insert(image1)
                set.insert(image2)
                set.insert(image1)  // Duplicate
                #expect(set.count == 2)
            }
        }
    }
}
