//
//  CGFontTests.swift
//  OpenCoreGraphics
//
//  Tests for CGFont and CGFontPostScriptFormat
//

import Foundation
import Testing
@testable import OpenCoreGraphics

// MARK: - Helper

/// Creates minimal valid TrueType font data for testing.
private func createMinimalFontData() -> Data {
    var data = Data()

    // SFNT version (TrueType)
    data.append(contentsOf: [0x00, 0x01, 0x00, 0x00])

    // Number of tables: 3 (head, maxp, hhea)
    data.append(contentsOf: [0x00, 0x03])

    // searchRange, entrySelector, rangeShift (for 3 tables)
    data.append(contentsOf: [0x00, 0x30])  // searchRange = 48
    data.append(contentsOf: [0x00, 0x01])  // entrySelector = 1
    data.append(contentsOf: [0x00, 0x00])  // rangeShift = 0

    // Calculate offsets: header (12) + 3 tables * 16 = 60 bytes for directory
    let headOffset: UInt32 = 60
    let maxpOffset: UInt32 = headOffset + 54  // head table is 54 bytes
    let hheaOffset: UInt32 = maxpOffset + 6   // maxp v0.5 is 6 bytes

    func appendUInt32(_ value: UInt32) {
        data.append(UInt8((value >> 24) & 0xFF))
        data.append(UInt8((value >> 16) & 0xFF))
        data.append(UInt8((value >> 8) & 0xFF))
        data.append(UInt8(value & 0xFF))
    }

    // Table directory entries

    // 'head' table entry
    data.append(contentsOf: [0x68, 0x65, 0x61, 0x64])  // tag 'head'
    data.append(contentsOf: [0x00, 0x00, 0x00, 0x00])  // checksum
    appendUInt32(headOffset)                            // offset
    data.append(contentsOf: [0x00, 0x00, 0x00, 0x36])  // length = 54

    // 'hhea' table entry
    data.append(contentsOf: [0x68, 0x68, 0x65, 0x61])  // tag 'hhea'
    data.append(contentsOf: [0x00, 0x00, 0x00, 0x00])  // checksum
    appendUInt32(hheaOffset)                            // offset
    data.append(contentsOf: [0x00, 0x00, 0x00, 0x24])  // length = 36

    // 'maxp' table entry
    data.append(contentsOf: [0x6D, 0x61, 0x78, 0x70])  // tag 'maxp'
    data.append(contentsOf: [0x00, 0x00, 0x00, 0x00])  // checksum
    appendUInt32(maxpOffset)                            // offset
    data.append(contentsOf: [0x00, 0x00, 0x00, 0x06])  // length = 6

    // 'head' table data (54 bytes)
    data.append(contentsOf: [0x00, 0x01])              // majorVersion = 1
    data.append(contentsOf: [0x00, 0x00])              // minorVersion = 0
    data.append(contentsOf: [0x00, 0x01, 0x00, 0x00])  // fontRevision = 1.0
    data.append(contentsOf: [0x00, 0x00, 0x00, 0x00])  // checksumAdjustment
    data.append(contentsOf: [0x5F, 0x0F, 0x3C, 0xF5])  // magicNumber
    data.append(contentsOf: [0x00, 0x00])              // flags
    data.append(contentsOf: [0x03, 0xE8])              // unitsPerEm = 1000
    data.append(contentsOf: Array(repeating: 0, count: 8))  // created
    data.append(contentsOf: Array(repeating: 0, count: 8))  // modified
    data.append(contentsOf: [0x00, 0x00])              // xMin = 0
    data.append(contentsOf: [0xFF, 0x38])              // yMin = -200
    data.append(contentsOf: [0x03, 0xE8])              // xMax = 1000
    data.append(contentsOf: [0x03, 0x20])              // yMax = 800
    data.append(contentsOf: [0x00, 0x00])              // macStyle
    data.append(contentsOf: [0x00, 0x08])              // lowestRecPPEM = 8
    data.append(contentsOf: [0x00, 0x00])              // fontDirectionHint
    data.append(contentsOf: [0x00, 0x00])              // indexToLocFormat = 0 (short)
    data.append(contentsOf: [0x00, 0x00])              // glyphDataFormat

    // 'maxp' table data (6 bytes - version 0.5)
    data.append(contentsOf: [0x00, 0x00, 0x50, 0x00])  // version = 0.5
    data.append(contentsOf: [0x01, 0x00])              // numGlyphs = 256

    // 'hhea' table data (36 bytes)
    data.append(contentsOf: [0x00, 0x01])              // majorVersion = 1
    data.append(contentsOf: [0x00, 0x00])              // minorVersion = 0
    data.append(contentsOf: [0x03, 0x20])              // ascent = 800
    data.append(contentsOf: [0xFF, 0x38])              // descent = -200
    data.append(contentsOf: [0x00, 0x00])              // lineGap = 0
    data.append(contentsOf: [0x03, 0xE8])              // advanceWidthMax = 1000
    data.append(contentsOf: [0x00, 0x00])              // minLeftSideBearing = 0
    data.append(contentsOf: [0x00, 0x00])              // minRightSideBearing = 0
    data.append(contentsOf: [0x03, 0xE8])              // xMaxExtent = 1000
    data.append(contentsOf: [0x00, 0x01])              // caretSlopeRise = 1
    data.append(contentsOf: [0x00, 0x00])              // caretSlopeRun = 0
    data.append(contentsOf: [0x00, 0x00])              // caretOffset = 0
    data.append(contentsOf: Array(repeating: 0, count: 8))  // reserved
    data.append(contentsOf: [0x00, 0x00])              // metricDataFormat = 0
    data.append(contentsOf: [0x01, 0x00])              // numberOfHMetrics = 256

    return data
}

