//
//  CGShading.swift
//  OpenCoreGraphics
//
//  Created by OpenCoreGraphics contributors.
//


import Foundation


/// A definition for a smooth transition between colors, controlled by a
/// custom function you provide, for drawing radial and axial gradient fills.
///
/// An alternative to using a CGShading instance is to use the CGGradient type.
/// For applications that run in modern systems, CGGradient objects are much simpler to use.
public class CGShading: @unchecked Sendable {

    /// The type of shading.
    public enum ShadingType {
        case axial
        case radial
    }

    /// The shading type.
    public let type: ShadingType

    /// The color space for the shading.
    public let colorSpace: CGColorSpace

    /// The start point for the shading.
    public let startPoint: CGPoint

    /// The end point for the shading.
    public let endPoint: CGPoint

    /// The start radius for radial shading.
    public let startRadius: CGFloat

    /// The end radius for radial shading.
    public let endRadius: CGFloat

    /// The function that defines the color transition.
    public let function: CGFunction

    /// Whether to extend the shading beyond the start point.
    public let extendStart: Bool

    /// Whether to extend the shading beyond the end point.
    public let extendEnd: Bool

    /// The content headroom for HDR content.
    public let contentHeadroom: Float

    // MARK: - Initializers

    /// Creates a shading object to use for axial shading.
    ///
    /// - Parameters:
    ///   - axialSpace: The color space for the shading.
    ///   - start: The start point for the axis.
    ///   - end: The end point for the axis.
    ///   - function: A function that defines the color transition.
    ///   - extendStart: Whether to extend beyond the start point.
    ///   - extendEnd: Whether to extend beyond the end point.
    public init?(axialSpace: CGColorSpace,
                 start: CGPoint,
                 end: CGPoint,
                 function: CGFunction,
                 extendStart: Bool,
                 extendEnd: Bool) {
        self.type = .axial
        self.colorSpace = axialSpace
        self.startPoint = start
        self.endPoint = end
        self.startRadius = 0
        self.endRadius = 0
        self.function = function
        self.extendStart = extendStart
        self.extendEnd = extendEnd
        self.contentHeadroom = 1.0
    }

    /// Creates a shading object to use for axial shading with headroom.
    ///
    /// - Parameters:
    ///   - axialHeadroom: The content headroom for HDR.
    ///   - space: The color space for the shading.
    ///   - start: The start point for the axis.
    ///   - end: The end point for the axis.
    ///   - function: A function that defines the color transition.
    ///   - extendStart: Whether to extend beyond the start point.
    ///   - extendEnd: Whether to extend beyond the end point.
    public init?(axialHeadroom: Float,
                 space: CGColorSpace,
                 start: CGPoint,
                 end: CGPoint,
                 function: CGFunction,
                 extendStart: Bool,
                 extendEnd: Bool) {
        self.type = .axial
        self.colorSpace = space
        self.startPoint = start
        self.endPoint = end
        self.startRadius = 0
        self.endRadius = 0
        self.function = function
        self.extendStart = extendStart
        self.extendEnd = extendEnd
        self.contentHeadroom = axialHeadroom
    }

    /// Creates a shading object to use for radial shading.
    ///
    /// - Parameters:
    ///   - radialSpace: The color space for the shading.
    ///   - start: The center of the starting circle.
    ///   - startRadius: The radius of the starting circle.
    ///   - end: The center of the ending circle.
    ///   - endRadius: The radius of the ending circle.
    ///   - function: A function that defines the color transition.
    ///   - extendStart: Whether to extend beyond the starting circle.
    ///   - extendEnd: Whether to extend beyond the ending circle.
    public init?(radialSpace: CGColorSpace,
                 start: CGPoint,
                 startRadius: CGFloat,
                 end: CGPoint,
                 endRadius: CGFloat,
                 function: CGFunction,
                 extendStart: Bool,
                 extendEnd: Bool) {
        self.type = .radial
        self.colorSpace = radialSpace
        self.startPoint = start
        self.endPoint = end
        self.startRadius = startRadius
        self.endRadius = endRadius
        self.function = function
        self.extendStart = extendStart
        self.extendEnd = extendEnd
        self.contentHeadroom = 1.0
    }

    /// Creates a shading object to use for radial shading with headroom.
    ///
    /// - Parameters:
    ///   - radialHeadroom: The content headroom for HDR.
    ///   - space: The color space for the shading.
    ///   - start: The center of the starting circle.
    ///   - startRadius: The radius of the starting circle.
    ///   - end: The center of the ending circle.
    ///   - endRadius: The radius of the ending circle.
    ///   - function: A function that defines the color transition.
    ///   - extendStart: Whether to extend beyond the starting circle.
    ///   - extendEnd: Whether to extend beyond the ending circle.
    public init?(radialHeadroom: Float,
                 space: CGColorSpace,
                 start: CGPoint,
                 startRadius: CGFloat,
                 end: CGPoint,
                 endRadius: CGFloat,
                 function: CGFunction,
                 extendStart: Bool,
                 extendEnd: Bool) {
        self.type = .radial
        self.colorSpace = space
        self.startPoint = start
        self.endPoint = end
        self.startRadius = startRadius
        self.endRadius = endRadius
        self.function = function
        self.extendStart = extendStart
        self.extendEnd = extendEnd
        self.contentHeadroom = radialHeadroom
    }

