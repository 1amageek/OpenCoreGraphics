//
//  CGColorConversionInfoTests.swift
//  OpenCoreGraphics
//
//  Tests for CGColorConversionInfo, CGColorConversionInfoTransformType,
//  CGToneMapping, and CGColorBufferFormat
//

import Foundation
import Testing
@testable import OpenCoreGraphics

// Type aliases to avoid ambiguity with CoreFoundation types on macOS
private typealias CGFloat = Foundation.CGFloat
private typealias CGColorSpace = OpenCoreGraphics.CGColorSpace
private typealias CGColorConversionInfo = OpenCoreGraphics.CGColorConversionInfo
private typealias CGColorConversionInfoTransformType = OpenCoreGraphics.CGColorConversionInfoTransformType
private typealias CGToneMapping = OpenCoreGraphics.CGToneMapping
private typealias CGColorBufferFormat = OpenCoreGraphics.CGColorBufferFormat
private typealias CGBitmapInfo = OpenCoreGraphics.CGBitmapInfo

// MARK: - CGColorConversionInfoTransformType Tests

@Suite("CGColorConversionInfoTransformType Tests")
struct CGColorConversionInfoTransformTypeTests {

    @Test("Raw values")
    func rawValues() {
        #expect(CGColorConversionInfoTransformType.transformFromSpace.rawValue == 0)
        #expect(CGColorConversionInfoTransformType.transformToSpace.rawValue == 1)
        #expect(CGColorConversionInfoTransformType.transformApplySpace.rawValue == 2)
    }

    @Test("Init from raw value")
    func initFromRawValue() {
        #expect(CGColorConversionInfoTransformType(rawValue: 0) == .transformFromSpace)
        #expect(CGColorConversionInfoTransformType(rawValue: 1) == .transformToSpace)
        #expect(CGColorConversionInfoTransformType(rawValue: 2) == .transformApplySpace)
        #expect(CGColorConversionInfoTransformType(rawValue: 100) == nil)
    }

    @Test("Sendable conformance")
    func sendableConformance() async {
        let type = CGColorConversionInfoTransformType.transformFromSpace
        let task = Task {
            return type
        }
        let result = await task.value
        #expect(result == .transformFromSpace)
    }
}

// MARK: - CGToneMapping Tests

@Suite("CGToneMapping Tests")
struct CGToneMappingTests {

    @Test("Raw values")
    func rawValues() {
        #expect(CGToneMapping.default.rawValue == 0)
        #expect(CGToneMapping.none.rawValue == 1)
        #expect(CGToneMapping.acesFilmic.rawValue == 2)
        #expect(CGToneMapping.iturBt2390.rawValue == 3)
        #expect(CGToneMapping.exponentialRolloff.rawValue == 4)
    }

    @Test("Init from raw value")
    func initFromRawValue() {
        #expect(CGToneMapping(rawValue: 0) == .default)
        #expect(CGToneMapping(rawValue: 1) == CGToneMapping.none)
        #expect(CGToneMapping(rawValue: 2) == .acesFilmic)
        #expect(CGToneMapping(rawValue: 3) == .iturBt2390)
        #expect(CGToneMapping(rawValue: 4) == .exponentialRolloff)
        #expect(CGToneMapping(rawValue: 100) == nil)
    }

    @Test("Sendable conformance")
    func sendableConformance() async {
        let mapping = CGToneMapping.acesFilmic
        let task = Task {
            return mapping
        }
        let result = await task.value
        #expect(result == .acesFilmic)
    }
}

// MARK: - CGColorBufferFormat Tests

@Suite("CGColorBufferFormat Tests")
struct CGColorBufferFormatTests {

    @Suite("Initialization")
    struct InitializationTests {

        @Test("Empty initialization")
        func emptyInitialization() {
            let format = CGColorBufferFormat()

            #expect(format.version == 0)
            #expect(format.bitmapInfo.isEmpty)
            #expect(format.bitsPerComponent == 0)
            #expect(format.bitsPerPixel == 0)
            #expect(format.bytesPerRow == 0)
        }

        @Test("Default version initialization")
        func defaultVersionInit() {
            let format = CGColorBufferFormat(
                version: 0,
                bitmapInfo: CGBitmapInfo.byteOrder32Little,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: 1024
            )

            #expect(format.version == 0)
            #expect(format.bitsPerComponent == 8)
            #expect(format.bitsPerPixel == 32)
            #expect(format.bytesPerRow == 1024)
        }

