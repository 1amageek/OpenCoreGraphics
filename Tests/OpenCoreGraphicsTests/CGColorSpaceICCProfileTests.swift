//
//  CGColorSpaceICCProfileTests.swift
//  OpenCoreGraphics
//

import Foundation
import Testing
@testable import OpenCoreGraphics

@Suite("CGColorSpace ICC Profile Tests")
struct CGColorSpaceICCProfileTests {
    @Test("ICC tag table determines model and preserves profile")
    func parsesProfile() throws {
        let rgbProfile = Self.rgbMatrixProfile()
        let rgb = try #require(CGColorSpace(iccData: rgbProfile))
        #expect(rgb.model == .rgb)
        #expect(rgb.numberOfComponents == 3)
        #expect(rgb.copyICCData() == rgbProfile)
        #expect(rgb.colorProfile != nil)

        let grayProfile = Self.grayMatrixProfile()
        let gray = try #require(CGColorSpace(iccData: grayProfile))
        #expect(gray.model == .monochrome)
        #expect(gray.numberOfComponents == 1)
        #expect(gray.colorProfile != nil)

        let deviceN = try #require(CGColorSpace(iccData: Self.headerOnlyProfile(signature: "5CLR")))
        #expect(deviceN.model == .deviceN)
        #expect(deviceN.numberOfComponents == 5)
        #expect(deviceN.colorProfile == nil)
    }

    @Test("Matrix and parametric TRC profile performs an actual conversion")
    func matrixTRCConversion() throws {
        let profileSpace = try #require(CGColorSpace(iccData: Self.rgbMatrixProfile()))
        let linearSpace = try #require(CGColorSpace(name: CGColorSpace.linearSRGB))
        let source = try #require(CGColor(colorSpace: profileSpace, components: [0.5, 0.5, 0.5, 0.75]))
        let converted = try #require(source.converted(to: linearSpace, intent: .relativeColorimetric, options: nil))
        let components = try #require(converted.components)

        #expect(abs(components[0] - 0.21404) < 0.0002)
        #expect(abs(components[1] - 0.21404) < 0.0002)
        #expect(abs(components[2] - 0.21404) < 0.0002)
        #expect(components[3] == 0.75)
    }

    @Test("Curve table profile interpolates and inverts monotonically")
    func curveTableConversion() throws {
        let graySpace = try #require(CGColorSpace(iccData: Self.grayMatrixProfile()))
        let linearGray = try #require(CGColorSpace(name: CGColorSpace.linearGray))
        let source = try #require(CGColor(colorSpace: graySpace, components: [0.5, 1]))
        let linear = try #require(source.converted(to: linearGray, intent: .relativeColorimetric, options: nil))
        let linearValue = try #require(linear.components?.first)
        #expect(abs(linearValue - 0.25) < 0.0001)

        let roundTrip = try #require(linear.converted(to: graySpace, intent: .relativeColorimetric, options: nil))
        let roundTripValue = try #require(roundTrip.components?.first)
        #expect(abs(roundTripValue - 0.5) < 0.0001)
    }

    @Test("Unsupported ICC transform does not silently use a model fallback")
    func unsupportedTransformFails() throws {
        let cmyk = try #require(CGColorSpace(iccData: Self.headerOnlyProfile(signature: "CMYK")))
        let color = try #require(CGColor(colorSpace: cmyk, components: [0, 1, 1, 0, 1]))
        let destination = try #require(CGColorSpace(name: CGColorSpace.sRGB))

        #expect(color.converted(to: destination, intent: .relativeColorimetric, options: nil) == nil)
        #expect(CGColorConversionInfo(src: cmyk, dst: destination) == nil)
    }

    @Test("Distinct ICC profiles are not equal")
    func profileIdentityAffectsEquality() throws {
        let rgb = try #require(CGColorSpace(iccData: Self.rgbMatrixProfile()))
        let gray = try #require(CGColorSpace(iccData: Self.grayMatrixProfile()))
        #expect(rgb != gray)

        var modified = Self.rgbMatrixProfile()
        modified[84] = 1
        let secondRGB = try #require(CGColorSpace(iccData: modified))
        #expect(rgb != secondRGB)
        #expect(Set([rgb, secondRGB]).count == 2)
    }

    @Test("Invalid ICC structures fail")
    func rejectsInvalidStructures() {
        #expect(CGColorSpace(iccData: Data(repeating: 0, count: 131)) == nil)

        var invalidMagic = Self.rgbMatrixProfile()
        invalidMagic[36] = 0
        #expect(CGColorSpace(iccData: invalidMagic) == nil)

        var oversized = Self.rgbMatrixProfile()
        Self.writeUInt32(UInt32(oversized.count + 1), to: &oversized, at: 0)
        #expect(CGColorSpace(iccData: oversized) == nil)

        var invalidTagRange = Self.rgbMatrixProfile()
        Self.writeUInt32(UInt32(invalidTagRange.count - 4), to: &invalidTagRange, at: 136)
        Self.writeUInt32(20, to: &invalidTagRange, at: 140)
        #expect(CGColorSpace(iccData: invalidTagRange) == nil)

        var duplicateTag = Self.rgbMatrixProfile()
        for byte in 0..<4 { duplicateTag[144 + byte] = duplicateTag[132 + byte] }
        #expect(CGColorSpace(iccData: duplicateTag) == nil)

        #expect(CGColorSpace(iccData: Self.headerOnlyProfile(signature: "YUV ")) == nil)
    }

