//
//  CGAdditionalTypesTests.swift
//  OpenCoreGraphics
//
//  Tests for additional types: CGTextDrawingMode, CGInterpolationQuality,
//  CGError, CGComponent, CGColorModel, CGContentInfo, CGContentToneMappingInfo,
//  CGImageComponentInfo, CGRenderingBufferProvider
//

import Foundation
import Testing
@testable import OpenCoreGraphics

// Type aliases
private typealias CGFloat = OpenCoreGraphics.CGFloat
private typealias CGTextDrawingMode = OpenCoreGraphics.CGTextDrawingMode
private typealias CGInterpolationQuality = OpenCoreGraphics.CGInterpolationQuality
private typealias CGError = OpenCoreGraphics.CGError
private typealias CGComponent = OpenCoreGraphics.CGComponent
private typealias CGColorModel = OpenCoreGraphics.CGColorModel
private typealias CGContentInfo = OpenCoreGraphics.CGContentInfo
private typealias CGContentToneMappingInfo = OpenCoreGraphics.CGContentToneMappingInfo
private typealias CGImageComponentInfo = OpenCoreGraphics.CGImageComponentInfo
private typealias CGRenderingBufferProvider = OpenCoreGraphics.CGRenderingBufferProvider
private typealias CGColorSpace = OpenCoreGraphics.CGColorSpace

// MARK: - CGTextDrawingMode Tests

@Suite("CGTextDrawingMode Tests")
struct CGTextDrawingModeTests {

    @Test("Raw values")
    func rawValues() {
        #expect(CGTextDrawingMode.fill.rawValue == 0)
        #expect(CGTextDrawingMode.stroke.rawValue == 1)
        #expect(CGTextDrawingMode.fillStroke.rawValue == 2)
        #expect(CGTextDrawingMode.invisible.rawValue == 3)
        #expect(CGTextDrawingMode.fillClip.rawValue == 4)
        #expect(CGTextDrawingMode.strokeClip.rawValue == 5)
        #expect(CGTextDrawingMode.fillStrokeClip.rawValue == 6)
        #expect(CGTextDrawingMode.clip.rawValue == 7)
    }

    @Test("Init from raw value")
    func initFromRawValue() {
        #expect(CGTextDrawingMode(rawValue: 0) == .fill)
        #expect(CGTextDrawingMode(rawValue: 1) == .stroke)
        #expect(CGTextDrawingMode(rawValue: 7) == .clip)
        #expect(CGTextDrawingMode(rawValue: 100) == nil)
    }

    @Test("Sendable conformance")
    func sendableConformance() async {
        let mode = CGTextDrawingMode.fill
        let task = Task {
            return mode
        }
        let result = await task.value
        #expect(result == .fill)
    }
}

// MARK: - CGInterpolationQuality Tests

@Suite("CGInterpolationQuality Tests")
struct CGInterpolationQualityTests {

    @Test("Raw values")
    func rawValues() {
        #expect(CGInterpolationQuality.default.rawValue == 0)
        #expect(CGInterpolationQuality.none.rawValue == 1)
        #expect(CGInterpolationQuality.low.rawValue == 2)
        #expect(CGInterpolationQuality.high.rawValue == 3)
        #expect(CGInterpolationQuality.medium.rawValue == 4)
    }

    @Test("Init from raw value")
    func initFromRawValue() {
        #expect(CGInterpolationQuality(rawValue: 0) == .default)
        #expect(CGInterpolationQuality(rawValue: 1) == CGInterpolationQuality.none)
        #expect(CGInterpolationQuality(rawValue: 4) == .medium)
        #expect(CGInterpolationQuality(rawValue: 100) == nil)
    }

    @Test("Sendable conformance")
    func sendableConformance() async {
        let quality = CGInterpolationQuality.high
        let task = Task {
            return quality
        }
        let result = await task.value
        #expect(result == .high)
    }
}

// MARK: - CGError Tests

@Suite("CGError Tests")
struct CGErrorTests {

