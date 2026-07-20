//
//  CGGlyphOutlineTests.swift
//  OpenCoreGraphics
//

import Foundation
import Synchronization
import Testing
@testable import OpenCoreGraphics

@Suite("Glyph Outline Tests")
struct CGGlyphOutlineTests {

    private final class RecordingRenderer: CGContextRendererDelegate {
        private let fillBounds = Mutex<[CGRect]>([])

        func snapshot() -> [CGRect] {
            fillBounds.withLock { $0 }
        }

        func fill(path: CGPath, color: CGColor, alpha: CGFloat, blendMode: CGBlendMode, rule: CGPathFillRule) {
            fillBounds.withLock { $0.append(path.boundingBox) }
        }

        func stroke(
            path: CGPath,
            color: CGColor,
            lineWidth: CGFloat,
            lineCap: CGLineCap,
            lineJoin: CGLineJoin,
            miterLimit: CGFloat,
            dashPhase: CGFloat,
            dashLengths: [CGFloat],
            alpha: CGFloat,
            blendMode: CGBlendMode
        ) {}

        func clear(rect: CGRect) {}

        func draw(
            image: CGImage,
            in rect: CGRect,
            alpha: CGFloat,
            blendMode: CGBlendMode,
            interpolationQuality: CGInterpolationQuality
        ) {}

        func drawLinearGradient(
            _ gradient: CGGradient,
            start: CGPoint,
            end: CGPoint,
            options: CGGradientDrawingOptions
        ) {}

        func drawRadialGradient(
            _ gradient: CGGradient,
            startCenter: CGPoint,
            startRadius: CGFloat,
            endCenter: CGPoint,
            endRadius: CGFloat,
            options: CGGradientDrawingOptions
        ) {}

        func drawShading(_ shading: CGShading, alpha: CGFloat, blendMode: CGBlendMode) {}

        func fillWithPattern(
            path: CGPath,
            pattern: CGPattern,
            patternSpace: CGColorSpace,
            colorComponents: [CGFloat]?,
            patternPhase: CGSize,
            alpha: CGFloat,
            blendMode: CGBlendMode,
            rule: CGPathFillRule
        ) {}

        func strokeWithPattern(
            path: CGPath,
            pattern: CGPattern,
            patternSpace: CGColorSpace,
            colorComponents: [CGFloat]?,
            patternPhase: CGSize,
            lineWidth: CGFloat,
            lineCap: CGLineCap,
            lineJoin: CGLineJoin,
            miterLimit: CGFloat,
            dashPhase: CGFloat,
            dashLengths: [CGFloat],
            alpha: CGFloat,
            blendMode: CGBlendMode
        ) {}
    }

    @Test("Simple glyph decodes consecutive off-curve points")
    func simpleGlyphDecodesImpliedOnCurvePoint() throws {
        let parser = try #require(SFNTParser(data: makeParserData()))
        let path = try #require(parser.parseGlyphPath(glyphIndex: 0, loca: makeLocaTable()))

        #expect(path.commands.count == 4)
        #expect(path.boundingBox == CGRect(x: 0, y: 0, width: 100, height: 100))

        guard case let .quadCurveTo(control, end) = path.commands[1] else {
            Issue.record("Expected first quadratic segment")
            return
        }
        #expect(control == CGPoint(x: 50, y: 100))
        #expect(end == CGPoint(x: 75, y: 100))
    }

    @Test("Compound glyph applies component translation")
    func compoundGlyphAppliesTranslation() throws {
        let parser = try #require(SFNTParser(data: makeParserData()))
        let path = try #require(parser.parseGlyphPath(glyphIndex: 1, loca: makeLocaTable()))

        #expect(path.boundingBox == CGRect(x: 200, y: -50, width: 100, height: 100))
    }

    @Test("Recursive compound glyph is rejected")
    func recursiveCompoundGlyphIsRejected() throws {
        let parser = try #require(SFNTParser(data: makeRecursiveParserData()))
        let loca = LocaTable(offsets: [0, 18])

        #expect(parser.parseGlyphPath(glyphIndex: 0, loca: loca) == nil)
    }