// MARK: - CGFontPostScriptFormat Tests

@Suite("CGFontPostScriptFormat Tests")
struct CGFontPostScriptFormatTests {

    @Test("Raw values")
    func rawValues() {
        #expect(OpenCoreGraphics.CGFontPostScriptFormat.type1.rawValue == 1)
        #expect(OpenCoreGraphics.CGFontPostScriptFormat.type3.rawValue == 3)
        #expect(OpenCoreGraphics.CGFontPostScriptFormat.type42.rawValue == 42)
    }

    @Test("Init from raw value")
    func initFromRawValue() {
        #expect(OpenCoreGraphics.CGFontPostScriptFormat(rawValue: 1) == .type1)
        #expect(OpenCoreGraphics.CGFontPostScriptFormat(rawValue: 3) == .type3)
        #expect(OpenCoreGraphics.CGFontPostScriptFormat(rawValue: 42) == .type42)
        #expect(OpenCoreGraphics.CGFontPostScriptFormat(rawValue: 100) == nil)
    }
}

// MARK: - CGFont Tests

@Suite("CGFont Tests")
struct CGFontTests {

    // MARK: - Initialization Tests

    @Test("Init with font name returns nil")
    func initWithFontNameReturnsNil() {
        let font = OpenCoreGraphics.CGFont("Helvetica" as CFString)
        #expect(font == nil)
    }

    @Test("Init with valid data provider")
    func initWithValidDataProvider() {
        let fontData = createMinimalFontData()
        let provider = OpenCoreGraphics.CGDataProvider(data: fontData)
        let font = OpenCoreGraphics.CGFont(provider)
        #expect(font != nil)
    }

    @Test("Init with invalid data returns nil")
    func initWithInvalidDataReturnsNil() {
        let invalidData = Data(repeating: 0, count: 100)
        let provider = OpenCoreGraphics.CGDataProvider(data: invalidData)
        let font = OpenCoreGraphics.CGFont(provider)
        #expect(font == nil)
    }

    // MARK: - Properties Tests

    @Test("Number of glyphs")
    func numberOfGlyphs() {
        let fontData = createMinimalFontData()
        let provider = OpenCoreGraphics.CGDataProvider(data: fontData)
        let font = OpenCoreGraphics.CGFont(provider)
        #expect(font?.numberOfGlyphs == 256)
    }

    @Test("Units per em")
    func unitsPerEm() {
        let fontData = createMinimalFontData()
        let provider = OpenCoreGraphics.CGDataProvider(data: fontData)
        let font = OpenCoreGraphics.CGFont(provider)
        #expect(font?.unitsPerEm == 1000)
    }

    @Test("Ascent and descent")
    func ascentAndDescent() {
        let fontData = createMinimalFontData()
        let provider = OpenCoreGraphics.CGDataProvider(data: fontData)
        let font = OpenCoreGraphics.CGFont(provider)
        #expect(font?.ascent == 800)
        #expect(font?.descent == -200)
    }

    @Test("Leading")
    func leading() {
        let fontData = createMinimalFontData()
        let provider = OpenCoreGraphics.CGDataProvider(data: fontData)
        let font = OpenCoreGraphics.CGFont(provider)
        #expect(font?.leading == 0)
    }

    @Test("Font bounding box")
    func fontBBox() {
        let fontData = createMinimalFontData()
        let provider = OpenCoreGraphics.CGDataProvider(data: fontData)
        let font = OpenCoreGraphics.CGFont(provider)
        let bbox = font?.fontBBox

        #expect(bbox != nil)
        #expect(bbox?.origin.x == 0)
        #expect(bbox?.origin.y == -200)
        #expect(bbox?.width == 1000)
        #expect(bbox?.height == 1000)
    }

