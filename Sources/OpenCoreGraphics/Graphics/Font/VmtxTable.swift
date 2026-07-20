//
//  VmtxTable.swift
//  OpenCoreGraphics
//

import Foundation

/// OpenType vertical metrics table.
internal struct VmtxTable: Sendable {
    struct LongVerMetric: Sendable {
        let advanceHeight: UInt16
        let topSideBearing: Int16
    }

    let metrics: [LongVerMetric]
    let topSideBearings: [Int16]
    let glyphCount: Int

    func advanceHeight(for glyphIndex: Int) -> UInt16? {
        guard (0..<glyphCount).contains(glyphIndex), let lastMetric = metrics.last else { return nil }
        if metrics.indices.contains(glyphIndex) { return metrics[glyphIndex].advanceHeight }
        return lastMetric.advanceHeight
    }

    func topSideBearing(for glyphIndex: Int) -> Int16? {
        guard (0..<glyphCount).contains(glyphIndex) else { return nil }
        if metrics.indices.contains(glyphIndex) { return metrics[glyphIndex].topSideBearing }
        let index = glyphIndex - metrics.count
        guard topSideBearings.indices.contains(index) else { return nil }
        return topSideBearings[index]
    }
}
