//
//  PostScriptFontEncoder.swift
//  OpenCoreGraphics
//
//  Type 1 and Type 42 font subset generation.
//

import Foundation

internal struct PostScriptFontEncoder {
    private let fontData: Data
    private let glyphCount: Int
    private let unitsPerEm: Int
    private let fontBoundingBox: CGRect
    private let italicAngle: CGFloat
    private let defaultFontName: String
    private let path: (CGGlyph) -> CGPath?
    private let glyphName: (CGGlyph) -> String?
    private let advance: (CGGlyph) -> Int32?
    private let leftSideBearing: (CGGlyph) -> Int32?

    init(
        fontData: Data,
        glyphCount: Int,
        unitsPerEm: Int,
        fontBoundingBox: CGRect,
        italicAngle: CGFloat,
        defaultFontName: String,
        path: @escaping (CGGlyph) -> CGPath?,
        glyphName: @escaping (CGGlyph) -> String?,
        advance: @escaping (CGGlyph) -> Int32?,
        leftSideBearing: @escaping (CGGlyph) -> Int32?
    ) {
        self.fontData = fontData
        self.glyphCount = glyphCount
        self.unitsPerEm = unitsPerEm
        self.fontBoundingBox = fontBoundingBox
        self.italicAngle = italicAngle
        self.defaultFontName = defaultFontName
        self.path = path
        self.glyphName = glyphName
        self.advance = advance
        self.leftSideBearing = leftSideBearing
    }

    func subset(
        name suppliedName: String,
        format: CGFontPostScriptFormat,
        glyphs requestedGlyphs: [CGGlyph],
        encoding: [CGGlyph]?
    ) -> Data? {
        guard glyphCount > 0, unitsPerEm > 0,
              requestedGlyphs.allSatisfy({ Int($0) < glyphCount }) else {
            return nil
        }

        var selected = Set(requestedGlyphs)
        selected.insert(0)
        if let encoding {
            for glyph in encoding where glyph != 0 && Int(glyph) < glyphCount {
                selected.insert(glyph)
            }
        }
        let glyphs = selected.sorted()
        let name = Self.postScriptName(suppliedName.isEmpty ? defaultFontName : suppliedName)
        let names = uniqueNames(for: glyphs)

        switch format {
        case .type1:
            return type1Subset(name: name, glyphs: glyphs, names: names, encoding: encoding)
        case .type3:
            return nil
        case .type42:
            return type42Subset(name: name, glyphs: glyphs, names: names, encoding: encoding)
        }
    }

    static func encodingData(
        encoding: [CGGlyph],
        glyphName: (CGGlyph) -> String?
    ) -> Data? {
        guard encoding.count == 256 else { return nil }
        var source = "256 array 0 1 255 {1 index exch/.notdef put} for\n"
        for (code, glyph) in encoding.enumerated() where glyph != 0 {
            let rawName = glyphName(glyph) ?? "gid\(glyph)"
            source += "dup \(code) /\(postScriptName(rawName)) put\n"
        }
        source += "\n"
        return source.data(using: .ascii)
    }

    private func uniqueNames(for glyphs: [CGGlyph]) -> [CGGlyph: String] {
        var result: [CGGlyph: String] = [:]
        var used: Set<String> = []
        for glyph in glyphs {
            let base = glyph == 0
                ? ".notdef"
                : Self.postScriptName(glyphName(glyph) ?? "gid\(glyph)")
            var candidate = base
            if used.contains(candidate) {
                candidate = "\(base).gid\(glyph)"
            }
            used.insert(candidate)
            result[glyph] = candidate
        }
        return result
    }

