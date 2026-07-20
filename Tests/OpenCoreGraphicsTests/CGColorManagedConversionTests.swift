//
//  CGColorManagedConversionTests.swift
//  OpenCoreGraphics
//

import Foundation
import Testing
@testable import OpenCoreGraphics

@Suite("CGColor managed conversion tests")
struct CGColorManagedConversionTests {
    @Test(
        "All ICC parametric curve functions decode and invert",
        arguments: [
            (UInt16(0), [CGFloat(2)], CGFloat(0.25)),
            (UInt16(1), [CGFloat(2), 1, 0], CGFloat(0.25)),
            (UInt16(2), [CGFloat(2), 1, 0, 0.1], CGFloat(0.35)),
            (UInt16(3), [CGFloat(2), 1, 0, 0.2, 0.2], CGFloat(0.25)),
            (UInt16(4), [CGFloat(2), 1, 0, 0.2, 0.2, 0, 0], CGFloat(0.25))
        ]
    )
    func parametricCurves(function: UInt16, parameters: [CGFloat], expected: CGFloat) throws {
        let curve = CGTransferCurve.parametric(function: function, parameters: parameters)
        #expect(curve.isValid)
        let decoded = try #require(curve.decoded(0.5, extended: false))
        #expect(abs(decoded - expected) < 0.000001)
        let encoded = try #require(curve.encoded(decoded, extended: false))
        #expect(abs(encoded - 0.5) < 0.000001)
    }

