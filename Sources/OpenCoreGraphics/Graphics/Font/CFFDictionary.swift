//
//  CFFDictionary.swift
//  OpenCoreGraphics
//

import Foundation

internal enum CFFDictionary {
    static func parse(data: Data, range: Range<Int>) -> [UInt16: [CGFloat]]? {
        guard range.lowerBound >= 0, range.upperBound <= data.count else { return nil }
        var result: [UInt16: [CGFloat]] = [:]
        var operands: [CGFloat] = []
        var cursor = range.lowerBound

        while cursor < range.upperBound {
            let byte = data.readUInt8(at: cursor)
            if byte >= 28 {
                guard operands.count < 48,
                      let number = decodeNumber(data: data, cursor: &cursor, end: range.upperBound) else {
                    return nil
                }
                operands.append(number)
                continue
            }

            cursor += 1
            let key: UInt16
            if byte == 12 {
                guard cursor < range.upperBound else { return nil }
                key = 0x0C00 | UInt16(data.readUInt8(at: cursor))
                cursor += 1
            } else {
                key = UInt16(byte)
            }
            guard result[key] == nil else { return nil }
            result[key] = operands
            operands.removeAll(keepingCapacity: true)
        }
        return operands.isEmpty ? result : nil
    }

    static func integers(_ dictionary: [UInt16: [CGFloat]], key: UInt16, count: Int) -> [Int]? {
        guard let values = dictionary[key], values.count == count else { return nil }
        var integers: [Int] = []
        integers.reserveCapacity(count)
        for value in values {
            guard value.isFinite, value.rounded(.towardZero) == value,
                  value >= CGFloat(Int.min), value <= CGFloat(Int.max) else {
                return nil
            }
            integers.append(Int(value))
        }
        return integers
    }

    static func decodeNumber(data: Data, cursor: inout Int, end: Int) -> CGFloat? {
        guard cursor < end else { return nil }
        let byte = data.readUInt8(at: cursor)
        cursor += 1
        switch byte {
        case 28:
            guard cursor <= end - 2 else { return nil }
            let value = data.readInt16BE(at: cursor)
            cursor += 2
            return CGFloat(value)
        case 29:
            guard cursor <= end - 4 else { return nil }
            let value = data.readInt32BE(at: cursor)
            cursor += 4
            return CGFloat(value)
        case 30:
            var text = ""
            var terminated = false
            while cursor < end, !terminated {
                let packed = data.readUInt8(at: cursor)
                cursor += 1
                for nibble in [packed >> 4, packed & 0x0F] {
                    switch nibble {
                    case 0...9: text.append(String(nibble))
                    case 0xA: text.append(".")
                    case 0xB: text.append("E")
                    case 0xC: text.append(contentsOf: "E-")
                    case 0xE: text.append("-")
                    case 0xF: terminated = true
                    default: return nil
                    }
                    if terminated { break }
                }
            }
            guard terminated, let value = Double(text), value.isFinite else { return nil }
            return CGFloat(value)
        case 32...246:
            return CGFloat(Int(byte) - 139)
        case 247...250:
            guard cursor < end else { return nil }
            let next = Int(data.readUInt8(at: cursor))
            cursor += 1
            return CGFloat((Int(byte) - 247) * 256 + next + 108)
        case 251...254:
            guard cursor < end else { return nil }
            let next = Int(data.readUInt8(at: cursor))
            cursor += 1
            return CGFloat(-((Int(byte) - 251) * 256) - next - 108)
        default:
            return nil
        }
    }
}
