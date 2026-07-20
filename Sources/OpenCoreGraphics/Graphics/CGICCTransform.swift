//
//  CGICCTransform.swift
//  OpenCoreGraphics
//

import Foundation

internal struct CGICCTransformSet: Hashable, Sendable {
    let mediaWhitePoint: CGColorVector
    let perceptualToPCS: CGICCTransform?
    let colorimetricToPCS: CGICCTransform?
    let saturationToPCS: CGICCTransform?
    let absoluteToPCS: CGICCTransform?
    let perceptualFromPCS: CGICCTransform?
    let colorimetricFromPCS: CGICCTransform?
    let saturationFromPCS: CGICCTransform?
    let absoluteFromPCS: CGICCTransform?

    func toPCS(_ components: [CGFloat], intent: CGColorRenderingIntent) -> CGColorVector? {
        let usesExplicitAbsolute = intent == .absoluteColorimetric && absoluteToPCS != nil
        guard let transform = usesExplicitAbsolute
            ? absoluteToPCS
            : select(
                intent: intent,
                perceptual: perceptualToPCS,
                colorimetric: colorimetricToPCS,
                saturation: saturationToPCS
            ) else { return nil }
        guard var pcs = transform.toPCS(components) else { return nil }
        if intent == .absoluteColorimetric && !usesExplicitAbsolute {
            pcs = CGColorVector(
                x: pcs.x * mediaWhitePoint.x / CGColorVector.d50.x,
                y: pcs.y * mediaWhitePoint.y / CGColorVector.d50.y,
                z: pcs.z * mediaWhitePoint.z / CGColorVector.d50.z
            )
        }
        return pcs
    }

    func hasToPCS(intent: CGColorRenderingIntent) -> Bool {
        if intent == .absoluteColorimetric, absoluteToPCS != nil { return true }
        return select(
            intent: intent,
            perceptual: perceptualToPCS,
            colorimetric: colorimetricToPCS,
            saturation: saturationToPCS
        ) != nil
    }

    func fromPCS(_ pcs: CGColorVector, intent: CGColorRenderingIntent) -> [CGFloat]? {
        let usesExplicitAbsolute = intent == .absoluteColorimetric && absoluteFromPCS != nil
        guard let transform = usesExplicitAbsolute
            ? absoluteFromPCS
            : select(
                intent: intent,
                perceptual: perceptualFromPCS,
                colorimetric: colorimetricFromPCS,
                saturation: saturationFromPCS
            ) else { return nil }
        let input: CGColorVector
        if intent == .absoluteColorimetric && !usesExplicitAbsolute {
            guard mediaWhitePoint.x > 0, mediaWhitePoint.y > 0, mediaWhitePoint.z > 0 else { return nil }
            input = CGColorVector(
                x: pcs.x * CGColorVector.d50.x / mediaWhitePoint.x,
                y: pcs.y * CGColorVector.d50.y / mediaWhitePoint.y,
                z: pcs.z * CGColorVector.d50.z / mediaWhitePoint.z
            )
        } else {
            input = pcs
        }
        return transform.fromPCS(input)
    }

    func hasFromPCS(intent: CGColorRenderingIntent) -> Bool {
        if intent == .absoluteColorimetric, absoluteFromPCS != nil { return true }
        return select(
            intent: intent,
            perceptual: perceptualFromPCS,
            colorimetric: colorimetricFromPCS,
            saturation: saturationFromPCS
        ) != nil
    }

    private func select(
        intent: CGColorRenderingIntent,
        perceptual: CGICCTransform?,
        colorimetric: CGICCTransform?,
        saturation: CGICCTransform?
    ) -> CGICCTransform? {
        switch intent {
        case .defaultIntent, .perceptual:
            return perceptual ?? colorimetric ?? saturation
        case .absoluteColorimetric, .relativeColorimetric:
            // ICC profiles commonly omit the colorimetric table when one transform serves all
            // intents. ColorSync uses A2B0/B2A0 in that case, so this is a specified profile-table
            // substitution rather than a model-only fallback.
            return colorimetric ?? perceptual ?? saturation
        case .saturation:
            return saturation ?? perceptual ?? colorimetric
        }
    }
}

