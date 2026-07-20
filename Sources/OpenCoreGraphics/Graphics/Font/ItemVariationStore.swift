//
//  ItemVariationStore.swift
//  OpenCoreGraphics
//

import Foundation

/// Shared OpenType item variation store used by HVAR, VVAR, CFF2, and other variable tables.
internal struct ItemVariationStore: Sendable {
    private struct AxisRegion: Sendable {
        let start: CGFloat
        let peak: CGFloat
        let end: CGFloat

        func scalar(for coordinate: CGFloat) -> CGFloat {
            if peak == 0 { return 1 }
            if coordinate == peak { return 1 }
            if coordinate <= start || coordinate >= end { return 0 }
            if coordinate < peak { return (coordinate - start) / (peak - start) }
            return (end - coordinate) / (end - peak)
        }
    }

    private struct Region: Sendable {
        let axes: [AxisRegion]

        func scalar(for coordinates: [CGFloat]) -> CGFloat {
            var result: CGFloat = 1
            for index in axes.indices {
                result *= axes[index].scalar(for: coordinates[index])
                if result == 0 { return 0 }
            }
            return result
        }
    }

    private struct VariationData: Sendable {
        let itemCount: Int
        let wordDeltaCount: Int
        let usesLongWords: Bool
        let regionIndexes: [Int]
        let deltaSetsOffset: Int
        let rowByteCount: Int
    }

    private let data: Data
    private let axisCount: Int
    private let regions: [Region]
    private let variationData: [VariationData?]

    init?(data: Data, offset: Int, length: Int, axisCount: Int) {
        guard axisCount > 0, offset >= 0, length >= 8,
              offset <= data.count, length <= data.count - offset else {
            return nil
        }
        let storeEnd = offset + length
        guard data.readUInt16BE(at: offset) == 1 else { return nil }

        let regionListRelative = Int(data.readUInt32BE(at: offset + 2))
        let variationDataCount = Int(data.readUInt16BE(at: offset + 6))
        guard variationDataCount <= (storeEnd - offset - 8) / 4,
              regionListRelative >= 8 + variationDataCount * 4,
              regionListRelative <= storeEnd - offset - 4 else {
            return nil
        }

        var variationDataOffsets: [Int?] = []
        variationDataOffsets.reserveCapacity(variationDataCount)
        for index in 0..<variationDataCount {
            let relative = Int(data.readUInt32BE(at: offset + 8 + index * 4))
            if relative == 0 {
                variationDataOffsets.append(nil)
            } else {
                guard relative >= 8 + variationDataCount * 4,
                      relative <= storeEnd - offset - 6 else {
                    return nil
                }
                variationDataOffsets.append(offset + relative)
            }
        }

        let regionListStart = offset + regionListRelative
        let storedAxisCount = Int(data.readUInt16BE(at: regionListStart))
        let regionCount = Int(data.readUInt16BE(at: regionListStart + 2))
        guard storedAxisCount == axisCount, regionCount < 32_768,
              axisCount <= (storeEnd - regionListStart - 4) / 6,
              regionCount <= (storeEnd - regionListStart - 4) / (axisCount * 6) else {
            return nil
        }

        var parsedRegions: [Region] = []
        parsedRegions.reserveCapacity(regionCount)
        var regionCursor = regionListStart + 4
        for _ in 0..<regionCount {
            var axes: [AxisRegion] = []
            axes.reserveCapacity(axisCount)
            for _ in 0..<axisCount {
                let start = data.readF2Dot14(at: regionCursor)
                let peak = data.readF2Dot14(at: regionCursor + 2)
                let end = data.readF2Dot14(at: regionCursor + 4)
                guard start >= -1, end <= 1, start <= peak, peak <= end,
                      (start >= 0 && end >= 0)
                        || (start <= 0 && end <= 0)
                        || peak == 0 else {
                    return nil
                }
                axes.append(AxisRegion(start: start, peak: peak, end: end))
                regionCursor += 6
            }
            parsedRegions.append(Region(axes: axes))
        }

        var parsedVariationData: [VariationData?] = []
        parsedVariationData.reserveCapacity(variationDataCount)
        for variationOffset in variationDataOffsets {
            guard let variationOffset else {
                parsedVariationData.append(nil)
                continue
            }
            let itemCount = Int(data.readUInt16BE(at: variationOffset))
            let packedWordDeltaCount = data.readUInt16BE(at: variationOffset + 2)
            let usesLongWords = packedWordDeltaCount & 0x8000 != 0
            let wordDeltaCount = Int(packedWordDeltaCount & 0x7FFF)
            let regionIndexCount = Int(data.readUInt16BE(at: variationOffset + 4))
            guard wordDeltaCount <= regionIndexCount,
                  regionIndexCount <= (storeEnd - variationOffset - 6) / 2 else {
                return nil
            }

            var regionIndexes: [Int] = []
            regionIndexes.reserveCapacity(regionIndexCount)
            for index in 0..<regionIndexCount {
                let regionIndex = Int(data.readUInt16BE(at: variationOffset + 6 + index * 2))
                guard parsedRegions.indices.contains(regionIndex) else { return nil }
                regionIndexes.append(regionIndex)
            }

            let unitSize = usesLongWords ? 2 : 1
            let rowUnitCount = regionIndexCount + wordDeltaCount
            guard rowUnitCount <= Int.max / unitSize else { return nil }
            let rowByteCount = rowUnitCount * unitSize
            let deltaSetsOffset = variationOffset + 6 + regionIndexCount * 2
            guard itemCount == 0 || rowByteCount <= (storeEnd - deltaSetsOffset) / itemCount else {
                return nil
            }
            parsedVariationData.append(VariationData(
                itemCount: itemCount,
                wordDeltaCount: wordDeltaCount,
                usesLongWords: usesLongWords,
                regionIndexes: regionIndexes,
                deltaSetsOffset: deltaSetsOffset,
                rowByteCount: rowByteCount
            ))
        }

        self.data = data
        self.axisCount = axisCount
        self.regions = parsedRegions
        self.variationData = parsedVariationData
    }