    @Test("Table tags")
    func tableTags() {
        let fontData = createMinimalFontData()
        let provider = OpenCoreGraphics.CGDataProvider(data: fontData)
        let font = OpenCoreGraphics.CGFont(provider)

        guard let tags = font?.tableTags as? [UInt32] else {
            #expect(Bool(false), "tableTags should return array")
            return
        }
        #expect(tags.count == 3)
    }

    @Test("Variations for non-variable font")
    func variationsForNonVariableFont() {
        let fontData = createMinimalFontData()
        let provider = OpenCoreGraphics.CGDataProvider(data: fontData)
        let font = OpenCoreGraphics.CGFont(provider)
        #expect(font?.variations == nil)
        #expect(font?.variationAxes == nil)
    }

    // MARK: - Table Access Tests

    @Test("Get existing table")
    func tableForExistingTag() {
        let fontData = createMinimalFontData()
        let provider = OpenCoreGraphics.CGDataProvider(data: fontData)
        let font = OpenCoreGraphics.CGFont(provider)

        // 'head' = 0x68656164
        let headTable = font?.table(for: 0x68656164)
        #expect(headTable != nil)
    }

    @Test("Get non-existing table")
    func tableForNonExistingTag() {
        let fontData = createMinimalFontData()
        let provider = OpenCoreGraphics.CGDataProvider(data: fontData)
        let font = OpenCoreGraphics.CGFont(provider)

        // 'COLR' = 0x434F4C52 (not in minimal font)
        let colrTable = font?.table(for: 0x434F4C52)
        #expect(colrTable == nil)
    }

    // MARK: - Factory Function Tests

    @Test("CGFontCreateWithFontName returns nil")
    func createWithFontName() {
        let font = CGFontCreateWithFontName("Helvetica" as CFString)
        #expect(font == nil)
    }

    @Test("CGFontCreateWithDataProvider")
    func createWithDataProvider() {
        let fontData = createMinimalFontData()
        let provider = OpenCoreGraphics.CGDataProvider(data: fontData)
        let font = CGFontCreateWithDataProvider(provider)
        #expect(font != nil)
    }

    // MARK: - Variation Tests

    @Test("Copy with variations for non-variable font")
    func copyWithVariationsNonVariable() {
        let fontData = createMinimalFontData()
        let provider = OpenCoreGraphics.CGDataProvider(data: fontData)
        guard let font = OpenCoreGraphics.CGFont(provider) else {
            #expect(Bool(false), "Failed to create font")
            return
        }

        let variations: [String: Double] = ["wght": 700]
        let copy = font.copy(withVariations: variations as CFDictionary)
        #expect(copy == nil)
    }

    // MARK: - Font Metrics Tests

    @Test("Units per em is positive")
    func unitsPerEmIsPositive() {
        let fontData = createMinimalFontData()
        let provider = OpenCoreGraphics.CGDataProvider(data: fontData)
        guard let font = OpenCoreGraphics.CGFont(provider) else {
            #expect(Bool(false), "Failed to create font")
            return
        }
        #expect(font.unitsPerEm > 0)
    }

    @Test("Number of glyphs is non-negative")
    func numberOfGlyphsIsNonNegative() {
        let fontData = createMinimalFontData()
        let provider = OpenCoreGraphics.CGDataProvider(data: fontData)
        guard let font = OpenCoreGraphics.CGFont(provider) else {
            #expect(Bool(false), "Failed to create font")
            return
        }
        #expect(font.numberOfGlyphs >= 0)
    }

    // MARK: - Sendable Tests

    @Test("CGFont is Sendable")
    func cgFontIsSendable() {
        let fontData = createMinimalFontData()
        let provider = OpenCoreGraphics.CGDataProvider(data: fontData)
        let font = OpenCoreGraphics.CGFont(provider)
        let sendableFont: (any Sendable)? = font
        #expect(sendableFont != nil)
    }

    @Test("CGFontPostScriptFormat is Sendable")
    func postScriptFormatIsSendable() {
        let format = OpenCoreGraphics.CGFontPostScriptFormat.type1
        let sendableFormat: any Sendable = format
        #expect(type(of: sendableFormat) == OpenCoreGraphics.CGFontPostScriptFormat.self)
    }

    // MARK: - Color Font Tests

    @Test("Non-color font has no color glyphs")
    func nonColorFontHasNoColorGlyphs() {
        let fontData = createMinimalFontData()
        let provider = OpenCoreGraphics.CGDataProvider(data: fontData)
        guard let font = OpenCoreGraphics.CGFont(provider) else {
            #expect(Bool(false), "Failed to create font")
            return
        }
        #expect(font.hasColorGlyphs == false)
        #expect(font.numberOfColorPalettes == 0)
    }
}
