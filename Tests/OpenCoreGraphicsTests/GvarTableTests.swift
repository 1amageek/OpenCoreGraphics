//
//  GvarTableTests.swift
//  OpenCoreGraphicsTests
//

import Foundation
import Testing
@testable import OpenCoreGraphics

@Suite("TrueType gvar tests")
struct GvarTableTests {
    @Test("Private packed points drive contour-local IUP interpolation")
    func privatePointsAndIUP() throws {
        let table = try #require(GvarTable(
            data: makeTable(serializedData: Data([
                2, 1, 0, 2,
                1, 10, 30,
                0x81
            ])),
            axisCount: 1,
            glyphCount: 1
        ))
        let points = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 50, y: 40),
            CGPoint(x: 100, y: 0),
            CGPoint.zero, CGPoint.zero, CGPoint.zero, CGPoint.zero
        ]
        let deltas = try #require(table.adjustments(
            glyphIndex: 0,
            pointCount: points.count,
            normalizedCoordinates: [1],
            originalPoints: points,
            contourRanges: [0..<3]
        ))

        #expect(deltas[0] == CGPoint(x: 10, y: 0))
        #expect(deltas[1] == CGPoint(x: 20, y: 0))
        #expect(deltas[2] == CGPoint(x: 30, y: 0))
        #expect(deltas[3...] == ArraySlice(repeating: .zero, count: 4))
    }

    @Test("Repeated packed point numbers accumulate their deltas")
    func repeatedPointsAccumulate() throws {
        let table = try #require(GvarTable(
            data: makeTable(serializedData: Data([
                2, 1, 0, 0,
                1, 5, 7,
                0x81
            ])),
            axisCount: 1,
            glyphCount: 1
        ))
        let points = [CGPoint.zero, CGPoint(x: 20, y: 0)]
            + [CGPoint](repeating: .zero, count: 4)
        let deltas = try #require(table.adjustments(
            glyphIndex: 0,
            pointCount: points.count,
            normalizedCoordinates: [1],
            originalPoints: points,
            contourRanges: [0..<2]
        ))

        #expect(deltas[0].x == 12)
        #expect(deltas[1].x == 12)
    }

    @Test("Tuple peaks scale deltas and reject out-of-region coordinates")
    func tupleScalar() throws {
        let table = try #require(GvarTable(
            data: makeTable(serializedData: Data([
                2, 1, 0, 2,
                1, 10, 30,
                0x81
            ])),
            axisCount: 1,
            glyphCount: 1
        ))
        let points = [CGPoint.zero, CGPoint(x: 50, y: 0), CGPoint(x: 100, y: 0)]
            + [CGPoint](repeating: .zero, count: 4)
        let midpoint = try #require(table.adjustments(
            glyphIndex: 0,
            pointCount: points.count,
            normalizedCoordinates: [0.5],
            originalPoints: points,
            contourRanges: [0..<3]
        ))
        let opposite = try #require(table.adjustments(
            glyphIndex: 0,
            pointCount: points.count,
            normalizedCoordinates: [-0.5],
            originalPoints: points,
            contourRanges: [0..<3]
        ))

        #expect(midpoint[1].x == 10)
        #expect(opposite.allSatisfy { $0 == .zero })
    }

    @Test("Malformed gvar headers and tuple ranges are rejected")
    func malformedTables() {
        var reservedFlags = makeTable(serializedData: Data([
            2, 1, 0, 2, 1, 10, 30, 0x81
        ]))
        reservedFlags[14] = 0x80
        #expect(GvarTable(data: reservedFlags, axisCount: 1, glyphCount: 1) == nil)

        var invalidDataOffset = makeTable(serializedData: Data([
            2, 1, 0, 2, 1, 10, 30, 0x81
        ]))
        invalidDataOffset[27] = 4
        #expect(GvarTable(data: invalidDataOffset, axisCount: 1, glyphCount: 1) == nil)

        var outOfBoundsSharedTuples = makeTable(serializedData: Data([
            2, 1, 0, 2, 1, 10, 30, 0x81
        ]))
        outOfBoundsSharedTuples.replaceSubrange(8..<12, with: [0xFF, 0xFF, 0xFF, 0xFF])
        #expect(GvarTable(data: outOfBoundsSharedTuples, axisCount: 1, glyphCount: 1) == nil)
    }

    @Test("Installed TrueType variable font changes real outlines and metrics")
    func installedVariableFont() throws {
        let candidates = [
            "/System/Library/Fonts/Supplemental/Skia.ttf",
            "/System/Library/Fonts/SFNS.ttf"
        ]
        guard let path = candidates.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
            return
        }
        let data = try Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe)
        let font = try #require(CGFont(CGDataProvider(data: data)))
        #expect(font.table(for: FontTableTag.gvar) != nil)
        let axis = try #require(font.variationAxes?.first)
        let axisName = try #require(axis[kCGFontVariationAxisName] as? String)
        let maximum = try #require(axis[kCGFontVariationAxisMaxValue] as? CGFloat)
        let varied = try #require(font.copy(withVariations: [axisName: maximum]))

        var decoded = 0
        var changed = 0
        for glyphIndex in 0..<min(font.numberOfGlyphs, 256) {
            guard let defaultPath = font.path(for: CGGlyph(glyphIndex)),
                  let variedPath = varied.path(for: CGGlyph(glyphIndex)) else {
                continue
            }
            decoded += 1
            if defaultPath.boundingBox != variedPath.boundingBox { changed += 1 }
        }
        #expect(decoded >= 128)
        #expect(changed > 0)

        let glyphs = (0..<min(font.numberOfGlyphs, 256)).map(CGGlyph.init)
        var defaultAdvances = [Int32](repeating: 0, count: glyphs.count)
        var variedAdvances = [Int32](repeating: 0, count: glyphs.count)
        let advancesSucceeded = glyphs.withUnsafeBufferPointer { glyphBuffer in
            defaultAdvances.withUnsafeMutableBufferPointer { defaultBuffer in
                variedAdvances.withUnsafeMutableBufferPointer { variedBuffer in
                    font.getGlyphAdvances(
                        glyphs: glyphBuffer.baseAddress!,
                        count: glyphBuffer.count,
                        advances: defaultBuffer.baseAddress!
                    ) && varied.getGlyphAdvances(
                        glyphs: glyphBuffer.baseAddress!,
                        count: glyphBuffer.count,
                        advances: variedBuffer.baseAddress!
                    )
                }
            }
        }
        #expect(advancesSucceeded)
    }

    private func makeTable(serializedData: Data) -> Data {
        var glyph = Data()
        appendUInt16(1, to: &glyph)
        appendUInt16(10, to: &glyph)
        appendUInt16(UInt16(serializedData.count), to: &glyph)
        appendUInt16(0xA000, to: &glyph)
        appendInt16(16_384, to: &glyph)
        glyph.append(serializedData)
        if glyph.count % 2 != 0 { glyph.append(0) }

        var data = Data()
        appendUInt16(1, to: &data)
        appendUInt16(0, to: &data)
        appendUInt16(1, to: &data)
        appendUInt16(0, to: &data)
        appendUInt32(24, to: &data)
        appendUInt16(1, to: &data)
        appendUInt16(0, to: &data)
        appendUInt32(24, to: &data)
        appendUInt16(0, to: &data)
        appendUInt16(UInt16(glyph.count / 2), to: &data)
        data.append(glyph)
        return data
    }

    private func appendUInt16(_ value: UInt16, to data: inout Data) {
        data.append(UInt8(value >> 8))
        data.append(UInt8(value & 0xFF))
    }

    private func appendInt16(_ value: Int16, to data: inout Data) {
        appendUInt16(UInt16(bitPattern: value), to: &data)
    }

    private func appendUInt32(_ value: UInt32, to data: inout Data) {
        data.append(UInt8(value >> 24))
        data.append(UInt8((value >> 16) & 0xFF))
        data.append(UInt8((value >> 8) & 0xFF))
        data.append(UInt8(value & 0xFF))
    }
}