    // MARK: - Type ID

    /// Returns the Core Foundation type identifier for Core Graphics shading objects.
    public class var typeID: UInt {
        return 0 // Placeholder
    }
}

// MARK: - Equatable

extension CGShading: Equatable {
    public static func == (lhs: CGShading, rhs: CGShading) -> Bool {
        return lhs === rhs
    }
}

// MARK: - Hashable

extension CGShading: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}

// MARK: - Color Evaluation

extension CGShading {
    /// Evaluates the color at the specified parametric position.
    ///
    /// - Parameter t: A value from 0.0 to 1.0 representing the position along the shading.
    /// - Returns: The interpolated color at the given position, or nil if evaluation fails.
    public func color(at t: CGFloat) -> CGColor? {
        // Clamp t to valid range based on extend settings
        var effectiveT = t
        if !extendStart && t < 0 {
            return nil
        }
        if !extendEnd && t > 1 {
            return nil
        }
        effectiveT = max(0, min(1, t))

        // Evaluate the function
        let input: [CGFloat] = [effectiveT]
        let output = function.evaluate(input: input)

        // The function should output color components
        let expectedComponents = colorSpace.numberOfComponents
        guard output.count >= expectedComponents else { return nil }

        // Build complete component array with alpha
        var components = Array(output.prefix(expectedComponents))

        // Add alpha if not provided by function
        if output.count > expectedComponents {
            components.append(output[expectedComponents])
        } else {
            components.append(1.0)  // Default alpha
        }

        return CGColor(space: colorSpace, componentArray: components)
    }

    /// Generates an array of color stops for rendering.
    ///
    /// This method samples the shading function at regular intervals to create
    /// a lookup table suitable for GPU-based rendering.
    ///
    /// - Parameter steps: The number of color stops to generate. Default is 256.
    /// - Returns: An array of tuples containing the parametric position and corresponding color.
    public func generateColorStops(steps: Int = 256) -> [(location: CGFloat, color: CGColor)] {
        guard steps > 1 else { return [] }

        var stops: [(location: CGFloat, color: CGColor)] = []
        stops.reserveCapacity(steps)

        for i in 0..<steps {
            let t = CGFloat(i) / CGFloat(steps - 1)
            if let color = self.color(at: t) {
                stops.append((t, color))
            }
        }

        return stops
    }

    /// Computes the parametric value t for a given point in axial shading.
    ///
    /// - Parameter point: The point to evaluate.
    /// - Returns: The parametric value t (may be outside 0-1 range), or 0 if this is not an axial shading.
    public func axialParametricValue(at point: CGPoint) -> CGFloat {
        guard type == .axial else { return 0 }

        let axis = CGPoint(x: endPoint.x - startPoint.x, y: endPoint.y - startPoint.y)
        let axisLengthSquared = axis.x * axis.x + axis.y * axis.y

        guard axisLengthSquared > 0 else { return 0 }

        let toPoint = CGPoint(x: point.x - startPoint.x, y: point.y - startPoint.y)
        let dot = toPoint.x * axis.x + toPoint.y * axis.y

        return dot / axisLengthSquared
    }

    /// Computes the parametric value t for a given point in radial shading.
    ///
    /// - Parameter point: The point to evaluate.
    /// - Returns: The parametric value t, or nil if the point is not covered by the shading or this is not a radial shading.
    public func radialParametricValue(at point: CGPoint) -> CGFloat? {
        guard type == .radial else { return nil }

        // For radial gradient: find t such that point lies on the circle
        // center(t) = startPoint + t * (endPoint - startPoint)
        // radius(t) = startRadius + t * (endRadius - startRadius)
        // |point - center(t)| = radius(t)

        let dx = endPoint.x - startPoint.x
        let dy = endPoint.y - startPoint.y
        let dr = endRadius - startRadius

        let px = point.x - startPoint.x
        let py = point.y - startPoint.y

        // Quadratic equation: At² + Bt + C = 0
        let A = dx * dx + dy * dy - dr * dr
        let B = -2 * (px * dx + py * dy + startRadius * dr)
        let C = px * px + py * py - startRadius * startRadius

        // Handle degenerate case (A ≈ 0)
        if abs(A) < 1e-10 {
            if abs(B) < 1e-10 {
                return nil
            }
            return -C / B
        }

        let discriminant = B * B - 4 * A * C
        if discriminant < 0 {
            return nil
        }

        let sqrtDisc = sqrt(discriminant)
        let t1 = (-B - sqrtDisc) / (2 * A)
        let t2 = (-B + sqrtDisc) / (2 * A)

        // Return the larger valid t value (for proper layering)
        if t2 >= 0 || extendStart {
            if t2 <= 1 || extendEnd {
                return t2
            }
        }
        if t1 >= 0 || extendStart {
            if t1 <= 1 || extendEnd {
                return t1
            }
        }

        return nil
    }
}


