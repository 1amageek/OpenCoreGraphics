//
//  CGFontTests.swift
//  OpenCoreGraphics
//
//  Tests for CGFont and CGFontPostScriptFormat
//

import Foundation
import Testing
@testable import OpenCoreGraphics

// Type aliases to avoid ambiguity with CoreFoundation types on macOS
private typealias CGFont = OpenCoreGraphics.CGFont
private typealias CGFontPostScriptFormat = OpenCoreGraphics.CGFontPostScriptFormat
private typealias CGDataProvider = OpenCoreGraphics.CGDataProvider
private typealias CGRect = Foundation.CGRect
private typealias CGFloat = Foundation.CGFloat

// MARK: - CGFontPostScriptFormat Tests

@Suite("CGFontPostScriptFormat Tests")
struct CGFontPostScriptFormatTests {

    @Test("Raw values")
    func rawValues() {
        #expect(CGFontPostScriptFormat.type1.rawValue == 1)
        #expect(CGFontPostScriptFormat.type3.rawValue == 3)
        #expect(CGFontPostScriptFormat.type42.rawValue == 42)
    }

    @Test("Init from raw value")
    func initFromRawValue() {
        #expect(CGFontPostScriptFormat(rawValue: 1) == .type1)
        #expect(CGFontPostScriptFormat(rawValue: 3) == .type3)
        #expect(CGFontPostScriptFormat(rawValue: 42) == .type42)
        #expect(CGFontPostScriptFormat(rawValue: 100) == nil)
    }
}

// MARK: - CGFont Tests

@Suite("CGFont Tests")
struct CGFontTests {

    // MARK: - Initialization Tests

    @Suite("Initialization")
    struct InitializationTests {

        @Test("Init with font name")
        func initWithFontName() {
            let font = CGFont(name: "Helvetica")

            #expect(font != nil)
            #expect(font?.postScriptName == "Helvetica")
            #expect(font?.fullName == "Helvetica")
        }

        @Test("Init with data provider")
        func initWithDataProvider() {
            let fontData = Data(repeating: 0, count: 100)
            let provider = CGDataProvider(data: fontData)
            let font = CGFont(dataProvider: provider)

            #expect(font != nil)
        }
    }

    // MARK: - Properties Tests

    @Suite("Properties")
    struct PropertiesTests {

        @Test("Number of glyphs")
        func numberOfGlyphs() {
            let font = CGFont(name: "Helvetica")
            #expect(font?.numberOfGlyphs == 256)
        }

        @Test("Units per em")
        func unitsPerEm() {
            let font = CGFont(name: "Helvetica")
            #expect(font?.unitsPerEm == 1000)
        }

        @Test("Ascent and descent")
        func ascentAndDescent() {
            let font = CGFont(name: "Helvetica")
            #expect(font?.ascent == 800)
            #expect(font?.descent == -200)
        }

        @Test("Leading")
        func leading() {
            let font = CGFont(name: "Helvetica")
            #expect(font?.leading == 0)
        }

        @Test("Cap height and x-height")
        func capHeightAndXHeight() {
            let font = CGFont(name: "Helvetica")
            #expect(font?.capHeight == 700)
            #expect(font?.xHeight == 500)
        }

        @Test("Font bounding box")
        func fontBBox() {
            let font = CGFont(name: "Helvetica")
            let bbox = font?.fontBBox

            #expect(bbox != nil)
            #expect(bbox?.origin.x == 0)
            #expect(bbox?.origin.y == -200)
            #expect(bbox?.width == 1000)
            #expect(bbox?.height == 1000)
        }

        @Test("Italic angle")
        func italicAngle() {
            let font = CGFont(name: "Helvetica")
            #expect(font?.italicAngle == 0)
        }

        @Test("Stem V")
        func stemV() {
            let font = CGFont(name: "Helvetica")
            #expect(font?.stemV == 80)
        }