        @Test("Full initialization")
        func fullInit() {
            let format = CGColorBufferFormat(
                version: 1,
                bitmapInfo: [.byteOrder32Big, .floatComponents],
                bitsPerComponent: 16,
                bitsPerPixel: 64,
                bytesPerRow: 2048
            )

            #expect(format.version == 1)
            #expect(format.bitsPerComponent == 16)
            #expect(format.bitsPerPixel == 64)
            #expect(format.bytesPerRow == 2048)
        }
    }

    @Suite("Properties")
    struct PropertiesTests {

        @Test("Bitmap info contains options")
        func bitmapInfoContainsOptions() {
            let format = CGColorBufferFormat(
                version: 0,
                bitmapInfo: [.byteOrder32Little, .floatComponents],
                bitsPerComponent: 32,
                bitsPerPixel: 128,
                bytesPerRow: 4096
            )

            #expect(format.bitmapInfo.contains(.byteOrder32Little))
            #expect(format.bitmapInfo.contains(.floatComponents))
        }

        @Test("Common 8-bit RGBA format")
        func common8BitRGBAFormat() {
            let format = CGColorBufferFormat(
                version: 0,
                bitmapInfo: .byteOrder32Little,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: 256 * 4
            )

            #expect(format.bitsPerComponent == 8)
            #expect(format.bitsPerPixel == 32)
            #expect(format.bytesPerRow == 1024)
        }
    }

    @Test("Sendable conformance")
    func sendableConformance() async {
        let format = CGColorBufferFormat(
            version: 0,
            bitmapInfo: .byteOrderDefault,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: 1024
        )

        let task = Task {
            return format
        }
        let result = await task.value
        #expect(result.bitsPerComponent == 8)
    }
}

// MARK: - CGColorConversionInfo Tests

@Suite("CGColorConversionInfo Tests")
struct CGColorConversionInfoTests {

    @Suite("Initialization")
    struct InitializationTests {

        @Test("Init with source and destination color spaces")
        func initWithSrcDst() {
            let src = CGColorSpace(name: CGColorSpace.sRGB)!
            let dst = CGColorSpace(name: CGColorSpace.genericGrayGamma2_2)!

            let info = CGColorConversionInfo(src: src, dst: dst)

            #expect(info != nil)
            #expect(info?.sourceColorSpace == src)
            #expect(info?.destinationColorSpace == dst)
            #expect(info?.intent == .defaultIntent)
        }

        @Test("Init with options")
        func initWithOptions() {
            let src = CGColorSpace(name: CGColorSpace.sRGB)!
            let dst = CGColorSpace(name: CGColorSpace.genericCMYK)!
            let options: [String: Any] = ["key": "value"]

            let info = CGColorConversionInfo(optionsSrc: src, dst: dst, options: options)

            #expect(info != nil)
            #expect(info?.sourceColorSpace == src)
            #expect(info?.destinationColorSpace == dst)
        }

        @Test("Init with nil options")
        func initWithNilOptions() {
            let src = CGColorSpace(name: CGColorSpace.sRGB)!
            let dst = CGColorSpace(name: CGColorSpace.genericGrayGamma2_2)!

            let info = CGColorConversionInfo(optionsSrc: src, dst: dst, options: nil)

            #expect(info != nil)
        }
    }

    @Suite("Properties")
    struct PropertiesTests {

        @Test("Source color space property")
        func sourceColorSpace() {
            let src = CGColorSpace(name: CGColorSpace.sRGB)!
            let dst = CGColorSpace(name: CGColorSpace.genericGrayGamma2_2)!
            let info = CGColorConversionInfo(src: src, dst: dst)

            #expect(info?.sourceColorSpace == src)
        }

        @Test("Destination color space property")
        func destinationColorSpace() {
            let src = CGColorSpace(name: CGColorSpace.sRGB)!
            let dst = CGColorSpace(name: CGColorSpace.genericGrayGamma2_2)!
            let info = CGColorConversionInfo(src: src, dst: dst)

            #expect(info?.destinationColorSpace == dst)
        }

        @Test("Intent property")
        func intentProperty() {
            let src = CGColorSpace(name: CGColorSpace.sRGB)!
            let dst = CGColorSpace(name: CGColorSpace.genericGrayGamma2_2)!
            let info = CGColorConversionInfo(src: src, dst: dst)

            #expect(info?.intent == .defaultIntent)
        }

    }

    @Suite("Equatable Conformance")
    struct EquatableTests {

        @Test("Same instance is equal")
        func sameInstanceEqual() {
            let src = CGColorSpace(name: CGColorSpace.sRGB)!
            let dst = CGColorSpace(name: CGColorSpace.genericGrayGamma2_2)!
            let info = CGColorConversionInfo(src: src, dst: dst)

            #expect(info == info)
        }