    private func type1Subset(
        name: String,
        glyphs: [CGGlyph],
        names: [CGGlyph: String],
        encoding: [CGGlyph]?
    ) -> Data? {
        var charStrings: [(String, Data)] = []
        charStrings.reserveCapacity(glyphs.count)
        for glyph in glyphs {
            guard let glyphPath = path(glyph),
                  let width = advance(glyph),
                  let bearing = leftSideBearing(glyph),
                  let glyphName = names[glyph],
                  let charString = Self.type1CharString(
                    path: glyphPath,
                    sideBearing: bearing,
                    width: width
                  ) else {
                return nil
            }
            charStrings.append((glyphName, charString))
        }

        let matrixScale = 1.0 / CGFloat(unitsPerEm)
        let bbox = Self.integerBounds(fontBoundingBox)
        var clear = "%!FontType1-1.0: \(name) 1.0\n"
        clear += "11 dict begin\n"
        clear += "/FontInfo 5 dict dup begin\n"
        clear += "/FullName (\(Self.postScriptString(name))) readonly def\n"
        clear += "/FamilyName (\(Self.postScriptString(name))) readonly def\n"
        clear += "/Weight (Regular) readonly def\n"
        clear += "/ItalicAngle \(Self.number(italicAngle)) def\n"
        clear += "/isFixedPitch false def\n"
        clear += "end readonly def\n"
        clear += "/FontName /\(name) def\n"
        clear += "/PaintType 0 def\n/FontType 1 def\n"
        clear += "/FontMatrix [\(Self.number(matrixScale)) 0 0 \(Self.number(matrixScale)) 0 0] readonly def\n"
        clear += "/FontBBox {\(bbox.minX) \(bbox.minY) \(bbox.maxX) \(bbox.maxY)} readonly def\n"
        clear += Self.encodingSource(encoding: encoding, names: names)
        clear += "currentdict end\ncurrentfile eexec\n"

        var encryptedSource = Data()
        encryptedSource.appendASCII("dup/Private 10 dict dup begin\n")
        encryptedSource.appendASCII("/RD{string currentfile exch readstring pop}executeonly def\n")
        encryptedSource.appendASCII("/ND{noaccess def}executeonly def\n")
        encryptedSource.appendASCII("/NP{noaccess put}executeonly def\n")
        encryptedSource.appendASCII("/BlueValues[]def\n/OtherBlues[]def\n")
        encryptedSource.appendASCII("/MinFeature{16 16}def\n/password 5839 def\n")
        encryptedSource.appendASCII("/Subrs 0 array ND\n")
        encryptedSource.appendASCII("2 index/CharStrings \(charStrings.count) dict dup begin\n")
        for (glyphName, charString) in charStrings {
            var charStringPlaintext = Data(repeating: 0, count: 4)
            charStringPlaintext.append(charString)
            let encryptedCharString = Self.encrypt(charStringPlaintext, seed: 4_330)
            encryptedSource.appendASCII("/\(glyphName) \(encryptedCharString.count) RD ")
            encryptedSource.append(encryptedCharString)
            encryptedSource.appendASCII(" ND\n")
        }
        encryptedSource.appendASCII("end\nend readonly put\nnoaccess put\n")
        encryptedSource.appendASCII("dup/FontName get exch definefont pop\n")
        encryptedSource.appendASCII("mark currentfile closefile\n")

        var encryptedPlaintext = Data(repeating: 0, count: 4)
        encryptedPlaintext.append(encryptedSource)
        let encrypted = Self.encrypt(encryptedPlaintext, seed: 55_665)
        clear += Self.wrappedHex(encrypted)
        clear += "\n0000000000000000000000000000000000000000000000000000000000000000\n"
        clear += "cleartomark\n"
        return clear.data(using: .ascii)
    }

    private func type42Subset(
        name: String,
        glyphs: [CGGlyph],
        names: [CGGlyph: String],
        encoding: [CGGlyph]?
    ) -> Data? {
        guard let sfnt = trueTypeSubset(glyphs: Set(glyphs)) else { return nil }
        let bbox = Self.integerBounds(fontBoundingBox)
        var source = "%!PS-TrueTypeFont-1.0: \(name) 1.0\n"
        source += "11 dict begin\n"
        source += "/FontName /\(name) def\n/FontType 42 def\n/PaintType 0 def\n"
        source += "/FontMatrix [1 0 0 1 0 0] def\n"
        source += "/FontBBox [\(bbox.minX) \(bbox.minY) \(bbox.maxX) \(bbox.maxY)] def\n"
        source += Self.encodingSource(encoding: encoding, names: names)
        source += "/CharStrings \(glyphs.count) dict dup begin\n"
        for glyph in glyphs {
            guard let glyphName = names[glyph] else { return nil }
            source += "/\(glyphName) \(glyph) def\n"
        }
        source += "end readonly def\n/sfnts [\n"
        var offset = 0
        while offset < sfnt.count {
            let length = min(32_760, sfnt.count - offset)
            guard let chunk = sfnt.slice(from: offset, length: length) else { return nil }
            source += "<\(Self.hex(chunk))>\n"
            offset += length
        }
        source += "] def\nFontName currentdict end definefont pop\n"
        return source.data(using: .ascii)
    }

