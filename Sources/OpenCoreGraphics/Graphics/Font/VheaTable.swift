//
//  VheaTable.swift
//  OpenCoreGraphics
//

import Foundation

/// OpenType vertical header table values required to decode vmtx.
internal struct VheaTable: Sendable {
    let advanceHeightMax: UInt16
    let numberOfVMetrics: UInt16
}
