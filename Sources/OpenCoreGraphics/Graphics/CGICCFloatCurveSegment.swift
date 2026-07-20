//
//  CGICCFloatCurveSegment.swift
//  OpenCoreGraphics
//

import Foundation

internal enum CGICCFloatCurveSegment: Hashable, Sendable {
    case formula(CGICCFloatFormula)
    case sampled([CGFloat])
}
