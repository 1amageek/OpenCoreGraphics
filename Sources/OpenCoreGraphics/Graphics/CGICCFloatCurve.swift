//
//  CGICCFloatCurve.swift
//  OpenCoreGraphics
//

import Foundation

internal struct CGICCFloatCurve: Hashable, Sendable {
    let breakpoints: [CGFloat]
    let segments: [CGICCFloatCurveSegment]

    func evaluate(_ input: CGFloat) -> CGFloat? {
        guard input.isFinite, segments.count == breakpoints.count + 1 else { return nil }
        let segmentIndex = breakpoints.firstIndex(where: { input <= $0 }) ?? segments.count - 1
        return evaluate(segment: segmentIndex, input: input)
    }

    private func evaluate(segment index: Int, input: CGFloat) -> CGFloat? {
        guard segments.indices.contains(index) else { return nil }
        switch segments[index] {
        case .formula(let formula):
            return formula.evaluate(input)
        case .sampled(let samples):
            guard index > 0, index < segments.count - 1,
                  !samples.isEmpty else { return nil }
            let lower = breakpoints[index - 1]
            let upper = breakpoints[index]
            guard upper > lower,
                  let valueAtLower = evaluate(segment: index - 1, input: lower) else {
                return nil
            }
            let position = min(max((input - lower) / (upper - lower), 0), 1) * CGFloat(samples.count)
            let lowerIndex = min(Int(position), samples.count)
            let upperIndex = min(lowerIndex + 1, samples.count)
            let lowerValue = lowerIndex == 0 ? valueAtLower : samples[lowerIndex - 1]
            let upperValue = upperIndex == 0 ? valueAtLower : samples[upperIndex - 1]
            let fraction = position - CGFloat(lowerIndex)
            let result = lowerValue + (upperValue - lowerValue) * fraction
            return result.isFinite ? result : nil
        }
    }
}