    private func trueTypeSubset(glyphs: Set<CGGlyph>) -> Data? {
        guard let parser = SFNTParser(data: fontData),
              parser.hasTable(FontTableTag.glyf),
              parser.hasTable(FontTableTag.loca),
              var head = parser.tableData(for: FontTableTag.head), head.count >= 54,
              var hhea = parser.tableData(for: FontTableTag.hhea), hhea.count >= 36,
              var maxp = parser.tableData(for: FontTableTag.maxp), maxp.count >= 6,
              glyphCount <= Int(UInt16.max) else {
            return nil
        }

        var glyf = Data()
        var loca: [UInt32] = [0]
        loca.reserveCapacity(glyphCount + 1)
        var maximumPoints = 0
        var maximumContours = 0
        for glyphIndex in 0..<glyphCount {
            if glyphs.contains(CGGlyph(glyphIndex)) {
                guard let glyphPath = path(CGGlyph(glyphIndex)),
                      let encoded = Self.trueTypeGlyph(path: glyphPath) else {
                    return nil
                }
                maximumPoints = max(maximumPoints, encoded.pointCount)
                maximumContours = max(maximumContours, encoded.contourCount)
                glyf.append(encoded.data)
                while !glyf.count.isMultiple(of: 4) { glyf.append(0) }
            }
            guard let offset = UInt32(exactly: glyf.count) else { return nil }
            loca.append(offset)
        }

        var locaData = Data()
        locaData.reserveCapacity(loca.count * 4)
        for offset in loca { locaData.appendUInt32BE(offset) }

        var hmtx = Data()
        hmtx.reserveCapacity(glyphCount * 4)
        let sourceMetrics: HmtxTable
        do {
            let sourceHeader = try parser.parseHheaTable()
            sourceMetrics = try parser.parseHmtxTable(
                numberOfGlyphs: glyphCount,
                numberOfHMetrics: Int(sourceHeader.numberOfHMetrics)
            )
        } catch {
            return nil
        }
        for glyphIndex in 0..<glyphCount {
            let glyph = CGGlyph(glyphIndex)
            let width = glyphs.contains(glyph)
                ? advance(glyph)
                : sourceMetrics.advanceWidth(for: glyphIndex).map(Int32.init)
            let bearing = glyphs.contains(glyph)
                ? leftSideBearing(glyph)
                : sourceMetrics.leftSideBearing(for: glyphIndex).map(Int32.init)
            guard let width, let bearing,
                  let unsignedWidth = UInt16(exactly: width),
                  let signedBearing = Int16(exactly: bearing) else {
                return nil
            }
            hmtx.appendUInt16BE(unsignedWidth)
            hmtx.appendInt16BE(signedBearing)
        }

        head.replaceUInt32BE(at: 8, with: 0)
        head.replaceInt16BE(at: 50, with: 1)
        hhea.replaceUInt16BE(at: 34, with: UInt16(glyphCount))
        maxp.replaceUInt16BE(at: 4, with: UInt16(glyphCount))
        if maxp.count >= 32 {
            maxp.replaceUInt16BE(at: 6, with: UInt16(clamping: maximumPoints))
            maxp.replaceUInt16BE(at: 8, with: UInt16(clamping: maximumContours))
            maxp.replaceUInt16BE(at: 10, with: 0)
            maxp.replaceUInt16BE(at: 12, with: 0)
            maxp.replaceUInt16BE(at: 26, with: 0)
            maxp.replaceUInt16BE(at: 28, with: 0)
            maxp.replaceUInt16BE(at: 30, with: 0)
        }

        let retainedTags = [
            FontTableTag.cmap, FontTableTag.name, FontTableTag.OS2, FontTableTag.post,
            FontTableTag.fromString("cvt "), FontTableTag.fromString("fpgm"),
            FontTableTag.fromString("prep"), FontTableTag.fromString("gasp")
        ]
        var tables: [UInt32: Data] = [
            FontTableTag.head: head,
            FontTableTag.hhea: hhea,
            FontTableTag.maxp: maxp,
            FontTableTag.hmtx: hmtx,
            FontTableTag.glyf: glyf,
            FontTableTag.loca: locaData
        ]
        for tag in retainedTags {
            if let data = parser.tableData(for: tag) { tables[tag] = data }
        }
        return Self.sfnt(tables: tables, version: 0x0001_0000)
    }

