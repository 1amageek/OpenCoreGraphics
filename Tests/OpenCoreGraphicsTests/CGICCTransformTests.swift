//
//  CGICCTransformTests.swift
//  OpenCoreGraphics
//

import Foundation
import Testing
@testable import OpenCoreGraphics

@Suite("ICC LUT transform tests")
struct CGICCTransformTests {
    @Test("CICP HDR metadata selects the interoperable BT.2100 rendering")
    func cicpHLGProfile() throws {
        let data = Self.makeProfile(
            colorSpace: "RGB ",
            pcs: "XYZ ",
            tags: [
                ("A2B0", Self.complexTag(type: "mAB ")),
                ("cicp", Self.cicpTag(primaries: 9, transfer: 18))
            ]
        )
        let space = try #require(CGColorSpace(iccData: data))
        let linear = try #require(CGColorSpace(name: CGColorSpace.extendedLinearITUR_2020))
        let source = try #require(CGColor(colorSpace: space, components: [0.5, 0.5, 0.5, 1]))
        let converted = try #require(source.converted(to: linear, intent: .relativeColorimetric, options: nil))
        let values = try #require(converted.components)
        #expect(abs(values[0] - 0.249739) < 0.00001)
        #expect(abs(values[1] - 0.249739) < 0.00001)
        #expect(abs(values[2] - 0.249739) < 0.00001)
    }

    @Test("mAB and mBA execute every processing element in the specified direction")
    func complexPipelines() throws {
        let clut = CGICCCLUT(
            gridPoints: [2, 2, 2],
            outputChannels: 3,
            values: Self.identityCLUT(inputChannels: 3, outputChannels: 3)
        )
        #expect(clut.interpolate([.nan, 0.5, 0.5]) == nil)
        let matrix = CGColorMatrix(
            m00: 0.5, m01: 0, m02: 0,
            m10: 0, m11: 1, m12: 0,
            m20: 0, m21: 0, m22: 1
        )
        let lut = CGICCComplexLUT(
            inputChannels: 3,
            outputChannels: 3,
            aCurves: [.gamma(2), .identity, .identity],
            clut: clut,
            mCurves: [.identity, .identity, .identity],
            matrix: matrix,
            matrixOffset: CGColorVector(x: 0.1, y: 0, z: 0),
            bCurves: [.identity, .identity, .identity]
        )

        let forward = try #require(lut.applyAToB([0.5, 0.25, 0.75]))
        #expect(abs(forward[0] - 0.225) < 0.000001)
        #expect(abs(forward[1] - 0.25) < 0.000001)
        #expect(abs(forward[2] - 0.75) < 0.000001)

        let reverse = try #require(lut.applyBToA([0.5, 0.25, 0.75]))
        #expect(abs(reverse[0] - 0.1225) < 0.000001)
        #expect(abs(reverse[1] - 0.25) < 0.000001)
        #expect(abs(reverse[2] - 0.75) < 0.000001)
    }

    @Test("mAB and mBA profiles round-trip through normalized PCSXYZ")
    func complexXYZProfile() throws {
        let data = Self.makeProfile(
            colorSpace: "RGB ",
            pcs: "XYZ ",
            tags: [
                ("A2B0", Self.complexTag(type: "mAB ")),
                ("B2A0", Self.complexTag(type: "mBA "))
            ]
        )
        let space = try #require(CGColorSpace(iccData: data))
        let profile = try #require(space.colorProfile)
        let input: [CGFloat] = [0.2, 0.4, 0.6]
        let pcs = try #require(profile.toPCS(input, intent: .relativeColorimetric))
        let scale = CGFloat(65_535) / 32_768
        #expect(abs(pcs.x - input[0] * scale) < 0.000001)
        #expect(abs(pcs.y - input[1] * scale) < 0.000001)
        #expect(abs(pcs.z - input[2] * scale) < 0.000001)

        let roundTrip = try #require(profile.fromPCS(pcs, intent: .relativeColorimetric))
        #expect(abs(roundTrip[0] - input[0]) < 0.000001)
        #expect(abs(roundTrip[1] - input[1]) < 0.000001)
        #expect(abs(roundTrip[2] - input[2]) < 0.000001)
    }

    @Test("mAB converts normalized PCSLAB to the D50 XYZ connection space")
    func complexLabProfile() throws {
        let data = Self.makeProfile(
            colorSpace: "RGB ",
            pcs: "Lab ",
            tags: [("A2B0", Self.complexTag(type: "mAB "))]
        )
        let space = try #require(CGColorSpace(iccData: data))
        let profile = try #require(space.colorProfile)
        let pcs = try #require(profile.toPCS([0.5, 128 / 255, 128 / 255], intent: .perceptual))
        let neutralY = pow(CGFloat(66) / 116, 3)
        #expect(abs(pcs.x - CGColorVector.d50.x * neutralY) < 0.00001)
        #expect(abs(pcs.y - neutralY) < 0.00001)
        #expect(abs(pcs.z - CGColorVector.d50.z * neutralY) < 0.00001)
    }