    @Test("Raw values")
    func rawValues() {
        #expect(CGError.success.rawValue == 0)
        #expect(CGError.failure.rawValue == 1000)
        #expect(CGError.illegalArgument.rawValue == 1001)
        #expect(CGError.invalidConnection.rawValue == 1002)
        #expect(CGError.invalidContext.rawValue == 1003)
        #expect(CGError.cannotComplete.rawValue == 1004)
        #expect(CGError.notImplemented.rawValue == 1006)
        #expect(CGError.rangeCheck.rawValue == 1007)
        #expect(CGError.typeCheck.rawValue == 1008)
        #expect(CGError.invalidOperation.rawValue == 1010)
        #expect(CGError.noneAvailable.rawValue == 1011)
    }

    @Test("Init from raw value")
    func initFromRawValue() {
        #expect(CGError(rawValue: 0) == .success)
        #expect(CGError(rawValue: 1000) == .failure)
        #expect(CGError(rawValue: 1011) == .noneAvailable)
        #expect(CGError(rawValue: 9999) == nil)
    }

    @Test("Error conformance")
    func errorConformance() {
        let error: Error = CGError.failure
        #expect(error is CGError)
    }

    @Test("Equatable conformance")
    func equatableConformance() {
        #expect(CGError.success == CGError.success)
        #expect(CGError.success != CGError.failure)
    }

    @Test("Hashable conformance")
    func hashableConformance() {
        var set = Set<CGError>()
        set.insert(.success)
        set.insert(.failure)
        set.insert(.success)
        #expect(set.count == 2)
    }
}

// MARK: - CGComponent Tests

@Suite("CGComponent Tests")
struct CGComponentTests {

    @Test("Raw values")
    func rawValues() {
        #expect(CGComponent.unknown.rawValue == 0)
        #expect(CGComponent.integer8Bit.rawValue == 1)
        #expect(CGComponent.integer10Bit.rawValue == 2)
        #expect(CGComponent.integer16Bit.rawValue == 3)
        #expect(CGComponent.integer32Bit.rawValue == 4)
        #expect(CGComponent.float16Bit.rawValue == 5)
        #expect(CGComponent.float32Bit.rawValue == 6)
    }

    @Test("Init from raw value")
    func initFromRawValue() {
        #expect(CGComponent(rawValue: 0) == .unknown)
        #expect(CGComponent(rawValue: 1) == .integer8Bit)
        #expect(CGComponent(rawValue: 6) == .float32Bit)
        #expect(CGComponent(rawValue: 100) == nil)
    }

    @Test("Equatable conformance")
    func equatableConformance() {
        #expect(CGComponent.integer8Bit == CGComponent.integer8Bit)
        #expect(CGComponent.integer8Bit != CGComponent.integer16Bit)
    }

    @Test("Hashable conformance")
    func hashableConformance() {
        var set = Set<CGComponent>()
        set.insert(.integer8Bit)
        set.insert(.float32Bit)
        set.insert(.integer8Bit)
        #expect(set.count == 2)
    }
}

// MARK: - CGColorModel Tests

@Suite("CGColorModel Tests")
struct CGColorModelTests {

    @Test("Raw values")
    func rawValues() {
        #expect(CGColorModel.gray.rawValue == 1)
        #expect(CGColorModel.rgb.rawValue == 2)
        #expect(CGColorModel.cmyk.rawValue == 4)
        #expect(CGColorModel.lab.rawValue == 8)
        #expect(CGColorModel.deviceN.rawValue == 16)
    }

    @Test("OptionSet operations")
    func optionSetOperations() {
        let models: CGColorModel = [.rgb, .cmyk]
        #expect(models.contains(.rgb))
        #expect(models.contains(.cmyk))
        #expect(!models.contains(.gray))
    }

    @Test("Union of options")
    func unionOfOptions() {
        let models1 = CGColorModel.rgb
        let models2 = CGColorModel.cmyk
        let combined = models1.union(models2)
        #expect(combined.contains(.rgb))
        #expect(combined.contains(.cmyk))
    }

    @Test("Empty options")
    func emptyOptions() {
        let models: CGColorModel = []
        #expect(models.rawValue == 0)
    }

    @Test("ExpressibleByArrayLiteral")
    func expressibleByArrayLiteral() {
        let models: CGColorModel = [.gray, .rgb, .lab]
        #expect(models.contains(.gray))
        #expect(models.contains(.rgb))
        #expect(models.contains(.lab))
    }
}

