//
//  Type1FontProgram.swift
//  OpenCoreGraphics
//
//  Adobe Type 1 PFA/PFB font parsing.
//

import Foundation

internal struct Type1FontProgram: Sendable {
    struct Glyph: Sendable {
        let name: String
        let charString: Data
    }

    let fullName: String?
    let postScriptName: String?
    let fontBBox: CGRect
    let metricsBBox: CGRect
    let italicAngle: CGFloat
    let unitsPerEm: Int
    let glyphs: [Glyph]
    let subroutines: [Data?]
    let lenIV: Int

    private let glyphIndicesByName: [String: Int]
    private let designTransform: CGAffineTransform
    private let blueValues: [CGFloat]

    var capHeight: CGFloat? {
        glyphHeight(named: "H")
    }

    var xHeight: CGFloat? {
        glyphHeight(named: "x")
    }

    init?(data: Data) {
        guard let sections = Self.sections(from: data),
              let metadata = Self.metadata(from: sections.cleartext),
              let decrypted = Self.decrypt(sections.ciphertext, seed: 55_665),
              decrypted.count >= 4,
              let privateProgram = Self.privateProgram(from: Data(decrypted.dropFirst(4))),
              !privateProgram.glyphs.isEmpty,
              privateProgram.glyphs.count <= Int(UInt16.max) else {
            return nil
        }

        let orderedGlyphs = Self.orderGlyphs(privateProgram.glyphs)
        var indices: [String: Int] = [:]
        indices.reserveCapacity(orderedGlyphs.count)
        for (index, glyph) in orderedGlyphs.enumerated() {
            guard indices[glyph.name] == nil else { return nil }
            indices[glyph.name] = index
        }

        let scale = Self.designScale(for: metadata.fontMatrix)
        self.fullName = metadata.fullName
        self.postScriptName = metadata.postScriptName
        self.italicAngle = metadata.italicAngle
        self.unitsPerEm = scale.unitsPerEm
        self.designTransform = scale.transform
        let metricsBBox = Self.transformedBounds(metadata.fontBBox, by: scale.transform)
        let paddedSourceBBox = CGRect(
            x: metadata.fontBBox.minX - 31,
            y: metadata.fontBBox.minY - 31,
            width: metadata.fontBBox.width + 62,
            height: metadata.fontBBox.height + 62
        )
        let paddedBBox = Self.transformedBounds(paddedSourceBBox, by: scale.transform)
        self.fontBBox = CGRect(
            x: floor(paddedBBox.minX),
            y: floor(paddedBBox.minY),
            width: ceil(paddedBBox.maxX) - floor(paddedBBox.minX),
            height: ceil(paddedBBox.maxY) - floor(paddedBBox.minY)
        )
        self.metricsBBox = metricsBBox
        self.glyphs = orderedGlyphs
        self.glyphIndicesByName = indices
        self.subroutines = privateProgram.subroutines
        self.lenIV = privateProgram.lenIV
        self.blueValues = privateProgram.blueValues
    }

    func glyphIndex(named name: String) -> Int? {
        glyphIndicesByName[name]
    }

    func glyphName(at index: Int) -> String? {
        guard glyphs.indices.contains(index) else { return nil }
        return glyphs[index].name
    }

    func glyph(at index: Int) -> Type1Glyph? {
        guard let glyph = rawGlyph(at: index) else { return nil }
        let transformedPath = CGMutablePath()
        transformedPath.addPath(glyph.path, transform: designTransform)
        return Type1Glyph(
            path: transformedPath.copy() ?? transformedPath,
            sideBearing: glyph.sideBearing.applying(designTransform),
            advance: CGSize(
                width: glyph.advance.width * designTransform.a
                    + glyph.advance.height * designTransform.c,
                height: glyph.advance.width * designTransform.b
                    + glyph.advance.height * designTransform.d
            )
        )
    }

