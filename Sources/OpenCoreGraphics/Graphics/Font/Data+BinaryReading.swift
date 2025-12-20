//
//  Data+BinaryReading.swift
//  OpenCoreGraphics
//
//  Binary reading utilities for font table parsing.
//  All font data uses Big Endian byte order.
//

import Foundation

extension Data {

    // MARK: - Unsigned Integers (Big Endian)

    /// Reads a UInt8 at the specified offset.
    func readUInt8(at offset: Int) -> UInt8 {
        guard offset >= 0 && offset < count else { return 0 }
        return self[offset]
    }

    /// Reads a UInt16 in Big Endian format at the specified offset.
    func readUInt16BE(at offset: Int) -> UInt16 {
        guard offset >= 0 && offset + 1 < count else { return 0 }
        return UInt16(self[offset]) << 8 | UInt16(self[offset + 1])
    }

    /// Reads a UInt32 in Big Endian format at the specified offset.
    func readUInt32BE(at offset: Int) -> UInt32 {
        guard offset >= 0 && offset + 3 < count else { return 0 }
        return UInt32(self[offset]) << 24 |
               UInt32(self[offset + 1]) << 16 |
               UInt32(self[offset + 2]) << 8 |
               UInt32(self[offset + 3])
    }

    /// Reads a UInt64 in Big Endian format at the specified offset.
    func readUInt64BE(at offset: Int) -> UInt64 {
        guard offset >= 0 && offset + 7 < count else { return 0 }
        return UInt64(self[offset]) << 56 |
               UInt64(self[offset + 1]) << 48 |
               UInt64(self[offset + 2]) << 40 |
               UInt64(self[offset + 3]) << 32 |
               UInt64(self[offset + 4]) << 24 |
               UInt64(self[offset + 5]) << 16 |
               UInt64(self[offset + 6]) << 8 |
               UInt64(self[offset + 7])
    }

    // MARK: - Signed Integers (Big Endian)

    /// Reads an Int8 at the specified offset.
    func readInt8(at offset: Int) -> Int8 {
        return Int8(bitPattern: readUInt8(at: offset))
    }

    /// Reads an Int16 in Big Endian format at the specified offset.
    func readInt16BE(at offset: Int) -> Int16 {
        return Int16(bitPattern: readUInt16BE(at: offset))
    }

    /// Reads an Int32 in Big Endian format at the specified offset.
    func readInt32BE(at offset: Int) -> Int32 {
        return Int32(bitPattern: readUInt32BE(at: offset))
    }

    /// Reads an Int64 in Big Endian format at the specified offset.
    func readInt64BE(at offset: Int) -> Int64 {
        return Int64(bitPattern: readUInt64BE(at: offset))
    }

    // MARK: - Fixed Point Numbers

    /// Reads a 16.16 Fixed point number as CGFloat.
    /// Used in many font tables for precise measurements.
    func readFixed(at offset: Int) -> CGFloat {
        let raw = readInt32BE(at: offset)
        return CGFloat(raw) / 65536.0
    }

    /// Reads a 2.14 Fixed point number as CGFloat.
    /// Used for F2Dot14 values in font tables.
    func readF2Dot14(at offset: Int) -> CGFloat {
        let raw = readInt16BE(at: offset)
        return CGFloat(raw) / 16384.0
    }

    // MARK: - Font-Specific Types

    /// Reads a 4-byte tag (e.g., 'head', 'hhea', 'glyf').
    func readTag(at offset: Int) -> UInt32 {
        return readUInt32BE(at: offset)
    }

    /// Reads a 4-byte tag and returns it as a String.
    func readTagString(at offset: Int) -> String {
        guard offset >= 0 && offset + 3 < count else { return "" }
        let bytes = [self[offset], self[offset + 1], self[offset + 2], self[offset + 3]]
        return String(bytes: bytes, encoding: .ascii) ?? ""
    }

    /// Reads a LONGDATETIME (64-bit signed integer representing seconds since 1904-01-01).
    func readLongDateTime(at offset: Int) -> Date {
        let seconds = readInt64BE(at: offset)
        // Mac epoch is January 1, 1904. Unix epoch is January 1, 1970.
        // Difference: 2082844800 seconds
        let unixSeconds = TimeInterval(seconds) - 2082844800
        return Date(timeIntervalSince1970: unixSeconds)
    }

    // MARK: - Offset/Size Types

    /// Reads an Offset16 (2-byte unsigned offset).
    func readOffset16(at offset: Int) -> Int {
        return Int(readUInt16BE(at: offset))
    }

    /// Reads an Offset32 (4-byte unsigned offset).
    func readOffset32(at offset: Int) -> Int {
        return Int(readUInt32BE(at: offset))
    }

    // MARK: - Array Reading

    /// Reads an array of UInt16 values.
    func readUInt16Array(at offset: Int, count: Int) -> [UInt16] {
        var result: [UInt16] = []
        result.reserveCapacity(count)
        for i in 0..<count {
            result.append(readUInt16BE(at: offset + i * 2))
        }
        return result
    }

    /// Reads an array of Int16 values.
    func readInt16Array(at offset: Int, count: Int) -> [Int16] {
        var result: [Int16] = []
        result.reserveCapacity(count)
        for i in 0..<count {
            result.append(readInt16BE(at: offset + i * 2))
        }
        return result
    }

    // MARK: - Subsetting

    /// Returns a slice of data starting at offset with the specified length.
    /// Note: Creates a new Data object with indices starting from 0 (not a slice with retained indices).
    func slice(from offset: Int, length: Int) -> Data? {
        guard offset >= 0 && offset + length <= count else { return nil }
        // Create new Data to reset indices to start from 0
        return Data(self[offset..<(offset + length)])
    }
}

// MARK: - Tag Constants

/// Common font table tags as UInt32 values.
enum FontTableTag {
    static let head: UInt32 = 0x68656164  // 'head'
    static let hhea: UInt32 = 0x68686561  // 'hhea'
    static let hmtx: UInt32 = 0x686D7478  // 'hmtx'
    static let maxp: UInt32 = 0x6D617870  // 'maxp'
    static let post: UInt32 = 0x706F7374  // 'post'
    static let name: UInt32 = 0x6E616D65  // 'name'
    static let OS2:  UInt32 = 0x4F532F32  // 'OS/2'
    static let cmap: UInt32 = 0x636D6170  // 'cmap'
    static let loca: UInt32 = 0x6C6F6361  // 'loca'
    static let glyf: UInt32 = 0x676C7966  // 'glyf'
    static let fvar: UInt32 = 0x66766172  // 'fvar'
    static let gvar: UInt32 = 0x67766172  // 'gvar'
    static let COLR: UInt32 = 0x434F4C52  // 'COLR'
    static let CPAL: UInt32 = 0x4350414C  // 'CPAL'

    /// Creates a tag from a 4-character string.
    static func fromString(_ string: String) -> UInt32 {
        guard string.count == 4 else { return 0 }
        let bytes = Array(string.utf8)
        return UInt32(bytes[0]) << 24 |
               UInt32(bytes[1]) << 16 |
               UInt32(bytes[2]) << 8 |
               UInt32(bytes[3])
    }

    /// Converts a tag to a 4-character string.
    static func toString(_ tag: UInt32) -> String {
        let bytes: [UInt8] = [
            UInt8((tag >> 24) & 0xFF),
            UInt8((tag >> 16) & 0xFF),
            UInt8((tag >> 8) & 0xFF),
            UInt8(tag & 0xFF)
        ]
        return String(bytes: bytes, encoding: .ascii) ?? ""
    }
}
