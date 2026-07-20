//
//  VariableMetricsTests.swift
//  OpenCoreGraphicsTests
//

import Foundation
import Testing
@testable import OpenCoreGraphics

@Suite("Variable metrics tests")
struct VariableMetricsTests {
    @Test("HVAR and VVAR metrics follow normalized variation coordinates")
    func variableMetrics() throws {
        let font = try #require(CGFont(CGDataProvider(data: makeFontData())))
        #expect(advances(font) == [500, 600])
        #expect(font.verticalAdvance(for: 0) == 800)
        #expect(font.verticalAdvance(for: 1) == 900)
        #expect(font.horizontalLeftSideBearing(for: 0) == 0)
        #expect(font.verticalTopSideBearing(for: 0) == 10)

        let midpoint = try #require(font.copy(withVariations: ["wght": 650]))
        #expect(advances(midpoint) == [525, 588])
        #expect(midpoint.verticalAdvance(for: 0) == 808)
        #expect(midpoint.verticalAdvance(for: 1) == 890)
        #expect(midpoint.horizontalLeftSideBearing(for: 0) == 25)
        #expect(midpoint.verticalTopSideBearing(for: 0) == 18)

        let maximum = try #require(font.copy(withVariations: ["wght": 900]))
        #expect(advances(maximum) == [600, 550])
        #expect(maximum.verticalAdvance(for: 0) == 830)
        #expect(maximum.verticalAdvance(for: 1) == 860)
        #expect(maximum.horizontalLeftSideBearing(for: 0) == 100)
        #expect(maximum.verticalTopSideBearing(for: 0) == 40)
    }