    func glyphBounds(at index: Int) -> CGRect? {
        guard let glyph = rawGlyph(at: index) else { return nil }
        if glyph.path.isEmpty { return .zero }
        let bounds = glyph.path.boundingBox
        let integralBounds = CGRect(
            x: floor(bounds.minX),
            y: floor(bounds.minY),
            width: ceil(bounds.maxX) - floor(bounds.minX),
            height: ceil(bounds.maxY) - floor(bounds.minY)
        )
        let transformed = Self.transformedBounds(integralBounds, by: designTransform)
        return CGRect(
            x: floor(transformed.minX),
            y: floor(transformed.minY),
            width: ceil(transformed.maxX) - floor(transformed.minX),
            height: ceil(transformed.maxY) - floor(transformed.minY)
        )
    }

    private func rawGlyph(at index: Int) -> Type1Glyph? {
        guard glyphs.indices.contains(index) else { return nil }
        return Type1CharStringInterpreter(program: self, glyphIndex: index).parse()
    }

    private func glyphHeight(named name: String) -> CGFloat? {
        guard let index = glyphIndex(named: name), let path = glyph(at: index)?.path,
              !path.isEmpty else { return nil }
        let outlineHeight = path.boundingBox.maxY
        let topZones = stride(from: 2, to: blueValues.count - 1, by: 2).map { index in
            let midpoint = (blueValues[index] + blueValues[index + 1]) / 2
            return CGPoint(x: 0, y: midpoint).applying(designTransform).y
        }
        return topZones.min(by: {
            abs($0 - outlineHeight) < abs($1 - outlineHeight)
        }) ?? outlineHeight
    }

    func decryptedCharString(at index: Int) -> Data? {
        guard glyphs.indices.contains(index) else { return nil }
        return Self.decryptCharString(glyphs[index].charString, lenIV: lenIV)
    }

    func decryptedSubroutine(at index: Int) -> Data? {
        guard subroutines.indices.contains(index), let data = subroutines[index] else { return nil }
        return Self.decryptCharString(data, lenIV: lenIV)
    }

    private struct Sections {
        let cleartext: Data
        let ciphertext: Data
    }

    private struct Metadata {
        let fullName: String?
        let postScriptName: String?
        let fontBBox: CGRect
        let fontMatrix: [CGFloat]
        let italicAngle: CGFloat
    }

    private struct PrivateProgram {
        let glyphs: [Glyph]
        let subroutines: [Data?]
        let lenIV: Int
        let blueValues: [CGFloat]
    }

    private struct DesignScale {
        let unitsPerEm: Int
        let transform: CGAffineTransform
    }

    private static func sections(from data: Data) -> Sections? {
        if data.count >= 2, data.readUInt8(at: 0) == 0x80 {
            return pfbSections(from: data)
        }
        return pfaSections(from: data)
    }

    private static func pfbSections(from data: Data) -> Sections? {
        var cleartext = Data()
        var ciphertext = Data()
        var offset = 0
        var sawASCII = false
        var sawBinary = false
        var sawEnd = false
        while offset < data.count {
            guard offset <= data.count - 2, data.readUInt8(at: offset) == 0x80 else { return nil }
            let kind = data.readUInt8(at: offset + 1)
            offset += 2
            if kind == 3 {
                guard offset == data.count else { return nil }
                sawEnd = true
                break
            }
            guard kind == 1 || kind == 2, offset <= data.count - 4 else { return nil }
            let length = Int(data.readUInt8(at: offset))
                | Int(data.readUInt8(at: offset + 1)) << 8
                | Int(data.readUInt8(at: offset + 2)) << 16
                | Int(data.readUInt8(at: offset + 3)) << 24
            offset += 4
            guard length >= 0, length <= data.count - offset else { return nil }
            guard let segment = data.slice(from: offset, length: length) else { return nil }
            if kind == 1 {
                if !sawBinary { cleartext.append(segment) }
                sawASCII = true
            } else {
                ciphertext.append(segment)
                sawBinary = true
            }
            offset += length
        }
        guard sawASCII, sawBinary, sawEnd,
              Self.containsEexec(cleartext) else { return nil }
        return Sections(cleartext: cleartext, ciphertext: ciphertext)
    }