    @Test("mft2 supplies executable CMYK device-to-PCS and PCS-to-device transforms")
    func legacyCMYKProfile() throws {
        let forward = Self.legacyTag(inputChannels: 4, outputChannels: 3) { input in
            [1 - input[0], 1 - input[1], 1 - input[2]]
        }
        let reverse = Self.legacyTag(inputChannels: 3, outputChannels: 4) { input in
            [1 - input[0], 1 - input[1], 1 - input[2], 0]
        }
        let data = Self.makeProfile(
            colorSpace: "CMYK",
            pcs: "XYZ ",
            tags: [("A2B0", forward), ("B2A0", reverse)]
        )
        let space = try #require(CGColorSpace(iccData: data))
        let profile = try #require(space.colorProfile)
        let pcs = try #require(profile.toPCS([0.2, 0.3, 0.4, 0.5], intent: .relativeColorimetric))
        let scale = CGFloat(65_535) / 32_768
        #expect(abs(pcs.x - 0.8 * scale) < 0.00002)
        #expect(abs(pcs.y - 0.7 * scale) < 0.00002)
        #expect(abs(pcs.z - 0.6 * scale) < 0.00002)

        let device = try #require(profile.fromPCS(pcs, intent: .relativeColorimetric))
        #expect(abs(device[0] - 0.2) < 0.00002)
        #expect(abs(device[1] - 0.3) < 0.00002)
        #expect(abs(device[2] - 0.4) < 0.00002)
        #expect(abs(device[3]) < 0.00002)

        let destination = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        #expect(CGColorConversionInfo(src: space, dst: destination) != nil)

        let forwardOnlyData = Self.makeProfile(
            colorSpace: "CMYK",
            pcs: "XYZ ",
            tags: [("A2B0", forward)]
        )
        let forwardOnly = try #require(CGColorSpace(iccData: forwardOnlyData))
        #expect(CGColorConversionInfo(src: forwardOnly, dst: destination) != nil)
        #expect(CGColorConversionInfo(src: destination, dst: forwardOnly) == nil)
    }

    @Test("mft1 executes an eight-bit PCSLAB transform")
    func legacyLab8Profile() throws {
        let data = Self.makeProfile(
            colorSpace: "RGB ",
            pcs: "Lab ",
            tags: [("A2B0", Self.legacy8IdentityTag())]
        )
        let space = try #require(CGColorSpace(iccData: data))
        let profile = try #require(space.colorProfile)
        let pcs = try #require(profile.toPCS([0.5, 128 / 255, 128 / 255], intent: .perceptual))
        let neutralY = pow(CGFloat(66) / 116, 3)
        #expect(abs(pcs.x - CGColorVector.d50.x * neutralY) < 0.00002)
        #expect(abs(pcs.y - neutralY) < 0.00002)
        #expect(abs(pcs.z - CGColorVector.d50.z * neutralY) < 0.00002)
    }

    @Test("Rendering intents select their corresponding ICC tables")
    func renderingIntentSelection() throws {
        let identity = CGICCTransform(
            pipeline: .aToB(Self.bOnlyLUT(curve: .identity)),
            pcsEncoding: .xyz,
            direction: .toPCS
        )
        let squared = CGICCTransform(
            pipeline: .aToB(Self.bOnlyLUT(curve: .gamma(2))),
            pcsEncoding: .xyz,
            direction: .toPCS
        )
        let transforms = CGICCTransformSet(
            mediaWhitePoint: .d50,
            perceptualToPCS: identity,
            colorimetricToPCS: squared,
            saturationToPCS: nil,
            absoluteToPCS: nil,
            perceptualFromPCS: nil,
            colorimetricFromPCS: nil,
            saturationFromPCS: nil,
            absoluteFromPCS: nil
        )
        let perceptual = try #require(transforms.toPCS([0.5, 0.5, 0.5], intent: .perceptual))
        let relative = try #require(transforms.toPCS([0.5, 0.5, 0.5], intent: .relativeColorimetric))
        #expect(abs(perceptual.y - 0.99998474) < 0.00001)
        #expect(abs(relative.y - 0.49999237) < 0.00001)
    }

