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

        @Test("Copy font creates independent instance")
        func copyFontCreatesIndependentInstance() {
            let original = CGFont(name: "Helvetica")
            let copy = original?.copy()

            #expect(copy != nil)
            // Verify they are different instances
            #expect(copy !== original)
        }

        @Test("Copy font preserves all properties")
        func copyFontPreservesAllProperties() {
            let original = CGFont(name: "Helvetica")
            let copy = original?.copy()

            #expect(copy != nil)
            #expect(copy?.postScriptName == original?.postScriptName)
            #expect(copy?.fullName == original?.fullName)
            #expect(copy?.numberOfGlyphs == original?.numberOfGlyphs)
            #expect(copy?.unitsPerEm == original?.unitsPerEm)
            #expect(copy?.ascent == original?.ascent)
            #expect(copy?.descent == original?.descent)
            #expect(copy?.leading == original?.leading)
            #expect(copy?.capHeight == original?.capHeight)
            #expect(copy?.xHeight == original?.xHeight)
            #expect(copy?.italicAngle == original?.italicAngle)
            #expect(copy?.stemV == original?.stemV)
            #expect(copy?.fontBBox == original?.fontBBox)
        }

        @Test("Copy with variations creates independent instance")
        func copyWithVariations() {
            let original = CGFont(name: "Helvetica")
            let variations: [String: Double] = ["wght": 700]
            let copy = original?.copy(withVariations: variations)

            #expect(copy != nil)
            #expect(copy !== original)
        }
    }

    // MARK: - Glyph Tests

    @Suite("Glyph Operations")
    struct GlyphTests {

        @Test("Get glyph for name returns valid glyph index")
        func glyphForName() {
            let font = CGFont(name: "Helvetica")
            let glyph = font?.glyph(named: "A")

            // Even placeholder returns 0, which is a valid glyph index
            #expect(glyph != nil)
        }

        @Test("Advance is calculated based on unitsPerEm")
        func advanceCalculation() {
            guard let font = CGFont(name: "Helvetica") else {
                #expect(Bool(false), "Failed to create font")
                return
            }

            let advance = font.advance(for: 0)
            // Verify the advance is unitsPerEm / 2
            #expect(advance == font.unitsPerEm / 2)
        }

        @Test("All glyphs have consistent advance calculation")
        func advancesConsistentCalculation() {
            guard let font = CGFont(name: "Helvetica") else {
                #expect(Bool(false), "Failed to create font")
                return
            }

            let glyphs: [CGFont.CGGlyph] = [0, 1, 2, 100, 255]
            let advances = font.advances(for: glyphs)

            #expect(advances.count == glyphs.count)

            // All advances should be the same (unitsPerEm / 2)
            let expectedAdvance = font.unitsPerEm / 2
            for advance in advances {
                #expect(advance == expectedAdvance)
            }
        }

        @Test("Bounding box height is calculated from ascent and descent")
        func boundingBoxHeightCalculation() {
            guard let font = CGFont(name: "Helvetica") else {
                #expect(Bool(false), "Failed to create font")
                return
            }

            let bbox = font.boundingBox(for: 0)

            // Height should be ascent - descent
            let expectedHeight = CGFloat(font.ascent - font.descent)
            #expect(bbox.height == expectedHeight)
        }

        @Test("Bounding box y origin matches descent")
        func boundingBoxYOrigin() {
            guard let font = CGFont(name: "Helvetica") else {
                #expect(Bool(false), "Failed to create font")
                return
            }

            let bbox = font.boundingBox(for: 0)

            // Y origin should be descent (compare as Double to avoid CGFloat type issues)
            #expect(Double(bbox.origin.y) == Double(font.descent))
        }

        @Test("Bounding boxes for multiple glyphs returns same count as input")
        func boundingBoxesCountMatchesInput() {
            guard let font = CGFont(name: "Helvetica") else {
                #expect(Bool(false), "Failed to create font")
                return
            }

            let glyphs: [CGFont.CGGlyph] = [0, 1, 2, 3, 4]
            let bboxes = font.boundingBoxes(for: glyphs)

            #expect(bboxes.count == glyphs.count)
        }

        @Test("Empty glyphs array returns empty results")
        func emptyGlyphsReturnsEmptyResults() {
            guard let font = CGFont(name: "Helvetica") else {
                #expect(Bool(false), "Failed to create font")
                return
            }

            let emptyGlyphs: [CGFont.CGGlyph] = []
            let advances = font.advances(for: emptyGlyphs)
            let bboxes = font.boundingBoxes(for: emptyGlyphs)

            #expect(advances.isEmpty)
            #expect(bboxes.isEmpty)
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

    // MARK: - Font Metrics Relationships Tests

    @Suite("Font Metrics Relationships")
    struct FontMetricsRelationshipsTests {

        @Test("Font bounding box contains typical glyph metrics")
        func fontBBoxContainsGlyphMetrics() {
            guard let font = CGFont(name: "Helvetica") else {
                #expect(Bool(false), "Failed to create font")
                return
            }

            let fontBBox = font.fontBBox

            // The font bounding box should contain the ascent and descent
            #expect(CGFloat(font.descent) >= fontBBox.minY)
            #expect(CGFloat(font.ascent) <= fontBBox.maxY)
        }

        @Test("Cap height is less than or equal to ascent")
        func capHeightLessThanAscent() {
            guard let font = CGFont(name: "Helvetica") else {
                #expect(Bool(false), "Failed to create font")
                return
            }

            #expect(font.capHeight <= font.ascent)
        }

        @Test("X-height is less than or equal to cap height")
        func xHeightLessThanCapHeight() {
            guard let font = CGFont(name: "Helvetica") else {
                #expect(Bool(false), "Failed to create font")
                return
            }

            #expect(font.xHeight <= font.capHeight)
        }

        @Test("Descent is non-positive")
        func descentIsNonPositive() {
            guard let font = CGFont(name: "Helvetica") else {
                #expect(Bool(false), "Failed to create font")
                return
            }

            // Descent is typically negative (below baseline)
            #expect(font.descent <= 0)
        }

        @Test("Units per em is positive")
        func unitsPerEmIsPositive() {
            guard let font = CGFont(name: "Helvetica") else {
                #expect(Bool(false), "Failed to create font")
                return
            }

            #expect(font.unitsPerEm > 0)
        }

        @Test("Number of glyphs is non-negative")
        func numberOfGlyphsIsNonNegative() {
            guard let font = CGFont(name: "Helvetica") else {
                #expect(Bool(false), "Failed to create font")
                return
            }

            #expect(font.numberOfGlyphs >= 0)
        }
    }

    // MARK: - Sendable Tests

    @Suite("Sendable Conformance")
    struct SendableTests {

        @Test("CGFont is Sendable")
        func cgFontIsSendable() {
            let font = CGFont(name: "Helvetica")

            // Verify CGFont can be used as Sendable
            let sendableFont: (any Sendable)? = font
            #expect(sendableFont != nil)
        }

        @Test("CGFontPostScriptFormat is Sendable")
        func postScriptFormatIsSendable() {
            let format = CGFontPostScriptFormat.type1

            // Verify CGFontPostScriptFormat can be used as Sendable
            let sendableFormat: any Sendable = format
            #expect(type(of: sendableFormat) == CGFontPostScriptFormat.self)
        }
    }
}
