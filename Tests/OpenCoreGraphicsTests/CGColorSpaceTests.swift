//
//  CGColorSpaceTests.swift
//  OpenCoreGraphics
//
//  Tests for CGColorSpace, CGColorSpaceModel, and CGColorRenderingIntent types
//

import Foundation
import Testing
@testable import OpenCoreGraphics

// Type aliases to avoid ambiguity with CoreFoundation types on macOS
private typealias CGColorSpace = OpenCoreGraphics.CGColorSpace
private typealias CGColorSpaceModel = OpenCoreGraphics.CGColorSpaceModel
private typealias CGColorRenderingIntent = OpenCoreGraphics.CGColorRenderingIntent

@Suite("CGColorSpace Tests")
struct CGColorSpaceTests {

    // MARK: - Named Color Space Initialization Tests

    @Suite("Named Color Space Initialization")
    struct NamedInitTests {

        @Test("Init sRGB color space")
        func initSRGB() {
            let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)
            #expect(colorSpace != nil)
            #expect(colorSpace?.model == .rgb)
            #expect(colorSpace?.numberOfComponents == 3)
            #expect(colorSpace?.name as String? == CGColorSpace.sRGB as String)
        }

        @Test("Init Display P3 color space")
        func initDisplayP3() {
            let colorSpace = CGColorSpace(name: CGColorSpace.displayP3)
            #expect(colorSpace != nil)
            #expect(colorSpace?.model == .rgb)
            #expect(colorSpace?.numberOfComponents == 3)
        }

        @Test("Init Linear sRGB color space")
        func initLinearSRGB() {
            let colorSpace = CGColorSpace(name: CGColorSpace.linearSRGB)
            #expect(colorSpace != nil)
            #expect(colorSpace?.model == .rgb)
            #expect(colorSpace?.numberOfComponents == 3)
        }

        @Test("Init Extended sRGB color space")
        func initExtendedSRGB() {
            let colorSpace = CGColorSpace(name: CGColorSpace.extendedSRGB)
            #expect(colorSpace != nil)
            #expect(colorSpace?.model == .rgb)
            #expect(colorSpace?.numberOfComponents == 3)
        }

        @Test("Init Generic Gray Gamma 2.2 color space")
        func initGenericGray() {
            let colorSpace = CGColorSpace(name: CGColorSpace.genericGrayGamma2_2)
            #expect(colorSpace != nil)
            #expect(colorSpace?.model == .monochrome)
            #expect(colorSpace?.numberOfComponents == 1)
        }

        @Test("Init Generic CMYK color space")
        func initGenericCMYK() {
            let colorSpace = CGColorSpace(name: CGColorSpace.genericCMYK)
            #expect(colorSpace != nil)
            #expect(colorSpace?.model == .cmyk)
            #expect(colorSpace?.numberOfComponents == 4)
        }

        @Test("Init Generic RGB Linear color space")
        func initGenericRGBLinear() {
            let colorSpace = CGColorSpace(name: CGColorSpace.genericRGBLinear)
            #expect(colorSpace != nil)
            #expect(colorSpace?.model == .rgb)
            #expect(colorSpace?.numberOfComponents == 3)
        }

        @Test("Init Generic Lab color space")
        func initGenericLab() {
            let colorSpace = CGColorSpace(name: CGColorSpace.genericLab)
            #expect(colorSpace != nil)
            #expect(colorSpace?.model == .lab)
            #expect(colorSpace?.numberOfComponents == 3)
        }

        @Test("Init Generic XYZ color space")
        func initGenericXYZ() {
            let colorSpace = CGColorSpace(name: CGColorSpace.genericXYZ)
            #expect(colorSpace != nil)
            #expect(colorSpace?.model == .XYZ)
            #expect(colorSpace?.numberOfComponents == 3)
        }