    private static func encodingSource(
        encoding: [CGGlyph]?,
        names: [CGGlyph: String]
    ) -> String {
        var source = "/Encoding 256 array\n0 1 255 {1 index exch /.notdef put} for\n"
        if let encoding {
            for (code, glyph) in encoding.enumerated() where glyph != 0 {
                let name = names[glyph] ?? postScriptName("gid\(glyph)")
                source += "dup \(code) /\(name) put\n"
            }
        }
        source += "readonly def\n"
        return source
    }

    private static func type1CharString(
        path: CGPath,
        sideBearing: Int32,
        width: Int32
    ) -> Data? {
        var result = Data()
        appendType1Number(Int(sideBearing), to: &result)
        appendType1Number(Int(width), to: &result)
        result.append(13)

        var current = CGPoint(x: CGFloat(sideBearing), y: 0)
        var contourStart: CGPoint?
        for command in path.commands {
            switch command {
            case .moveTo(let point):
                let target = integerPoint(point)
                appendType1Delta(from: current, to: target, operation: 21, data: &result)
                current = target
                contourStart = target
            case .lineTo(let point):
                let target = integerPoint(point)
                appendType1Delta(from: current, to: target, operation: 5, data: &result)
                current = target
            case .quadCurveTo(let control, let end):
                let endPoint = integerPoint(end)
                let control1 = integerPoint(CGPoint(
                    x: current.x + (control.x - current.x) * 2 / 3,
                    y: current.y + (control.y - current.y) * 2 / 3
                ))
                let control2 = integerPoint(CGPoint(
                    x: end.x + (control.x - end.x) * 2 / 3,
                    y: end.y + (control.y - end.y) * 2 / 3
                ))
                appendType1Curve(
                    from: current,
                    control1: control1,
                    control2: control2,
                    end: endPoint,
                    data: &result
                )
                current = endPoint
            case .curveTo(let control1, let control2, let end):
                let first = integerPoint(control1)
                let second = integerPoint(control2)
                let endPoint = integerPoint(end)
                appendType1Curve(
                    from: current,
                    control1: first,
                    control2: second,
                    end: endPoint,
                    data: &result
                )
                current = endPoint
            case .closeSubpath:
                if contourStart != nil { result.append(9) }
                contourStart = nil
            }
        }
        result.append(14)
        return result
    }

    private static func appendType1Delta(
        from start: CGPoint,
        to end: CGPoint,
        operation: UInt8,
        data: inout Data
    ) {
        appendType1Number(Int(end.x - start.x), to: &data)
        appendType1Number(Int(end.y - start.y), to: &data)
        data.append(operation)
    }

    private static func appendType1Curve(
        from start: CGPoint,
        control1: CGPoint,
        control2: CGPoint,
        end: CGPoint,
        data: inout Data
    ) {
        appendType1Number(Int(control1.x - start.x), to: &data)
        appendType1Number(Int(control1.y - start.y), to: &data)
        appendType1Number(Int(control2.x - control1.x), to: &data)
        appendType1Number(Int(control2.y - control1.y), to: &data)
        appendType1Number(Int(end.x - control2.x), to: &data)
        appendType1Number(Int(end.y - control2.y), to: &data)
        data.append(8)
    }

    private static func appendType1Number(_ value: Int, to data: inout Data) {
        if (-107...107).contains(value) {
            data.append(UInt8(value + 139))
        } else if (108...1131).contains(value) {
            let adjusted = value - 108
            data.append(UInt8(247 + adjusted / 256))
            data.append(UInt8(adjusted % 256))
        } else if (-1131 ... -108).contains(value) {
            let adjusted = -value - 108
            data.append(UInt8(251 + adjusted / 256))
            data.append(UInt8(adjusted % 256))
        } else {
            data.append(255)
            let signed = Int32(clamping: value)
            data.appendUInt32BE(UInt32(bitPattern: signed))
        }
    }