    private static func pfaSections(from data: Data) -> Sections? {
        guard let encryptedStart = eexecEnd(in: data) else { return nil }
        guard let cleartext = data.slice(from: 0, length: encryptedStart) else { return nil }
        var cursor = encryptedStart
        while cursor < data.count, Self.isWhitespace(data.readUInt8(at: cursor)) { cursor += 1 }
        guard cursor < data.count else { return nil }

        let remaining = data.count - cursor
        let sampleCount = min(8, remaining)
        let isHex = sampleCount >= 4 && (0..<sampleCount).allSatisfy {
            Self.hexNibble(data.readUInt8(at: cursor + $0)) != nil
        }
        if !isHex {
            guard let ciphertext = data.slice(from: cursor, length: remaining) else { return nil }
            return Sections(cleartext: cleartext, ciphertext: ciphertext)
        }

        var ciphertext = Data()
        var token: [UInt8] = []
        var reachedPadding = false
        while cursor < data.count, !reachedPadding {
            let byte = data.readUInt8(at: cursor)
            cursor += 1
            if isWhitespace(byte) {
                guard appendHexToken(token, to: &ciphertext, reachedPadding: &reachedPadding) else {
                    return nil
                }
                token.removeAll(keepingCapacity: true)
            } else if hexNibble(byte) != nil {
                token.append(byte)
            } else {
                break
            }
        }
        if !token.isEmpty,
           !appendHexToken(token, to: &ciphertext, reachedPadding: &reachedPadding) {
            return nil
        }
        guard !ciphertext.isEmpty else { return nil }
        return Sections(cleartext: cleartext, ciphertext: ciphertext)
    }

    private static func appendHexToken(
        _ token: [UInt8],
        to ciphertext: inout Data,
        reachedPadding: inout Bool
    ) -> Bool {
        guard !token.isEmpty else { return true }
        if token.count >= 32, token.allSatisfy({ $0 == 48 }) {
            reachedPadding = true
            return true
        }
        guard token.count.isMultiple(of: 2) else { return false }
        for index in stride(from: 0, to: token.count, by: 2) {
            guard let high = hexNibble(token[index]), let low = hexNibble(token[index + 1]) else {
                return false
            }
            ciphertext.append(high << 4 | low)
        }
        return true
    }

    private static func containsEexec(_ data: Data) -> Bool {
        eexecEnd(in: data) != nil
    }

    private static func eexecEnd(in data: Data) -> Int? {
        var scanner = PostScriptTokenScanner(data: data)
        while let token = scanner.next() {
            if token == "eexec" { return scanner.offset }
        }
        return nil
    }

    private static func metadata(from data: Data) -> Metadata? {
        var scanner = PostScriptTokenScanner(data: data)
        var fullName: String?
        var postScriptName: String?
        var fontBBox: [CGFloat]?
        var fontMatrix: [CGFloat]?
        var italicAngle: CGFloat = 0

        while let token = scanner.next() {
            switch token {
            case "/FullName":
                fullName = scanner.next().flatMap(Self.literalString)
            case "/FontName":
                postScriptName = scanner.next().flatMap(Self.nameString)
            case "/ItalicAngle":
                if let value = scanner.next().flatMap(Self.number) { italicAngle = value }
            case "/FontMatrix":
                fontMatrix = Self.numberSequence(scanner: &scanner, count: 6)
            case "/FontBBox":
                fontBBox = Self.numberSequence(scanner: &scanner, count: 4)
            default:
                continue
            }
        }
        guard let matrix = fontMatrix, matrix.count == 6,
              matrix.allSatisfy(\.isFinite),
              matrix[0] * matrix[3] - matrix[1] * matrix[2] != 0,
              let bbox = fontBBox, bbox.count == 4,
              bbox.allSatisfy(\.isFinite),
              bbox[0] <= bbox[2], bbox[1] <= bbox[3] else {
            return nil
        }
        return Metadata(
            fullName: fullName,
            postScriptName: postScriptName,
            fontBBox: CGRect(
                x: bbox[0], y: bbox[1],
                width: bbox[2] - bbox[0], height: bbox[3] - bbox[1]
            ),
            fontMatrix: matrix,
            italicAngle: italicAngle
        )
    }

