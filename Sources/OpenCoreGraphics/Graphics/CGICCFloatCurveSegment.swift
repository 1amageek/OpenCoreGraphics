//
//  CGICCFloatCurveSegment.swift
//  OpenCoreGraphics
//

import OpenCoreGraphicsSupport

internal enum CGICCFloatCurveSegment: Hashable, Sendable {
    case formula(CGICCFloatFormula)
    case sampled([CGFloat])
}
