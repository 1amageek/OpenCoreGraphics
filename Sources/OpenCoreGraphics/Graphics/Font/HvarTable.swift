//
//  HvarTable.swift
//  OpenCoreGraphics
//

import Foundation

/// OpenType horizontal metrics variations table.
internal struct HvarTable: Sendable {
    private let store: ItemVariationStore
    private let advanceWidthMap: DeltaSetIndexMap?
    private let leftSideBearingMap: DeltaSetIndexMap?
    private let rightSideBearingMap: DeltaSetIndexMap?

    init?(data: Data, axisCount: Int, glyphCount: Int) {
        guard axisCount > 0, glyphCount > 0, data.count >= 20,
              data.readUInt16BE(at: 0) == 1,
              data.readUInt16BE(at: 2) == 0 else {
            return nil
        }
        let storeOffset = Int(data.readUInt32BE(at: 4))
        let advanceMapOffset = Int(data.readUInt32BE(at: 8))
        let leftMapOffset = Int(data.readUInt32BE(at: 12))
        let rightMapOffset = Int(data.readUInt32BE(at: 16))
        let subtableOffsets = Set([storeOffset, advanceMapOffset, leftMapOffset, rightMapOffset])
            .filter { $0 != 0 }
            .sorted()
        guard subtableOffsets.allSatisfy({ $0 >= 20 && $0 < data.count }),
              let storeEnd = Self.subtableEnd(after: storeOffset, offsets: subtableOffsets, data: data),
              storeOffset <= storeEnd - 8,
              (leftMapOffset == 0) == (rightMapOffset == 0),
              let store = ItemVariationStore(
                data: data,
                offset: storeOffset,
                length: storeEnd - storeOffset,
                axisCount: axisCount
              ) else {
            return nil
        }
        guard let advanceMap = Self.parseMap(
                data: data,
                offset: advanceMapOffset,
                subtableOffsets: subtableOffsets
              ),
              let leftMap = Self.parseMap(
                data: data,
                offset: leftMapOffset,
                subtableOffsets: subtableOffsets
              ),
              let rightMap = Self.parseMap(
                data: data,
                offset: rightMapOffset,
                subtableOffsets: subtableOffsets
              ) else {
            return nil
        }
        for map in [advanceMap, leftMap, rightMap] {
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
            if let leftMap, let indices = leftMap.indices(for: glyphIndex) {
                guard store.containsDeltaSet(outerIndex: indices.outer, innerIndex: indices.inner) else {
                    return nil
                }
            }
            if let rightMap, let indices = rightMap.indices(for: glyphIndex) {
                guard store.containsDeltaSet(outerIndex: indices.outer, innerIndex: indices.inner) else {
                    return nil
                }
            }
        }
        self.store = store
        self.advanceWidthMap = advanceMap
        self.leftSideBearingMap = leftMap
        self.rightSideBearingMap = rightMap
    }

    func advanceWidthDelta(for glyphIndex: Int, coordinates: [CGFloat]) -> CGFloat? {
        delta(for: glyphIndex, map: advanceWidthMap, coordinates: coordinates)
    }

    func regionScalars(for coordinates: [CGFloat]) -> [CGFloat]? {
        store.regionScalars(for: coordinates)
    }

    func advanceWidthDelta(for glyphIndex: Int, regionScalars: [CGFloat]) -> CGFloat? {
        delta(for: glyphIndex, map: advanceWidthMap, regionScalars: regionScalars)
    }

    func leftSideBearingDelta(for glyphIndex: Int, coordinates: [CGFloat]) -> CGFloat? {
        guard let leftSideBearingMap else { return 0 }
        return delta(for: glyphIndex, map: leftSideBearingMap, coordinates: coordinates)
    }

    func rightSideBearingDelta(for glyphIndex: Int, coordinates: [CGFloat]) -> CGFloat? {
        guard let rightSideBearingMap else { return 0 }
        return delta(for: glyphIndex, map: rightSideBearingMap, coordinates: coordinates)
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

    private func delta(
        for glyphIndex: Int,
        map: DeltaSetIndexMap?,
        regionScalars: [CGFloat]
    ) -> CGFloat? {
        guard glyphIndex >= 0 else { return nil }
        let indices = map?.indices(for: glyphIndex) ?? (outer: 0, inner: glyphIndex)
        return store.delta(
            outerIndex: indices.outer,
            innerIndex: indices.inner,
            regionScalars: regionScalars
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