        @Test("Table tags")
        func tableTags() {
            let font = CGFont(name: "Helvetica")
            #expect(font?.tableTags.isEmpty == true)
        }

        @Test("Variations")
        func variations() {
            let font = CGFont(name: "Helvetica")
            #expect(font?.variations == nil)
            #expect(font?.variationAxes == nil)
        }
    }

    // MARK: - Copy Tests

    @Suite("Copy Operations")
    struct CopyTests {

        @Test("Copy font")
        func copyFont() {
            let original = CGFont(name: "Helvetica")
            let copy = original?.copy()

            #expect(copy != nil)
            #expect(copy?.postScriptName == original?.postScriptName)
            #expect(copy?.unitsPerEm == original?.unitsPerEm)
        }

        @Test("Copy with variations")
        func copyWithVariations() {
            let original = CGFont(name: "Helvetica")
            let variations: [String: Double] = ["wght": 700]
            let copy = original?.copy(withVariations: variations)

            #expect(copy != nil)
        }
    }

    // MARK: - Glyph Tests

    @Suite("Glyph Operations")
    struct GlyphTests {

        @Test("Get glyph for name")
        func glyphForName() {
            let font = CGFont(name: "Helvetica")
            let glyph = font?.glyph(named: "A")

            #expect(glyph == 0)  // Placeholder implementation
        }

        @Test("Get name for glyph")
        func nameForGlyph() {
            let font = CGFont(name: "Helvetica")
            let name = font?.name(for: 0)

            #expect(name == nil)  // Placeholder implementation
        }

        @Test("Get advance for glyph")
        func advanceForGlyph() {
            let font = CGFont(name: "Helvetica")
            let advance = font?.advance(for: 0)

            #expect(advance == 500)  // unitsPerEm / 2
        }

        @Test("Get advances for multiple glyphs")
        func advancesForGlyphs() {
            let font = CGFont(name: "Helvetica")
            let glyphs: [CGFont.CGGlyph] = [0, 1, 2]
            let advances = font?.advances(for: glyphs)

            #expect(advances?.count == 3)
            #expect(advances?[0] == 500)
        }

        @Test("Get bounding box for glyph")
        func boundingBoxForGlyph() {
            let font = CGFont(name: "Helvetica")
            let bbox = font?.boundingBox(for: 0)

            #expect(bbox != nil)
            #expect(bbox?.width == 500)
        }

        @Test("Get bounding boxes for multiple glyphs")
        func boundingBoxesForGlyphs() {
            let font = CGFont(name: "Helvetica")
            let glyphs: [CGFont.CGGlyph] = [0, 1]
            let bboxes = font?.boundingBoxes(for: glyphs)

            #expect(bboxes?.count == 2)
        }
    }

    // MARK: - Table Tests

    @Suite("Font Table Operations")
    struct TableTests {

        @Test("Get table for tag")
        func tableForTag() {
            let font = CGFont(name: "Helvetica")
            let table = font?.table(for: 0x68656164)  // 'head'

            #expect(table == nil)  // Placeholder implementation
        }
    }

    // MARK: - Factory Function Tests

    @Suite("Factory Functions")
    struct FactoryFunctionTests {

        @Test("CGFontCreateWithFontName")
        func createWithFontName() {
            let font = CGFontCreateWithFontName("Helvetica")
            #expect(font != nil)
        }

        @Test("CGFontCreateWithDataProvider")
        func createWithDataProvider() {
            let data = Data(repeating: 0, count: 100)
            let provider = CGDataProvider(data: data)
            let font = CGFontCreateWithDataProvider(provider)

            #expect(font != nil)
        }

        @Test("CGFontCreateCopyWithVariations")
        func createCopyWithVariations() {
            let font = CGFont(name: "Helvetica")!
            let variations: [String: Double] = ["wght": 700]
            let copy = CGFontCreateCopyWithVariations(font, variations)

            #expect(copy != nil)
        }
    }
}
