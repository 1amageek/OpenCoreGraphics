//
//  CGColor.swift
//  OpenCoreGraphics
//
//  Created by OpenCoreGraphics contributors.
//


import Foundation


/// A set of components that define a color, with a color space specifying
/// how to interpret them.
public class CGColor: @unchecked Sendable {

    /// The color space associated with the color.
    public let colorSpace: CGColorSpace?

    /// The values of the color components (including alpha) associated with the color.
    public let components: [CGFloat]?

    /// The number of color components (including alpha) associated with the color.
    public var numberOfComponents: Int {
        return components?.count ?? 0
    }

    /// The value of the alpha component associated with the color.
    public var alpha: CGFloat {
        guard let components = components, !components.isEmpty else { return 1.0 }
        return components[components.count - 1]
    }

    // MARK: - Initializers

    /// Internal initializer
    internal init(space: CGColorSpace?, componentArray: [CGFloat]) {
        self.colorSpace = space
        self.components = componentArray
    }

    /// Creates a color using a list of intensity values (including alpha) and an associated color space.
    public convenience init?(colorSpace: CGColorSpace, components: UnsafePointer<CGFloat>) {
        let count = colorSpace.numberOfComponents + 1 // +1 for alpha
        var componentArray: [CGFloat] = []
        for i in 0..<count {
            componentArray.append(components[i])
        }
        self.init(space: colorSpace, componentArray: componentArray)
    }

    /// Creates a color in the Generic gray color space.
    public convenience init(gray: CGFloat, alpha: CGFloat) {
        self.init(space: .deviceGray, componentArray: [gray, alpha])
    }

    /// Creates a color in the Generic RGB color space.
    public convenience init(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        self.init(space: .deviceRGB, componentArray: [red, green, blue, alpha])
    }

    /// Creates a color in the sRGB color space.
    public convenience init(srgbRed red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? .deviceRGB
        self.init(space: colorSpace, componentArray: [red, green, blue, alpha])
    }

    /// Creates a color in the Generic CMYK color space.
    public convenience init(genericCMYKCyan cyan: CGFloat, magenta: CGFloat, yellow: CGFloat, black: CGFloat, alpha: CGFloat) {
        self.init(space: .deviceCMYK, componentArray: [cyan, magenta, yellow, black, alpha])
    }

    /// Creates a color in the Generic gray color space with a gamma ramp of 2.2.
    public convenience init(genericGrayGamma2_2Gray gray: CGFloat, alpha: CGFloat) {
        let colorSpace = CGColorSpace(name: CGColorSpace.genericGrayGamma2_2) ?? .deviceGray
        self.init(space: colorSpace, componentArray: [gray, alpha])
    }

    // MARK: - System Colors

    /// The black color in the Generic gray color space.
    public static let black = CGColor(gray: 0.0, alpha: 1.0)

    /// The white color in the Generic gray color space.
    public static let white = CGColor(gray: 1.0, alpha: 1.0)

    /// The clear color in the Generic gray color space.
    public static let clear = CGColor(gray: 0.0, alpha: 0.0)

    // MARK: - Copying

    /// Creates a copy of an existing color.
    public func copy() -> CGColor? {
        guard let components = components else { return nil }
        return CGColor(space: colorSpace, componentArray: components)
    }

    /// Creates a copy of an existing color, substituting a new alpha value.
    public func copy(alpha: CGFloat) -> CGColor? {
        guard var newComponents = components else { return nil }
        if !newComponents.isEmpty {
            newComponents[newComponents.count - 1] = alpha
        }
        return CGColor(space: colorSpace, componentArray: newComponents)
    }

    // MARK: - Converting

