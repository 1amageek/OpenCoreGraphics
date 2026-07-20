//
//  CFF2FontTests.swift
//  OpenCoreGraphicsTests
//

import Foundation
import Testing
@testable import OpenCoreGraphics

@Suite("CFF2 font tests")
struct CFF2FontTests {
    @Test("CFF2 blend changes glyph outlines at normalized variation coordinates")
    func blendChangesGlyphOutlines() throws {
        let font = try #require(CGFont(CGDataProvider(data: makeFontData())))
        #expect(font.numberOfGlyphs == 2)
        #expect(try #require(font.path(for: 1)).boundingBox == CGRect(x: 0, y: 0, width: 100, height: 100))

        let midpoint = try #require(font.copy(withVariations: ["wght": 650]))
        #expect(try #require(midpoint.path(for: 1)).boundingBox == CGRect(x: 0, y: 0, width: 150, height: 100))

        let maximum = try #require(font.copy(withVariations: ["wght": 900]))
        #expect(try #require(maximum.path(for: 1)).boundingBox == CGRect(x: 0, y: 0, width: 200, height: 100))

        var glyph: CGGlyph = 1
        var bounds = CGRect.zero
        let succeeded = withUnsafePointer(to: &glyph) { glyphPointer in
            withUnsafeMutablePointer(to: &bounds) { boundsPointer in
                maximum.getGlyphBBoxes(glyphs: glyphPointer, count: 1, bboxes: boundsPointer)
            }
        }
        #expect(succeeded)
        #expect(bounds == CGRect(x: 0, y: 0, width: 200, height: 100))
    }

    @Test("CFF2 variation values clamp and invalid requests fail explicitly")
    func variationValidation() throws {
        let font = try #require(CGFont(CGDataProvider(data: makeFontData())))
        let clamped = try #require(font.copy(withVariations: ["wght": 2_000]))
        #expect(clamped.variations?["wght"] == 900)
        #expect(try #require(clamped.path(for: 1)).boundingBox.width == 200)
        #expect(font.copy(withVariations: ["unknown": 1]) == nil)
        #expect(font.copy(withVariations: ["wght": CGFloat.nan]) == nil)
        #expect(font.copy(withVariations: ["wght": "heavy"]) == nil)
    }

    @Test("avar segment maps are applied before CFF2 region evaluation")
    func avarMapping() throws {
        let font = try #require(CGFont(CGDataProvider(data: makeFontData(includeAvar: true))))
        let midpoint = try #require(font.copy(withVariations: ["wght": 650]))
        #expect(try #require(midpoint.path(for: 1)).boundingBox.width == 125)
    }

    @Test("Malformed CFF2 variation stores reject the font")
    func malformedVariationStore() {
        var data = makeFontData()
        let cff2Record = 12 + 3 * 16
        let cff2Offset = Int(data.readUInt32BE(at: cff2Record + 8))
        let variationStoreOffset = cff2Offset + 22 + makeCFF2Index([
            Data(),
            variableRectangleCharString()
        ]).count
        data[variationStoreOffset + 2] = 0
        data[variationStoreOffset + 3] = 2
        #expect(CGFont(CGDataProvider(data: data)) == nil)
    }

    @Test("CFF2 blend keeps delta groups in operand order")
    func blendDeltaOrdering() throws {
        let storeData = makeTwoRegionVariationStore()
        let store = try #require(CFF2VariationStore(data: storeData, offset: 0, axisCount: 1))
        let charString = Data([
            149, 159,
            138, 140,
            137, 141,
            141, 16,
            21,
            149, 149, 5
        ])
        let positive = Type2CharStringInterpreter(
            data: charString,
            charString: charString.indices,
            localSubroutines: nil,
            globalSubroutines: [],
            randomSeed: 1,
            format: .cff2,
            variationStore: store,
            normalizedCoordinates: [1]
        ).parse()
        #expect(try #require(positive).boundingBox == CGRect(x: 11, y: 22, width: 10, height: 10))

        let negative = Type2CharStringInterpreter(
            data: charString,
            charString: charString.indices,
            localSubroutines: nil,
            globalSubroutines: [],
            randomSeed: 1,
            format: .cff2,
            variationStore: store,
            normalizedCoordinates: [-1]
        ).parse()
        #expect(try #require(negative).boundingBox == CGRect(x: 9, y: 18, width: 10, height: 10))
    }

    @Test("CFF2 shortint operands preserve their sign")
    func signedShortInteger() throws {
        let charString = Data([28, 0xFF, 0x9C, 139, 21, 239, 239, 5])
        let path = Type2CharStringInterpreter(
            data: charString,
            charString: charString.indices,
            localSubroutines: nil,
            globalSubroutines: [],
            randomSeed: 1,
            format: .cff2
        ).parse()
        #expect(try #require(path).boundingBox == CGRect(x: -100, y: 0, width: 100, height: 100))
    }