        @Test("Init with unknown name returns nil")
        func initUnknownName() {
            let colorSpace = CGColorSpace(name: "UnknownColorSpace")
            #expect(colorSpace == nil)
        }
    }

    // MARK: - Factory Function Tests

    @Suite("Factory Functions")
    struct FactoryFunctionTests {

        @Test("Create Device RGB")
        func createDeviceRGB() {
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            #expect(colorSpace.model == .rgb)
            #expect(colorSpace.numberOfComponents == 3)
            #expect(colorSpace.name as String? == "DeviceRGB")
        }

        @Test("Create Device CMYK")
        func createDeviceCMYK() {
            let colorSpace = CGColorSpaceCreateDeviceCMYK()
            #expect(colorSpace.model == .cmyk)
            #expect(colorSpace.numberOfComponents == 4)
            #expect(colorSpace.name as String? == "DeviceCMYK")
        }

        @Test("Create Device Gray")
        func createDeviceGray() {
            let colorSpace = CGColorSpaceCreateDeviceGray()
            #expect(colorSpace.model == .monochrome)
            #expect(colorSpace.numberOfComponents == 1)
            #expect(colorSpace.name as String? == "DeviceGray")
        }
    }

    // MARK: - Indexed Color Space Tests

    @Suite("Indexed Color Space")
    struct IndexedColorSpaceTests {

        @Test("Init indexed color space")
        func initIndexed() {
            let baseSpace = CGColorSpaceCreateDeviceRGB()
            let colorTable: [UInt8] = Array(repeating: 0, count: 768) // 256 * 3
            let colorSpace = colorTable.withUnsafeBufferPointer { buffer in
                CGColorSpace(indexedBaseSpace: baseSpace, last: 255, colorTable: buffer.baseAddress!)
            }
            #expect(colorSpace != nil)
            #expect(colorSpace?.model == .indexed)
            #expect(colorSpace?.numberOfComponents == 1)
            #expect(colorSpace?.baseColorSpace == baseSpace)
        }

        @Test("Init indexed with invalid last returns nil")
        func initIndexedInvalidLast() {
            let baseSpace = CGColorSpaceCreateDeviceRGB()
            let colorTable: [UInt8] = Array(repeating: 0, count: 768)
            let colorSpace = colorTable.withUnsafeBufferPointer { buffer in
                CGColorSpace(indexedBaseSpace: baseSpace, last: 256, colorTable: buffer.baseAddress!)
            }
            #expect(colorSpace == nil)
        }

        @Test("Init indexed with negative last returns nil")
        func initIndexedNegativeLast() {
            let baseSpace = CGColorSpaceCreateDeviceRGB()
            let colorTable: [UInt8] = Array(repeating: 0, count: 768)
            let colorSpace = colorTable.withUnsafeBufferPointer { buffer in
                CGColorSpace(indexedBaseSpace: baseSpace, last: -1, colorTable: buffer.baseAddress!)
            }
            #expect(colorSpace == nil)
        }
    }

    // MARK: - Pattern Color Space Tests

    @Suite("Pattern Color Space")
    struct PatternColorSpaceTests {

        @Test("Init pattern color space with base")
        func initPatternWithBase() {
            let baseSpace = CGColorSpaceCreateDeviceRGB()
            let colorSpace = CGColorSpace(patternBaseSpace: baseSpace)
            #expect(colorSpace != nil)
            #expect(colorSpace?.model == .pattern)
            #expect(colorSpace?.numberOfComponents == 3)
            #expect(colorSpace?.baseColorSpace == baseSpace)
        }

        @Test("Init pattern color space without base")
        func initPatternWithoutBase() {
            let colorSpace = CGColorSpace(patternBaseSpace: nil)
            #expect(colorSpace != nil)
            #expect(colorSpace?.model == .pattern)
            #expect(colorSpace?.numberOfComponents == 0)
            #expect(colorSpace?.baseColorSpace == nil)
        }
    }

    // MARK: - Properties Tests

    @Suite("Properties")
    struct PropertiesTests {

        @Test("supportsOutput for standard color spaces")
        func supportsOutput() {
            let rgb = CGColorSpaceCreateDeviceRGB()
            let cmyk = CGColorSpaceCreateDeviceCMYK()
            let gray = CGColorSpaceCreateDeviceGray()

            #expect(rgb.supportsOutput)
            #expect(cmyk.supportsOutput)
            #expect(gray.supportsOutput)
        }

        @Test("supportsOutput for indexed returns false")
        func supportsOutputIndexed() {
            let baseSpace = CGColorSpaceCreateDeviceRGB()
            let colorTable: [UInt8] = Array(repeating: 0, count: 768)
            let indexed = colorTable.withUnsafeBufferPointer { buffer in
                CGColorSpace(indexedBaseSpace: baseSpace, last: 255, colorTable: buffer.baseAddress!)
            }
            #expect(indexed?.supportsOutput == false)
        }

        @Test("supportsOutput for pattern returns false")
        func supportsOutputPattern() {
            let pattern = CGColorSpace(patternBaseSpace: nil)
            #expect(pattern?.supportsOutput == false)
        }

        @Test("isWideGamutRGB for Display P3")
        func isWideGamutDisplayP3() {
            let p3 = CGColorSpace(name: CGColorSpace.displayP3)
            #expect(p3?.isWideGamutRGB == true)
        }

        @Test("isWideGamutRGB for Extended sRGB")
        func isWideGamutExtendedSRGB() {
            let extended = CGColorSpace(name: CGColorSpace.extendedSRGB)
            #expect(extended?.isWideGamutRGB == true)
        }

        @Test("isWideGamutRGB for standard sRGB")
        func isWideGamutSRGB() {
            let srgb = CGColorSpace(name: CGColorSpace.sRGB)
            #expect(srgb?.isWideGamutRGB == false)
        }

        @Test("isWideGamutRGB for non-RGB returns false")
        func isWideGamutNonRGB() {
            let gray = CGColorSpaceCreateDeviceGray()
            #expect(gray.isWideGamutRGB == false)
        }
    }

    // MARK: - Equatable Tests

    @Suite("Equatable Conformance")
    struct EquatableTests {

        @Test("Equal color spaces")
        func equalColorSpaces() {
            let rgb1 = CGColorSpaceCreateDeviceRGB()
            let rgb2 = CGColorSpaceCreateDeviceRGB()
            #expect(rgb1 == rgb2)
        }

        @Test("Unequal color spaces different model")
        func unequalDifferentModel() {
            let rgb = CGColorSpaceCreateDeviceRGB()
            let gray = CGColorSpaceCreateDeviceGray()
            #expect(rgb != gray)
        }

        @Test("Unequal color spaces different name")
        func unequalDifferentName() {
            let srgb = CGColorSpace(name: CGColorSpace.sRGB)
            let p3 = CGColorSpace(name: CGColorSpace.displayP3)
            #expect(srgb != p3)
        }
    }

    // MARK: - Hashable Tests

    @Suite("Hashable Conformance")
    struct HashableTests {

        @Test("Equal color spaces have equal hashes")
        func equalColorSpacesEqualHashes() {
            let rgb1 = CGColorSpaceCreateDeviceRGB()
            let rgb2 = CGColorSpaceCreateDeviceRGB()
            #expect(rgb1.hashValue == rgb2.hashValue)
        }

        @Test("Can be used in Set")
        func setUsage() {
            var set = Set<CGColorSpace>()
            set.insert(CGColorSpaceCreateDeviceRGB())
            set.insert(CGColorSpaceCreateDeviceGray())
            set.insert(CGColorSpaceCreateDeviceRGB())
            #expect(set.count == 2)
        }
    }

    // MARK: - Static Color Space Names Tests

    @Suite("Static Color Space Names")
    struct StaticNamesTests {

        @Test("sRGB name")
        func sRGBName() {
            #expect(CGColorSpace.sRGB as String == "kCGColorSpaceSRGB")
        }

        @Test("Display P3 name")
        func displayP3Name() {
            #expect(CGColorSpace.displayP3 as String == "kCGColorSpaceDisplayP3")
        }

        @Test("Linear sRGB name")
        func linearSRGBName() {
            #expect(CGColorSpace.linearSRGB as String == "kCGColorSpaceLinearSRGB")
        }

        @Test("Extended sRGB name")
        func extendedSRGBName() {
            #expect(CGColorSpace.extendedSRGB as String == "kCGColorSpaceExtendedSRGB")
        }

        @Test("Generic Gray Gamma 2.2 name")
        func genericGrayGamma2_2Name() {
            #expect(CGColorSpace.genericGrayGamma2_2 as String == "kCGColorSpaceGenericGrayGamma2_2")
        }

        @Test("Generic CMYK name")
        func genericCMYKName() {
            #expect(CGColorSpace.genericCMYK as String == "kCGColorSpaceGenericCMYK")
        }

        @Test("Generic RGB Linear name")
        func genericRGBLinearName() {
            #expect(CGColorSpace.genericRGBLinear as String == "kCGColorSpaceGenericRGBLinear")
        }

        @Test("Generic Lab name")
        func genericLabName() {
            #expect(CGColorSpace.genericLab as String == "kCGColorSpaceGenericLab")
        }

        @Test("Generic XYZ name")
        func genericXYZName() {
            #expect(CGColorSpace.genericXYZ as String == "kCGColorSpaceGenericXYZ")
        }
    }
}

