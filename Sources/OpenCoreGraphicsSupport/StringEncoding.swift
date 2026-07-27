#if hasFeature(Embedded)
public enum StringEncoding: Sendable {
    case ascii
    case utf8
    case utf16BigEndian
    case isoLatin1
    case macOSRoman
}

extension String {
    public init?<S: Sequence>(bytes: S, encoding: StringEncoding) where S.Element == UInt8 {
        guard let decoded = Self.decode(Array(bytes), using: encoding) else { return nil }
        self = decoded
    }

    public init?(data: Data, encoding: StringEncoding) {
        guard let decoded = Self.decode(Array(data), using: encoding) else { return nil }
        self = decoded
    }

    public func data(using encoding: StringEncoding) -> Data? {
        switch encoding {
        case .ascii:
            let bytes = Array(utf8)
            guard bytes.allSatisfy({ $0 < 0x80 }) else { return nil }
            return Data(bytes)
        case .utf8:
            return Data(utf8)
        case .isoLatin1, .macOSRoman, .utf16BigEndian:
            return nil
        }
    }

    public func contains(_ substring: String) -> Bool {
        let haystack = Array(self)
        let needle = Array(substring)
        guard !needle.isEmpty else { return true }
        guard needle.count <= haystack.count else { return false }
        for start in 0...(haystack.count - needle.count) {
            var matches = true
            for offset in needle.indices where haystack[start + offset] != needle[offset] {
                matches = false
                break
            }
            if matches { return true }
        }
        return false
    }

    public func replacingOccurrences(of target: String, with replacement: String) -> String {
        let source = Array(self)
        let pattern = Array(target)
        guard !pattern.isEmpty, pattern.count <= source.count else { return self }
        var result = ""
        var index = 0
        while index < source.count {
            if index <= source.count - pattern.count,
               source[index..<(index + pattern.count)].elementsEqual(pattern) {
                result += replacement
                index += pattern.count
            } else {
                result.append(source[index])
                index += 1
            }
        }
        return result
    }

    private static func decode(_ bytes: [UInt8], using encoding: StringEncoding) -> String? {
        switch encoding {
        case .ascii:
            guard bytes.allSatisfy({ $0 < 0x80 }) else { return nil }
            return String(decoding: bytes, as: UTF8.self)
        case .utf8:
            guard isValidUTF8(bytes) else { return nil }
            return String(decoding: bytes, as: UTF8.self)
        case .utf16BigEndian:
            return decodeUTF16BigEndian(bytes)
        case .isoLatin1:
            return string(from: bytes.map(UInt32.init))
        case .macOSRoman:
            return string(from: bytes.map { byte in
                byte < 0x80 ? UInt32(byte) : macRomanScalars[Int(byte - 0x80)]
            })
        }
    }

    private static func string(from scalarValues: [UInt32]) -> String? {
        var result = ""
        for value in scalarValues {
            guard let scalar = Unicode.Scalar(value) else { return nil }
            result.unicodeScalars.append(scalar)
        }
        return result
    }

    private static func decodeUTF16BigEndian(_ bytes: [UInt8]) -> String? {
        guard bytes.count.isMultiple(of: 2) else { return nil }
        var result = ""
        var index = 0
        while index < bytes.count {
            let first = UInt16(bytes[index]) << 8 | UInt16(bytes[index + 1])
            index += 2
            let scalarValue: UInt32
            if (0xD800...0xDBFF).contains(first) {
                guard index < bytes.count else { return nil }
                let second = UInt16(bytes[index]) << 8 | UInt16(bytes[index + 1])
                guard (0xDC00...0xDFFF).contains(second) else { return nil }
                index += 2
                scalarValue = 0x10000
                    + (UInt32(first - 0xD800) << 10)
                    + UInt32(second - 0xDC00)
            } else {
                guard !(0xDC00...0xDFFF).contains(first) else { return nil }
                scalarValue = UInt32(first)
            }
            guard let scalar = Unicode.Scalar(scalarValue) else { return nil }
            result.unicodeScalars.append(scalar)
        }
        return result
    }

    private static func isValidUTF8(_ bytes: [UInt8]) -> Bool {
        var index = 0
        while index < bytes.count {
            let first = bytes[index]
            if first < 0x80 {
                index += 1
                continue
            }
            let continuationCount: Int
            let minimumScalar: UInt32
            var scalar: UInt32
            if first >= 0xC2 && first <= 0xDF {
                continuationCount = 1
                minimumScalar = 0x80
                scalar = UInt32(first & 0x1F)
            } else if first >= 0xE0 && first <= 0xEF {
                continuationCount = 2
                minimumScalar = 0x800
                scalar = UInt32(first & 0x0F)
            } else if first >= 0xF0 && first <= 0xF4 {
                continuationCount = 3
                minimumScalar = 0x10000
                scalar = UInt32(first & 0x07)
            } else {
                return false
            }
            guard index + continuationCount < bytes.count else { return false }
            for offset in 1...continuationCount {
                let continuation = bytes[index + offset]
                guard continuation & 0xC0 == 0x80 else { return false }
                scalar = (scalar << 6) | UInt32(continuation & 0x3F)
            }
            guard scalar >= minimumScalar,
                  scalar <= 0x10FFFF,
                  !(0xD800...0xDFFF).contains(scalar) else {
                return false
            }
            index += continuationCount + 1
        }
        return true
    }

    private static let macRomanScalars: [UInt32] = [
        0x00C4, 0x00C5, 0x00C7, 0x00C9, 0x00D1, 0x00D6, 0x00DC, 0x00E1,
        0x00E0, 0x00E2, 0x00E4, 0x00E3, 0x00E5, 0x00E7, 0x00E9, 0x00E8,
        0x00EA, 0x00EB, 0x00ED, 0x00EC, 0x00EE, 0x00EF, 0x00F1, 0x00F3,
        0x00F2, 0x00F4, 0x00F6, 0x00F5, 0x00FA, 0x00F9, 0x00FB, 0x00FC,
        0x2020, 0x00B0, 0x00A2, 0x00A3, 0x00A7, 0x2022, 0x00B6, 0x00DF,
        0x00AE, 0x00A9, 0x2122, 0x00B4, 0x00A8, 0x2260, 0x00C6, 0x00D8,
        0x221E, 0x00B1, 0x2264, 0x2265, 0x00A5, 0x00B5, 0x2202, 0x2211,
        0x220F, 0x03C0, 0x222B, 0x00AA, 0x00BA, 0x03A9, 0x00E6, 0x00F8,
        0x00BF, 0x00A1, 0x00AC, 0x221A, 0x0192, 0x2248, 0x2206, 0x00AB,
        0x00BB, 0x2026, 0x00A0, 0x00C0, 0x00C3, 0x00D5, 0x0152, 0x0153,
        0x2013, 0x2014, 0x201C, 0x201D, 0x2018, 0x2019, 0x00F7, 0x25CA,
        0x00FF, 0x0178, 0x2044, 0x20AC, 0x2039, 0x203A, 0xFB01, 0xFB02,
        0x2021, 0x00B7, 0x201A, 0x201E, 0x2030, 0x00C2, 0x00CA, 0x00C1,
        0x00CB, 0x00C8, 0x00CD, 0x00CE, 0x00CF, 0x00CC, 0x00D3, 0x00D4,
        0xF8FF, 0x00D2, 0x00DA, 0x00DB, 0x00D9, 0x0131, 0x02C6, 0x02DC,
        0x00AF, 0x02D8, 0x02D9, 0x02DA, 0x00B8, 0x02DD, 0x02DB, 0x02C7
    ]
}
#endif