// MARK: - CGContentInfo Tests

@Suite("CGContentInfo Tests")
struct CGContentInfoTests {

    @Test("Default initialization")
    func defaultInitialization() {
        let info = CGContentInfo()
        #expect(info.deepestImageComponent == .unknown)
        #expect(info.contentColorModels.rawValue == 0)
        #expect(info.hasWideGamut == false)
        #expect(info.hasTransparency == false)
        #expect(info.largestContentHeadroom == 1.0)
    }

    @Test("Custom initialization")
    func customInitialization() {
        let info = CGContentInfo(
            deepestImageComponent: .integer8Bit,
            contentColorModels: [.rgb, .gray],
            hasWideGamut: true,
            hasTransparency: true,
            largestContentHeadroom: 2.0
        )

        #expect(info.deepestImageComponent == .integer8Bit)
        #expect(info.contentColorModels.contains(.rgb))
        #expect(info.contentColorModels.contains(.gray))
        #expect(info.hasWideGamut == true)
        #expect(info.hasTransparency == true)
        #expect(info.largestContentHeadroom == 2.0)
    }

    @Test("Sendable conformance")
    func sendableConformance() async {
        let info = CGContentInfo()
        let task = Task {
            return info
        }
        let result = await task.value
        #expect(result.deepestImageComponent == .unknown)
    }
}

// MARK: - CGImageComponentInfo Tests

@Suite("CGImageComponentInfo Tests")
struct CGImageComponentInfoTests {

    @Test("Raw values")
    func rawValues() {
        #expect(CGImageComponentInfo.float.rawValue == 0)
        #expect(CGImageComponentInfo.integer.rawValue == 1)
    }

    @Test("Init from raw value")
    func initFromRawValue() {
        #expect(CGImageComponentInfo(rawValue: 0) == .float)
        #expect(CGImageComponentInfo(rawValue: 1) == .integer)
        #expect(CGImageComponentInfo(rawValue: 100) == nil)
    }

    @Test("CaseIterable conformance")
    func caseIterable() {
        let allCases = CGImageComponentInfo.allCases
        #expect(allCases.count == 2)
    }

    @Test("Debug description")
    func debugDescription() {
        #expect(CGImageComponentInfo.float.debugDescription == "CGImageComponentInfo.float")
        #expect(CGImageComponentInfo.integer.debugDescription == "CGImageComponentInfo.integer")
    }
}

// MARK: - CGContentToneMappingInfo Tests

@Suite("CGContentToneMappingInfo Tests")
struct CGContentToneMappingInfoTests {

    @Suite("Cases")
    struct CasesTests {

        @Test("None case")
        func noneCase() {
            let info = CGContentToneMappingInfo.none
            #expect(info.id == 0)
        }

        @Test("Default case with options")
        func defaultCaseWithOptions() {
            let options = CGContentToneMappingInfo.DefaultOptions()
            let info = CGContentToneMappingInfo.default(options)
            #expect(info.id == 1)
        }

        @Test("EXR gamma case")
        func exrGammaCase() {
            let options = CGContentToneMappingInfo.EXRGammaOptions()
            let info = CGContentToneMappingInfo.exrGamma(options)
            #expect(info.id == 2)
        }

        @Test("ITU recommended case")
        func ituRecommendedCase() {
            let options = CGContentToneMappingInfo.ITURecommendedOptions()
            let info = CGContentToneMappingInfo.ituRecommended(options)
            #expect(info.id == 4)
        }
    }

    @Suite("DefaultOptions")
    struct DefaultOptionsTests {

        @Test("Default initialization")
        func defaultInitialization() {
            let options = CGContentToneMappingInfo.DefaultOptions()
            #expect(options.preferredDynamicRange == .standard)
        }

        @Test("Custom initialization")
        func customInitialization() {
            let options = CGContentToneMappingInfo.DefaultOptions(
                contentAverageLightLevel: .nits(500),
                preferredDynamicRange: .high
            )
            #expect(options.preferredDynamicRange == .high)
        }
    }