    private static func rgbMatrixProfile() -> Data {
        let tagCount = 7
        let tagTableEnd = 132 + tagCount * 12
        let redXYZOffset = tagTableEnd
        let greenXYZOffset = redXYZOffset + 20
        let blueXYZOffset = greenXYZOffset + 20
        let whitePointOffset = blueXYZOffset + 20
        let curveOffset = whitePointOffset + 20
        let profileSize = curveOffset + 40
        var data = makeHeader(size: profileSize, colorSpace: "RGB ", pcs: "XYZ ", tagCount: tagCount)

        writeTag("rXYZ", offset: redXYZOffset, size: 20, to: &data, index: 0)
        writeTag("gXYZ", offset: greenXYZOffset, size: 20, to: &data, index: 1)
        writeTag("bXYZ", offset: blueXYZOffset, size: 20, to: &data, index: 2)
        writeTag("rTRC", offset: curveOffset, size: 40, to: &data, index: 3)
        writeTag("gTRC", offset: curveOffset, size: 40, to: &data, index: 4)
        writeTag("bTRC", offset: curveOffset, size: 40, to: &data, index: 5)
        writeTag("wtpt", offset: whitePointOffset, size: 20, to: &data, index: 6)

        writeXYZ(x: 0.4360747, y: 0.2225045, z: 0.0139322, to: &data, at: redXYZOffset)
        writeXYZ(x: 0.3850649, y: 0.7168786, z: 0.0971045, to: &data, at: greenXYZOffset)
        writeXYZ(x: 0.1430804, y: 0.0606169, z: 0.7141733, to: &data, at: blueXYZOffset)
        writeXYZ(x: 0.9642, y: 1, z: 0.8249, to: &data, at: whitePointOffset)

        writeSignature("para", to: &data, at: curveOffset)
        writeUInt16(4, to: &data, at: curveOffset + 8)
        let parameters: [CGFloat] = [2.4, 1 / 1.055, 0.055 / 1.055, 1 / 12.92, 0.04045, 0, 0]
        for (index, parameter) in parameters.enumerated() {
            writeS15Fixed16(parameter, to: &data, at: curveOffset + 12 + index * 4)
        }
        return data
    }

    private static func grayMatrixProfile() -> Data {
        let tagCount = 2
        let tagTableEnd = 132 + tagCount * 12
        let whitePointOffset = tagTableEnd
        let curveOffset = whitePointOffset + 20
        let profileSize = curveOffset + 20
        var data = makeHeader(size: profileSize, colorSpace: "GRAY", pcs: "XYZ ", tagCount: tagCount)
        writeTag("wtpt", offset: whitePointOffset, size: 20, to: &data, index: 0)
        writeTag("kTRC", offset: curveOffset, size: 20, to: &data, index: 1)
        writeXYZ(x: 0.9642, y: 1, z: 0.8249, to: &data, at: whitePointOffset)
        writeSignature("curv", to: &data, at: curveOffset)
        writeUInt32(3, to: &data, at: curveOffset + 8)
        for (index, sample) in [0, 16384, 65535].enumerated() {
            writeUInt16(UInt16(sample), to: &data, at: curveOffset + 12 + index * 2)
        }
        return data
    }

    private static func headerOnlyProfile(signature: String) -> Data {
        makeHeader(size: 132, colorSpace: signature, pcs: "XYZ ", tagCount: 0)
    }

    private static func makeHeader(size: Int, colorSpace: String, pcs: String, tagCount: Int) -> Data {
        var data = Data(repeating: 0, count: size)
        writeUInt32(UInt32(size), to: &data, at: 0)
        writeSignature("mntr", to: &data, at: 12)
        writeSignature(colorSpace, to: &data, at: 16)
        writeSignature(pcs, to: &data, at: 20)
        writeSignature("acsp", to: &data, at: 36)
        writeS15Fixed16(0.9642, to: &data, at: 68)
        writeS15Fixed16(1, to: &data, at: 72)
        writeS15Fixed16(0.8249, to: &data, at: 76)
        writeUInt32(UInt32(tagCount), to: &data, at: 128)
        return data
    }

    private static func writeTag(_ signature: String, offset: Int, size: Int, to data: inout Data, index: Int) {
        let entry = 132 + index * 12
        writeSignature(signature, to: &data, at: entry)
        writeUInt32(UInt32(offset), to: &data, at: entry + 4)
        writeUInt32(UInt32(size), to: &data, at: entry + 8)
    }

    private static func writeXYZ(x: CGFloat, y: CGFloat, z: CGFloat, to data: inout Data, at offset: Int) {
        writeSignature("XYZ ", to: &data, at: offset)
        writeS15Fixed16(x, to: &data, at: offset + 8)
        writeS15Fixed16(y, to: &data, at: offset + 12)
        writeS15Fixed16(z, to: &data, at: offset + 16)
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
        writeUInt32(UInt32(bitPattern: Int32((value * 65536).rounded())), to: &data, at: offset)
    }
}
