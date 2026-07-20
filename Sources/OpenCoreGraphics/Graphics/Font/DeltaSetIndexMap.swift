//
//  DeltaSetIndexMap.swift
//  OpenCoreGraphics
//

import Foundation

/// Packed mapping from a glyph or item index to an ItemVariationStore delta-set index.
internal struct DeltaSetIndexMap: Sendable {
    private let entries: [(outer: Int, inner: Int)]

    init?(data: Data, offset: Int, length: Int? = nil, requiredFormat: UInt8? = nil) {
        let availableLength = length ?? (data.count - offset)
        guard offset >= 0, availableLength >= 4,
              offset <= data.count, availableLength <= data.count - offset else {
            return nil
        }
        let end = offset + availableLength
        let format = data.readUInt8(at: offset)
        guard format == 0 || format == 1, requiredFormat == nil || format == requiredFormat else {
            return nil
        }
        let entryFormat = data.readUInt8(at: offset + 1)
        guard entryFormat & 0xC0 == 0 else { return nil }
        let entrySize = Int((entryFormat & 0x30) >> 4) + 1
        let innerBitCount = Int(entryFormat & 0x0F) + 1
        let headerSize = format == 0 ? 4 : 6
        guard innerBitCount <= entrySize * 8, offset <= end - headerSize else { return nil }
        let mapCount = format == 0
            ? Int(data.readUInt16BE(at: offset + 2))
            : Int(data.readUInt32BE(at: offset + 2))
        guard mapCount > 0, mapCount <= (end - offset - headerSize) / entrySize else {
            return nil
        }

        let innerMask = (UInt32(1) << UInt32(innerBitCount)) - 1
        var parsedEntries: [(outer: Int, inner: Int)] = []
        parsedEntries.reserveCapacity(mapCount)
        var cursor = offset + headerSize
        for _ in 0..<mapCount {
            var packed: UInt32 = 0
            for _ in 0..<entrySize {
                packed = (packed << 8) | UInt32(data.readUInt8(at: cursor))
                cursor += 1
            }
            let outer = Int(packed >> UInt32(innerBitCount))
            let inner = Int(packed & innerMask)
            guard outer <= 0xFFFF, inner <= 0xFFFF else { return nil }
            parsedEntries.append((outer: outer, inner: inner))
        }
        self.entries = parsedEntries
    }

    var count: Int { entries.count }

    func indices(for itemIndex: Int) -> (outer: Int, inner: Int)? {
        guard itemIndex >= 0, !entries.isEmpty else { return nil }
        return entries[min(itemIndex, entries.count - 1)]
    }

    func allIndicesSatisfy(_ predicate: (Int, Int) -> Bool) -> Bool {
        entries.allSatisfy { predicate($0.outer, $0.inner) }
    }
}