internal struct CGICCTransform: Hashable, Sendable {
    enum PCSEncoding: Hashable, Sendable {
        case xyz
        case lab
        case legacyLab16
        case floatXYZ
        case floatLab
    }

    let pipeline: CGICCTransformPipeline
    let pcsEncoding: PCSEncoding
    let direction: Direction

    enum Direction: Hashable, Sendable {
        case toPCS
        case fromPCS
    }

    func toPCS(_ deviceComponents: [CGFloat]) -> CGColorVector? {
        guard direction == .toPCS,
              let encodedPCS = pipeline.applying(to: deviceComponents) else {
            return nil
        }
        return decodePCS(encodedPCS)
    }

    func fromPCS(_ pcs: CGColorVector) -> [CGFloat]? {
        guard direction == .fromPCS,
              let encodedPCS = encodePCS(pcs) else {
            return nil
        }
        return pipeline.applying(to: encodedPCS)
    }

    private func decodePCS(_ values: [CGFloat]) -> CGColorVector? {
        guard values.count == 3 else { return nil }
        switch pcsEncoding {
        case .xyz:
            let scale = CGFloat(65_535) / 32_768
            return CGColorVector(x: values[0] * scale, y: values[1] * scale, z: values[2] * scale)
        case .lab:
            return Self.labToXYZ(
                lightness: values[0] * 100,
                a: values[1] * 255 - 128,
                b: values[2] * 255 - 128
            )
        case .legacyLab16:
            let codeScale = CGFloat(65_535) / 65_280
            return Self.labToXYZ(
                lightness: values[0] * codeScale * 100,
                a: values[1] * 65_535 / 256 - 128,
                b: values[2] * 65_535 / 256 - 128
            )
        case .floatXYZ:
            guard values.allSatisfy(\.isFinite) else { return nil }
            return CGColorVector(x: values[0], y: values[1], z: values[2])
        case .floatLab:
            guard values.allSatisfy(\.isFinite) else { return nil }
            let xyz = Self.labToXYZ(lightness: values[0], a: values[1], b: values[2])
            guard xyz.x.isFinite, xyz.y.isFinite, xyz.z.isFinite else { return nil }
            return xyz
        }
    }

    private func encodePCS(_ pcs: CGColorVector) -> [CGFloat]? {
        switch pcsEncoding {
        case .xyz:
            let scale = CGFloat(32_768) / 65_535
            return [pcs.x * scale, pcs.y * scale, pcs.z * scale].map(Self.clamp)
        case .lab, .legacyLab16:
            guard let lab = Self.xyzToLab(pcs) else { return nil }
            switch pcsEncoding {
            case .lab:
                return [lab.x / 100, (lab.y + 128) / 255, (lab.z + 128) / 255].map(Self.clamp)
            case .legacyLab16:
                return [
                    lab.x / 100 * 65_280 / 65_535,
                    (lab.y + 128) * 256 / 65_535,
                    (lab.z + 128) * 256 / 65_535
                ].map(Self.clamp)
            case .xyz:
                return nil
            case .floatXYZ, .floatLab:
                return nil
            }
        case .floatXYZ:
            guard pcs.x.isFinite, pcs.y.isFinite, pcs.z.isFinite else { return nil }
            return [pcs.x, pcs.y, pcs.z]
        case .floatLab:
            guard let lab = Self.xyzToLab(pcs) else { return nil }
            return [lab.x, lab.y, lab.z]
        }
    }

    private static func labToXYZ(lightness: CGFloat, a: CGFloat, b: CGFloat) -> CGColorVector {
        let fy = (lightness + 16) / 116
        let fx = fy + a / 500
        let fz = fy - b / 200
        let epsilon = CGFloat(216) / 24_389
        let kappa = CGFloat(24_389) / 27

        func inverse(_ value: CGFloat) -> CGFloat {
            let cube = value * value * value
            return cube > epsilon ? cube : (116 * value - 16) / kappa
        }

        return CGColorVector(
            x: CGColorVector.d50.x * inverse(fx),
            y: CGColorVector.d50.y * inverse(fy),
            z: CGColorVector.d50.z * inverse(fz)
        )
    }