// MARK: - CGColorSpaceModel Tests

@Suite("CGColorSpaceModel Tests")
struct CGColorSpaceModelTests {

    @Test("Raw values")
    func rawValues() {
        #expect(CGColorSpaceModel.unknown.rawValue == -1)
        #expect(CGColorSpaceModel.monochrome.rawValue == 0)
        #expect(CGColorSpaceModel.rgb.rawValue == 1)
        #expect(CGColorSpaceModel.cmyk.rawValue == 2)
        #expect(CGColorSpaceModel.lab.rawValue == 3)
        #expect(CGColorSpaceModel.deviceN.rawValue == 4)
        #expect(CGColorSpaceModel.indexed.rawValue == 5)
        #expect(CGColorSpaceModel.pattern.rawValue == 6)
        #expect(CGColorSpaceModel.XYZ.rawValue == 7)
    }

    @Test("Init from raw value")
    func initFromRawValue() {
        #expect(CGColorSpaceModel(rawValue: -1) == .unknown)
        #expect(CGColorSpaceModel(rawValue: 0) == .monochrome)
        #expect(CGColorSpaceModel(rawValue: 1) == .rgb)
        #expect(CGColorSpaceModel(rawValue: 2) == .cmyk)
        #expect(CGColorSpaceModel(rawValue: 3) == .lab)
        #expect(CGColorSpaceModel(rawValue: 4) == .deviceN)
        #expect(CGColorSpaceModel(rawValue: 5) == .indexed)
        #expect(CGColorSpaceModel(rawValue: 6) == .pattern)
        #expect(CGColorSpaceModel(rawValue: 7) == .XYZ)
        #expect(CGColorSpaceModel(rawValue: 100) == nil)
    }
}

// MARK: - CGColorRenderingIntent Tests

@Suite("CGColorRenderingIntent Tests")
struct CGColorRenderingIntentTests {

    @Test("Raw values")
    func rawValues() {
        #expect(CGColorRenderingIntent.defaultIntent.rawValue == 0)
        #expect(CGColorRenderingIntent.absoluteColorimetric.rawValue == 1)
        #expect(CGColorRenderingIntent.relativeColorimetric.rawValue == 2)
        #expect(CGColorRenderingIntent.perceptual.rawValue == 3)
        #expect(CGColorRenderingIntent.saturation.rawValue == 4)
    }

    @Test("Init from raw value")
    func initFromRawValue() {
        #expect(CGColorRenderingIntent(rawValue: 0) == .defaultIntent)
        #expect(CGColorRenderingIntent(rawValue: 1) == .absoluteColorimetric)
        #expect(CGColorRenderingIntent(rawValue: 2) == .relativeColorimetric)
        #expect(CGColorRenderingIntent(rawValue: 3) == .perceptual)
        #expect(CGColorRenderingIntent(rawValue: 4) == .saturation)
        #expect(CGColorRenderingIntent(rawValue: 100) == nil)
    }
}
