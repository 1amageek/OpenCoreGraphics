//
//  CGHLGTransfer.swift
//  OpenCoreGraphics
//

import Foundation

internal enum CGHLGTransfer {
    private static let a: CGFloat = 0.178_832_77
    private static let b: CGFloat = 0.284_668_92
    private static let c: CGFloat = 0.559_910_73
    private static let systemGamma: CGFloat = 1.2
    private static let nominalPeakLuminance: CGFloat = 1_000
    private static let extendedLinearReferenceLuminance: CGFloat = 203

    static func decoded(_ encoded: CGColorVector, luminance: CGColorVector) -> CGColorVector? {
        guard let red = inverseOETF(encoded.x),
              let green = inverseOETF(encoded.y),
              let blue = inverseOETF(encoded.z) else {
            return nil
        }
        let sceneLuminance = luminance.x * red + luminance.y * green + luminance.z * blue
        guard sceneLuminance.isFinite, sceneLuminance >= 0 else { return nil }
        let gain = pow(sceneLuminance, systemGamma - 1)
            * nominalPeakLuminance / extendedLinearReferenceLuminance
        return CGColorVector(x: red * gain, y: green * gain, z: blue * gain)
    }

    static func encoded(_ linear: CGColorVector, luminance: CGColorVector) -> CGColorVector? {
        guard linear.x.isFinite, linear.y.isFinite, linear.z.isFinite else { return nil }
        let displayScale = extendedLinearReferenceLuminance / nominalPeakLuminance
        let display = CGColorVector(
            x: max(linear.x * displayScale, 0),
            y: max(linear.y * displayScale, 0),
            z: max(linear.z * displayScale, 0)
        )
        let displayLuminance = luminance.x * display.x + luminance.y * display.y + luminance.z * display.z
        guard displayLuminance.isFinite, displayLuminance >= 0 else { return nil }
        if displayLuminance == 0 { return CGColorVector(x: 0, y: 0, z: 0) }

        let sceneLuminance = pow(displayLuminance, 1 / systemGamma)
        let gain = pow(sceneLuminance, systemGamma - 1)
        guard gain > 0 else { return nil }
        return CGColorVector(
            x: clamp(oetf(display.x / gain)),
            y: clamp(oetf(display.y / gain)),
            z: clamp(oetf(display.z / gain))
        )
    }

    private static func inverseOETF(_ value: CGFloat) -> CGFloat? {
        guard value.isFinite else { return nil }
        let encoded = min(max(value, 0), 1)
        if encoded <= 0.5 { return encoded * encoded / 3 }
        let result = (exp((encoded - c) / a) + b) / 12
        return result.isFinite ? result : nil
    }

    private static func oetf(_ value: CGFloat) -> CGFloat {
        let scene = max(value, 0)
        if scene <= 1 / 12 { return sqrt(3 * scene) }
        return a * log(12 * scene - b) + c
    }

    private static func clamp(_ value: CGFloat) -> CGFloat {
        min(max(value, 0), 1)
    }
}