    private static func privateProgram(from data: Data) -> PrivateProgram? {
        var scanner = PostScriptTokenScanner(data: data)
        var lenIV = 4
        var blueValues: [CGFloat] = []
        var subroutines: [Data?] = []
        var glyphs: [Glyph] = []

        while let token = scanner.next() {
            if token == "/lenIV" {
                guard let token = scanner.next(), let value = integer(token), value >= -1, value <= 255 else {
                    return nil
                }
                lenIV = value
                continue
            }
            if token == "/BlueValues" {
                guard let values = numberArray(scanner: &scanner),
                      values.count.isMultiple(of: 2), values.count <= 14 else { return nil }
                blueValues = values
                continue
            }
            if token == "/Subrs" {
                guard let countToken = scanner.next(), let count = integer(countToken),
                      count >= 0, count <= 65_535 else { return nil }
                subroutines = Array(repeating: nil, count: count)
                guard parseSubroutines(scanner: &scanner, subroutines: &subroutines) else { return nil }
                continue
            }
            if token == "/CharStrings" {
                guard let countToken = scanner.next(), let count = integer(countToken),
                      count > 0, count <= 65_535,
                      let parsed = parseCharStrings(scanner: &scanner, expectedCount: count) else {
                    return nil
                }
                glyphs = parsed
                break
            }
        }
        guard !glyphs.isEmpty else { return nil }
        return PrivateProgram(
            glyphs: glyphs,
            subroutines: subroutines,
            lenIV: lenIV,
            blueValues: blueValues
        )
    }

    private static func parseSubroutines(
        scanner: inout PostScriptTokenScanner,
        subroutines: inout [Data?]
    ) -> Bool {
        while let token = scanner.next() {
            if token == "/CharStrings" {
                scanner.rewindToStartOfLastToken()
                return true
            }
            guard token == "dup" else { continue }
            guard let indexToken = scanner.next(), let index = integer(indexToken),
                  let lengthToken = scanner.next(), let length = integer(lengthToken),
                  subroutines.indices.contains(index), length >= 0,
                  scanner.next() != nil,
                  let bytes = scanner.readBinary(length: length) else {
                return false
            }
            subroutines[index] = bytes
        }
        return false
    }

    private static func parseCharStrings(
        scanner: inout PostScriptTokenScanner,
        expectedCount: Int
    ) -> [Glyph]? {
        while let token = scanner.next(), token != "begin" {}
        var glyphs: [Glyph] = []
        glyphs.reserveCapacity(expectedCount)
        while glyphs.count < expectedCount, let token = scanner.next() {
            guard token.hasPrefix("/"), token.count > 1 else { continue }
            guard let lengthToken = scanner.next(), let length = integer(lengthToken), length >= 0,
                  scanner.next() != nil,
                  let bytes = scanner.readBinary(length: length) else {
                return nil
            }
            let name = decodeName(String(token.dropFirst()))
            guard !name.isEmpty else { return nil }
            glyphs.append(Glyph(name: name, charString: bytes))
        }
        return glyphs.count == expectedCount ? glyphs : nil
    }

    private static func orderGlyphs(_ glyphs: [Glyph]) -> [Glyph] {
        guard let notdef = glyphs.firstIndex(where: { $0.name == ".notdef" }), notdef != 0 else {
            return glyphs
        }
        var result = glyphs
        let glyph = result.remove(at: notdef)
        result.insert(glyph, at: 0)
        return result
    }

