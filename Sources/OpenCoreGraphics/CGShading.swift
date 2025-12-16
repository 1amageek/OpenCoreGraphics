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

// MARK: - CGContext Extension

extension CGContext {
    /// Fills the current clipping path using the specified shading.
    public func drawShading(_ shading: CGShading) {
        // In a real implementation, this would render the shading
    }
}