    private static func trueTypeGlyph(path: CGPath) -> (data: Data, pointCount: Int, contourCount: Int)? {
        struct Point {
            let position: CGPoint
            let onCurve: Bool
        }
        var contours: [[Point]] = []
        var contour: [Point] = []

        func finishContour() {
            guard !contour.isEmpty else { return }
            if contour.count > 1,
               contour.first?.position == contour.last?.position,
               contour.first?.onCurve == contour.last?.onCurve {
                contour.removeLast()
            }
            contours.append(contour)
            contour.removeAll(keepingCapacity: true)
        }

        for command in path.commands {
            switch command {
            case .moveTo(let point):
                finishContour()
                contour.append(Point(position: integerPoint(point), onCurve: true))
            case .lineTo(let point):
                contour.append(Point(position: integerPoint(point), onCurve: true))
            case .quadCurveTo(let control, let end):
                contour.append(Point(position: integerPoint(control), onCurve: false))
                contour.append(Point(position: integerPoint(end), onCurve: true))
            case .curveTo:
                return nil
            case .closeSubpath:
                finishContour()
            }
        }
        finishContour()
        if contours.isEmpty { return (Data(), 0, 0) }
        guard contours.count <= Int(Int16.max) else { return nil }

        let points = contours.flatMap { $0 }
        guard points.count <= Int(UInt16.max),
              points.allSatisfy({
                Int16(exactly: Int($0.position.x)) != nil && Int16(exactly: Int($0.position.y)) != nil
              }) else {
            return nil
        }
        let xs = points.map { Int($0.position.x) }
        let ys = points.map { Int($0.position.y) }
        var data = Data()
        data.appendInt16BE(Int16(contours.count))
        data.appendInt16BE(Int16(clamping: xs.min() ?? 0))
        data.appendInt16BE(Int16(clamping: ys.min() ?? 0))
        data.appendInt16BE(Int16(clamping: xs.max() ?? 0))
        data.appendInt16BE(Int16(clamping: ys.max() ?? 0))
        var endpoint = -1
        for contour in contours {
            endpoint += contour.count
            data.appendUInt16BE(UInt16(endpoint))
        }
        data.appendUInt16BE(0)
        for point in points { data.append(point.onCurve ? 0x01 : 0x00) }

        var previous = 0
        for x in xs {
            guard let delta = Int16(exactly: x - previous) else { return nil }
            data.appendInt16BE(delta)
            previous = x
        }
        previous = 0
        for y in ys {
            guard let delta = Int16(exactly: y - previous) else { return nil }
            data.appendInt16BE(delta)
            previous = y
        }
        return (data, points.count, contours.count)
    }

    private static func sfnt(tables: [UInt32: Data], version: UInt32) -> Data? {
        let tags = tables.keys.sorted()
        guard !tags.isEmpty, tags.count <= Int(UInt16.max) else { return nil }
        let count = tags.count
        let largestPower = 1 << Int(floor(log2(Double(count))))
        let searchRange = largestPower * 16
        let entrySelector = Int(log2(Double(largestPower)))
        let rangeShift = count * 16 - searchRange

        var result = Data()
        result.appendUInt32BE(version)
        result.appendUInt16BE(UInt16(count))
        result.appendUInt16BE(UInt16(searchRange))
        result.appendUInt16BE(UInt16(entrySelector))
        result.appendUInt16BE(UInt16(rangeShift))

        var offset = 12 + count * 16
        for tag in tags {
            guard let table = tables[tag],
                  let tableOffset = UInt32(exactly: offset),
                  let tableLength = UInt32(exactly: table.count) else {
                return nil
            }
            result.appendUInt32BE(tag)
            result.appendUInt32BE(checksum(table))
            result.appendUInt32BE(tableOffset)
            result.appendUInt32BE(tableLength)
            offset += (table.count + 3) & ~3
        }
        for tag in tags {
            guard let table = tables[tag] else { return nil }
            result.append(table)
            while !result.count.isMultiple(of: 4) { result.append(0) }
        }
        guard let headIndex = tags.firstIndex(of: FontTableTag.head) else { return nil }
        let headOffset = 12 + count * 16 + tags[..<headIndex].reduce(0) {
            $0 + (((tables[$1]?.count ?? 0) + 3) & ~3)
        }
        let adjustment = 0xB1B0_AFBA &- checksum(result)
        result.replaceUInt32BE(at: headOffset + 8, with: adjustment)
        return result
    }

