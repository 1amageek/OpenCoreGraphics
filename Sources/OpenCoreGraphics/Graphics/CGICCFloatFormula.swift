//
//  CGICCFloatFormula.swift
//  OpenCoreGraphics
//

import Foundation

internal struct CGICCFloatFormula: Hashable, Sendable {
    let function: UInt16
    let parameters: [CGFloat]

    func evaluate(_ input: CGFloat) -> CGFloat? {
        guard input.isFinite else { return nil }
        let result: CGFloat
        switch function {
        case 0 where parameters.count == 4:
            let gamma = parameters[0]
            let base = parameters[1] * input + parameters[2]
            result = pow(base, gamma) + parameters[3]
        case 1 where parameters.count == 5:
            let gamma = parameters[0]
            let logarithmInput = parameters[2] * pow(input, gamma) + parameters[3]
            guard logarithmInput > 0 else { return nil }
            result = parameters[1] * log10(logarithmInput) + parameters[4]
        case 2 where parameters.count == 5:
            let base = parameters[1]
            result = parameters[0] * pow(base, parameters[2] * input + parameters[3]) + parameters[4]
        default:
            return nil
        }
        return result.isFinite ? result : nil
    }
}
