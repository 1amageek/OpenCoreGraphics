//
//  CGColorSpaceICCProfileTests.swift
//  OpenCoreGraphics
//

import Foundation
import Testing
@testable import OpenCoreGraphics

@Suite("CGColorSpace ICC Profile Tests")
struct CGColorSpaceICCProfileTests {
    @Test("ICC header determines color model and preserves profile")
    func parsesHeader() throws {
        let rgbProfile = profile(signature: "RGB ")
        let rgb = try #require(CGColorSpace(iccData: rgbProfile))
        #expect(rgb.model == .rgb)
        #expect(rgb.numberOfComponents == 3)
        #expect(rgb.copyICCData() == rgbProfile)

        let gray = try #require(CGColorSpace(iccData: profile(signature: "GRAY")))
        #expect(gray.model == .monochrome)
        #expect(gray.numberOfComponents == 1)

        let deviceN = try #require(CGColorSpace(iccData: profile(signature: "5CLR")))
        #expect(deviceN.model == .deviceN)
        #expect(deviceN.numberOfComponents == 5)
    }

    @Test("Invalid ICC headers fail")
    func rejectsInvalidHeaders() {
        #expect(CGColorSpace(iccData: Data(repeating: 0, count: 127)) == nil)

        var invalidMagic = profile(signature: "RGB ")
        invalidMagic[36] = 0
        #expect(CGColorSpace(iccData: invalidMagic) == nil)

        var oversized = profile(signature: "RGB ")
        oversized[3] = 129
        #expect(CGColorSpace(iccData: oversized) == nil)

        #expect(CGColorSpace(iccData: profile(signature: "YUV ")) == nil)
    }

    private func profile(signature: String) -> Data {
        var bytes = [UInt8](repeating: 0, count: 128)
        bytes[3] = 128
        let signatureBytes = Array(signature.utf8)
        for index in 0..<min(signatureBytes.count, 4) {
            bytes[16 + index] = signatureBytes[index]
        }
        bytes[36] = 0x61
        bytes[37] = 0x63
        bytes[38] = 0x73
        bytes[39] = 0x70
        return Data(bytes)
    }
}