    private static func checksum(_ data: Data) -> UInt32 {
        var sum: UInt32 = 0
        var offset = 0
        while offset < data.count {
            var word: UInt32 = 0
            for byte in 0..<4 where offset + byte < data.count {
                word |= UInt32(data[offset + byte]) << UInt32(24 - byte * 8)
            }
            sum &+= word
            offset += 4
        }
        return sum
    }

    private static func encrypt(_ data: Data, seed: UInt16) -> Data {
        var key = seed
        var result = Data()
        result.reserveCapacity(data.count)
        for byte in data {
            let cipher = byte ^ UInt8(key >> 8)
            result.append(cipher)
            key = UInt16(truncatingIfNeeded: (UInt32(cipher) + UInt32(key)) * 52_845 + 22_719)
        }
        return result
    }

    private static func postScriptName(_ value: String) -> String {
        let delimiters = Set("()<>[]{}/%".utf8)
        let bytes = value.utf8.map { byte -> UInt8 in
            guard byte >= 33, byte <= 126, !delimiters.contains(byte) else { return 95 }
            return byte
        }
        let name = String(bytes: bytes.prefix(127), encoding: .ascii) ?? "SubsetFont"
        return name.isEmpty ? "SubsetFont" : name
    }

    private static func postScriptString(_ value: String) -> String {
        value.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "(", with: "\\(")
            .replacingOccurrences(of: ")", with: "\\)")
    }

    private static func number(_ value: CGFloat) -> String {
        guard value.isFinite else { return "0" }
        if value.rounded() == value { return String(Int(value)) }
        return String(format: "%.10g", Double(value))
    }

    private static func integerPoint(_ point: CGPoint) -> CGPoint {
        CGPoint(x: point.x.rounded(), y: point.y.rounded())
    }

    private static func integerBounds(_ rect: CGRect) -> (minX: Int, minY: Int, maxX: Int, maxY: Int) {
        guard !rect.isNull, !rect.isInfinite else { return (0, 0, 0, 0) }
        return (
            Int(floor(rect.minX)), Int(floor(rect.minY)),
            Int(ceil(rect.maxX)), Int(ceil(rect.maxY))
        )
    }

    private static func hex(_ data: Data) -> String {
        let digits = Array("0123456789abcdef".utf8)
        var bytes: [UInt8] = []
        bytes.reserveCapacity(data.count * 2)
        for byte in data {
            bytes.append(digits[Int(byte >> 4)])
            bytes.append(digits[Int(byte & 0x0F)])
        }
        return String(decoding: bytes, as: UTF8.self)
    }

    private static func wrappedHex(_ data: Data) -> String {
        let value = hex(data)
        var result = ""
        var index = value.startIndex
        while index < value.endIndex {
            let end = value.index(index, offsetBy: 64, limitedBy: value.endIndex) ?? value.endIndex
            result += value[index..<end]
            result += "\n"
            index = end
        }
        return result
    }
}

private extension Data {
    mutating func appendASCII(_ value: String) {
        append(contentsOf: value.utf8)
    }

    mutating func appendUInt16BE(_ value: UInt16) {
        append(UInt8(value >> 8))
        append(UInt8(value & 0xFF))
    }

    mutating func appendInt16BE(_ value: Int16) {
        appendUInt16BE(UInt16(bitPattern: value))
    }

    mutating func appendUInt32BE(_ value: UInt32) {
        append(UInt8(value >> 24))
        append(UInt8((value >> 16) & 0xFF))
        append(UInt8((value >> 8) & 0xFF))
        append(UInt8(value & 0xFF))
    }

    mutating func replaceUInt16BE(at offset: Int, with value: UInt16) {
        self[offset] = UInt8(value >> 8)
        self[offset + 1] = UInt8(value & 0xFF)
    }

    mutating func replaceInt16BE(at offset: Int, with value: Int16) {
        replaceUInt16BE(at: offset, with: UInt16(bitPattern: value))
    }

    mutating func replaceUInt32BE(at offset: Int, with value: UInt32) {
        self[offset] = UInt8(value >> 24)
        self[offset + 1] = UInt8((value >> 16) & 0xFF)
        self[offset + 2] = UInt8((value >> 8) & 0xFF)
        self[offset + 3] = UInt8(value & 0xFF)
    }
}
