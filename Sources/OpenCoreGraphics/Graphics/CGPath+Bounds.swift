//
//  CGPath+Bounds.swift
//  OpenCoreGraphics
//

import Foundation


extension CGRect {
    @inline(__always)
    internal func including(_ point: CGPoint) -> CGRect {
        if isNull {
            return CGRect(origin: point, size: .zero)
        }
        let minimumX = min(minX, point.x)
        let minimumY = min(minY, point.y)
        let maximumX = max(maxX, point.x)
        let maximumY = max(maxY, point.y)
        return CGRect(
            x: minimumX,
            y: minimumY,
            width: maximumX - minimumX,
            height: maximumY - minimumY
        )
    }

    internal func includingQuadraticCurve(
        start: CGPoint,
        control: CGPoint,
        end: CGPoint
    ) -> CGRect {
        var result = including(start).including(end)
        let xDenominator = start.x - 2 * control.x + end.x
        if xDenominator != 0 {
            let parameter = (start.x - control.x) / xDenominator
            if parameter > 0, parameter < 1 {
                result = result.including(Self.quadraticPoint(
                    start: start,
                    control: control,
                    end: end,
                    parameter: parameter
                ))
            }
        }
        let yDenominator = start.y - 2 * control.y + end.y
        if yDenominator != 0 {
            let parameter = (start.y - control.y) / yDenominator
            if parameter > 0, parameter < 1 {
                result = result.including(Self.quadraticPoint(
                    start: start,
                    control: control,
                    end: end,
                    parameter: parameter
                ))
            }
        }
        return result
    }

    internal func includingCubicCurve(
        start: CGPoint,
        control1: CGPoint,
        control2: CGPoint,
        end: CGPoint
    ) -> CGRect {
        var result = including(start).including(end)
        let xRoots = Self.cubicDerivativeRoots(
            start.x,
            control1.x,
            control2.x,
            end.x
        )
        let yRoots = Self.cubicDerivativeRoots(
            start.y,
            control1.y,
            control2.y,
            end.y
        )
        for parameter in xRoots + yRoots where parameter > 0 && parameter < 1 {
            result = result.including(Self.cubicPoint(
                start: start,
                control1: control1,
                control2: control2,
                end: end,
                parameter: parameter
            ))
        }
        return result
    }

    @inline(__always)
    private static func quadraticPoint(
        start: CGPoint,
        control: CGPoint,
        end: CGPoint,
        parameter: CGFloat
    ) -> CGPoint {
        let inverse = 1 - parameter
        return CGPoint(
            x: inverse * inverse * start.x
                + 2 * inverse * parameter * control.x
                + parameter * parameter * end.x,
            y: inverse * inverse * start.y
                + 2 * inverse * parameter * control.y
                + parameter * parameter * end.y
        )
    }

    @inline(__always)
    private static func cubicPoint(
        start: CGPoint,
        control1: CGPoint,
        control2: CGPoint,
        end: CGPoint,
        parameter: CGFloat
    ) -> CGPoint {
        let inverse = 1 - parameter
        let inverseSquared = inverse * inverse
        let parameterSquared = parameter * parameter
        return CGPoint(
            x: inverseSquared * inverse * start.x
                + 3 * inverseSquared * parameter * control1.x
                + 3 * inverse * parameterSquared * control2.x
                + parameterSquared * parameter * end.x,
            y: inverseSquared * inverse * start.y
                + 3 * inverseSquared * parameter * control1.y
                + 3 * inverse * parameterSquared * control2.y
                + parameterSquared * parameter * end.y
        )
    }

    private static func cubicDerivativeRoots(
        _ start: CGFloat,
        _ control1: CGFloat,
        _ control2: CGFloat,
        _ end: CGFloat
    ) -> [CGFloat] {
        let quadratic = -start + 3 * control1 - 3 * control2 + end
        let linear = 2 * (start - 2 * control1 + control2)
        let constant = control1 - start
        let scale = max(
            1,
            max(abs(start), max(abs(control1), max(abs(control2), abs(end))))
        )
        let epsilon = scale * CGFloat.ulpOfOne * 32

        if abs(quadratic) <= epsilon {
            guard abs(linear) > epsilon else { return [] }
            return [-constant / linear]
        }

        let discriminant = linear * linear - 4 * quadratic * constant
        let coefficientScale = max(1, max(abs(quadratic), max(abs(linear), abs(constant))))
        let discriminantEpsilon = coefficientScale * coefficientScale * CGFloat.ulpOfOne * 128
        if discriminant < -discriminantEpsilon { return [] }
        if abs(discriminant) <= discriminantEpsilon {
            return [-linear / (2 * quadratic)]
        }

        let root = sqrt(discriminant)
        let denominator = 2 * quadratic
        return [
            (-linear - root) / denominator,
            (-linear + root) / denominator,
        ]
    }
}
