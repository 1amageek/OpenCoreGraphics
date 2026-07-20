//
//  CGICCMultiProcessElement.swift
//  OpenCoreGraphics
//

import Foundation

internal enum CGICCMultiProcessElement: Hashable, Sendable {
    case curveSet([CGICCFloatCurve])
    case matrix(CGICCFloatMatrix)
    case clut(CGICCCLUT)
    case passThrough(channels: Int)

    var inputChannels: Int {
        switch self {
        case .curveSet(let curves): return curves.count
        case .matrix(let matrix): return matrix.inputChannels
        case .clut(let clut): return clut.gridPoints.count
        case .passThrough(let channels): return channels
        }
    }

    var outputChannels: Int {
        switch self {
        case .curveSet(let curves): return curves.count
        case .matrix(let matrix): return matrix.outputChannels
        case .clut(let clut): return clut.outputChannels
        case .passThrough(let channels): return channels
        }
    }

    func apply(_ input: [CGFloat]) -> [CGFloat]? {
        guard input.count == inputChannels else { return nil }
        switch self {
        case .curveSet(let curves):
            var output: [CGFloat] = []
            output.reserveCapacity(curves.count)
            for index in curves.indices {
                guard let value = curves[index].evaluate(input[index]) else { return nil }
                output.append(value)
            }
            return output
        case .matrix(let matrix):
            return matrix.apply(input)
        case .clut(let clut):
            return clut.interpolate(input)
        case .passThrough:
            return input
        }
    }
}
