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

        // Simple conversion - just copy components if same model
        if colorSpace?.model == space.model {
            return CGColor(space: space, componentArray: components)
        }

        // For different models, we would need actual color conversion
        // This is a simplified implementation
        switch (colorSpace?.model, space.model) {
        case (.monochrome, .rgb):
            // Gray to RGB
            let gray = components[0]
            let alpha = components.count > 1 ? components[1] : CGFloat(1.0)
            return CGColor(space: space, componentArray: [gray, gray, gray, alpha])
        case (.rgb, .monochrome):
            // RGB to Gray (using luminance)
            let r = components[0]
            let g = components[1]
            let b = components[2]
            let gray = 0.299 * r + 0.587 * g + 0.114 * b
            let alpha = components.count > 3 ? components[3] : CGFloat(1.0)
            return CGColor(space: space, componentArray: [gray, alpha])
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