    func containsDeltaSet(outerIndex: Int, innerIndex: Int) -> Bool {
        if outerIndex == 0xFFFF && innerIndex == 0xFFFF { return true }
        guard variationData.indices.contains(outerIndex) else { return false }
        guard let variationData = variationData[outerIndex] else { return true }
        return variationData.itemCount > innerIndex && innerIndex >= 0
    }

    func delta(outerIndex: Int, innerIndex: Int, coordinates: [CGFloat]) -> CGFloat? {
        guard let regionScalars = regionScalars(for: coordinates) else { return nil }
        return delta(
            outerIndex: outerIndex,
            innerIndex: innerIndex,
            regionScalars: regionScalars
        )
    }

    func regionScalars(for coordinates: [CGFloat]) -> [CGFloat]? {
        guard coordinates.count == axisCount else { return nil }
        return regions.map { $0.scalar(for: coordinates) }
    }

    func delta(
        outerIndex: Int,
        innerIndex: Int,
        regionScalars: [CGFloat]
    ) -> CGFloat? {
        guard regionScalars.count == regions.count else { return nil }
        if outerIndex == 0xFFFF && innerIndex == 0xFFFF { return 0 }
        guard variationData.indices.contains(outerIndex) else { return nil }
        guard let variationData = variationData[outerIndex] else { return 0 }
        guard variationData.itemCount > innerIndex, innerIndex >= 0 else { return nil }

        var cursor = variationData.deltaSetsOffset + innerIndex * variationData.rowByteCount
        var result: CGFloat = 0
        for column in variationData.regionIndexes.indices {
            let delta: Int32
            if variationData.usesLongWords {
                if column < variationData.wordDeltaCount {
                    delta = data.readInt32BE(at: cursor)
                    cursor += 4
                } else {
                    delta = Int32(data.readInt16BE(at: cursor))
                    cursor += 2
                }
            } else if column < variationData.wordDeltaCount {
                delta = Int32(data.readInt16BE(at: cursor))
                cursor += 2
            } else {
                delta = Int32(data.readInt8(at: cursor))
                cursor += 1
            }
            result += CGFloat(delta) * regionScalars[variationData.regionIndexes[column]]
        }
        return result
    }

    func scalars(for variationDataIndex: Int, coordinates: [CGFloat]) -> [CGFloat]? {
        guard coordinates.count == axisCount,
              variationData.indices.contains(variationDataIndex),
              let variationData = variationData[variationDataIndex] else {
            return nil
        }
        return variationData.regionIndexes.map { regions[$0].scalar(for: coordinates) }
    }

    func regionCount(for variationDataIndex: Int) -> Int? {
        guard variationData.indices.contains(variationDataIndex),
              let variationData = variationData[variationDataIndex] else {
            return nil
        }
        return variationData.regionIndexes.count
    }

    func isCFF2Compatible() -> Bool {
        variationData.allSatisfy {
            guard let variationData = $0 else { return false }
            return variationData.itemCount == 0
                && variationData.wordDeltaCount == 0
                && !variationData.usesLongWords
        }
    }
}