    /// Creates a new color in a different color space that matches the provided color.
    public func converted(to space: CGColorSpace, intent: CGColorRenderingIntent, options: [String: Any]?) -> CGColor? {
        guard let components = self.components else { return nil }

        // Same color space - just copy components
        if let sourceName = colorSpace?.name, sourceName == space.name {
            return CGColor(space: space, componentArray: components)
        }

        // Color conversion between different models
        switch (colorSpace?.model, space.model) {

        // MARK: Monochrome conversions
        case (.monochrome, .rgb):
            // Gray to RGB
            let gray = components[0]
            let alpha = components.count > 1 ? components[1] : CGFloat(1.0)
            return CGColor(space: space, componentArray: [gray, gray, gray, alpha])

        case (.monochrome, .cmyk):
            // Gray to CMYK (K channel only)
            let gray = components[0]
            let alpha = components.count > 1 ? components[1] : CGFloat(1.0)
            let k = 1.0 - gray
            return CGColor(space: space, componentArray: [0.0, 0.0, 0.0, k, alpha])

        // MARK: RGB conversions
        case (.rgb, .monochrome):
            // RGB to Gray (using ITU-R BT.601 luminance coefficients)
            let r = components[0]
            let g = components[1]
            let b = components[2]
            let gray = 0.299 * r + 0.587 * g + 0.114 * b
            let alpha = components.count > 3 ? components[3] : CGFloat(1.0)
            return CGColor(space: space, componentArray: [gray, alpha])

        case (.rgb, .cmyk):
            // RGB to CMYK
            let r = components[0]
            let g = components[1]
            let b = components[2]
            let alpha = components.count > 3 ? components[3] : CGFloat(1.0)

            let k = 1.0 - max(r, max(g, b))

            // Avoid division by zero when K = 1 (pure black)
            if k >= 1.0 {
                return CGColor(space: space, componentArray: [0.0, 0.0, 0.0, 1.0, alpha])
            }

            let c = (1.0 - r - k) / (1.0 - k)
            let m = (1.0 - g - k) / (1.0 - k)
            let y = (1.0 - b - k) / (1.0 - k)
            return CGColor(space: space, componentArray: [c, m, y, k, alpha])

        // MARK: CMYK conversions
        case (.cmyk, .rgb):
            // CMYK to RGB
            let c = components[0]
            let m = components[1]
            let y = components[2]
            let k = components[3]
            let alpha = components.count > 4 ? components[4] : CGFloat(1.0)

            let r = (1.0 - c) * (1.0 - k)
            let g = (1.0 - m) * (1.0 - k)
            let b = (1.0 - y) * (1.0 - k)
            return CGColor(space: space, componentArray: [r, g, b, alpha])

        case (.cmyk, .monochrome):
            // CMYK to Gray (convert to RGB first, then to gray)
            let c = components[0]
            let m = components[1]
            let y = components[2]
            let k = components[3]
            let alpha = components.count > 4 ? components[4] : CGFloat(1.0)

            let r = (1.0 - c) * (1.0 - k)
            let g = (1.0 - m) * (1.0 - k)
            let b = (1.0 - y) * (1.0 - k)
            let gray = 0.299 * r + 0.587 * g + 0.114 * b
            return CGColor(space: space, componentArray: [gray, alpha])

        // MARK: Lab conversions
        case (.lab, .rgb):
            // Lab to RGB (through XYZ, using D65 illuminant)
            let l = components[0]
            let a = components[1]
            let bLab = components[2]
            let alpha = components.count > 3 ? components[3] : CGFloat(1.0)

            // Lab to XYZ (D65 reference white)
            let fy = (l + 16.0) / 116.0
            let fx = a / 500.0 + fy
            let fz = fy - bLab / 200.0

            let xr: CGFloat = fx > 0.206893 ? fx * fx * fx : (fx - 16.0 / 116.0) / 7.787
            let yr: CGFloat = l > 8.0 ? fy * fy * fy : l / 903.3
            let zr: CGFloat = fz > 0.206893 ? fz * fz * fz : (fz - 16.0 / 116.0) / 7.787

            // D65 reference white
            let x = xr * 0.95047
            let yVal = yr * 1.0
            let z = zr * 1.08883

            // XYZ to sRGB
            var r = x *  3.2404542 + yVal * -1.5371385 + z * -0.4985314
            var g = x * -0.9692660 + yVal *  1.8760108 + z *  0.0415560
            var bOut = x *  0.0556434 + yVal * -0.2040259 + z *  1.0572252

            // Apply sRGB gamma
            r = r > 0.0031308 ? 1.055 * pow(r, 1.0 / 2.4) - 0.055 : 12.92 * r
            g = g > 0.0031308 ? 1.055 * pow(g, 1.0 / 2.4) - 0.055 : 12.92 * g
            bOut = bOut > 0.0031308 ? 1.055 * pow(bOut, 1.0 / 2.4) - 0.055 : 12.92 * bOut

            // Clamp to valid range
            r = max(0.0, min(1.0, r))
            g = max(0.0, min(1.0, g))
            bOut = max(0.0, min(1.0, bOut))

            return CGColor(space: space, componentArray: [r, g, bOut, alpha])

        case (.rgb, .lab):
            // RGB to Lab (through XYZ, using D65 illuminant)
            var r = components[0]
            var g = components[1]
            var bVal = components[2]
            let alpha = components.count > 3 ? components[3] : CGFloat(1.0)

            // Remove sRGB gamma
            r = r > 0.04045 ? pow((r + 0.055) / 1.055, 2.4) : r / 12.92
            g = g > 0.04045 ? pow((g + 0.055) / 1.055, 2.4) : g / 12.92
            bVal = bVal > 0.04045 ? pow((bVal + 0.055) / 1.055, 2.4) : bVal / 12.92

            // RGB to XYZ
            let x = (r * 0.4124564 + g * 0.3575761 + bVal * 0.1804375) / 0.95047
            let y = (r * 0.2126729 + g * 0.7151522 + bVal * 0.0721750) / 1.0
            let z = (r * 0.0193339 + g * 0.1191920 + bVal * 0.9503041) / 1.08883

            // XYZ to Lab
            let fx = x > 0.008856 ? pow(x, 1.0 / 3.0) : (7.787 * x) + 16.0 / 116.0
            let fy = y > 0.008856 ? pow(y, 1.0 / 3.0) : (7.787 * y) + 16.0 / 116.0
            let fz = z > 0.008856 ? pow(z, 1.0 / 3.0) : (7.787 * z) + 16.0 / 116.0

            let l = (116.0 * fy) - 16.0
            let aOut = 500.0 * (fx - fy)
            let bOut = 200.0 * (fy - fz)

            return CGColor(space: space, componentArray: [l, aOut, bOut, alpha])

        // MARK: XYZ conversions
        case (.XYZ, .rgb):
            // XYZ to sRGB (D65)
            let x = components[0]
            let y = components[1]
            let z = components[2]
            let alpha = components.count > 3 ? components[3] : CGFloat(1.0)

            // XYZ to linear sRGB
            var r = x *  3.2404542 + y * -1.5371385 + z * -0.4985314
            var g = x * -0.9692660 + y *  1.8760108 + z *  0.0415560
            var bOut = x *  0.0556434 + y * -0.2040259 + z *  1.0572252

            // Apply sRGB gamma
            r = r > 0.0031308 ? 1.055 * pow(r, 1.0 / 2.4) - 0.055 : 12.92 * r
            g = g > 0.0031308 ? 1.055 * pow(g, 1.0 / 2.4) - 0.055 : 12.92 * g
            bOut = bOut > 0.0031308 ? 1.055 * pow(bOut, 1.0 / 2.4) - 0.055 : 12.92 * bOut

            // Clamp to valid range
            r = max(0.0, min(1.0, r))
            g = max(0.0, min(1.0, g))
            bOut = max(0.0, min(1.0, bOut))

            return CGColor(space: space, componentArray: [r, g, bOut, alpha])

        case (.rgb, .XYZ):
            // sRGB to XYZ (D65)
            var r = components[0]
            var g = components[1]
            var bVal = components[2]
            let alpha = components.count > 3 ? components[3] : CGFloat(1.0)

            // Remove sRGB gamma
            r = r > 0.04045 ? pow((r + 0.055) / 1.055, 2.4) : r / 12.92
            g = g > 0.04045 ? pow((g + 0.055) / 1.055, 2.4) : g / 12.92
            bVal = bVal > 0.04045 ? pow((bVal + 0.055) / 1.055, 2.4) : bVal / 12.92

            // Linear RGB to XYZ
            let x = r * 0.4124564 + g * 0.3575761 + bVal * 0.1804375
            let y = r * 0.2126729 + g * 0.7151522 + bVal * 0.0721750
            let z = r * 0.0193339 + g * 0.1191920 + bVal * 0.9503041

            return CGColor(space: space, componentArray: [x, y, z, alpha])

        // MARK: Lab <-> CMYK (via RGB)
        case (.lab, .cmyk):
            // Lab to CMYK (Lab -> RGB -> CMYK)
            guard let rgbColor = self.converted(to: .deviceRGB, intent: intent, options: options) else {
                return nil
            }
            return rgbColor.converted(to: space, intent: intent, options: options)

        case (.cmyk, .lab):
            // CMYK to Lab (CMYK -> RGB -> Lab)
            guard let rgbColor = self.converted(to: .deviceRGB, intent: intent, options: options) else {
                return nil
            }
            return rgbColor.converted(to: space, intent: intent, options: options)

        // MARK: XYZ <-> CMYK (via RGB)
        case (.XYZ, .cmyk):
            guard let rgbColor = self.converted(to: .deviceRGB, intent: intent, options: options) else {
                return nil
            }
            return rgbColor.converted(to: space, intent: intent, options: options)

        case (.cmyk, .XYZ):
            guard let rgbColor = self.converted(to: .deviceRGB, intent: intent, options: options) else {
                return nil
            }
            return rgbColor.converted(to: space, intent: intent, options: options)

        // MARK: Lab <-> Monochrome (via RGB)
        case (.lab, .monochrome):
            guard let rgbColor = self.converted(to: .deviceRGB, intent: intent, options: options) else {
                return nil
            }
            return rgbColor.converted(to: space, intent: intent, options: options)

        case (.monochrome, .lab):
            guard let rgbColor = self.converted(to: .deviceRGB, intent: intent, options: options) else {
                return nil
            }
            return rgbColor.converted(to: space, intent: intent, options: options)

        // MARK: XYZ <-> Monochrome (via RGB)
        case (.XYZ, .monochrome):
            guard let rgbColor = self.converted(to: .deviceRGB, intent: intent, options: options) else {
                return nil
            }
            return rgbColor.converted(to: space, intent: intent, options: options)

        case (.monochrome, .XYZ):
            guard let rgbColor = self.converted(to: .deviceRGB, intent: intent, options: options) else {
                return nil
            }
            return rgbColor.converted(to: space, intent: intent, options: options)

        // MARK: Lab <-> XYZ direct conversion
        case (.lab, .XYZ):
            let l = components[0]
            let a = components[1]
            let bLab = components[2]
            let alpha = components.count > 3 ? components[3] : CGFloat(1.0)

            let fy = (l + 16.0) / 116.0
            let fx = a / 500.0 + fy
            let fz = fy - bLab / 200.0

            let xr: CGFloat = fx > 0.206893 ? fx * fx * fx : (fx - 16.0 / 116.0) / 7.787
            let yr: CGFloat = l > 8.0 ? fy * fy * fy : l / 903.3
            let zr: CGFloat = fz > 0.206893 ? fz * fz * fz : (fz - 16.0 / 116.0) / 7.787

            // D65 reference white
            let x = xr * 0.95047
            let y = yr * 1.0
            let z = zr * 1.08883

            return CGColor(space: space, componentArray: [x, y, z, alpha])

        case (.XYZ, .lab):
            let xVal = components[0] / 0.95047
            let yVal = components[1] / 1.0
            let zVal = components[2] / 1.08883
            let alpha = components.count > 3 ? components[3] : CGFloat(1.0)

            let fx = xVal > 0.008856 ? pow(xVal, 1.0 / 3.0) : (7.787 * xVal) + 16.0 / 116.0
            let fy = yVal > 0.008856 ? pow(yVal, 1.0 / 3.0) : (7.787 * yVal) + 16.0 / 116.0
            let fz = zVal > 0.008856 ? pow(zVal, 1.0 / 3.0) : (7.787 * zVal) + 16.0 / 116.0

            let l = (116.0 * fy) - 16.0
            let a = 500.0 * (fx - fy)
            let bOut = 200.0 * (fy - fz)

            return CGColor(space: space, componentArray: [l, a, bOut, alpha])

        default:
            return nil
        }
    }
}

// MARK: - Equatable

extension CGColor: Equatable {
    public static func == (lhs: CGColor, rhs: CGColor) -> Bool {
        guard lhs.colorSpace == rhs.colorSpace else { return false }
        guard lhs.components?.count == rhs.components?.count else { return false }
        guard let lhsComponents = lhs.components, let rhsComponents = rhs.components else {
            return lhs.components == nil && rhs.components == nil
        }
        return lhsComponents == rhsComponents
    }
}

// MARK: - Hashable

extension CGColor: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(colorSpace)
        if let components = components {
            for component in components {
                hasher.combine(component)
            }
        }
    }
}

