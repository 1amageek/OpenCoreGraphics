//
//  CGAffineTransformComponents.swift
//  OpenCoreGraphics
//
//  Created by OpenCoreGraphics contributors.
//

#if arch(wasm32)

import Foundation

/// A structure that defines the decomposed components of an affine transformation matrix.
@frozen
public struct CGAffineTransformComponents: Sendable {

    /// The scale component of the transformation.
    public var scale: CGSize

    /// The horizontal shear component of the transformation.
    public var horizontalShear: CGFloat

    /// The rotation component of the transformation (in radians).
    public var rotation: CGFloat

    /// The translation component of the transformation.
    public var translation: CGVector

    /// Creates transform components with the specified values.
    @inlinable
    public init(
        scale: CGSize = CGSize(width: 1, height: 1),
        horizontalShear: CGFloat = 0,
        rotation: CGFloat = 0,
        translation: CGVector = .zero
    ) {
        self.scale = scale
        self.horizontalShear = horizontalShear
        self.rotation = rotation
        self.translation = translation
    }

    /// Creates an affine transformation matrix from these components.
    @inlinable
    public var transform: CGAffineTransform {
        // Build transform in order: scale, shear, rotation, translation
        // Translation is applied last in world space
        var t = CGAffineTransform.identity

        // Apply scale
        t = t.scaledBy(x: scale.width, y: scale.height)

        // Apply shear
        if horizontalShear != 0 {
            t = t.concatenating(CGAffineTransform(a: 1, b: 0, c: horizontalShear, d: 1, tx: 0, ty: 0))
        }

        // Apply rotation
        if rotation != 0 {
            t = t.rotated(by: rotation)
        }

        // Apply translation (in world space, so we set tx/ty directly)
        t.tx = translation.dx
        t.ty = translation.dy

        return t
    }
}

// MARK: - Equatable

extension CGAffineTransformComponents: Equatable {
    @inlinable
    public static func == (lhs: CGAffineTransformComponents, rhs: CGAffineTransformComponents) -> Bool {
        return lhs.scale == rhs.scale &&
               lhs.horizontalShear == rhs.horizontalShear &&
               lhs.rotation == rhs.rotation &&
               lhs.translation == rhs.translation
    }
}

// MARK: - Hashable

extension CGAffineTransformComponents: Hashable {
    @inlinable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(scale)
        hasher.combine(horizontalShear)
        hasher.combine(rotation)
        hasher.combine(translation)
    }
}

// MARK: - Codable

extension CGAffineTransformComponents: Codable {
    enum CodingKeys: String, CodingKey {
        case scale
        case horizontalShear
        case rotation
        case translation
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.scale = try container.decode(CGSize.self, forKey: .scale)
        self.horizontalShear = try container.decode(CGFloat.self, forKey: .horizontalShear)
        self.rotation = try container.decode(CGFloat.self, forKey: .rotation)
        self.translation = try container.decode(CGVector.self, forKey: .translation)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(scale, forKey: .scale)
        try container.encode(horizontalShear, forKey: .horizontalShear)
        try container.encode(rotation, forKey: .rotation)
        try container.encode(translation, forKey: .translation)
    }
}

// MARK: - CustomDebugStringConvertible

extension CGAffineTransformComponents: CustomDebugStringConvertible {
    public var debugDescription: String {
        return "CGAffineTransformComponents(scale: \(scale), horizontalShear: \(horizontalShear), rotation: \(rotation), translation: \(translation))"
    }
}

#endif