    @Test("CGContext renders scaled glyph path through the normal fill pipeline")
    func contextRendersGlyphPath() throws {
        let font = try #require(CGFont(CGDataProvider(data: makeFontData())))
        let context = try #require(CGContext(
            data: nil,
            width: 64,
            height: 64,
            bitsPerComponent: 8,
            bytesPerRow: 64 * 4,
            space: .deviceRGB,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        ))
        let renderer = RecordingRenderer()
        context.rendererDelegate = renderer
        context.setFont(font)
        context.setFontSize(10)
        context.textMatrix = CGAffineTransform(translationX: 3, y: 4)

        context.showGlyphs([0], at: [CGPoint(x: 2, y: 1)])

        #expect(renderer.snapshot() == [CGRect(x: 5, y: 5, width: 1, height: 1)])
    }

    @Test("CFF Type 2 outlines decode through CGFont with global subroutines and cubic curves")
    func cffType2Outlines() throws {
        let font = try #require(CGFont(CGDataProvider(data: makeCFFFontData())))
        #expect(font.numberOfGlyphs == 3)

        let square = try #require(font.path(for: 1))
        #expect(square.boundingBox == CGRect(x: 0, y: 0, width: 100, height: 100))
        #expect(square.commands.count == 6)

        let curve = try #require(font.path(for: 2))
        #expect(curve.commands.contains(where: {
            if case .curveTo = $0 { return true }
            return false
        }))

        var glyphs: [CGGlyph] = [1, 2]
        var boxes = Array(repeating: CGRect.zero, count: glyphs.count)
        let success = glyphs.withUnsafeBufferPointer { glyphBuffer in
            boxes.withUnsafeMutableBufferPointer { boxBuffer in
                font.getGlyphBBoxes(
                    glyphs: glyphBuffer.baseAddress!,
                    count: glyphBuffer.count,
                    bboxes: boxBuffer.baseAddress!
                )
            }
        }
        #expect(success)
        #expect(boxes[0] == square.boundingBox)
        #expect(boxes[1] == curve.boundingBox)

        var truncatedCFF = makeCFFTable()
        truncatedCFF.removeLast()
        #expect(CGFont(CGDataProvider(data: makeCFFFontData(cff: truncatedCFF))) == nil)
    }

    @Test("Real OpenType CFF outlines execute when an Apple CFF font is installed")
    func realCFFOutlines() throws {
        let url = URL(fileURLWithPath: "/Library/Fonts/SF-Pro-Text-Regular.otf")
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        let font = try #require(CGFont(CGDataProvider(data: data)))
        #expect(font.table(for: FontTableTag.CFF) != nil)

        var decoded = 0
        var cubic = 0
        for glyphIndex in 0..<min(font.numberOfGlyphs, 64) {
            if let path = font.path(for: CGGlyph(glyphIndex)), !path.commands.isEmpty {
                decoded += 1
                if path.commands.contains(where: {
                    if case .curveTo = $0 { return true }
                    return false
                }) {
                    cubic += 1
                }
            }
        }
        #expect(decoded >= 32)
        #expect(cubic > 0)
    }

    @Test("Text position aliases the text matrix translation")
    func textPositionAliasesTextMatrixTranslation() throws {
        let context = try #require(CGContext(
            data: nil,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: .deviceRGB,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        ))

        context.textPosition = CGPoint(x: 3, y: 4)
        #expect(context.textMatrix.tx == 3)
        #expect(context.textMatrix.ty == 4)

        context.textMatrix = CGAffineTransform(a: 2, b: 0, c: 0, d: 2, tx: 7, ty: 8)
        #expect(context.textPosition == CGPoint(x: 7, y: 8))
    }

    @Test("Disabled subpixel positioning rounds glyph origins")
    func disabledSubpixelPositioningRoundsOrigins() throws {
        let font = try #require(CGFont(CGDataProvider(data: makeFontData())))
        let context = try #require(CGContext(
            data: nil,
            width: 64,
            height: 64,
            bitsPerComponent: 8,
            bytesPerRow: 64 * 4,
            space: .deviceRGB,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        ))
        let renderer = RecordingRenderer()
        context.rendererDelegate = renderer
        context.setFont(font)
        context.setFontSize(10)
        context.textPosition = CGPoint(x: 3.2, y: 4.7)
        context.setShouldSubpixelPositionFonts(false)

        context.showGlyphs([0], at: [CGPoint(x: 2.2, y: 1.1)])

        #expect(renderer.snapshot() == [CGRect(x: 5, y: 6, width: 1, height: 1)])
    }

    private func makeLocaTable() -> LocaTable {
        LocaTable(offsets: [0, 22, 40])
    }

    private func makeParserData() -> Data {
        let glyphs = makeGlyphData()
        var data = sfntHeader(tableCount: 1)
        appendTableRecord(tag: FontTableTag.glyf, offset: 28, length: glyphs.count, to: &data)
        data.append(glyphs)
        return data
    }

    private func makeRecursiveParserData() -> Data {
        var glyph = Data()
        appendInt16(-1, to: &glyph)
        glyph.append(contentsOf: Array(repeating: 0, count: 8))
        appendUInt16(0x0003, to: &glyph)
        appendUInt16(0, to: &glyph)
        appendInt16(0, to: &glyph)
        appendInt16(0, to: &glyph)

        var data = sfntHeader(tableCount: 1)
        appendTableRecord(tag: FontTableTag.glyf, offset: 28, length: glyph.count, to: &data)
        data.append(glyph)
        return data
    }

    private func makeFontData() -> Data {
        let head = makeHeadTable()
        let maxp = Data([0x00, 0x00, 0x50, 0x00, 0x00, 0x02])
        let loca = Data([0x00, 0x00, 0x00, 0x0B, 0x00, 0x14])
        let glyphs = makeGlyphData()
        let directoryEnd = 12 + 4 * 16
        let headOffset = directoryEnd
        let maxpOffset = headOffset + head.count
        let locaOffset = maxpOffset + maxp.count
        let glyfOffset = locaOffset + loca.count

        var data = sfntHeader(tableCount: 4)
        appendTableRecord(tag: FontTableTag.head, offset: headOffset, length: head.count, to: &data)
        appendTableRecord(tag: FontTableTag.maxp, offset: maxpOffset, length: maxp.count, to: &data)
        appendTableRecord(tag: FontTableTag.loca, offset: locaOffset, length: loca.count, to: &data)
        appendTableRecord(tag: FontTableTag.glyf, offset: glyfOffset, length: glyphs.count, to: &data)
        data.append(head)
        data.append(maxp)
        data.append(loca)
        data.append(glyphs)
        return data
    }

    private func makeCFFFontData(cff suppliedCFF: Data? = nil) -> Data {
        let head = makeHeadTable()
        let maxp = Data([0x00, 0x00, 0x50, 0x00, 0x00, 0x03])
        let cff = suppliedCFF ?? makeCFFTable()
        let directoryEnd = 12 + 3 * 16
        let headOffset = directoryEnd
        let maxpOffset = headOffset + head.count
        let cffOffset = maxpOffset + maxp.count

        var data = Data("OTTO".utf8)
        appendUInt16(3, to: &data)
        data.append(contentsOf: Array(repeating: 0, count: 6))
        appendTableRecord(tag: FontTableTag.head, offset: headOffset, length: head.count, to: &data)
        appendTableRecord(tag: FontTableTag.maxp, offset: maxpOffset, length: maxp.count, to: &data)
        appendTableRecord(tag: FontTableTag.CFF, offset: cffOffset, length: cff.count, to: &data)
        data.append(head)
        data.append(maxp)
        data.append(cff)
        return data
    }

    private func makeCFFTable() -> Data {
        let name = makeCFFIndex([Data("Test".utf8)])
        let stringIndex = Data([0, 0])
        let squareSubroutine = Data([
            239, 139, 5,
            139, 239, 5,
            39, 139, 5,
            139, 39, 5,
            11
        ])
        let globalSubroutines = makeCFFIndex([squareSubroutine])
        let charStrings = makeCFFIndex([
            Data([14]),
            Data([139, 139, 21, 32, 29, 14]),
            Data([139, 139, 21, 189, 239, 189, 39, 189, 139, 8, 14])
        ])

        var topDictionary = makeCFFIndex([Data([139, 17])])
        let charStringsOffset = 4 + name.count + topDictionary.count + stringIndex.count + globalSubroutines.count
        precondition(charStringsOffset <= 107)
        topDictionary = makeCFFIndex([Data([UInt8(charStringsOffset + 139), 17])])

        var data = Data([1, 0, 4, 1])
        data.append(name)
        data.append(topDictionary)
        data.append(stringIndex)
        data.append(globalSubroutines)
        precondition(data.count == charStringsOffset)
        data.append(charStrings)
        return data
    }

    private func makeCFFIndex(_ objects: [Data]) -> Data {
        if objects.isEmpty { return Data([0, 0]) }
        let payloadSize = objects.reduce(0) { $0 + $1.count }
        precondition(payloadSize + 1 <= 255)
        var data = Data()
        appendUInt16(UInt16(objects.count), to: &data)
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
        data[41] = 0x64
        data[42] = 0x00
        data[43] = 0x64
        return data
    }

    private func makeGlyphData() -> Data {
        var simple = Data()
        appendInt16(1, to: &simple)
        appendInt16(0, to: &simple)
        appendInt16(0, to: &simple)
        appendInt16(100, to: &simple)
        appendInt16(100, to: &simple)
        appendUInt16(3, to: &simple)
        appendUInt16(0, to: &simple)
        simple.append(contentsOf: [0x31, 0x36, 0x32, 0x15])
        simple.append(contentsOf: [50, 50])
        simple.append(contentsOf: [100, 100])

        var compound = Data()
        appendInt16(-1, to: &compound)
        compound.append(contentsOf: Array(repeating: 0, count: 8))
        appendUInt16(0x0003, to: &compound)
        appendUInt16(0, to: &compound)
        appendInt16(200, to: &compound)
        appendInt16(-50, to: &compound)
        return simple + compound
    }

    private func sfntHeader(tableCount: UInt16) -> Data {
        var data = Data([0x00, 0x01, 0x00, 0x00])
        appendUInt16(tableCount, to: &data)
        data.append(contentsOf: Array(repeating: 0, count: 6))
        return data
    }

    private func appendTableRecord(tag: UInt32, offset: Int, length: Int, to data: inout Data) {
        appendUInt32(tag, to: &data)
        appendUInt32(0, to: &data)
        appendUInt32(UInt32(offset), to: &data)
        appendUInt32(UInt32(length), to: &data)
    }

    private func appendUInt16(_ value: UInt16, to data: inout Data) {
        data.append(UInt8((value >> 8) & 0xFF))
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
}