    private static func decryptCharString(_ data: Data, lenIV: Int) -> Data? {
        if lenIV == -1 { return data }
        guard lenIV >= 0, let decrypted = decrypt(data, seed: 4_330), decrypted.count >= lenIV else {
            return nil
        }
        return Data(decrypted.dropFirst(lenIV))
    }

    private static func decrypt(_ data: Data, seed: UInt16) -> Data? {
        guard !data.isEmpty else { return Data() }
        var state = seed
        var result = Data()
        result.reserveCapacity(data.count)
        for byte in data {
            let plain = byte ^ UInt8(state >> 8)
            result.append(plain)
            state = UInt16(truncatingIfNeeded: (UInt32(byte) + UInt32(state)) * 52_845 + 22_719)
        }
        return result
    }

    private static func designScale(for matrix: [CGFloat]) -> DesignScale {
        let units = 1_000
        let value = CGFloat(units)
        return DesignScale(
            unitsPerEm: units,
            transform: CGAffineTransform(
                a: matrix[0] * value,
                b: matrix[1] * value,
                c: matrix[2] * value,
                d: matrix[3] * value,
                tx: matrix[4] * value,
                ty: matrix[5] * value
            )
        )
    }

    private static func transformedBounds(_ rect: CGRect, by transform: CGAffineTransform) -> CGRect {
        let points = [
            CGPoint(x: rect.minX, y: rect.minY).applying(transform),
            CGPoint(x: rect.maxX, y: rect.minY).applying(transform),
            CGPoint(x: rect.minX, y: rect.maxY).applying(transform),
            CGPoint(x: rect.maxX, y: rect.maxY).applying(transform),
        ]
        let xs = points.map(\.x)
        let ys = points.map(\.y)
        return CGRect(
            x: xs.min() ?? 0,
            y: ys.min() ?? 0,
            width: (xs.max() ?? 0) - (xs.min() ?? 0),
            height: (ys.max() ?? 0) - (ys.min() ?? 0)
        )
    }

    private static func numberSequence(
        scanner: inout PostScriptTokenScanner,
        count: Int
    ) -> [CGFloat]? {
        guard let opening = scanner.next(), opening == "[" || opening == "{" else { return nil }
        var values: [CGFloat] = []
        values.reserveCapacity(count)
        while values.count < count, let token = scanner.next() {
            guard let value = number(token) else { return nil }
            values.append(value)
        }
        guard values.count == count, let closing = scanner.next(),
              closing == (opening == "[" ? "]" : "}") else { return nil }
        return values
    }

    private static func numberArray(scanner: inout PostScriptTokenScanner) -> [CGFloat]? {
        guard let opening = scanner.next(), opening == "[" else { return nil }
        var values: [CGFloat] = []
        while let token = scanner.next() {
            if token == "]" { return values }
            guard values.count < 64, let value = number(token) else { return nil }
            values.append(value)
        }
        return nil
    }

    private static func number(_ token: String) -> CGFloat? {
        guard let value = Double(token), value.isFinite else { return nil }
        return CGFloat(value)
    }

    private static func integer(_ token: String) -> Int? {
        guard let value = Int(token) else { return nil }
        return value
    }

    private static func literalString(_ token: String) -> String? {
        guard token.first == "(", token.last == ")" else { return nil }
        return String(token.dropFirst().dropLast())
    }

    private static func nameString(_ token: String) -> String? {
        guard token.first == "/" else { return nil }
        return decodeName(String(token.dropFirst()))
    }

    private static func decodeName(_ source: String) -> String {
        let bytes = Array(source.utf8)
        var result: [UInt8] = []
        var index = 0
        while index < bytes.count {
            if bytes[index] == 35, index + 2 < bytes.count,
               let high = hexNibble(bytes[index + 1]), let low = hexNibble(bytes[index + 2]) {
                result.append(high << 4 | low)
                index += 3
            } else {
                result.append(bytes[index])
                index += 1
            }
        }
        return String(bytes: result, encoding: .isoLatin1) ?? source
    }