    @Test("sRGB converts to Display P3 through linear XYZ")
    func sRGBToDisplayP3() throws {
        let sourceSpace = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let destinationSpace = try #require(CGColorSpace(name: CGColorSpace.displayP3))
        let source = try #require(CGColor(colorSpace: sourceSpace, components: [1, 0, 0, 0.6]))
        let result = try #require(source.converted(
            to: destinationSpace,
            intent: .relativeColorimetric,
            options: nil
        ))
        let values = try #require(result.components)

        #expect(abs(values[0] - 0.91747) < 0.0002)
        #expect(abs(values[1] - 0.20037) < 0.0002)
        #expect(abs(values[2] - 0.13852) < 0.0002)
        #expect(values[3] == 0.6)
    }

    @Test("Display P3 out-of-gamut values survive in extended sRGB")
    func displayP3ToExtendedSRGB() throws {
        let sourceSpace = try #require(CGColorSpace(name: CGColorSpace.displayP3))
        let destinationSpace = try #require(CGColorSpace(name: CGColorSpace.extendedSRGB))
        let source = try #require(CGColor(colorSpace: sourceSpace, components: [1, 0, 0, 1]))
        let result = try #require(source.converted(
            to: destinationSpace,
            intent: .relativeColorimetric,
            options: nil
        ))
        let values = try #require(result.components)

        #expect(abs(values[0] - 1.09309) < 0.0002)
        #expect(abs(values[1] + 0.22684) < 0.0002)
        #expect(abs(values[2] + 0.15008) < 0.0002)
    }

    @Test("Extended sRGB transfer function is sign preserving")
    func extendedSRGBTransfer() throws {
        let sourceSpace = try #require(CGColorSpace(name: CGColorSpace.extendedSRGB))
        let destinationSpace = try #require(CGColorSpace(name: CGColorSpace.extendedLinearSRGB))

        for (encoded, expected) in [(-0.5, -0.21404114), (-0.1, -0.01002283), (0.5, 0.21404114), (2, 4.9538455)] {
            let source = try #require(CGColor(
                colorSpace: sourceSpace,
                components: [CGFloat(encoded), CGFloat(encoded), CGFloat(encoded), 1]
            ))
            let result = try #require(source.converted(
                to: destinationSpace,
                intent: .relativeColorimetric,
                options: nil
            ))
            let value = try #require(result.components?.first)
            #expect(abs(value - CGFloat(expected)) < 0.00001)
        }
    }

    @Test("Calibrated RGB retains its gamma and matrix")
    func calibratedRGB() throws {
        var whitePoint: [CGFloat] = [0.95047, 1, 1.08883]
        var gamma: [CGFloat] = [2, 2, 2]
        var matrix: [CGFloat] = [
            0.4124564, 0.2126729, 0.0193339,
            0.3575761, 0.7151522, 0.1191920,
            0.1804375, 0.0721750, 0.9503041
        ]
        let calibrated = whitePoint.withUnsafeBufferPointer { whiteBuffer in
            gamma.withUnsafeBufferPointer { gammaBuffer in
                matrix.withUnsafeBufferPointer { matrixBuffer in
                    CGColorSpace(
                        calibratedRGBWhitePoint: whiteBuffer.baseAddress!,
                        blackPoint: nil,
                        gamma: gammaBuffer.baseAddress,
                        matrix: matrixBuffer.baseAddress
                    )
                }
            }
        }
        let sourceSpace = try #require(calibrated)
        let linearSpace = try #require(CGColorSpace(name: CGColorSpace.linearSRGB))
        let source = try #require(CGColor(colorSpace: sourceSpace, components: [0.5, 0.5, 0.5, 1]))
        let result = try #require(source.converted(to: linearSpace, intent: .relativeColorimetric, options: nil))
        let values = try #require(result.components)

        #expect(abs(values[0] - 0.25) < 0.00001)
        #expect(abs(values[1] - 0.25) < 0.00001)
        #expect(abs(values[2] - 0.25) < 0.00001)
    }

    @Test("ITU and Core Media transfer functions match system color spaces")
    func videoTransferFunctions() throws {
        let linearSpace = try #require(CGColorSpace(name: CGColorSpace.extendedLinearSRGB))
        let expectations: [(String, CGFloat)] = [
            (CGColorSpace.itur_709, 0.18946457),
            (CGColorSpace.itur_2020, 0.18946457),
            (CGColorSpace.itur_2020_sRGBGamma, 0.21404114),
            (CGColorSpace.coreMedia709, 0.25686148)
        ]

        for (name, expected) in expectations {
            let sourceSpace = try #require(CGColorSpace(name: name))
            let source = try #require(CGColor(colorSpace: sourceSpace, components: [0.5, 0.5, 0.5, 1]))
            let result = try #require(source.converted(
                to: linearSpace,
                intent: .relativeColorimetric,
                options: nil
            ))
            let value = try #require(result.components?.first)
            #expect(abs(value - expected) < 0.00005)
        }
    }

    @Test("PQ uses the extended-linear 203 nit reference white")
    func pqReferenceWhite() throws {
        let pqSpace = try #require(CGColorSpace(name: CGColorSpace.itur_2100_PQ))
        let linearSpace = try #require(CGColorSpace(name: CGColorSpace.extendedLinearITUR_2020))
        let source = try #require(CGColor(colorSpace: pqSpace, components: [0.5, 0.5, 0.5, 1]))
        let result = try #require(source.converted(to: linearSpace, intent: .relativeColorimetric, options: nil))
        let values = try #require(result.components)
        #expect(abs(values[0] - 0.45441049) < 0.00002)
        #expect(abs(values[1] - 0.45441049) < 0.00002)
        #expect(abs(values[2] - 0.45441049) < 0.00002)
    }

    @Test("HLG applies the luminance-coupled BT.2100 OOTF")
    func hlgCoupledOOTF() throws {
        let hlgSpace = try #require(CGColorSpace(name: CGColorSpace.itur_2100_HLG))
        let linearSpace = try #require(CGColorSpace(name: CGColorSpace.extendedLinearITUR_2020))
        let source = try #require(CGColor(colorSpace: hlgSpace, components: [0.5, 0.5, 0.5, 1]))
        let converted = try #require(source.converted(
            to: linearSpace,
            intent: .relativeColorimetric,
            options: nil
        ))
        let values = try #require(converted.components)
        #expect(abs(values[0] - 0.249739) < 0.00001)
        #expect(abs(values[1] - 0.249739) < 0.00001)
        #expect(abs(values[2] - 0.249739) < 0.00001)

        let roundTrip = try #require(converted.converted(
            to: hlgSpace,
            intent: .relativeColorimetric,
            options: nil
        ))
        let roundTripValues = try #require(roundTrip.components)
        #expect(abs(roundTripValues[0] - 0.5) < 0.00001)
        #expect(abs(roundTripValues[1] - 0.5) < 0.00001)
        #expect(abs(roundTripValues[2] - 0.5) < 0.00001)
        #expect(CGColorConversionInfo(src: hlgSpace, dst: linearSpace) != nil)
    }
}
