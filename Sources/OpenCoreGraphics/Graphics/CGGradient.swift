//
//  CGGradient.swift
//  OpenCoreGraphics
//
//  Created by OpenCoreGraphics contributors.
//


import Foundation


/// A definition for a smooth transition between colors for drawing
/// radial and axial gradient fills.
///
/// A gradient defines a smooth transition between colors across an area.
/// Colors can be provided as component values or as CGColor objects.
public class CGGradient: @unchecked Sendable {

    /// The color space in which the gradient colors are specified.
    public let colorSpace: CGColorSpace

    /// The colors that make up the gradient.
    public let colors: [CGColor]

    /// The locations of the colors in the gradient, in the range 0.0 to 1.0.
    public let locations: [CGFloat]?

    /// The content headroom for HDR content.
    public let contentHeadroom: Float

    /// The number of color-location pairs in the gradient.
    public var numberOfLocations: Int {
        return colors.count
    }

    // MARK: - Initializers

    /// Creates a gradient object from a color space, color components, locations, and count.
    public init?(colorSpace: CGColorSpace, colorComponents: UnsafePointer<CGFloat>,
                 locations: UnsafePointer<CGFloat>?, count: Int) {
        guard count > 0 else { return nil }

        self.colorSpace = colorSpace
        self.contentHeadroom = 1.0
        let componentsPerColor = colorSpace.numberOfComponents + 1 // +1 for alpha

        var colorsArray: [CGColor] = []
        for i in 0..<count {
            var components: [CGFloat] = []
            for j in 0..<componentsPerColor {
                components.append(colorComponents[i * componentsPerColor + j])
            }
            colorsArray.append(CGColor(space: colorSpace, componentArray: components))
        }
        self.colors = colorsArray

        if let locations = locations {
            var locationsArray: [CGFloat] = []
            for i in 0..<count {
                locationsArray.append(locations[i])
            }
            self.locations = locationsArray
        } else {
            self.locations = nil
        }
    }

    /// Creates a gradient object with HDR headroom support.
    ///
    /// - Parameters:
    ///   - headroom: The content headroom for HDR.
    ///   - colorSpace: The color space for the gradient.
    ///   - colorComponents: A pointer to color component values.
    ///   - locations: A pointer to location values.
    ///   - count: The number of color-location pairs.
    public init?(headroom: Float, colorSpace: CGColorSpace, colorComponents: UnsafePointer<CGFloat>,
                 locations: UnsafePointer<CGFloat>?, count: Int) {
        guard count > 0 else { return nil }
        guard headroom >= 1.0 else { return nil }

        self.colorSpace = colorSpace
        self.contentHeadroom = headroom
        let componentsPerColor = colorSpace.numberOfComponents + 1 // +1 for alpha

        var colorsArray: [CGColor] = []
        for i in 0..<count {
            var components: [CGFloat] = []
            for j in 0..<componentsPerColor {
                components.append(colorComponents[i * componentsPerColor + j])
            }
            colorsArray.append(CGColor(space: colorSpace, componentArray: components))
        }
        self.colors = colorsArray

        if let locations = locations {
            var locationsArray: [CGFloat] = []
            for i in 0..<count {
                locationsArray.append(locations[i])
            }
            self.locations = locationsArray
        } else {
            self.locations = nil
        }
    }

    /// Creates a gradient object from a color space, colors, and locations.
    public init?(colorSpace: CGColorSpace, colors: [CGColor], locations: [CGFloat]?) {
        guard !colors.isEmpty else { return nil }
        if let locations = locations {
            guard locations.count == colors.count else { return nil }
        }

        self.colorSpace = colorSpace
        self.colors = colors
        self.locations = locations
        self.contentHeadroom = 1.0
    }

    /// Creates a gradient object from a color space and array of colors.
    ///
    /// - Parameters:
    ///   - colorsSpace: The color space for the gradient (can be nil to use colors' space).
    ///   - colors: An array of CGColor objects.
    ///   - locations: A pointer to location values (can be nil for even distribution).
    public init?(colorsSpace: CGColorSpace?, colors: [CGColor], locations: UnsafePointer<CGFloat>?) {
        guard !colors.isEmpty else { return nil }

        self.colorSpace = colorsSpace ?? colors[0].colorSpace ?? .deviceRGB
        self.colors = colors
        self.contentHeadroom = 1.0

        if let locations = locations {
            var locationsArray: [CGFloat] = []
            for i in 0..<colors.count {
                locationsArray.append(locations[i])
            }
            self.locations = locationsArray
        } else {
            self.locations = nil
        }
    }

    /// Creates a gradient object from an array of colors and locations.
    public init?(colors: [CGColor], locations: [CGFloat]?) {
        guard !colors.isEmpty else { return nil }
        if let locations = locations {
            guard locations.count == colors.count else { return nil }
        }

        // Use the color space from the first color, or default to device RGB
        self.colorSpace = colors[0].colorSpace ?? .deviceRGB
        self.colors = colors
        self.locations = locations
        self.contentHeadroom = 1.0
    }

    // MARK: - Internal Initializer

    /// Internal initializer for creating gradient with direct arrays.
    private init(colorSpace: CGColorSpace, colorsArray: [CGColor], locationsArray: [CGFloat]?, headroom: Float = 1.0) {
        self.colorSpace = colorSpace
        self.colors = colorsArray
        self.locations = locationsArray
        self.contentHeadroom = headroom
    }

    // MARK: - Type ID

    /// Returns the Core Foundation type identifier for CGGradient objects.
    public class var typeID: UInt {
        return 0 // Placeholder
    }

    // MARK: - Color Interpolation

    /// Interpolates a color at the given position (0.0 to 1.0).
    public func color(at position: CGFloat) -> CGColor? {
        guard !colors.isEmpty else { return nil }

        let pos = max(0, min(1, position))

        // Calculate effective locations
        let effectiveLocations: [CGFloat]
        if let locations = self.locations {
            effectiveLocations = locations
        } else {
            // Generate evenly spaced locations
            effectiveLocations = (0..<colors.count).map { i in
                CGFloat(Double(i) / Double(colors.count - 1))
            }
        }

        // Find the two colors to interpolate between
        var lowerIndex = 0
        var upperIndex = colors.count - 1

        for i in 0..<effectiveLocations.count {
            if effectiveLocations[i] <= pos {
                lowerIndex = i
            }
            if effectiveLocations[i] >= pos && i < upperIndex {
                upperIndex = i
                break
            }
        }

        if lowerIndex == upperIndex {
            return colors[lowerIndex]
        }

        // Interpolate
        let lowerLoc = effectiveLocations[lowerIndex]
        let upperLoc = effectiveLocations[upperIndex]
        let t = (pos - lowerLoc) / (upperLoc - lowerLoc)

        return interpolateColors(colors[lowerIndex], colors[upperIndex], t: t)
    }

    private func interpolateColors(_ c1: CGColor, _ c2: CGColor, t: CGFloat) -> CGColor? {
        guard let comp1 = c1.components, let comp2 = c2.components else { return nil }
        guard comp1.count == comp2.count else { return nil }

        var interpolated: [CGFloat] = []
        for i in 0..<comp1.count {
            let value = comp1[i] + (comp2[i] - comp1[i]) * t
            interpolated.append(value)
        }

        return CGColor(space: colorSpace, componentArray: interpolated)
    }
}


