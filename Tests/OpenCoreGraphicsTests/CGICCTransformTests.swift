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
            perceptualFromPCS: nil,
            colorimetricFromPCS: nil,
            saturationFromPCS: nil
        )
        let perceptual = try #require(transforms.toPCS([0.5, 0.5, 0.5], intent: .perceptual))
        let relative = try #require(transforms.toPCS([0.5, 0.5, 0.5], intent: .relativeColorimetric))
        #expect(abs(perceptual.y - 0.99998474) < 0.00001)
        #expect(abs(relative.y - 0.49999237) < 0.00001)
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
            perceptualFromPCS: reverse,
            colorimetricFromPCS: reverse,
            saturationFromPCS: nil
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

    @Test("Floating multi-process overrides do not fall back to older ICC tables")
    func floatingOverrideFailsExplicitly() throws {
        var multiProcess = Data(repeating: 0, count: 16)
        Self.writeSignature("mpet", to: &multiProcess, at: 0)
        let data = Self.makeProfile(
            colorSpace: "RGB ",
            pcs: "XYZ ",
            tags: [
                ("A2B0", Self.complexTag(type: "mAB ")),
                ("D2B0", multiProcess)
            ]
        )
        let space = try #require(CGColorSpace(iccData: data))
        #expect(space.colorProfile == nil)
        let destination = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let source = try #require(CGColor(colorSpace: space, components: [0.5, 0.5, 0.5, 1]))
        #expect(source.converted(to: destination, intent: .perceptual, options: nil) == nil)
        #expect(CGColorConversionInfo(src: space, dst: destination) == nil)
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
}
