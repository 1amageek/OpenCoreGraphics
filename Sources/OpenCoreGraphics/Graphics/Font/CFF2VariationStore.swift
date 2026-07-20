//
//  CFF2VariationStore.swift
//  OpenCoreGraphics
//

import Foundation

internal struct CFF2VariationStore: Sendable {
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
            for (axis, coordinate) in zip(axes, coordinates) {
                result *= axis.scalar(for: coordinate)
                if result == 0 { return 0 }
            }
            return result
        }
    }

    private let regions: [Region]
    private let regionIndexesByVariationData: [[Int]]

    init?(data: Data, offset: Int, axisCount: Int) {
        guard axisCount > 0, offset >= 0, offset <= data.count - 2 else { return nil }
        let itemStoreLength = Int(data.readUInt16BE(at: offset))
        let storeStart = offset + 2
        guard itemStoreLength >= 8, itemStoreLength <= data.count - storeStart,
              data.readUInt16BE(at: storeStart) == 1 else {
            return nil
        }
        let storeEnd = storeStart + itemStoreLength
        let regionListRelative = Int(data.readUInt32BE(at: storeStart + 2))
        let variationDataCount = Int(data.readUInt16BE(at: storeStart + 6))
        guard variationDataCount <= (storeEnd - storeStart - 8) / 4 else { return nil }

        var variationDataOffsets: [Int] = []
        variationDataOffsets.reserveCapacity(variationDataCount)
        for index in 0..<variationDataCount {
            let relative = Int(data.readUInt32BE(at: storeStart + 8 + index * 4))
            guard relative != 0, relative <= storeEnd - storeStart - 6 else { return nil }
            variationDataOffsets.append(storeStart + relative)
        }

        guard regionListRelative <= storeEnd - storeStart - 4 else { return nil }
        let regionListStart = storeStart + regionListRelative
        let storedAxisCount = Int(data.readUInt16BE(at: regionListStart))
        let regionCount = Int(data.readUInt16BE(at: regionListStart + 2))
        guard storedAxisCount == axisCount, regionCount < 32_768,
              axisCount <= (storeEnd - regionListStart - 4) / 6,
              regionCount <= (storeEnd - regionListStart - 4) / (axisCount * 6) else {
            return nil
        }

        var parsedRegions: [Region] = []
        parsedRegions.reserveCapacity(regionCount)
        var cursor = regionListStart + 4
        for _ in 0..<regionCount {
            var axes: [AxisRegion] = []
            axes.reserveCapacity(axisCount)
            for _ in 0..<axisCount {
                let start = CGFloat(data.readInt16BE(at: cursor)) / 16_384
                let peak = CGFloat(data.readInt16BE(at: cursor + 2)) / 16_384
                let end = CGFloat(data.readInt16BE(at: cursor + 4)) / 16_384
                guard start >= -1, end <= 1, start <= peak, peak <= end,
                      (start >= 0 && end >= 0) || (start <= 0 && end <= 0) || peak == 0 else {
                    return nil
                }
                axes.append(AxisRegion(start: start, peak: peak, end: end))
                cursor += 6
            }
            parsedRegions.append(Region(axes: axes))
        }

        var parsedIndexSets: [[Int]] = []
        parsedIndexSets.reserveCapacity(variationDataCount)
        for variationDataOffset in variationDataOffsets {
            guard variationDataOffset <= storeEnd - 6,
                  data.readUInt16BE(at: variationDataOffset) == 0,
                  data.readUInt16BE(at: variationDataOffset + 2) == 0 else {
                return nil
            }
            let indexCount = Int(data.readUInt16BE(at: variationDataOffset + 4))
            guard indexCount <= (storeEnd - variationDataOffset - 6) / 2 else { return nil }
            var indexes: [Int] = []
            indexes.reserveCapacity(indexCount)
            for index in 0..<indexCount {
                let regionIndex = Int(data.readUInt16BE(at: variationDataOffset + 6 + index * 2))
                guard parsedRegions.indices.contains(regionIndex) else { return nil }
                indexes.append(regionIndex)
            }
            parsedIndexSets.append(indexes)
        }

        self.regions = parsedRegions
        self.regionIndexesByVariationData = parsedIndexSets
    }

    func scalars(for variationDataIndex: Int, coordinates: [CGFloat]) -> [CGFloat]? {
        guard regionIndexesByVariationData.indices.contains(variationDataIndex),
              regions.first?.axes.count == coordinates.count else {
            return nil
        }
        return regionIndexesByVariationData[variationDataIndex].map {
            regions[$0].scalar(for: coordinates)
        }
    }

    func regionCount(for variationDataIndex: Int) -> Int? {
        guard regionIndexesByVariationData.indices.contains(variationDataIndex) else { return nil }
        return regionIndexesByVariationData[variationDataIndex].count
    }
}
