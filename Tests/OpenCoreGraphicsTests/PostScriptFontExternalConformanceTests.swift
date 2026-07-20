//
//  PostScriptFontExternalConformanceTests.swift
//  OpenCoreGraphicsTests
//

#if canImport(CoreText)
import CoreFoundation
import CoreGraphics
import CoreText
import Foundation
import Testing
@testable import OpenCoreGraphics

@Suite("PostScript font external conformance tests")
struct PostScriptFontExternalConformanceTests {
    @Test("PostScript capabilities and encoding agree with Apple Core Graphics")
    func capabilitiesAndEncoding() throws {
        let openFont = try Self.openFont(at: Self.trueTypeFontPath)
        let appleFont = try Self.appleFont(at: Self.trueTypeFontPath)

        #expect(openFont.canCreatePostScriptSubset(.type1))
        #expect(!openFont.canCreatePostScriptSubset(.type3))
        #expect(openFont.canCreatePostScriptSubset(.type42))
        #expect(
            openFont.canCreatePostScriptSubset(.type1)
                == appleFont.canCreatePostScriptSubset(.type1)
        )
        #expect(
            openFont.canCreatePostScriptSubset(.type3)
                == appleFont.canCreatePostScriptSubset(.type3)
        )
        #expect(
            openFont.canCreatePostScriptSubset(.type42)
                == appleFont.canCreatePostScriptSubset(.type42)
        )

        let glyph = try #require(Self.openGlyph(named: "A", in: openFont))
        var encoding = [OpenCoreGraphics.CGGlyph](repeating: 0, count: 256)
        encoding[65] = glyph
        let openData = try #require(encoding.withUnsafeBufferPointer {
            openFont.createPostScriptEncoding(encoding: $0.baseAddress)
        })
        let appleData = try #require(encoding.withUnsafeBufferPointer {
            appleFont.createPostScriptEncoding(encoding: $0.baseAddress)
        })
        #expect(openData == appleData as Data)

        let defaultEncoding = try #require(openFont.createPostScriptEncoding(encoding: nil))
        let appleDefaultEncoding = try #require(appleFont.createPostScriptEncoding(encoding: nil))
        #expect(defaultEncoding == appleDefaultEncoding as Data)

        #expect(openFont.createPostScriptSubset(
            subsetName: "InvalidType3",
            format: .type3,
            glyphs: nil,
            count: 0,
            encoding: nil
        ) == nil)
        #expect(openFont.createPostScriptSubset(
            subsetName: "InvalidCount",
            format: .type1,
            glyphs: nil,
            count: -1,
            encoding: nil
        ) == nil)
        #expect(openFont.createPostScriptSubset(
            subsetName: "MissingGlyphs",
            format: .type1,
            glyphs: nil,
            count: 1,
            encoding: nil
        ) == nil)
    }

    @Test("Type 1 TrueType subset is accepted by Apple Core Graphics")
    func trueTypeType1Subset() throws {
        try verifySubset(format: .type1, path: Self.trueTypeFontPath)
    }

    @Test("Type 1 CFF subset is accepted by Apple Core Graphics")
    func cffType1Subset() throws {
        guard FileManager.default.fileExists(atPath: Self.cffFontPath) else { return }
        let openFont = try Self.openFont(at: Self.cffFontPath)
        #expect(openFont.canCreatePostScriptSubset(.type1))
        #expect(!openFont.canCreatePostScriptSubset(.type42))
        try verifySubset(format: .type1, path: Self.cffFontPath)
    }

    @Test("Type 42 subset is accepted by Apple Core Graphics and preserves metrics")
    func type42Subset() throws {
        try verifySubset(format: .type42, path: Self.trueTypeFontPath)
    }

    private func verifySubset(
        format: OpenCoreGraphics.CGFontPostScriptFormat,
        path: String
    ) throws {
        let openFont = try Self.openFont(at: path)
        let fixture = try #require(Self.fixtureGlyph(in: openFont))
        let glyph = fixture.glyph
        var encoding = [OpenCoreGraphics.CGGlyph](repeating: 0, count: 256)
        encoding[65] = glyph
        let glyphs: [OpenCoreGraphics.CGGlyph] = [0, glyph]
        let subset = try #require(glyphs.withUnsafeBufferPointer { glyphBuffer in
            encoding.withUnsafeBufferPointer { encodingBuffer in
                openFont.createPostScriptSubset(
                    subsetName: "OCGSubset",
                    format: format,
                    glyphs: glyphBuffer.baseAddress,
                    count: glyphBuffer.count,
                    encoding: encodingBuffer.baseAddress
                )
            }
        })
        #expect(!subset.isEmpty)

        let generatedFontData: Data
        if format == .type42 {
            generatedFontData = try #require(Self.embeddedSFNT(in: subset))
            let openProvider = OpenCoreGraphics.CGDataProvider(data: generatedFontData)
            let optionalOpenGeneratedFont: OpenCoreGraphics.CGFont? = .init(openProvider)
            let openGeneratedFont = try #require(optionalOpenGeneratedFont)
            let unselected = try #require(Self.unselectedGlyph(in: openFont, excluding: glyph))
            #expect(openGeneratedFont.path(for: unselected)?.isEmpty == true)
        } else {
            generatedFontData = subset
        }
        let optionalGeneratedProvider: CoreGraphics.CGDataProvider? = .init(
            data: generatedFontData as CFData
        )
        let provider = try #require(optionalGeneratedProvider)
        let optionalSubsetFont: CoreGraphics.CGFont? = .init(provider)
        let subsetFont = try #require(optionalSubsetFont)
        let subsetGlyph = subsetFont.getGlyphWithGlyphName(name: fixture.name as CFString)
        #expect(subsetGlyph != CoreGraphics.CGGlyph.max)

        var sourceGlyph = glyph
        var sourceAdvance: Int32 = 0
        #expect(openFont.getGlyphAdvances(
            glyphs: &sourceGlyph,
            count: 1,
            advances: &sourceAdvance
        ))
        var generatedGlyph = subsetGlyph
        var generatedAdvance: Int32 = 0
        #expect(subsetFont.getGlyphAdvances(
            glyphs: &generatedGlyph,
            count: 1,
            advances: &generatedAdvance
        ))
        let normalizedSourceAdvance = Double(sourceAdvance) / Double(openFont.unitsPerEm)
        let normalizedGeneratedAdvance = Double(generatedAdvance) / Double(subsetFont.unitsPerEm)
        #expect(Swift.abs(normalizedGeneratedAdvance - normalizedSourceAdvance) < 0.002)

        let generatedCTFont = CTFontCreateWithGraphicsFont(
            subsetFont,
            CGFloat(openFont.unitsPerEm),
            nil,
            nil
        )
        let generatedPath = try #require(
            CTFontCreatePathForGlyph(generatedCTFont, subsetGlyph, nil)
        )
        let sourcePath = try #require(openFont.path(for: glyph))
        let sourceBounds: Foundation.CGRect = sourcePath.boundingBox
        let generatedBounds: Foundation.CGRect = generatedPath.boundingBox
        #expect(Self.boundsApproximatelyEqual(sourceBounds, generatedBounds))
    }

    private static func openFont(at path: String) throws -> OpenCoreGraphics.CGFont {
        guard FileManager.default.fileExists(atPath: path) else {
            throw ConformanceError.missingFixture(path)
        }
        let data = try Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe)
        let provider = OpenCoreGraphics.CGDataProvider(data: data)
        let optionalFont: OpenCoreGraphics.CGFont? = .init(provider)
        return try #require(optionalFont)
    }

    private static func appleFont(at path: String) throws -> CoreGraphics.CGFont {
        let data = try Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe)
        let optionalProvider: CoreGraphics.CGDataProvider? = .init(data: data as CFData)
        let provider = try #require(optionalProvider)
        let optionalFont: CoreGraphics.CGFont? = .init(provider)
        return try #require(optionalFont)
    }

    private static func openGlyph(
        named name: String,
        in font: OpenCoreGraphics.CGFont
    ) -> OpenCoreGraphics.CGGlyph? {
        let glyph = font.getGlyphWithGlyphName(name: name)
        return glyph == OpenCoreGraphics.kCGFontIndexInvalid ? nil : glyph
    }

    private static func fixtureGlyph(
        in font: OpenCoreGraphics.CGFont
    ) -> (glyph: OpenCoreGraphics.CGGlyph, name: String)? {
        if let glyph = openGlyph(named: "A", in: font) { return (glyph, "A") }
        for index in 1..<min(font.numberOfGlyphs, 256) {
            let glyph = OpenCoreGraphics.CGGlyph(index)
            if let path = font.path(for: glyph), !path.isEmpty {
                return (glyph, "gid\(glyph)")
            }
        }
        return nil
    }

    private static func unselectedGlyph(
        in font: OpenCoreGraphics.CGFont,
        excluding selected: OpenCoreGraphics.CGGlyph
    ) -> OpenCoreGraphics.CGGlyph? {
        for index in 1..<min(font.numberOfGlyphs, 256) {
            let glyph = OpenCoreGraphics.CGGlyph(index)
            guard glyph != selected else { continue }
            if let path = font.path(for: glyph), !path.isEmpty { return glyph }
        }
        return nil
    }

    private static func embeddedSFNT(in type42: Data) -> Data? {
        guard let source = String(data: type42, encoding: .ascii),
              let start = source.range(of: "/sfnts [\n")?.upperBound,
              let end = source.range(of: "] def", range: start..<source.endIndex)?.lowerBound else {
            return nil
        }
        let digits = source[start..<end].utf8.filter { byte in
            (48...57).contains(byte) || (97...102).contains(byte) || (65...70).contains(byte)
        }
        guard digits.count.isMultiple(of: 2) else { return nil }
        func nibble(_ byte: UInt8) -> UInt8 {
            if byte <= 57 { return byte - 48 }
            return (byte & 0xDF) - 65 + 10
        }
        var result = Data()
        result.reserveCapacity(digits.count / 2)
        for index in stride(from: 0, to: digits.count, by: 2) {
            result.append(nibble(digits[index]) << 4 | nibble(digits[index + 1]))
        }
        return result
    }

    private static func boundsApproximatelyEqual(
        _ lhs: Foundation.CGRect,
        _ rhs: Foundation.CGRect
    ) -> Bool {
        let lhsValues: [Double] = [
            Double(lhs.origin.x), Double(lhs.origin.y),
            Double(lhs.size.width), Double(lhs.size.height),
        ]
        let rhsValues: [Double] = [
            Double(rhs.origin.x), Double(rhs.origin.y),
            Double(rhs.size.width), Double(rhs.size.height),
        ]
        return zip(lhsValues, rhsValues).allSatisfy { Swift.abs($0 - $1) <= 1.0 }
    }

    private enum ConformanceError: Error {
        case missingFixture(String)
    }

    private static let trueTypeFontPath = "/System/Library/Fonts/Supplemental/Skia.ttf"
    private static let cffFontPath = "/Library/Fonts/SF-Pro-Text-Regular.otf"
}
#endif