    @Test
    func deviceRGBDrawingResolvesInManagedContextSpace() throws {
        let destination = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let state = CGDrawingState(
            destinationColorSpace: destination,
            clipPaths: [],
            ctm: .identity,
            shadowOffset: .zero,
            shadowBlur: 0,
            shadowColor: nil
        )
        let converted = try #require(state.convertedColor(
            CGColor(red: 0.25, green: 0.5, blue: 0.75, alpha: 0.8)
        ))

        #expect(converted.colorSpace == destination)
        #expect(converted.components == [0.25, 0.5, 0.75, 0.8])
    }

    @Test("Bitmap drawing applies and restores the context rendering intent")
    func contextRenderingIntentAffectsPixels() throws {
        let identity = Self.legacyTag(inputChannels: 3, outputChannels: 3) { $0 }
        let halved = Self.legacyTag(inputChannels: 3, outputChannels: 3) { input in
            input.map { $0 * 0.5 }
        }
        let sourceData = Self.makeProfile(
            colorSpace: "RGB ",
            pcs: "XYZ ",
            tags: [("A2B0", identity), ("A2B1", halved)]
        )
        let destinationData = Self.makeProfile(
            colorSpace: "RGB ",
            pcs: "XYZ ",
            tags: [("B2A0", identity), ("B2A1", identity)]
        )
        let sourceSpace = try #require(CGColorSpace(iccData: sourceData))
        let destinationSpace = try #require(CGColorSpace(iccData: destinationData))
        let sourceColor = CGColor(
            space: sourceSpace,
            componentArray: [0.5, 0.5, 0.5, 1]
        )

        func renderedRed(intent: CGColorRenderingIntent) throws -> UInt8 {
            let optionalContext: OpenCoreGraphics.CGContext? = .init(
                data: nil,
                width: 1,
                height: 1,
                bitsPerComponent: 8,
                bytesPerRow: 4,
                space: destinationSpace,
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
            )
            let context = try #require(optionalContext)
            context.setFillColor(sourceColor)
            context.setRenderingIntent(intent)
            context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
            let image = try #require(context.makeImage())
            let data = try #require(image.data)
            return data[0]
        }

        let perceptual = try renderedRed(intent: .perceptual)
        let relative = try renderedRed(intent: .relativeColorimetric)
        let contextDefault = try renderedRed(intent: .defaultIntent)
        #expect(abs(Int(perceptual) - 128) <= 1)
        #expect(abs(Int(relative) - 64) <= 1)
        #expect(contextDefault == relative)
    }

    @Test("Sampled images use perceptual intent by default and honor context overrides")
    func sampledImageRenderingIntentAffectsPixels() throws {
        let identity = Self.legacyTag(inputChannels: 3, outputChannels: 3) { $0 }
        let halved = Self.legacyTag(inputChannels: 3, outputChannels: 3) { input in
            input.map { $0 * 0.5 }
        }
        let sourceSpace = try #require(CGColorSpace(iccData: Self.makeProfile(
            colorSpace: "RGB ",
            pcs: "XYZ ",
            tags: [("A2B0", identity), ("A2B1", halved)]
        )))
        let destinationSpace = try #require(CGColorSpace(iccData: Self.makeProfile(
            colorSpace: "RGB ",
            pcs: "XYZ ",
            tags: [("B2A0", identity), ("B2A1", identity)]
        )))
        let provider = CGDataProvider(data: Data([128, 128, 128, 255]))
        let optionalImage: OpenCoreGraphics.CGImage? = .init(
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: 4,
            space: sourceSpace,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
        let image = try #require(optionalImage)

        func renderedRed(intent: CGColorRenderingIntent) throws -> UInt8 {
            let optionalContext: OpenCoreGraphics.CGContext? = .init(
                data: nil,
                width: 1,
                height: 1,
                bitsPerComponent: 8,
                bytesPerRow: 4,
                space: destinationSpace,
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
            )
            let context = try #require(optionalContext)
            context.setRenderingIntent(intent)
            context.draw(image, in: CGRect(x: 0, y: 0, width: 1, height: 1))
            let output = try #require(context.makeImage())
            let data = try #require(output.data)
            return data[0]
        }

        let perceptual = try renderedRed(intent: .perceptual)
        let relative = try renderedRed(intent: .relativeColorimetric)
        let contextDefault = try renderedRed(intent: .defaultIntent)
        #expect(abs(Int(perceptual) - 128) <= 1)
        #expect(abs(Int(relative) - 64) <= 1)
        #expect(contextDefault == perceptual)
    }

    @Test("Bitmap drawing does not substitute source components when ICC conversion fails")
    func contextRenderingRejectsUnconvertibleColor() throws {
        let unsupportedData = Self.makeProfile(colorSpace: "RGB ", pcs: "XYZ ", tags: [])
        let unsupportedSpace = try #require(CGColorSpace(iccData: unsupportedData))
        #expect(unsupportedSpace.colorProfile == nil)
        let color = CGColor(
            space: unsupportedSpace,
            componentArray: [1, 0, 0, 1]
        )
        let optionalContext: OpenCoreGraphics.CGContext? = .init(
            data: nil,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: .deviceRGB,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        )
        let context = try #require(optionalContext)

        context.setFillColor(color)
        context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))

        let image = try #require(context.makeImage())
        let data = try #require(image.data)
        #expect(Array(data.prefix(4)) == [0, 0, 0, 0])
    }

    @Test("Absolute colorimetry scales through each profile media white point")
    func absoluteColorimetry() throws {
        let forward = CGICCTransform(
            pipeline: .aToB(Self.bOnlyLUT(curve: .identity)),
            pcsEncoding: .xyz,
            direction: .toPCS
        )
        let reverse = CGICCTransform(
            pipeline: .bToA(Self.bOnlyLUT(curve: .identity)),
            pcsEncoding: .xyz,
            direction: .fromPCS
        )
        let halfWhite = CGColorVector.d50 * 0.5
        let transforms = CGICCTransformSet(
            mediaWhitePoint: halfWhite,
            perceptualToPCS: forward,
            colorimetricToPCS: forward,
            saturationToPCS: nil,
            absoluteToPCS: nil,
            perceptualFromPCS: reverse,
            colorimetricFromPCS: reverse,
            saturationFromPCS: nil,
            absoluteFromPCS: nil
        )
        let relative = try #require(transforms.toPCS([0.5, 0.5, 0.5], intent: .relativeColorimetric))
        let absolute = try #require(transforms.toPCS([0.5, 0.5, 0.5], intent: .absoluteColorimetric))
        #expect(abs(absolute.x - relative.x * 0.5) < 0.000001)
        #expect(abs(absolute.y - relative.y * 0.5) < 0.000001)
        #expect(abs(absolute.z - relative.z * 0.5) < 0.000001)

        let roundTrip = try #require(transforms.fromPCS(absolute, intent: .absoluteColorimetric))
        #expect(abs(roundTrip[0] - 0.5) < 0.000001)
        #expect(abs(roundTrip[1] - 0.5) < 0.000001)
        #expect(abs(roundTrip[2] - 0.5) < 0.000001)
    }

    @Test("Float curve formulas and sampled segments execute over their declared domains")
    func floatCurveSegments() throws {
        let power = CGICCFloatFormula(function: 0, parameters: [2, 1, 0, 0])
        let logarithm = CGICCFloatFormula(function: 1, parameters: [1, 1, 1, 1, 0])
        let exponential = CGICCFloatFormula(function: 2, parameters: [2, 3, 1, 0, 1])
        let zeroBase = CGICCFloatFormula(function: 2, parameters: [1, 0, 0, 1, 0])
        #expect(abs(try #require(power.evaluate(0.5)) - 0.25) < 0.000001)
        #expect(abs(try #require(logarithm.evaluate(9)) - 1) < 0.000001)
        #expect(abs(try #require(exponential.evaluate(2)) - 19) < 0.000001)
        #expect(abs(try #require(zeroBase.evaluate(2))) < 0.000001)

        let curve = CGICCFloatCurve(
            breakpoints: [0, 1],
            segments: [
                .formula(CGICCFloatFormula(function: 0, parameters: [1, 1, 0, 0])),
                .sampled([0.25, 1]),
                .formula(CGICCFloatFormula(function: 0, parameters: [1, 1, 0, 0]))
            ]
        )
        #expect(abs(try #require(curve.evaluate(-0.5)) + 0.5) < 0.000001)
        #expect(abs(try #require(curve.evaluate(0.25)) - 0.125) < 0.000001)
        #expect(abs(try #require(curve.evaluate(0.75)) - 0.625) < 0.000001)
        #expect(abs(try #require(curve.evaluate(1.5)) - 1.5) < 0.000001)
    }

    @Test("Segmented float curves parse and interpolate inside an mpet curve set")
    func parsedSegmentedFloatCurve() throws {
        let curve = Self.segmentedFloatCurve()
        let transform = Self.multiProcess(
            inputChannels: 3,
            outputChannels: 3,
            elements: [Self.floatCurveSet(curves: [curve, curve, curve], storageOrder: [2, 0, 1])]
        )
        let data = Self.makeProfile(
            colorSpace: "RGB ",
            pcs: "XYZ ",
            tags: [("D2B0", transform)]
        )
        let space = try #require(CGColorSpace(iccData: data))
        let profile = try #require(space.colorProfile)
        let pcs = try #require(profile.toPCS([0.25, 0.75, 1.5], intent: .perceptual))
        #expect(abs(pcs.x - 0.125) < 0.000001)
        #expect(abs(pcs.y - 0.625) < 0.000001)
        #expect(abs(pcs.z - 1.5) < 0.000001)
    }

    @Test("D2B and B2D multi-process elements override integer transforms")
    func multiProcessOverrides() throws {
        let gammaCurve = Self.floatCurve(function: 0, parameters: [2, 1, 0, 0])
        let curveSet = Self.floatCurveSet(curves: [gammaCurve, gammaCurve, gammaCurve])
        let matrix = Self.floatMatrix(
            inputChannels: 3,
            outputChannels: 3,
            coefficients: Self.identityMatrixValues,
            offsets: [0.1, 0, 0]
        )
        let clut = Self.floatCLUT(
            inputChannels: 3,
            outputChannels: 3,
            values: Self.identityCLUT(inputChannels: 3, outputChannels: 3)
        )
        let forward = Self.multiProcess(
            inputChannels: 3,
            outputChannels: 3,
            elements: [curveSet, matrix, clut, Self.passThrough(channels: 3)],
            storageOrder: [1, 0, 2, 3]
        )
        let reverse = Self.multiProcess(
            inputChannels: 3,
            outputChannels: 3,
            elements: [Self.floatIdentityMatrix(channels: 3)]
        )
        let data = Self.makeProfile(
            colorSpace: "RGB ",
            pcs: "XYZ ",
            tags: [
                ("A2B0", Data(repeating: 0, count: 8)),
                ("D2B0", forward),
                ("B2D0", reverse)
            ]
        )
        let space = try #require(CGColorSpace(iccData: data))
        let profile = try #require(space.colorProfile)
        let pcs = try #require(profile.toPCS([0.5, 0.5, 0.5], intent: .perceptual))
        #expect(abs(pcs.x - 0.35) < 0.000001)
        #expect(abs(pcs.y - 0.25) < 0.000001)
        #expect(abs(pcs.z - 0.25) < 0.000001)

        let device = try #require(profile.fromPCS(
            CGColorVector(x: 0.2, y: 0.4, z: 0.6),
            intent: .perceptual
        ))
        #expect(abs(device[0] - 0.2) < 0.000001)
        #expect(abs(device[1] - 0.4) < 0.000001)
        #expect(abs(device[2] - 0.6) < 0.000001)
    }

    @Test("D2B3 and B2D3 provide direct absolute-colorimetric transforms")
    func explicitAbsoluteMultiProcess() throws {
        let relative = Self.multiProcess(
            inputChannels: 3,
            outputChannels: 3,
            elements: [Self.floatIdentityMatrix(channels: 3)]
        )
        let absoluteForward = Self.multiProcess(
            inputChannels: 3,
            outputChannels: 3,
            elements: [Self.floatMatrix(
                inputChannels: 3,
                outputChannels: 3,
                coefficients: Self.identityMatrixValues.map { $0 * 0.5 },
                offsets: [0, 0, 0]
            )]
        )
        let absoluteReverse = Self.multiProcess(
            inputChannels: 3,
            outputChannels: 3,
            elements: [Self.floatMatrix(
                inputChannels: 3,
                outputChannels: 3,
                coefficients: Self.identityMatrixValues.map { $0 * 2 },
                offsets: [0, 0, 0]
            )]
        )
        let data = Self.makeProfile(
            colorSpace: "RGB ",
            pcs: "XYZ ",
            tags: [
                ("D2B1", relative),
                ("D2B3", absoluteForward),
                ("B2D1", relative),
                ("B2D3", absoluteReverse)
            ]
        )
        let space = try #require(CGColorSpace(iccData: data))
        let profile = try #require(space.colorProfile)
        let relativePCS = try #require(profile.toPCS([0.4, 0.4, 0.4], intent: .relativeColorimetric))
        let absolutePCS = try #require(profile.toPCS([0.4, 0.4, 0.4], intent: .absoluteColorimetric))
        #expect(abs(relativePCS.y - 0.4) < 0.000001)
        #expect(abs(absolutePCS.y - 0.2) < 0.000001)
        let roundTrip = try #require(profile.fromPCS(absolutePCS, intent: .absoluteColorimetric))
        #expect(abs(roundTrip[0] - 0.4) < 0.000001)
        #expect(abs(roundTrip[1] - 0.4) < 0.000001)
        #expect(abs(roundTrip[2] - 0.4) < 0.000001)
    }

    @Test("Float PCSLAB values convert directly to the D50 XYZ connection space")
    func floatLabPCS() throws {
        let transform = Self.multiProcess(
            inputChannels: 3,
            outputChannels: 3,
            elements: [Self.floatIdentityMatrix(channels: 3)]
        )
        let data = Self.makeProfile(
            colorSpace: "RGB ",
            pcs: "Lab ",
            tags: [("D2B0", transform)]
        )
        let space = try #require(CGColorSpace(iccData: data))
        let profile = try #require(space.colorProfile)
        let pcs = try #require(profile.toPCS([50, 0, 0], intent: .perceptual))
        let neutralY = pow(CGFloat(66) / 116, 3)
        #expect(abs(pcs.x - CGColorVector.d50.x * neutralY) < 0.00001)
        #expect(abs(pcs.y - neutralY) < 0.00001)
        #expect(abs(pcs.z - CGColorVector.d50.z * neutralY) < 0.00001)
    }

    @Test("Malformed LUT combinations and ranges reject the ICC profile")
    func malformedLUTs() {
        var missingCLUT = Self.complexTag(type: "mAB ")
        Self.writeUInt32(0, to: &missingCLUT, at: 24)
        let missingCLUTProfile = Self.makeProfile(
            colorSpace: "RGB ",
            pcs: "XYZ ",
            tags: [("A2B0", missingCLUT)]
        )
        #expect(CGColorSpace(iccData: missingCLUTProfile) == nil)

        var invalidPrecision = Self.complexTag(type: "mAB ")
        invalidPrecision[152 + 16] = 3
        let invalidPrecisionProfile = Self.makeProfile(
            colorSpace: "RGB ",
            pcs: "XYZ ",
            tags: [("A2B0", invalidPrecision)]
        )
        #expect(CGColorSpace(iccData: invalidPrecisionProfile) == nil)
    }

    @Test("Unknown multi-process elements use the ICC-defined integer-table fallback")
    func unknownMultiProcessFallsBack() throws {
        var unknown = Data(repeating: 0, count: 12)
        Self.writeSignature("zzzz", to: &unknown, at: 0)
        Self.writeUInt16(3, to: &unknown, at: 8)
        Self.writeUInt16(3, to: &unknown, at: 10)
        let multiProcess = Self.multiProcess(inputChannels: 3, outputChannels: 3, elements: [unknown])
        let data = Self.makeProfile(
            colorSpace: "RGB ",
            pcs: "XYZ ",
            tags: [
                ("A2B0", Self.complexTag(type: "mAB ")),
                ("D2B0", multiProcess)
            ]
        )
        let space = try #require(CGColorSpace(iccData: data))
        let profile = try #require(space.colorProfile)
        let pcs = try #require(profile.toPCS([0.5, 0.5, 0.5], intent: .perceptual))
        let expected = CGFloat(0.5) * 65_535 / 32_768
        #expect(abs(pcs.x - expected) < 0.000001)
        #expect(abs(pcs.y - expected) < 0.000001)
        #expect(abs(pcs.z - expected) < 0.000001)

        let unknownOnlyData = Self.makeProfile(
            colorSpace: "RGB ",
            pcs: "XYZ ",
            tags: [("D2B0", multiProcess)]
        )
        let unknownOnly = try #require(CGColorSpace(iccData: unknownOnlyData))
        #expect(unknownOnly.colorProfile == nil)
        let destination = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        #expect(CGColorConversionInfo(src: unknownOnly, dst: destination) == nil)
    }

    @Test("Malformed known multi-process elements reject the ICC profile")
    func malformedMultiProcessFails() {
        var malformed = Data(repeating: 0, count: 16)
        Self.writeSignature("mpet", to: &malformed, at: 0)
        let data = Self.makeProfile(
            colorSpace: "RGB ",
            pcs: "XYZ ",
            tags: [
                ("A2B0", Self.complexTag(type: "mAB ")),
                ("D2B0", malformed)
            ]
        )
        #expect(CGColorSpace(iccData: data) == nil)

        var subnormalMatrix = Self.floatIdentityMatrix(channels: 3)
        Self.writeUInt32(1, to: &subnormalMatrix, at: 12)
        let subnormalData = Self.makeProfile(
            colorSpace: "RGB ",
            pcs: "XYZ ",
            tags: [("D2B0", Self.multiProcess(
                inputChannels: 3,
                outputChannels: 3,
                elements: [subnormalMatrix]
            ))]
        )
        #expect(CGColorSpace(iccData: subnormalData) == nil)

        var oversizedPassThrough = Data(repeating: 0, count: 20)
        Self.writeSignature("bACS", to: &oversizedPassThrough, at: 0)
        Self.writeUInt16(3, to: &oversizedPassThrough, at: 8)
        Self.writeUInt16(3, to: &oversizedPassThrough, at: 10)
        let oversizedData = Self.makeProfile(
            colorSpace: "RGB ",
            pcs: "XYZ ",
            tags: [("D2B0", Self.multiProcess(
                inputChannels: 3,
                outputChannels: 3,
                elements: [oversizedPassThrough]
            ))]
        )
        #expect(CGColorSpace(iccData: oversizedData) == nil)
    }

    private static func bOnlyLUT(curve: CGTransferCurve) -> CGICCComplexLUT {
        CGICCComplexLUT(
            inputChannels: 3,
            outputChannels: 3,
            aCurves: nil,
            clut: nil,
            mCurves: nil,
            matrix: nil,
            matrixOffset: nil,
            bCurves: [curve, curve, curve]
        )
    }

    private static func cicpTag(primaries: UInt8, transfer: UInt8) -> Data {
        var data = Data(repeating: 0, count: 12)
        writeSignature("cicp", to: &data, at: 0)
        data[8] = primaries
        data[9] = transfer
        data[10] = 0
        data[11] = 1
        return data
    }

    private static let identityMatrixValues: [CGFloat] = [
        1, 0, 0,
        0, 1, 0,
        0, 0, 1
    ]

    private static func multiProcess(
        inputChannels: Int,
        outputChannels: Int,
        elements: [Data],
        storageOrder: [Int]? = nil
    ) -> Data {
        let order = storageOrder ?? Array(elements.indices)
        precondition(order.sorted() == Array(elements.indices))
        let tableEnd = 16 + elements.count * 8
        let size = elements.reduce(tableEnd) { $0 + $1.count }
        var data = Data(repeating: 0, count: size)
        writeSignature("mpet", to: &data, at: 0)
        writeUInt16(UInt16(inputChannels), to: &data, at: 8)
        writeUInt16(UInt16(outputChannels), to: &data, at: 10)
        writeUInt32(UInt32(elements.count), to: &data, at: 12)
        var payloadOffset = tableEnd
        var positions = Array(repeating: 0, count: elements.count)
        for index in order {
            positions[index] = payloadOffset
            let element = elements[index]
            data.replaceSubrange(payloadOffset..<(payloadOffset + element.count), with: element)
            payloadOffset += element.count
        }
        for (index, element) in elements.enumerated() {
            let entry = 16 + index * 8
            writeUInt32(UInt32(positions[index]), to: &data, at: entry)
            writeUInt32(UInt32(element.count), to: &data, at: entry + 4)
        }
        return data
    }

    private static func floatCurveSet(curves: [Data], storageOrder: [Int]? = nil) -> Data {
        let order = storageOrder ?? Array(curves.indices)
        precondition(order.sorted() == Array(curves.indices))
        let tableEnd = 12 + curves.count * 8
        let size = curves.reduce(tableEnd) { $0 + $1.count }
        var data = Data(repeating: 0, count: size)
        writeSignature("cvst", to: &data, at: 0)
        writeUInt16(UInt16(curves.count), to: &data, at: 8)
        writeUInt16(UInt16(curves.count), to: &data, at: 10)
        var payloadOffset = tableEnd
        var positions = Array(repeating: 0, count: curves.count)
        for index in order {
            positions[index] = payloadOffset
            let curve = curves[index]
            data.replaceSubrange(payloadOffset..<(payloadOffset + curve.count), with: curve)
            payloadOffset += curve.count
        }
        for (index, curve) in curves.enumerated() {
            let entry = 12 + index * 8
            writeUInt32(UInt32(positions[index]), to: &data, at: entry)
            writeUInt32(UInt32(curve.count), to: &data, at: entry + 4)
        }
        return data
    }

    private static func floatCurve(function: UInt16, parameters: [CGFloat]) -> Data {
        let parameterCount = function == 0 ? 4 : 5
        precondition(parameters.count == parameterCount)
        var data = Data(repeating: 0, count: 12 + 12 + parameterCount * 4)
        writeSignature("curf", to: &data, at: 0)
        writeUInt16(1, to: &data, at: 8)
        writeSignature("parf", to: &data, at: 12)
        writeUInt16(function, to: &data, at: 20)
        for (index, value) in parameters.enumerated() {
            writeFloat32(value, to: &data, at: 24 + index * 4)
        }
        return data
    }

    private static func segmentedFloatCurve() -> Data {
        var data = Data(repeating: 0, count: 96)
        writeSignature("curf", to: &data, at: 0)
        writeUInt16(3, to: &data, at: 8)
        writeFloat32(0, to: &data, at: 12)
        writeFloat32(1, to: &data, at: 16)

        writeSignature("parf", to: &data, at: 20)
        writeUInt16(0, to: &data, at: 28)
        for (index, value) in [CGFloat(1), 1, 0, 0].enumerated() {
            writeFloat32(value, to: &data, at: 32 + index * 4)
        }

        writeSignature("samf", to: &data, at: 48)
        writeUInt32(2, to: &data, at: 56)
        writeFloat32(0.25, to: &data, at: 60)
        writeFloat32(1, to: &data, at: 64)

        writeSignature("parf", to: &data, at: 68)
        writeUInt16(0, to: &data, at: 76)
        for (index, value) in [CGFloat(1), 1, 0, 0].enumerated() {
            writeFloat32(value, to: &data, at: 80 + index * 4)
        }
        return data
    }

    private static func floatMatrix(
        inputChannels: Int,
        outputChannels: Int,
        coefficients: [CGFloat],
        offsets: [CGFloat]
    ) -> Data {
        precondition(coefficients.count == inputChannels * outputChannels)
        precondition(offsets.count == outputChannels)
        let values = coefficients + offsets
        var data = Data(repeating: 0, count: 12 + values.count * 4)
        writeSignature("matf", to: &data, at: 0)
        writeUInt16(UInt16(inputChannels), to: &data, at: 8)
        writeUInt16(UInt16(outputChannels), to: &data, at: 10)
        for (index, value) in values.enumerated() {
            writeFloat32(value, to: &data, at: 12 + index * 4)
        }
        return data
    }

    private static func floatIdentityMatrix(channels: Int) -> Data {
        var coefficients = Array(repeating: CGFloat.zero, count: channels * channels)
        for channel in 0..<channels { coefficients[channel * channels + channel] = 1 }
        return floatMatrix(
            inputChannels: channels,
            outputChannels: channels,
            coefficients: coefficients,
            offsets: Array(repeating: 0, count: channels)
        )
    }

    private static func floatCLUT(
        inputChannels: Int,
        outputChannels: Int,
        values: [CGFloat]
    ) -> Data {
        var data = Data(repeating: 0, count: 28 + values.count * 4)
        writeSignature("clut", to: &data, at: 0)
        writeUInt16(UInt16(inputChannels), to: &data, at: 8)
        writeUInt16(UInt16(outputChannels), to: &data, at: 10)
        for channel in 0..<inputChannels { data[12 + channel] = 2 }
        for (index, value) in values.enumerated() {
            writeFloat32(value, to: &data, at: 28 + index * 4)
        }
        return data
    }

    private static func passThrough(channels: Int) -> Data {
        var data = Data(repeating: 0, count: 16)
        writeSignature("bACS", to: &data, at: 0)
        writeUInt16(UInt16(channels), to: &data, at: 8)
        writeUInt16(UInt16(channels), to: &data, at: 10)
        return data
    }

    private static func complexTag(type: String) -> Data {
        let bOffset = 32
        let matrixOffset = 68
        let mOffset = 116
        let clutOffset = 152
        let aOffset = 196
        var data = Data(repeating: 0, count: 232)
        writeSignature(type, to: &data, at: 0)
        data[8] = 3
        data[9] = 3
        writeUInt32(UInt32(bOffset), to: &data, at: 12)
        writeUInt32(UInt32(matrixOffset), to: &data, at: 16)
        writeUInt32(UInt32(mOffset), to: &data, at: 20)
        writeUInt32(UInt32(clutOffset), to: &data, at: 24)
        writeUInt32(UInt32(aOffset), to: &data, at: 28)
        writeIdentityCurves(to: &data, at: bOffset, count: 3)
        writeIdentityMatrix(to: &data, at: matrixOffset)
        writeIdentityCurves(to: &data, at: mOffset, count: 3)
        writeCLUT(identityCLUT(inputChannels: 3, outputChannels: 3), gridPoints: [2, 2, 2], to: &data, at: clutOffset)
        writeIdentityCurves(to: &data, at: aOffset, count: 3)
        return data
    }

    private static func legacyTag(
        inputChannels: Int,
        outputChannels: Int,
        function: ([CGFloat]) -> [CGFloat]
    ) -> Data {
        let gridPoints = 2
        let inputEntryCount = 2
        let outputEntryCount = 2
        let clutPointCount = 1 << inputChannels
        let valueCount = inputChannels * inputEntryCount
            + clutPointCount * outputChannels
            + outputChannels * outputEntryCount
        var data = Data(repeating: 0, count: 52 + valueCount * 2)
        writeSignature("mft2", to: &data, at: 0)
        data[8] = UInt8(inputChannels)
        data[9] = UInt8(outputChannels)
        data[10] = UInt8(gridPoints)
        writeIdentityMatrix(to: &data, at: 12, includeOffset: false)
        writeUInt16(UInt16(inputEntryCount), to: &data, at: 48)
        writeUInt16(UInt16(outputEntryCount), to: &data, at: 50)

        var cursor = 52
        for _ in 0..<inputChannels {
            writeUInt16(0, to: &data, at: cursor)
            writeUInt16(65_535, to: &data, at: cursor + 2)
            cursor += 4
        }
        for point in 0..<clutPointCount {
            let input = (0..<inputChannels).map { channel in
                CGFloat((point >> (inputChannels - channel - 1)) & 1)
            }
            for value in function(input) {
                writeUInt16(UInt16((min(max(value, 0), 1) * 65_535).rounded()), to: &data, at: cursor)
                cursor += 2
            }
        }
        for _ in 0..<outputChannels {
            writeUInt16(0, to: &data, at: cursor)
            writeUInt16(65_535, to: &data, at: cursor + 2)
            cursor += 4
        }
        return data
    }

    private static func legacy8IdentityTag() -> Data {
        let inputChannels = 3
        let outputChannels = 3
        let gridPoints = 2
        let clutValues = identityCLUT(inputChannels: inputChannels, outputChannels: outputChannels)
        let size = 48 + inputChannels * 256 + clutValues.count + outputChannels * 256
        var data = Data(repeating: 0, count: size)
        writeSignature("mft1", to: &data, at: 0)
        data[8] = UInt8(inputChannels)
        data[9] = UInt8(outputChannels)
        data[10] = UInt8(gridPoints)
        writeIdentityMatrix(to: &data, at: 12, includeOffset: false)

        var cursor = 48
        for _ in 0..<inputChannels {
            for value in 0...255 { data[cursor + value] = UInt8(value) }
            cursor += 256
        }
        for value in clutValues {
            data[cursor] = UInt8((value * 255).rounded())
            cursor += 1
        }
        for _ in 0..<outputChannels {
            for value in 0...255 { data[cursor + value] = UInt8(value) }
            cursor += 256
        }
        return data
    }

    private static func makeProfile(
        colorSpace: String,
        pcs: String,
        tags: [(String, Data)]
    ) -> Data {
        let tableEnd = 132 + tags.count * 12
        let size = tags.reduce(tableEnd) { $0 + $1.1.count }
        var data = Data(repeating: 0, count: size)
        writeUInt32(UInt32(size), to: &data, at: 0)
        writeSignature("mntr", to: &data, at: 12)
        writeSignature(colorSpace, to: &data, at: 16)
        writeSignature(pcs, to: &data, at: 20)
        writeSignature("acsp", to: &data, at: 36)
        writeS15Fixed16(CGColorVector.d50.x, to: &data, at: 68)
        writeS15Fixed16(CGColorVector.d50.y, to: &data, at: 72)
        writeS15Fixed16(CGColorVector.d50.z, to: &data, at: 76)
        writeUInt32(UInt32(tags.count), to: &data, at: 128)

        var payloadOffset = tableEnd
        for (index, tag) in tags.enumerated() {
            let entry = 132 + index * 12
            writeSignature(tag.0, to: &data, at: entry)
            writeUInt32(UInt32(payloadOffset), to: &data, at: entry + 4)
            writeUInt32(UInt32(tag.1.count), to: &data, at: entry + 8)
            data.replaceSubrange(payloadOffset..<(payloadOffset + tag.1.count), with: tag.1)
            payloadOffset += tag.1.count
        }
        return data
    }

    private static func identityCLUT(inputChannels: Int, outputChannels: Int) -> [CGFloat] {
        let pointCount = 1 << inputChannels
        var values: [CGFloat] = []
        values.reserveCapacity(pointCount * outputChannels)
        for point in 0..<pointCount {
            let input = (0..<inputChannels).map { channel in
                CGFloat((point >> (inputChannels - channel - 1)) & 1)
            }
            for channel in 0..<outputChannels {
                values.append(channel < input.count ? input[channel] : 0)
            }
        }
        return values
    }

    private static func writeCLUT(
        _ values: [CGFloat],
        gridPoints: [Int],
        to data: inout Data,
        at offset: Int
    ) {
        for (index, count) in gridPoints.enumerated() { data[offset + index] = UInt8(count) }
        data[offset + 16] = 1
        for (index, value) in values.enumerated() {
            data[offset + 20 + index] = UInt8((min(max(value, 0), 1) * 255).rounded())
        }
    }

    private static func writeIdentityCurves(to data: inout Data, at offset: Int, count: Int) {
        for index in 0..<count {
            writeSignature("curv", to: &data, at: offset + index * 12)
            writeUInt32(0, to: &data, at: offset + index * 12 + 8)
        }
    }

    private static func writeIdentityMatrix(to data: inout Data, at offset: Int, includeOffset: Bool = true) {
        let values: [CGFloat] = includeOffset
            ? [1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0]
            : [1, 0, 0, 0, 1, 0, 0, 0, 1]
        for (index, value) in values.enumerated() {
            writeS15Fixed16(value, to: &data, at: offset + index * 4)
        }
    }

    private static func writeSignature(_ signature: String, to data: inout Data, at offset: Int) {
        for (index, byte) in signature.utf8.prefix(4).enumerated() { data[offset + index] = byte }
    }

    private static func writeUInt16(_ value: UInt16, to data: inout Data, at offset: Int) {
        data[offset] = UInt8((value >> 8) & 0xff)
        data[offset + 1] = UInt8(value & 0xff)
    }

    private static func writeUInt32(_ value: UInt32, to data: inout Data, at offset: Int) {
        data[offset] = UInt8((value >> 24) & 0xff)
        data[offset + 1] = UInt8((value >> 16) & 0xff)
        data[offset + 2] = UInt8((value >> 8) & 0xff)
        data[offset + 3] = UInt8(value & 0xff)
    }

    private static func writeS15Fixed16(_ value: CGFloat, to data: inout Data, at offset: Int) {
        writeUInt32(UInt32(bitPattern: Int32((value * 65_536).rounded())), to: &data, at: offset)
    }

    private static func writeFloat32(_ value: CGFloat, to data: inout Data, at offset: Int) {
        writeUInt32(Float(value).bitPattern, to: &data, at: offset)
    }
}