    @Suite("EXRGammaOptions")
    struct EXRGammaOptionsTests {

        @Test("Default initialization")
        func defaultInitialization() {
            let options = CGContentToneMappingInfo.EXRGammaOptions()
            #expect(options.defog == 0.0)
            #expect(options.exposure == 0.0)
            #expect(options.kneeHigh == 5.0)
            #expect(options.kneeLow == 0.0)
        }

        @Test("Custom initialization")
        func customInitialization() {
            let options = CGContentToneMappingInfo.EXRGammaOptions(
                defog: 0.1,
                exposure: 1.0,
                kneeHigh: 4.0,
                kneeLow: 0.5
            )
            #expect(options.defog == 0.1)
            #expect(options.exposure == 1.0)
        }
    }

    @Suite("ITURecommendedOptions")
    struct ITURecommendedOptionsTests {

        @Test("Default initialization")
        func defaultInitialization() {
            let options = CGContentToneMappingInfo.ITURecommendedOptions()
            #expect(options.skipBoostToHDR == false)
            #expect(options.use100nitsHLGOOTF == false)
            #expect(options.useBT1886ForCoreVideoGamma == false)
            #expect(options.useLegacyHDREcosystem == false)
        }
    }

    @Suite("DynamicRange")
    struct DynamicRangeTests {

        @Test("All cases")
        func allCases() {
            let standard = CGContentToneMappingInfo.DynamicRange.standard
            let high = CGContentToneMappingInfo.DynamicRange.high
            let constrained = CGContentToneMappingInfo.DynamicRange.constrained

            #expect(standard == .standard)
            #expect(high == .high)
            #expect(constrained == .constrained)
        }

        @Test("Equatable and Hashable")
        func equatableAndHashable() {
            var set = Set<CGContentToneMappingInfo.DynamicRange>()
            set.insert(.standard)
            set.insert(.high)
            set.insert(.standard)
            #expect(set.count == 2)
        }
    }

    @Suite("LightLevel")
    struct LightLevelTests {

        @Test("Nits case")
        func nitsCase() {
            let level = CGContentToneMappingInfo.LightLevel.nits(500)
            if case .nits(let value) = level {
                #expect(value == 500)
            } else {
                #expect(Bool(false), "Expected nits case")
            }
        }

        @Test("Relative case")
        func relativeCase() {
            let level = CGContentToneMappingInfo.LightLevel.relative(1.5)
            if case .relative(let value) = level {
                #expect(value == 1.5)
            } else {
                #expect(Bool(false), "Expected relative case")
            }
        }

        @Test("Equatable")
        func equatable() {
            let nits1 = CGContentToneMappingInfo.LightLevel.nits(500)
            let nits2 = CGContentToneMappingInfo.LightLevel.nits(500)
            let nits3 = CGContentToneMappingInfo.LightLevel.nits(600)

            #expect(nits1 == nits2)
            #expect(nits1 != nits3)
        }
    }

    @Suite("Equatable Conformance")
    struct EquatableTests {

        @Test("None equals none")
        func noneEqualsNone() {
            let info1 = CGContentToneMappingInfo.none
            let info2 = CGContentToneMappingInfo.none
            #expect(info1 == info2)
        }

        @Test("Different cases not equal")
        func differentCasesNotEqual() {
            let info1 = CGContentToneMappingInfo.none
            let options = CGContentToneMappingInfo.DefaultOptions()
            let info2 = CGContentToneMappingInfo.default(options)
            #expect(info1 != info2)
        }
    }

    @Suite("Hashable Conformance")
    struct HashableTests {

        @Test("Can be used in Set")
        func setUsage() {
            var set = Set<CGContentToneMappingInfo>()
            set.insert(.none)
            let options = CGContentToneMappingInfo.DefaultOptions()
            set.insert(.default(options))
            set.insert(.none)
            #expect(set.count == 2)
        }
    }
}

// MARK: - CGRenderingBufferProvider Tests

@Suite("CGRenderingBufferProvider Tests")
struct CGRenderingBufferProviderTests {

    @Suite("Initialization")
    struct InitializationTests {

