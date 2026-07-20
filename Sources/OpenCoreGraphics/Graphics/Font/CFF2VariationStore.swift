//
//  CFF2VariationStore.swift
//  OpenCoreGraphics
//

import Foundation

internal struct CFF2VariationStore: Sendable {
    private let store: ItemVariationStore

    init?(data: Data, offset: Int, axisCount: Int) {
        guard axisCount > 0, offset >= 0, offset <= data.count - 2 else { return nil }
        let itemStoreLength = Int(data.readUInt16BE(at: offset))
        let storeStart = offset + 2
        guard let store = ItemVariationStore(
            data: data,
            offset: storeStart,
            length: itemStoreLength,
            axisCount: axisCount
        ), store.isCFF2Compatible() else {
            return nil
        }
        self.store = store
    }

    func scalars(for variationDataIndex: Int, coordinates: [CGFloat]) -> [CGFloat]? {
        store.scalars(for: variationDataIndex, coordinates: coordinates)
    }

    func regionCount(for variationDataIndex: Int) -> Int? {
        store.regionCount(for: variationDataIndex)
    }
}