    private func makeFontData(includeAvar: Bool = false) -> Data {
        let head = makeHeadTable()
        let maxp = Data([0x00, 0x00, 0x50, 0x00, 0x00, 0x02])
        let fvar = makeFvarTable()
        let cff2 = makeCFF2Table()
        let tables: [(UInt32, Data)] = includeAvar
            ? [
                (FontTableTag.head, head),
                (FontTableTag.maxp, maxp),
                (FontTableTag.fvar, fvar),
                (FontTableTag.avar, makeAvarTable()),
                (FontTableTag.CFF2, cff2)
            ]
            : [
                (FontTableTag.head, head),
                (FontTableTag.maxp, maxp),
                (FontTableTag.fvar, fvar),
                (FontTableTag.CFF2, cff2)
            ]
        let directoryEnd = 12 + tables.count * 16
        var offset = directoryEnd
        var data = Data("OTTO".utf8)
        appendUInt16(UInt16(tables.count), to: &data)
        data.append(contentsOf: Array(repeating: 0, count: 6))
        for (tag, table) in tables {
            appendUInt32(tag, to: &data)
            appendUInt32(0, to: &data)
            appendUInt32(UInt32(offset), to: &data)
            appendUInt32(UInt32(table.count), to: &data)
            offset += table.count
        }
        for (_, table) in tables { data.append(table) }
        return data
    }

    private func makeCFF2Table() -> Data {
        let globalSubroutines = makeCFF2Index([])
        let charStrings = makeCFF2Index([Data(), variableRectangleCharString()])
        let variationStore = makeVariationStore()
        let fontDictionaries = makeCFF2Index([Data([139, 139, 18])])
        let topDictionarySize = 13
        let charStringsOffset = 5 + topDictionarySize + globalSubroutines.count
        let variationStoreOffset = charStringsOffset + charStrings.count
        let fontDictionariesOffset = variationStoreOffset + variationStore.count

        var topDictionary = Data()
        topDictionary.append(dictInteger(charStringsOffset))
        topDictionary.append(17)
        topDictionary.append(dictInteger(variationStoreOffset))
        topDictionary.append(24)
        topDictionary.append(dictInteger(fontDictionariesOffset))
        topDictionary.append(contentsOf: [12, 36])
        precondition(topDictionary.count == topDictionarySize)

        var data = Data([2, 0, 5])
        appendUInt16(UInt16(topDictionary.count), to: &data)
        data.append(topDictionary)
        data.append(globalSubroutines)
        data.append(charStrings)
        data.append(variationStore)
        data.append(fontDictionaries)
        return data
    }

    private func variableRectangleCharString() -> Data {
        Data([
            139, 139, 21,
            239, 239, 140, 16, 139,
            139, 239,
            39, 139,
            139, 39,
            5
        ])
    }

    private func makeVariationStore() -> Data {
        var itemStore = Data()
        appendUInt16(1, to: &itemStore)
        appendUInt32(12, to: &itemStore)
        appendUInt16(1, to: &itemStore)
        appendUInt32(22, to: &itemStore)
        appendUInt16(1, to: &itemStore)
        appendUInt16(1, to: &itemStore)
        appendInt16(0, to: &itemStore)
        appendInt16(16_384, to: &itemStore)
        appendInt16(16_384, to: &itemStore)
        appendUInt16(0, to: &itemStore)
        appendUInt16(0, to: &itemStore)
        appendUInt16(1, to: &itemStore)
        appendUInt16(0, to: &itemStore)

        var store = Data()
        appendUInt16(UInt16(itemStore.count), to: &store)
        store.append(itemStore)
        return store
    }

    private func makeTwoRegionVariationStore() -> Data {
        var itemStore = Data()
        appendUInt16(1, to: &itemStore)
        appendUInt32(12, to: &itemStore)
        appendUInt16(1, to: &itemStore)
        appendUInt32(28, to: &itemStore)
        appendUInt16(1, to: &itemStore)
        appendUInt16(2, to: &itemStore)
        appendInt16(-16_384, to: &itemStore)
        appendInt16(-16_384, to: &itemStore)
        appendInt16(0, to: &itemStore)
        appendInt16(0, to: &itemStore)
        appendInt16(16_384, to: &itemStore)
        appendInt16(16_384, to: &itemStore)
        appendUInt16(0, to: &itemStore)
        appendUInt16(0, to: &itemStore)
        appendUInt16(2, to: &itemStore)
        appendUInt16(0, to: &itemStore)
        appendUInt16(1, to: &itemStore)

        var store = Data()
        appendUInt16(UInt16(itemStore.count), to: &store)
        store.append(itemStore)
        return store
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

    private func makeCFF2Index(_ objects: [Data]) -> Data {
        var data = Data()
        appendUInt32(UInt32(objects.count), to: &data)
        if objects.isEmpty { return data }
        data.append(1)
        var offset = 1
        data.append(UInt8(offset))
        for object in objects {
            offset += object.count
            data.append(UInt8(offset))
        }
        for object in objects { data.append(object) }
        return data
    }

    private func dictInteger(_ value: Int) -> Data {
        var data = Data([28])
        appendInt16(Int16(value), to: &data)
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
        data[40] = 0x00
        data[41] = 0xC8
        data[42] = 0x00
        data[43] = 0x64
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
        data.append(UInt8((value >> 24) & 0xFF))
        data.append(UInt8((value >> 16) & 0xFF))
        data.append(UInt8((value >> 8) & 0xFF))
        data.append(UInt8(value & 0xFF))
    }

    private func appendFixed(_ value: Int32, to data: inout Data) {
        appendUInt32(UInt32(bitPattern: value << 16), to: &data)
    }
}
