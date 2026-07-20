//
//  CFF2Index.swift
//  OpenCoreGraphics
//

import Foundation

internal struct CFF2Index: Sendable {
    let data: Data
    let ranges: [Range<Int>]
    let endOffset: Int

    init?(data: Data, offset: Int) {
        guard offset >= 0, offset <= data.count - 4 else { return nil }
        let countValue = data.readUInt32BE(at: offset)
        guard let count = Int(exactly: countValue) else { return nil }
        if count == 0 {
            self.data = data
            self.ranges = []
            self.endOffset = offset + 4
            return
        }

        guard offset + 5 <= data.count else { return nil }
        let offsetSize = Int(data.readUInt8(at: offset + 4))
        guard (1...4).contains(offsetSize),
              count <= (data.count - offset - 5) / offsetSize - 1 else {
            return nil
        }

        let offsetsStart = offset + 5
        var offsets: [Int] = []
        offsets.reserveCapacity(count + 1)
        for index in 0...count {
            guard let value = Self.readOffset(data, at: offsetsStart + index * offsetSize, size: offsetSize) else {
                return nil
            }
            offsets.append(value)
        }
        guard offsets.first == 1,
              zip(offsets, offsets.dropFirst()).allSatisfy({ $0 <= $1 }) else {
            return nil
        }

        let payloadStart = offsetsStart + (count + 1) * offsetSize
        guard let last = offsets.last, last >= 1, last - 1 <= data.count - payloadStart else { return nil }
        self.data = data
        self.ranges = (0..<count).map {
            (payloadStart + offsets[$0] - 1)..<(payloadStart + offsets[$0 + 1] - 1)
        }
        self.endOffset = payloadStart + last - 1
    }

    func range(at index: Int) -> Range<Int>? {
        guard ranges.indices.contains(index) else { return nil }
        return ranges[index]
    }

    private static func readOffset(_ data: Data, at offset: Int, size: Int) -> Int? {
        guard offset >= 0, (1...4).contains(size), offset <= data.count - size else { return nil }
        var value: UInt32 = 0
        for index in 0..<size {
            value = (value << 8) | UInt32(data.readUInt8(at: offset + index))
        }
        return Int(value)
    }
}
