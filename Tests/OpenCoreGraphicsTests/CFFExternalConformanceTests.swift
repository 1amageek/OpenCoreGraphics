//
//  CFFExternalConformanceTests.swift
//  OpenCoreGraphicsTests
//

#if canImport(CoreText)
import CoreFoundation
import CoreGraphics
import CoreText
import Foundation
import Testing
@testable import OpenCoreGraphics

@Suite("CFF external conformance tests")
struct CFFExternalConformanceTests {
    @Test("CFF glyph bounds agree with Apple CoreText")
    func glyphBoundsAgreeWithCoreText() throws {
        let url = URL(fileURLWithPath: "/Library/Fonts/SF-Pro-Text-Regular.otf")
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        let openProvider: OpenCoreGraphics.CGDataProvider = .init(data: data)
        guard let openFont: OpenCoreGraphics.CGFont = .init(openProvider) else {
            Issue.record("OpenCoreGraphics rejected the CFF font")
            return
        }
        guard let appleProvider: CoreGraphics.CGDataProvider = .init(data: data as CFData),
              let appleFont: CoreGraphics.CGFont = .init(appleProvider) else {
            Issue.record("CoreGraphics rejected the CFF font")
            return
        }
        let coreTextFont = CTFontCreateWithGraphicsFont(
            appleFont,
            CGFloat(openFont.unitsPerEm),
            nil,
            nil
        )

        var compared = 0
        for glyphIndex in 0..<min(openFont.numberOfGlyphs, 128) {
            let glyph = UInt16(glyphIndex)
            guard let openPath = openFont.path(for: glyph),
                  let applePath = CTFontCreatePathForGlyph(coreTextFont, glyph, nil) else {
                continue
            }
            let openBounds = openPath.boundingBox
            let appleBounds = applePath.boundingBox
            let openValues = Self.values(openBounds)
            let appleValues = Self.values(appleBounds)
            let differences = zip(openValues, appleValues).map { Swift.abs($0 - $1) }
            #expect(differences.allSatisfy { $0 < 0.01 })
            compared += 1
        }
        #expect(compared >= 64)
    }

    @Test("CFF2 variable glyph bounds agree with Apple CoreText")
    func cff2VariableGlyphBoundsAgreeWithCoreText() throws {
        let path = ProcessInfo.processInfo.environment["OPENCOREGRAPHICS_CFF2_FONT"]
            ?? "/tmp/OpenCoreGraphics-CFF2-Conformance.otf"
        guard FileManager.default.fileExists(atPath: path) else { return }
        let data = try Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe)
        let openProvider = OpenCoreGraphics.CGDataProvider(data: data)
        let optionalOpenFont: OpenCoreGraphics.CGFont? = .init(openProvider)
        let openFont = try #require(optionalOpenFont)
        let optionalAppleProvider: CoreGraphics.CGDataProvider? = .init(data: data as CFData)
        let appleProvider = try #require(optionalAppleProvider)
        let optionalAppleFont: CoreGraphics.CGFont? = .init(appleProvider)
        let appleFont = try #require(optionalAppleFont)

        try Self.compareBounds(openFont: openFont, appleFont: appleFont)

        let axisName = try #require(
            openFont.variationAxes?.first(where: {
                ($0[OpenCoreGraphics.kCGFontVariationAxisName] as? String) == "Weight"
            })?[OpenCoreGraphics.kCGFontVariationAxisName] as? String
        )
        let openVariableFont = try #require(openFont.copy(withVariations: [axisName: 900]))
        let appleVariableFont = try #require(
            appleFont.copy(withVariations: [axisName: 900] as CFDictionary)
        )
        #expect(openVariableFont.variations?[axisName] == 900)
        try Self.compareBounds(openFont: openVariableFont, appleFont: appleVariableFont)
    }

    private static func compareBounds(
        openFont: OpenCoreGraphics.CGFont,
        appleFont: CoreGraphics.CGFont
    ) throws {
        let opticalSize = openFont.variations?["Optical Size"] ?? CGFloat(openFont.unitsPerEm)
        let scale = CGFloat(openFont.unitsPerEm) / opticalSize
        let coreTextFont = CTFontCreateWithGraphicsFont(
            appleFont,
            opticalSize,
            nil,
            nil
        )
        var compared = 0
        for glyphIndex in 0..<min(openFont.numberOfGlyphs, 128) {
            let glyph = UInt16(glyphIndex)
            var transform = CoreGraphics.CGAffineTransform(
                a: scale,
                b: 0,
                c: 0,
                d: scale,
                tx: 0,
                ty: 0
            )
            guard let openPath = openFont.path(for: glyph),
                  let applePath = CTFontCreatePathForGlyph(coreTextFont, glyph, &transform) else {
                continue
            }
            let openValues = values(openPath.boundingBox)
            let appleValues = values(applePath.boundingBox)
            let differences = zip(openValues, appleValues).map {
                Swift.abs($0 - $1)
            }
            #expect(
                differences.allSatisfy { $0 < 0.01 },
                "Glyph \(glyphIndex): open \(openValues), Apple \(appleValues)"
            )
            compared += 1
        }
        #expect(compared >= 64)
    }

    private static func values(_ rect: Foundation.CGRect) -> [Double] {
        let minimumX = Double(rect.origin.x)
        let minimumY = Double(rect.origin.y)
        let maximumX = minimumX + Double(rect.size.width)
        let maximumY = minimumY + Double(rect.size.height)
        return [minimumX, minimumY, maximumX, maximumY]
    }
}
#endif