    @Test("Delta-set maps reuse their final entry and reject reserved bits")
    func deltaSetIndexMap() throws {
        let map = try #require(DeltaSetIndexMap(data: Data([0, 1, 0, 1, 1]), offset: 0))
        let first = try #require(map.indices(for: 0))
        let repeated = try #require(map.indices(for: 500))
        #expect(first.outer == 0 && first.inner == 1)
        #expect(repeated.outer == 0 && repeated.inner == 1)
        #expect(DeltaSetIndexMap(data: Data([0, 0xC0, 0, 1, 0]), offset: 0) == nil)

        let formatOne = try #require(DeltaSetIndexMap(
            data: Data([1, 0, 0, 0, 0, 1, 0]),
            offset: 0
        ))
        #expect(formatOne.indices(for: 0)?.inner == 0)
    }

    @Test("HVAR and VVAR expose every optional metric mapping")
    func optionalMetricMappings() throws {
        let hvar = try #require(HvarTable(
            data: makeHvarTable(includeSideBearings: true),
            axisCount: 1,
            glyphCount: 2
        ))
        #expect(hvar.leftSideBearingDelta(for: 0, coordinates: [1]) == 100)
        #expect(hvar.rightSideBearingDelta(for: 1, coordinates: [1]) == -50)

        let vvar = try #require(VvarTable(
            data: makeVvarTable(includeOptionalMetrics: true),
            axisCount: 1,
            glyphCount: 2
        ))
        #expect(vvar.topSideBearingDelta(for: 0, coordinates: [1]) == 30)
        #expect(vvar.bottomSideBearingDelta(for: 1, coordinates: [1]) == -40)
        #expect(vvar.verticalOriginDelta(for: 0, coordinates: [1]) == 30)
    }

    @Test("Item variation stores decode LONG_WORDS without truncation")
    func longWordDeltas() throws {
        let store = try #require(ItemVariationStore(
            data: makeItemVariationStore(deltas: [70_000], usesLongWords: true),
            offset: 0,
            length: makeItemVariationStore(deltas: [70_000], usesLongWords: true).count,
            axisCount: 1
        ))
        #expect(store.delta(outerIndex: 0, innerIndex: 0, coordinates: [1]) == 70_000)
        #expect(store.delta(outerIndex: 0, innerIndex: 0, coordinates: [0.5]) == 35_000)
    }

    @Test("Malformed variable metric tables reject the font")
    func malformedTables() {
        var data = makeFontData()
        let hvarOffset = tableOffset(FontTableTag.HVAR, in: data)
        #expect(hvarOffset != nil)
        if let hvarOffset {
            data[hvarOffset + 12] = 0
            data[hvarOffset + 13] = 0
            data[hvarOffset + 14] = 0
            data[hvarOffset + 15] = 20
        }
        #expect(CGFont(CGDataProvider(data: data)) == nil)
    }

    @Test("Out-of-range glyph metrics fail instead of reusing the final width")
    func invalidGlyph() throws {
        let font = try #require(CGFont(CGDataProvider(data: makeFontData())))
        var glyph = CGGlyph(2)
        var advance: Int32 = -1
        let succeeded = withUnsafePointer(to: &glyph) { glyphPointer in
            withUnsafeMutablePointer(to: &advance) { advancePointer in
                font.getGlyphAdvances(glyphs: glyphPointer, count: 1, advances: advancePointer)
            }
        }
        #expect(!succeeded)
        #expect(advance == -1)
    }

    private func advances(_ font: CGFont) -> [Int32]? {
        var glyphs: [CGGlyph] = [0, 1]
        var values: [Int32] = [0, 0]
        let succeeded = glyphs.withUnsafeBufferPointer { glyphBuffer in
            values.withUnsafeMutableBufferPointer { valueBuffer in
                font.getGlyphAdvances(
                    glyphs: glyphBuffer.baseAddress!,
                    count: glyphBuffer.count,
                    advances: valueBuffer.baseAddress!
                )
            }
        }
        return succeeded ? values : nil
    }

    private func makeFontData() -> Data {
        let tables: [(UInt32, Data)] = [
            (FontTableTag.head, makeHeadTable()),
            (FontTableTag.maxp, Data([0, 0, 0x50, 0, 0, 2])),
            (FontTableTag.fvar, makeFvarTable()),
            (FontTableTag.avar, makeAvarTable()),
            (FontTableTag.hhea, makeMetricsHeader(maximum: 700, metricCount: 2)),
            (FontTableTag.hmtx, makeMetricsTable(first: (500, 0), second: (600, 0))),
            (FontTableTag.HVAR, makeHvarTable(includeSideBearings: true)),
            (FontTableTag.vhea, makeMetricsHeader(
                version: 0x0001_1000,
                maximum: 900,
                metricCount: 2
            )),
            (FontTableTag.vmtx, makeMetricsTable(first: (800, 10), second: (900, 20))),
            (FontTableTag.VVAR, makeVvarTable(includeOptionalMetrics: true))
        ]
        let directoryEnd = 12 + tables.count * 16
        var tableOffset = directoryEnd
        var data = Data([0, 1, 0, 0])
        appendUInt16(UInt16(tables.count), to: &data)
        data.append(contentsOf: repeatElement(0, count: 6))
        for (tag, table) in tables {
            appendUInt32(tag, to: &data)
            appendUInt32(0, to: &data)
            appendUInt32(UInt32(tableOffset), to: &data)
            appendUInt32(UInt32(table.count), to: &data)
            tableOffset += table.count
        }
        for (_, table) in tables { data.append(table) }
        return data
    }

    private func makeHvarTable(includeSideBearings: Bool = false) -> Data {
        let store = makeItemVariationStore(deltas: [100, -50], usesLongWords: false)
        let mapOffset = UInt32(20 + store.count)
        var data = Data()
        appendUInt16(1, to: &data)
        appendUInt16(0, to: &data)
        appendUInt32(20, to: &data)
        appendUInt32(mapOffset, to: &data)
        appendUInt32(includeSideBearings ? mapOffset : 0, to: &data)
        appendUInt32(includeSideBearings ? mapOffset : 0, to: &data)
        data.append(store)
        data.append(contentsOf: [0, 1, 0, 2, 0, 1])
        return data
    }

    private func makeVvarTable(includeOptionalMetrics: Bool = false) -> Data {
        let store = makeItemVariationStore(deltas: [30, -40], usesLongWords: false)
        let mapOffset = UInt32(24 + store.count)
        var data = Data()
        appendUInt16(1, to: &data)
        appendUInt16(0, to: &data)
        appendUInt32(24, to: &data)
        appendUInt32(0, to: &data)
        appendUInt32(includeOptionalMetrics ? mapOffset : 0, to: &data)
        appendUInt32(includeOptionalMetrics ? mapOffset : 0, to: &data)
        appendUInt32(includeOptionalMetrics ? mapOffset : 0, to: &data)
        data.append(store)
        if includeOptionalMetrics {
            data.append(contentsOf: [0, 1, 0, 2, 0, 1])
        }
        return data
    }

    private func makeItemVariationStore(deltas: [Int32], usesLongWords: Bool) -> Data {
        var data = Data()
        appendUInt16(1, to: &data)
        appendUInt32(12, to: &data)
        appendUInt16(1, to: &data)
        appendUInt32(22, to: &data)
        appendUInt16(1, to: &data)
        appendUInt16(1, to: &data)
        appendInt16(0, to: &data)
        appendInt16(16_384, to: &data)
        appendInt16(16_384, to: &data)
        appendUInt16(UInt16(deltas.count), to: &data)
        appendUInt16(usesLongWords ? 0x8001 : 1, to: &data)
        appendUInt16(1, to: &data)
        appendUInt16(0, to: &data)
        for delta in deltas {
            if usesLongWords {
                appendInt32(delta, to: &data)
            } else {
                appendInt16(Int16(delta), to: &data)
            }
        }
        return data
    }

    private func makeMetricsHeader(
        version: UInt32 = 0x0001_0000,
        maximum: UInt16,
        metricCount: UInt16
    ) -> Data {
        var data = Data(repeating: 0, count: 36)
        data[0] = UInt8((version >> 24) & 0xFF)
        data[1] = UInt8((version >> 16) & 0xFF)
        data[2] = UInt8((version >> 8) & 0xFF)
        data[3] = UInt8(version & 0xFF)
        data[10] = UInt8(maximum >> 8)
        data[11] = UInt8(maximum & 0xFF)
        data[34] = UInt8(metricCount >> 8)
        data[35] = UInt8(metricCount & 0xFF)
        return data
    }

    private func makeMetricsTable(
        first: (advance: UInt16, bearing: Int16),
        second: (advance: UInt16, bearing: Int16)
    ) -> Data {
        var data = Data()
        for metric in [first, second] {
            appendUInt16(metric.advance, to: &data)
            appendInt16(metric.bearing, to: &data)
        }
        return data
    }

    private func makeFvarTable() -> Data {
        var data = Data()
        appendUInt16(1, to: &data)
        appendUInt16(0, to: &data)
        appendUInt16(16, to: &data)
        appendUInt16(2, to: &data)
        appendUInt16(1, to: &data)
        appendUInt16(20, to: &data)
        appendUInt16(0, to: &data)
        appendUInt16(8, to: &data)
        appendUInt32(FontTableTag.fromString("wght"), to: &data)
        appendFixed(100, to: &data)
        appendFixed(400, to: &data)
        appendFixed(900, to: &data)
        appendUInt16(0, to: &data)
        appendUInt16(256, to: &data)
        return data
    }

    private func makeAvarTable() -> Data {
        var data = Data()
        appendUInt16(1, to: &data)
        appendUInt16(0, to: &data)
        appendUInt16(0, to: &data)
        appendUInt16(1, to: &data)
        appendUInt16(4, to: &data)
        for (from, to) in [(-16_384, -16_384), (0, 0), (8_192, 4_096), (16_384, 16_384)] {
            appendInt16(Int16(from), to: &data)
            appendInt16(Int16(to), to: &data)
        }
        return data
    }

    private func makeHeadTable() -> Data {
        var data = Data(repeating: 0, count: 54)
        data[1] = 1
        data[12] = 0x5F
        data[13] = 0x0F
        data[14] = 0x3C
        data[15] = 0xF5
        data[18] = 0x03
        data[19] = 0xE8
        return data
    }

    private func tableOffset(_ tag: UInt32, in data: Data) -> Int? {
        let count = Int(data.readUInt16BE(at: 4))
        for index in 0..<count {
            let record = 12 + index * 16
            if data.readUInt32BE(at: record) == tag {
                return Int(data.readUInt32BE(at: record + 8))
            }
        }
        return nil
    }

    private func appendUInt16(_ value: UInt16, to data: inout Data) {
        data.append(UInt8(value >> 8))
        data.append(UInt8(value & 0xFF))
    }

    private func appendInt16(_ value: Int16, to data: inout Data) {
        appendUInt16(UInt16(bitPattern: value), to: &data)
    }

    private func appendUInt32(_ value: UInt32, to data: inout Data) {
        data.append(UInt8((value >> 24) & 0xFF))
        data.append(UInt8((value >> 16) & 0xFF))
        data.append(UInt8((value >> 8) & 0xFF))
        data.append(UInt8(value & 0xFF))
    }

    private func appendInt32(_ value: Int32, to data: inout Data) {
        appendUInt32(UInt32(bitPattern: value), to: &data)
    }

    private func appendFixed(_ value: Int32, to data: inout Data) {
        appendUInt32(UInt32(bitPattern: value << 16), to: &data)
    }
}
