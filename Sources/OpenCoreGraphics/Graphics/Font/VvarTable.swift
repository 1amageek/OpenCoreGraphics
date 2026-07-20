//
//  VvarTable.swift
//  OpenCoreGraphics
//

import Foundation

/// OpenType vertical metrics variations table.
internal struct VvarTable: Sendable {
    private let store: ItemVariationStore
    private let advanceHeightMap: DeltaSetIndexMap?
    private let topSideBearingMap: DeltaSetIndexMap?
    private let bottomSideBearingMap: DeltaSetIndexMap?
    private let verticalOriginMap: DeltaSetIndexMap?

    init?(data: Data, axisCount: Int, glyphCount: Int) {
        guard axisCount > 0, glyphCount > 0, data.count >= 24,
              data.readUInt16BE(at: 0) == 1,
              data.readUInt16BE(at: 2) == 0 else {
            return nil
        }
        let storeOffset = Int(data.readUInt32BE(at: 4))
        let advanceMapOffset = Int(data.readUInt32BE(at: 8))
        let topMapOffset = Int(data.readUInt32BE(at: 12))
        let bottomMapOffset = Int(data.readUInt32BE(at: 16))
        let verticalOriginMapOffset = Int(data.readUInt32BE(at: 20))
        let subtableOffsets = Set([
            storeOffset,
            advanceMapOffset,
            topMapOffset,
            bottomMapOffset,
            verticalOriginMapOffset
        ]).filter { $0 != 0 }.sorted()
        guard subtableOffsets.allSatisfy({ $0 >= 24 && $0 < data.count }),
              let storeEnd = Self.subtableEnd(after: storeOffset, offsets: subtableOffsets, data: data),
              storeOffset <= storeEnd - 8,
              (topMapOffset == 0) == (bottomMapOffset == 0),
              let store = ItemVariationStore(
                data: data,
                offset: storeOffset,
                length: storeEnd - storeOffset,
                axisCount: axisCount
              ),
              let advanceMap = Self.parseMap(
                data: data,
                offset: advanceMapOffset,
                subtableOffsets: subtableOffsets
              ),
              let topMap = Self.parseMap(
                data: data,
                offset: topMapOffset,
                subtableOffsets: subtableOffsets
              ),
              let bottomMap = Self.parseMap(
                data: data,
                offset: bottomMapOffset,
                subtableOffsets: subtableOffsets
              ),
              let verticalOriginMap = Self.parseMap(
                data: data,
                offset: verticalOriginMapOffset,
                subtableOffsets: subtableOffsets
              ) else {
            return nil
        }
        let maps = [topMap, bottomMap, verticalOriginMap]
        for map in [advanceMap] + maps {
            guard map?.allIndicesSatisfy({
                store.containsDeltaSet(outerIndex: $0, innerIndex: $1)
            }) != false else {
                return nil
            }
        }
        for glyphIndex in 0..<glyphCount {
            let advanceIndices = advanceMap?.indices(for: glyphIndex) ?? (outer: 0, inner: glyphIndex)
            guard store.containsDeltaSet(
                outerIndex: advanceIndices.outer,
                innerIndex: advanceIndices.inner
            ) else {
                return nil
            }
            for map in maps {
                if let map, let indices = map.indices(for: glyphIndex) {
                    guard store.containsDeltaSet(
                        outerIndex: indices.outer,
                        innerIndex: indices.inner
                    ) else {
                        return nil
                    }
                }
            }
        }
        self.store = store
        self.advanceHeightMap = advanceMap
        self.topSideBearingMap = topMap
        self.bottomSideBearingMap = bottomMap
        self.verticalOriginMap = verticalOriginMap
    }

    func advanceHeightDelta(for glyphIndex: Int, coordinates: [CGFloat]) -> CGFloat? {
        delta(for: glyphIndex, map: advanceHeightMap, coordinates: coordinates)
    }

    func topSideBearingDelta(for glyphIndex: Int, coordinates: [CGFloat]) -> CGFloat? {
        guard let topSideBearingMap else { return 0 }
        return delta(for: glyphIndex, map: topSideBearingMap, coordinates: coordinates)
    }

    func bottomSideBearingDelta(for glyphIndex: Int, coordinates: [CGFloat]) -> CGFloat? {
        guard let bottomSideBearingMap else { return 0 }
        return delta(for: glyphIndex, map: bottomSideBearingMap, coordinates: coordinates)
    }

    func verticalOriginDelta(for glyphIndex: Int, coordinates: [CGFloat]) -> CGFloat? {
        guard let verticalOriginMap else { return 0 }
        return delta(for: glyphIndex, map: verticalOriginMap, coordinates: coordinates)
    }

    private func delta(
        for glyphIndex: Int,
        map: DeltaSetIndexMap?,
        coordinates: [CGFloat]
    ) -> CGFloat? {
        guard glyphIndex >= 0 else { return nil }
        let indices = map?.indices(for: glyphIndex) ?? (outer: 0, inner: glyphIndex)
        return store.delta(
            outerIndex: indices.outer,
            innerIndex: indices.inner,
            coordinates: coordinates
        )
    }

    private static func parseMap(
        data: Data,
        offset: Int,
        subtableOffsets: [Int]
    ) -> DeltaSetIndexMap?? {
        if offset == 0 { return .some(nil) }
        guard let end = subtableEnd(after: offset, offsets: subtableOffsets, data: data),
              let map = DeltaSetIndexMap(
                data: data,
                offset: offset,
                length: end - offset,
                requiredFormat: 0
              ) else {
            return nil
        }
        return .some(map)
    }

    private static func subtableEnd(after offset: Int, offsets: [Int], data: Data) -> Int? {
        guard offsets.contains(offset) else { return nil }
        return offsets.first(where: { $0 > offset }) ?? data.count
    }
}