    private static func isWhitespace(_ byte: UInt8) -> Bool {
        byte == 0 || byte == 9 || byte == 10 || byte == 12 || byte == 13 || byte == 32
    }

    private static func hexNibble(_ byte: UInt8) -> UInt8? {
        switch byte {
        case 48...57: return byte - 48
        case 65...70: return byte - 65 + 10
        case 97...102: return byte - 97 + 10
        default: return nil
        }
    }
}

internal struct Type1Glyph: Sendable {
    let path: CGPath
    let sideBearing: CGPoint
    let advance: CGSize
}

private struct PostScriptTokenScanner {
    private let data: Data
    private(set) var offset: Int = 0
    private var lastTokenStart: Int = 0

    init(data: Data) {
        self.data = data
    }

    mutating func next() -> String? {
        skipWhitespaceAndComments()
        guard offset < data.count else { return nil }
        lastTokenStart = offset
        let byte = data.readUInt8(at: offset)
        if byte == 40 { return literalString() }
        if Self.isDelimiter(byte) {
            offset += 1
            if byte == 47 {
                let start = offset
                while offset < data.count,
                      !Self.isWhitespace(data.readUInt8(at: offset)),
                      !Self.isDelimiter(data.readUInt8(at: offset)) {
                    offset += 1
                }
                return "/" + Self.string(data, range: start..<offset)
            }
            return String(UnicodeScalar(byte))
        }
        let start = offset
        while offset < data.count,
              !Self.isWhitespace(data.readUInt8(at: offset)),
              !Self.isDelimiter(data.readUInt8(at: offset)) {
            offset += 1
        }
        return Self.string(data, range: start..<offset)
    }

    mutating func readBinary(length: Int) -> Data? {
        guard length >= 0, offset < data.count, Self.isWhitespace(data.readUInt8(at: offset)) else {
            return nil
        }
        if data.readUInt8(at: offset) == 13, offset + 1 < data.count,
           data.readUInt8(at: offset + 1) == 10 {
            offset += 2
        } else {
            offset += 1
        }
        guard length <= data.count - offset,
              let bytes = data.slice(from: offset, length: length) else { return nil }
        offset += length
        return bytes
    }

    mutating func rewindToStartOfLastToken() {
        offset = lastTokenStart
    }

    private mutating func skipWhitespaceAndComments() {
        while offset < data.count {
            let byte = data.readUInt8(at: offset)
            if Self.isWhitespace(byte) {
                offset += 1
            } else if byte == 37 {
                while offset < data.count {
                    let value = data.readUInt8(at: offset)
                    offset += 1
                    if value == 10 || value == 13 { break }
                }
            } else {
                break
            }
        }
    }

    private mutating func literalString() -> String? {
        let start = offset
        var depth = 0
        var escaped = false
        while offset < data.count {
            let byte = data.readUInt8(at: offset)
            offset += 1
            if escaped {
                escaped = false
            } else if byte == 92 {
                escaped = true
            } else if byte == 40 {
                depth += 1
            } else if byte == 41 {
                depth -= 1
                if depth == 0 { return Self.string(data, range: start..<offset) }
            }
        }
        return nil
    }

    private static func string(_ data: Data, range: Range<Int>) -> String {
        guard let bytes = data.slice(from: range.lowerBound, length: range.count) else { return "" }
        return String(data: bytes, encoding: .isoLatin1) ?? ""
    }

    private static func isWhitespace(_ byte: UInt8) -> Bool {
        byte == 0 || byte == 9 || byte == 10 || byte == 12 || byte == 13 || byte == 32
    }

    private static func isDelimiter(_ byte: UInt8) -> Bool {
        byte == 40 || byte == 41 || byte == 60 || byte == 62 || byte == 91 || byte == 93
            || byte == 123 || byte == 125 || byte == 47 || byte == 37
    }
}