    private static func xyzToLab(_ xyz: CGColorVector) -> CGColorVector? {
        guard xyz.x.isFinite, xyz.y.isFinite, xyz.z.isFinite else { return nil }
        let epsilon = CGFloat(216) / 24_389
        let kappa = CGFloat(24_389) / 27

        func forward(_ value: CGFloat) -> CGFloat {
            value > epsilon ? pow(value, 1 / 3) : (kappa * value + 16) / 116
        }

        let fx = forward(xyz.x / CGColorVector.d50.x)
        let fy = forward(xyz.y / CGColorVector.d50.y)
        let fz = forward(xyz.z / CGColorVector.d50.z)
        return CGColorVector(x: 116 * fy - 16, y: 500 * (fx - fy), z: 200 * (fy - fz))
    }

    private static func clamp(_ value: CGFloat) -> CGFloat {
        min(max(value, 0), 1)
    }
}

internal enum CGICCTransformPipeline: Hashable, Sendable {
    case aToB(CGICCComplexLUT)
    case bToA(CGICCComplexLUT)
    case legacy(CGICCLegacyLUT)
    case multiProcess(CGICCMultiProcessPipeline)

    func applying(to input: [CGFloat]) -> [CGFloat]? {
        switch self {
        case .aToB(let lut): return lut.applyAToB(input)
        case .bToA(let lut): return lut.applyBToA(input)
        case .legacy(let lut): return lut.apply(input)
        case .multiProcess(let pipeline): return pipeline.apply(input)
        }
    }
}

internal struct CGICCComplexLUT: Hashable, Sendable {
    let inputChannels: Int
    let outputChannels: Int
    let aCurves: [CGTransferCurve]?
    let clut: CGICCCLUT?
    let mCurves: [CGTransferCurve]?
    let matrix: CGColorMatrix?
    let matrixOffset: CGColorVector?
    let bCurves: [CGTransferCurve]

    func applyAToB(_ input: [CGFloat]) -> [CGFloat]? {
        guard input.count >= inputChannels else { return nil }
        var values = Array(input.prefix(inputChannels)).map(Self.clamp)
        if let aCurves {
            guard let result = apply(curves: aCurves, to: values) else { return nil }
            values = result
        }
        if let clut {
            guard let result = clut.interpolate(values) else { return nil }
            values = result
        }
        if let mCurves {
            guard let result = apply(curves: mCurves, to: values) else { return nil }
            values = result
        }
        if let matrix, let matrixOffset {
            guard values.count == 3 else { return nil }
            let result = matrix.applying(to: CGColorVector(x: values[0], y: values[1], z: values[2]))
            values = [result.x + matrixOffset.x, result.y + matrixOffset.y, result.z + matrixOffset.z]
                .map(Self.clamp)
        }
        return apply(curves: bCurves, to: values)
    }

    func applyBToA(_ input: [CGFloat]) -> [CGFloat]? {
        guard input.count >= inputChannels,
              var values = apply(curves: bCurves, to: Array(input.prefix(inputChannels)).map(Self.clamp)) else {
            return nil
        }
        if let matrix, let matrixOffset {
            guard values.count == 3 else { return nil }
            let result = matrix.applying(to: CGColorVector(x: values[0], y: values[1], z: values[2]))
            values = [result.x + matrixOffset.x, result.y + matrixOffset.y, result.z + matrixOffset.z]
                .map(Self.clamp)
        }
        if let mCurves {
            guard let result = apply(curves: mCurves, to: values) else { return nil }
            values = result
        }
        if let clut {
            guard let result = clut.interpolate(values) else { return nil }
            values = result
        }
        if let aCurves {
            return apply(curves: aCurves, to: values)
        }
        return values
    }