        @Test("Different instances are not equal")
        func differentInstancesNotEqual() {
            let src = CGColorSpace(name: CGColorSpace.sRGB)!
            let dst = CGColorSpace(name: CGColorSpace.genericGrayGamma2_2)!
            let info1 = CGColorConversionInfo(src: src, dst: dst)
            let info2 = CGColorConversionInfo(src: src, dst: dst)

            #expect(info1 != info2)
        }
    }

    @Suite("Hashable Conformance")
    struct HashableTests {

        @Test("Can be used in Set")
        func setUsage() {
            var set = Set<CGColorConversionInfo>()
            let src = CGColorSpace(name: CGColorSpace.sRGB)!
            let dst = CGColorSpace(name: CGColorSpace.genericGrayGamma2_2)!

            if let info1 = CGColorConversionInfo(src: src, dst: dst),
               let info2 = CGColorConversionInfo(src: src, dst: dst) {
                set.insert(info1)
                set.insert(info2)
                set.insert(info1)
                #expect(set.count == 2)
            }
        }
    }

    @Suite("Color buffer conversion")
    struct ConversionTests {
        private static let rgba8 = CGColorBufferFormat(
            version: 0,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: 8
        )

        private static let grayAlpha8 = CGColorBufferFormat(
            version: 0,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
            bitsPerComponent: 8,
            bitsPerPixel: 16,
            bytesPerRow: 4
        )

        @Test("Converts two RGBA pixels to gray and preserves alpha")
        func rgbaToGray() throws {
            let sourceSpace = try #require(CGColorSpace(name: CGColorSpace.sRGB))
            let destinationSpace = try #require(CGColorSpace(name: CGColorSpace.genericGrayGamma2_2))
            let conversion = try #require(CGColorConversionInfo(src: sourceSpace, dst: destinationSpace))
            let source: [UInt8] = [255, 0, 0, 255, 0, 255, 0, 128]
            var destination = [UInt8](repeating: 0, count: 4)

            let succeeded = source.withUnsafeBytes { sourceBytes in
                destination.withUnsafeMutableBytes { destinationBytes in
                    conversion.convert(
                        width: 2,
                        height: 1,
                        to: destinationBytes.baseAddress!,
                        format: Self.grayAlpha8,
                        from: sourceBytes.baseAddress!,
                        format: Self.rgba8,
                        options: nil
                    )
                }
            }

            #expect(succeeded)
            #expect(destination == [76, 255, 150, 128])
        }

        @Test("Unpremultiplies source and premultiplies destination")
        func premultipliedAlphaRoundTrip() throws {
            let colorSpace = try #require(CGColorSpace(name: CGColorSpace.sRGB))
            let conversion = try #require(CGColorConversionInfo(src: colorSpace, dst: colorSpace))
            let format = CGColorBufferFormat(
                version: 0,
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: 4
            )
            let source: [UInt8] = [64, 32, 16, 128]
            var destination = [UInt8](repeating: 0, count: 4)

            let succeeded = source.withUnsafeBytes { sourceBytes in
                destination.withUnsafeMutableBytes { destinationBytes in
                    conversion.convert(
                        width: 1,
                        height: 1,
                        to: destinationBytes.baseAddress!,
                        format: format,
                        from: sourceBytes.baseAddress!,
                        format: format,
                        options: nil
                    )
                }
            }

            #expect(succeeded)
            #expect(destination == source)
        }

        @Test("Rejects invalid row stride without modifying output")
        func invalidStride() throws {
            let colorSpace = try #require(CGColorSpace(name: CGColorSpace.sRGB))
            let conversion = try #require(CGColorConversionInfo(src: colorSpace, dst: colorSpace))
            let invalidFormat = CGColorBufferFormat(
                version: 0,
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: 3
            )
            let source: [UInt8] = [1, 2, 3, 4]
            var destination: [UInt8] = [9, 9, 9, 9]

            let succeeded = source.withUnsafeBytes { sourceBytes in
                destination.withUnsafeMutableBytes { destinationBytes in
                    conversion.convert(
                        width: 1,
                        height: 1,
                        to: destinationBytes.baseAddress!,
                        format: invalidFormat,
                        from: sourceBytes.baseAddress!,
                        format: invalidFormat,
                        options: nil
                    )
                }
            }

            #expect(!succeeded)
            #expect(destination == [9, 9, 9, 9])
        }

        @Test("Rejects device color spaces")
        func rejectsDeviceColorSpaces() {
            #expect(CGColorConversionInfo(src: .deviceRGB, dst: .deviceGray) == nil)
        }
    }
}