        @Test("Init with valid parameters")
        func initWithValidParameters() {
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let provider = CGRenderingBufferProvider(
                width: 100,
                height: 100,
                bytesPerRow: 400,
                pixelFormat: 0,
                colorSpace: colorSpace
            )

            #expect(provider != nil)
            #expect(provider?.width == 100)
            #expect(provider?.height == 100)
        }

        @Test("Init with zero width returns nil")
        func initWithZeroWidth() {
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let provider = CGRenderingBufferProvider(
                width: 0,
                height: 100,
                bytesPerRow: 400,
                pixelFormat: 0,
                colorSpace: colorSpace
            )

            #expect(provider == nil)
        }

        @Test("Init with zero height returns nil")
        func initWithZeroHeight() {
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let provider = CGRenderingBufferProvider(
                width: 100,
                height: 0,
                bytesPerRow: 400,
                pixelFormat: 0,
                colorSpace: colorSpace
            )

            #expect(provider == nil)
        }

        @Test("Init with zero bytes per row returns nil")
        func initWithZeroBytesPerRow() {
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let provider = CGRenderingBufferProvider(
                width: 100,
                height: 100,
                bytesPerRow: 0,
                pixelFormat: 0,
                colorSpace: colorSpace
            )

            #expect(provider == nil)
        }

        @Test("Init with nil color space")
        func initWithNilColorSpace() {
            let provider = CGRenderingBufferProvider(
                width: 100,
                height: 100,
                bytesPerRow: 400,
                pixelFormat: 0,
                colorSpace: nil
            )

            #expect(provider != nil)
            #expect(provider?.colorSpace == nil)
        }
    }

    @Suite("Properties")
    struct PropertiesTests {

        @Test("Width and height")
        func widthAndHeight() {
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let provider = CGRenderingBufferProvider(
                width: 200,
                height: 150,
                bytesPerRow: 800,
                pixelFormat: 0,
                colorSpace: colorSpace
            )

            #expect(provider?.width == 200)
            #expect(provider?.height == 150)
        }

        @Test("Bytes per row")
        func bytesPerRow() {
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let provider = CGRenderingBufferProvider(
                width: 100,
                height: 100,
                bytesPerRow: 512,
                pixelFormat: 0,
                colorSpace: colorSpace
            )

            #expect(provider?.bytesPerRow == 512)
        }

        @Test("Data pointer")
        func dataPointer() {
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let provider = CGRenderingBufferProvider(
                width: 100,
                height: 100,
                bytesPerRow: 400,
                pixelFormat: 0,
                colorSpace: colorSpace
            )

            #expect(provider?.data != nil)
        }
    }

    @Suite("Equatable Conformance")
    struct EquatableTests {

        @Test("Same instance is equal")
        func sameInstanceEqual() {
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let provider = CGRenderingBufferProvider(
                width: 100,
                height: 100,
                bytesPerRow: 400,
                pixelFormat: 0,
                colorSpace: colorSpace
            )

            #expect(provider == provider)
        }

        @Test("Different instances are not equal")
        func differentInstancesNotEqual() {
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let provider1 = CGRenderingBufferProvider(
                width: 100,
                height: 100,
                bytesPerRow: 400,
                pixelFormat: 0,
                colorSpace: colorSpace
            )
            let provider2 = CGRenderingBufferProvider(
                width: 100,
                height: 100,
                bytesPerRow: 400,
                pixelFormat: 0,
                colorSpace: colorSpace
            )

            #expect(provider1 != provider2)
        }
    }

    @Suite("Hashable Conformance")
    struct HashableTests {

        @Test("Can be used in Set")
        func setUsage() {
            var set = Set<CGRenderingBufferProvider>()
            let colorSpace = CGColorSpaceCreateDeviceRGB()

            if let p1 = CGRenderingBufferProvider(width: 100, height: 100, bytesPerRow: 400, pixelFormat: 0, colorSpace: colorSpace),
               let p2 = CGRenderingBufferProvider(width: 100, height: 100, bytesPerRow: 400, pixelFormat: 0, colorSpace: colorSpace) {
                set.insert(p1)
                set.insert(p2)
                set.insert(p1)
                #expect(set.count == 2)
            }
        }
    }
}
