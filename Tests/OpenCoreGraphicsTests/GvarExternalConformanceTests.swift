//
//  GvarExternalConformanceTests.swift
//  OpenCoreGraphicsTests
//

#if canImport(CoreText)
import CoreFoundation
import CoreGraphics
import CoreText
import Foundation
import Testing
@testable import OpenCoreGraphics

@Suite("gvar external conformance tests")
struct GvarExternalConformanceTests {
    @Test("TrueType variable glyph bounds and advances agree with Apple CoreText")
    func variableGlyphsAgreeWithCoreText() throws {
        let path = "/System/Library/Fonts/Supplemental/Skia.ttf"
        guard FileManager.default.fileExists(atPath: path) else { return }
        let data = try Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe)
        let optionalOpenFont: OpenCoreGraphics.CGFont? = .init(
            OpenCoreGraphics.CGDataProvider(data: data)
        )
        let openFont = try #require(optionalOpenFont)
        let optionalAppleProvider: CoreGraphics.CGDataProvider? = .init(data: data as CFData)
        let appleProvider = try #require(optionalAppleProvider)
        let optionalAppleFont: CoreGraphics.CGFont? = .init(appleProvider)
        let appleFont = try #require(optionalAppleFont)
        try compareBounds(openFont: openFont, appleFont: appleFont)
        try compareAdvances(openFont: openFont, appleFont: appleFont)
        compareBoundingBoxAPI(openFont: openFont, appleFont: appleFont)
        let axis = try #require(openFont.variationAxes?.first)
        let axisName = try #require(axis[OpenCoreGraphics.kCGFontVariationAxisName] as? String)
        let maximum = try #require(axis[OpenCoreGraphics.kCGFontVariationAxisMaxValue] as? CGFloat)
        let optionalOpenVariable = openFont.copy(withVariations: [axisName: maximum])
        let openVariable = try #require(optionalOpenVariable)
        let optionalAppleVariable = appleFont.copy(
            withVariations: [axisName: maximum] as CFDictionary
        )
        let appleVariable = try #require(optionalAppleVariable)

        try compareBounds(openFont: openVariable, appleFont: appleVariable)
        try compareAdvances(openFont: openVariable, appleFont: appleVariable)
        compareBoundingBoxAPI(openFont: openVariable, appleFont: appleVariable)
    }

    private func compareBounds(
        openFont: OpenCoreGraphics.CGFont,
        appleFont: CoreGraphics.CGFont
    ) throws {
        let coreTextFont = CTFontCreateWithGraphicsFont(
            appleFont,
            CGFloat(openFont.unitsPerEm),
            nil,
            nil
        )
        var compared = 0
        for glyphIndex in 0..<min(openFont.numberOfGlyphs, 256) {
            let glyph = UInt16(glyphIndex)
            guard let openPath = openFont.path(for: glyph),
                  let applePath = CTFontCreatePathForGlyph(coreTextFont, glyph, nil) else {
                continue
            }
            let openBounds = openPath.boundingBox
            let appleBounds = applePath.boundingBox
            let openValues: [Double] = [
                Double(openBounds.origin.x),
                Double(openBounds.origin.y),
                Double(openBounds.size.width),
                Double(openBounds.size.height),
            ]
            let appleValues: [Double] = [
                Double(appleBounds.origin.x),
                Double(appleBounds.origin.y),
                Double(appleBounds.size.width),
                Double(appleBounds.size.height),
            ]
            #expect(
                zip(openValues, appleValues).allSatisfy { abs($0 - $1) < 0.01 },
                "Glyph \(glyphIndex): open \(openValues), Apple \(appleValues)"
            )
            compared += 1
        }
        #expect(compared >= 128)
    }

    private func compareAdvances(
        openFont: OpenCoreGraphics.CGFont,
        appleFont: CoreGraphics.CGFont
    ) throws {
        let glyphs = (0..<min(openFont.numberOfGlyphs, 256)).map(UInt16.init)
        var openValues = [Int32](repeating: 0, count: glyphs.count)
        var appleValues = [Int32](repeating: 0, count: glyphs.count)
        let succeeded = glyphs.withUnsafeBufferPointer { glyphBuffer in
            openValues.withUnsafeMutableBufferPointer { openBuffer in
                appleValues.withUnsafeMutableBufferPointer { appleBuffer in
                    openFont.getGlyphAdvances(
                        glyphs: glyphBuffer.baseAddress!,
                        count: glyphBuffer.count,
                        advances: openBuffer.baseAddress!
                    ) && appleFont.getGlyphAdvances(
                        glyphs: glyphBuffer.baseAddress!,
                        count: glyphBuffer.count,
                        advances: appleBuffer.baseAddress!
                    )
                }
            }
        }
        #expect(succeeded)
        #expect(openValues == appleValues)
    }

    private func compareBoundingBoxAPI(
        openFont: OpenCoreGraphics.CGFont,
        appleFont: CoreGraphics.CGFont
    ) {
        let glyphs = (0..<min(openFont.numberOfGlyphs, 256)).map(UInt16.init)
        var openBounds: [Foundation.CGRect] = []
        var appleBounds: [Foundation.CGRect] = []
        openBounds.reserveCapacity(glyphs.count)
        appleBounds.reserveCapacity(glyphs.count)
        for _ in glyphs {
            let zero = Foundation.CGRect(
                origin: Foundation.CGPoint(x: 0, y: 0),
                size: Foundation.CGSize(width: 0, height: 0)
            )
            openBounds.append(zero)
            appleBounds.append(zero)
        }
        let openSucceeded = glyphs.withUnsafeBufferPointer { glyphBuffer in
            openBounds.withUnsafeMutableBufferPointer { openBuffer in
                openFont.getGlyphBBoxes(
                    glyphs: glyphBuffer.baseAddress!,
                    count: glyphBuffer.count,
                    bboxes: openBuffer.baseAddress!
                )
            }
        }
        let appleSucceeded = glyphs.withUnsafeBufferPointer { glyphBuffer in
            appleBounds.withUnsafeMutableBufferPointer { appleBuffer in
                appleFont.getGlyphBBoxes(
                    glyphs: glyphBuffer.baseAddress!,
                    count: glyphBuffer.count,
                    bboxes: appleBuffer.baseAddress!
                )
            }
        }
        #expect(openSucceeded)
        #expect(appleSucceeded)
        for index in glyphs.indices {
            let open = openBounds[index]
            let apple = appleBounds[index]
            let openValues: [Double] = [
                Double(open.origin.x), Double(open.origin.y),
                Double(open.size.width), Double(open.size.height),
            ]
            let appleValues: [Double] = [
                Double(apple.origin.x), Double(apple.origin.y),
                Double(apple.size.width), Double(apple.size.height),
            ]
            let agrees = zip(openValues, appleValues).allSatisfy {
                abs($0 - $1) < 0.01
            }
            #expect(
                agrees,
                "Glyph \(index): open \(openValues), Apple \(appleValues)"
            )
        }
    }

}
#endif