    private func apply(curves: [CGTransferCurve], to values: [CGFloat]) -> [CGFloat]? {
        guard curves.count == values.count else { return nil }
        var result: [CGFloat] = []
        result.reserveCapacity(values.count)
        for index in values.indices {
            guard let value = curves[index].decoded(values[index], extended: false) else { return nil }
            result.append(Self.clamp(value))
        }
        return result
    }

    private static func clamp(_ value: CGFloat) -> CGFloat {
        min(max(value, 0), 1)
    }
}

internal struct CGICCLegacyLUT: Hashable, Sendable {
    let inputChannels: Int
    let outputChannels: Int
    let matrix: CGColorMatrix
    let appliesMatrix: Bool
    let inputTables: [[CGFloat]]
    let clut: CGICCCLUT
    let outputTables: [[CGFloat]]

    func apply(_ input: [CGFloat]) -> [CGFloat]? {
        guard input.count >= inputChannels else { return nil }
        var values = Array(input.prefix(inputChannels)).map(Self.clamp)
        if appliesMatrix {
            guard values.count == 3 else { return nil }
            let result = matrix.applying(to: CGColorVector(x: values[0], y: values[1], z: values[2]))
            values = [result.x, result.y, result.z].map(Self.clamp)
        }
        guard let tableValues = Self.interpolate(tables: inputTables, values: values),
              let clutValues = clut.interpolate(tableValues),
              let output = Self.interpolate(tables: outputTables, values: clutValues) else {
            return nil
        }
        return output
    }

    private static func interpolate(tables: [[CGFloat]], values: [CGFloat]) -> [CGFloat]? {
        guard tables.count == values.count else { return nil }
        var result: [CGFloat] = []
        result.reserveCapacity(values.count)
        for index in values.indices {
            let table = tables[index]
            guard table.count >= 2 else { return nil }
            let position = clamp(values[index]) * CGFloat(table.count - 1)
            let lower = min(Int(position), table.count - 1)
            let upper = min(lower + 1, table.count - 1)
            let fraction = position - CGFloat(lower)
            result.append(table[lower] + (table[upper] - table[lower]) * fraction)
        }
        return result
    }

    private static func clamp(_ value: CGFloat) -> CGFloat {
        min(max(value, 0), 1)
    }
}

internal struct CGICCCLUT: Hashable, Sendable {
    let gridPoints: [Int]
    let outputChannels: Int
    let values: [CGFloat]

    func interpolate(_ input: [CGFloat]) -> [CGFloat]? {
        guard input.count == gridPoints.count,
              !gridPoints.isEmpty,
              input.allSatisfy({ !$0.isNaN }),
              gridPoints.allSatisfy({ $0 >= 2 }),
              gridPoints.count < Int.bitWidth - 1 else {
            return nil
        }

        var lower: [Int] = []
        var fractions: [CGFloat] = []
        lower.reserveCapacity(input.count)
        fractions.reserveCapacity(input.count)
        for dimension in input.indices {
            let position = min(max(input[dimension], 0), 1) * CGFloat(gridPoints[dimension] - 1)
            let low = min(Int(position), gridPoints[dimension] - 2)
            lower.append(low)
            fractions.append(position - CGFloat(low))
        }

        var output = Array(repeating: CGFloat.zero, count: outputChannels)
        for corner in 0..<(1 << input.count) {
            var weight: CGFloat = 1
            var pointIndex = 0
            for dimension in input.indices {
                let upper = (corner & (1 << dimension)) != 0
                weight *= upper ? fractions[dimension] : 1 - fractions[dimension]
                pointIndex = pointIndex * gridPoints[dimension] + lower[dimension] + (upper ? 1 : 0)
            }
            if weight == 0 { continue }
            let valueIndex = pointIndex * outputChannels
            guard valueIndex <= values.count - outputChannels else { return nil }
            for channel in 0..<outputChannels {
                output[channel] += values[valueIndex + channel] * weight
            }
        }
        return output
    }
}
