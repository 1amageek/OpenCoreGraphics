//
//  CGICCFloatMatrix.swift
//  OpenCoreGraphics
//

import Foundation

internal struct CGICCFloatMatrix: Hashable, Sendable {
    let inputChannels: Int
    let outputChannels: Int
    let coefficients: [CGFloat]
    let offsets: [CGFloat]

    func apply(_ input: [CGFloat]) -> [CGFloat]? {
        guard input.count == inputChannels,
              coefficients.count == inputChannels * outputChannels,
              offsets.count == outputChannels else {
            return nil
        }
        var output = offsets
        for row in 0..<outputChannels {
            for column in 0..<inputChannels {
                output[row] += coefficients[row * inputChannels + column] * input[column]
            }
            guard output[row].isFinite else { return nil }
        }
        return output
    }
}
