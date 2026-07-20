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

    @Test("Generated Type 1 PFA reloads with Apple-compatible metadata, metrics, and outlines")
    func type1PFAReload() throws {
        let source = try Self.openFont(at: Self.trueTypeFontPath)
        let fixture = try #require(Self.fixtureGlyph(in: source))
        let data = try Self.type1Subset(font: source, fixture: fixture)
        try Self.verifyType1Reload(data: data, glyphName: fixture.name)
    }

    @Test("Generated Type 1 PFB reloads with Apple-compatible metadata, metrics, and outlines")
    func type1PFBReload() throws {
        let source = try Self.openFont(at: Self.trueTypeFontPath)
        let fixture = try #require(Self.fixtureGlyph(in: source))
        let pfa = try Self.type1Subset(font: source, fixture: fixture)
        let pfb = try #require(Self.pfb(from: pfa))
        try Self.verifyType1Reload(data: pfb, glyphName: fixture.name)
    }

    @Test("Truncated PFA and malformed PFB are rejected")
    func malformedType1Containers() throws {
        let source = try Self.openFont(at: Self.trueTypeFontPath)
        let fixture = try #require(Self.fixtureGlyph(in: source))
        let pfa = try Self.type1Subset(font: source, fixture: fixture)
        let eexec = try #require(pfa.range(of: Data("eexec\n".utf8)))
        let truncated = Data(pfa.prefix(eexec.upperBound + 16))
        let truncatedProvider = OpenCoreGraphics.CGDataProvider(data: truncated)
        let truncatedFont: OpenCoreGraphics.CGFont? = .init(truncatedProvider)
        #expect(truncatedFont == nil)

        var pfb = try #require(Self.pfb(from: pfa))
        #expect(pfb.count > 12)
        pfb[2] = 0xFF
        pfb[3] = 0xFF
        pfb[4] = 0xFF
        pfb[5] = 0x7F
        let malformedProvider = OpenCoreGraphics.CGDataProvider(data: pfb)
        let malformedFont: OpenCoreGraphics.CGFont? = .init(malformedProvider)
        #expect(malformedFont == nil)
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

    private static func openFont(data: Data) throws -> OpenCoreGraphics.CGFont {
        let provider = OpenCoreGraphics.CGDataProvider(data: data)
        let optionalFont: OpenCoreGraphics.CGFont? = .init(provider)
        return try #require(optionalFont)
    }

    private static func appleFont(data: Data) throws -> CoreGraphics.CGFont {
        let optionalProvider: CoreGraphics.CGDataProvider? = .init(data: data as CFData)
        let provider = try #require(optionalProvider)
        let optionalFont: CoreGraphics.CGFont? = .init(provider)
        return try #require(optionalFont)
    }

    private static func type1Subset(
        font: OpenCoreGraphics.CGFont,
        fixture: (glyph: OpenCoreGraphics.CGGlyph, name: String)
    ) throws -> Data {
        var encoding = [OpenCoreGraphics.CGGlyph](repeating: 0, count: 256)
        encoding[65] = fixture.glyph
        let glyphs: [OpenCoreGraphics.CGGlyph] = [0, fixture.glyph]
        return try #require(glyphs.withUnsafeBufferPointer { glyphBuffer in
            encoding.withUnsafeBufferPointer { encodingBuffer in
                font.createPostScriptSubset(
                    subsetName: "OCGType1Reload",
                    format: .type1,
                    glyphs: glyphBuffer.baseAddress,
                    count: glyphBuffer.count,
                    encoding: encodingBuffer.baseAddress
                )
            }
        })
    }

    private static func verifyType1Reload(data: Data, glyphName: String) throws {
        let open = try openFont(data: data)
        let apple = try appleFont(data: data)
        #expect(open.fullName == apple.fullName as String?)
        #expect(open.postScriptName == apple.postScriptName as String?)
        #expect(open.numberOfGlyphs == apple.numberOfGlyphs)
        #expect(open.unitsPerEm == apple.unitsPerEm)
        #expect(open.ascent == apple.ascent)
        #expect(open.descent == apple.descent)
        #expect(open.leading == apple.leading)
        #expect(open.capHeight == apple.capHeight)
        #expect(open.xHeight == apple.xHeight)
        #expect(open.fontBBox.origin.x == apple.fontBBox.origin.x)
        #expect(Swift.abs(Double(open.fontBBox.origin.y - apple.fontBBox.origin.y)) <= 1)
        #expect(Swift.abs(Double(open.fontBBox.size.width - apple.fontBBox.size.width)) <= 1)
        #expect(Swift.abs(Double(open.fontBBox.size.height - apple.fontBBox.size.height)) <= 1)
        #expect(open.italicAngle == apple.italicAngle)
        #expect(open.stemV == apple.stemV)
        #expect(open.tableTags == nil)
        #expect(apple.tableTags == nil)
        #expect(open.canCreatePostScriptSubset(.type1) == apple.canCreatePostScriptSubset(.type1))
        #expect(open.canCreatePostScriptSubset(.type3) == apple.canCreatePostScriptSubset(.type3))
        #expect(open.canCreatePostScriptSubset(.type42) == apple.canCreatePostScriptSubset(.type42))

        let openGlyph = open.getGlyphWithGlyphName(name: glyphName)
        let appleGlyph = apple.getGlyphWithGlyphName(name: glyphName as CFString)
        #expect(openGlyph != OpenCoreGraphics.kCGFontIndexInvalid)
        #expect(appleGlyph != CoreGraphics.CGGlyph.max)
        #expect(open.name(for: openGlyph) == apple.name(for: appleGlyph) as String?)

        var mutableOpenGlyph = openGlyph
        var openAdvance: Int32 = 0
        #expect(open.getGlyphAdvances(glyphs: &mutableOpenGlyph, count: 1, advances: &openAdvance))
        var mutableAppleGlyph = appleGlyph
        var appleAdvance: Int32 = 0
        #expect(apple.getGlyphAdvances(glyphs: &mutableAppleGlyph, count: 1, advances: &appleAdvance))
        #expect(openAdvance == appleAdvance)

        var openBounds = Foundation.CGRect(x: 0, y: 0, width: 0, height: 0)
        var appleBounds = Foundation.CGRect(x: 0, y: 0, width: 0, height: 0)
        #expect(open.getGlyphBBoxes(glyphs: &mutableOpenGlyph, count: 1, bboxes: &openBounds))
        #expect(apple.getGlyphBBoxes(glyphs: &mutableAppleGlyph, count: 1, bboxes: &appleBounds))
        #expect(Swift.abs(Double(openBounds.origin.x - appleBounds.origin.x)) <= 1)
        #expect(Swift.abs(Double(openBounds.origin.y - appleBounds.origin.y)) <= 1)
        #expect(openBounds.size.width == appleBounds.size.width)
        #expect(openBounds.size.height == appleBounds.size.height)
        let openPath = try #require(open.path(for: openGlyph))
        let appleCTFont = CTFontCreateWithGraphicsFont(apple, CGFloat(apple.unitsPerEm), nil, nil)
        let applePath = try #require(CTFontCreatePathForGlyph(appleCTFont, appleGlyph, nil))
        #expect(boundsApproximatelyEqual(openPath.boundingBox, applePath.boundingBox))
    }

    private static func pfb(from pfa: Data) -> Data? {
        guard let eexec = pfa.range(of: Data("eexec\n".utf8)) else { return nil }
        let clear = Data(pfa[..<eexec.upperBound])
        guard let source = String(data: pfa[eexec.upperBound...], encoding: .ascii) else { return nil }
        var ciphertext = Data()
        for token in source.split(whereSeparator: { $0.isWhitespace }) {
            if token.count >= 32, token.allSatisfy({ $0 == "0" }) { break }
            let bytes = Array(token.utf8)
            guard bytes.count.isMultiple(of: 2) else { return nil }
            for index in stride(from: 0, to: bytes.count, by: 2) {
                guard let high = hexNibble(bytes[index]), let low = hexNibble(bytes[index + 1]) else {
                    return nil
                }
                ciphertext.append(high << 4 | low)
            }
        }
        guard !ciphertext.isEmpty else { return nil }
        var result = Data()
        appendPFBSegment(type: 1, data: clear, to: &result)
        appendPFBSegment(type: 2, data: ciphertext, to: &result)
        result.append(contentsOf: [0x80, 0x03])
        return result
    }

    private static func appendPFBSegment(type: UInt8, data: Data, to result: inout Data) {
        result.append(contentsOf: [0x80, type])
        let length = UInt32(data.count)
        result.append(UInt8(truncatingIfNeeded: length))
        result.append(UInt8(truncatingIfNeeded: length >> 8))
        result.append(UInt8(truncatingIfNeeded: length >> 16))
        result.append(UInt8(truncatingIfNeeded: length >> 24))
        result.append(data)
    }

    private static func hexNibble(_ byte: UInt8) -> UInt8? {
        switch byte {
        case 48...57: return byte - 48
        case 65...70: return byte - 65 + 10
        case 97...102: return byte - 97 + 10
        default: return nil
        }
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
