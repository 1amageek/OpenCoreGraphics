//
//  CGAffineTransformComponents.swift
//  OpenCoreGraphics
//
//  Created by OpenCoreGraphics contributors.
//

/// The separate components of an affine transform matrix.
public struct CGAffineTransformComponents: Sendable {

    /// The scale component of the transform.
    public var scale: CGSize

    /// The horizontal shear component of the transform.
    public var horizontalShear: CGFloat

    /// The rotation component of the transform (in radians).
    public var rotation: CGFloat

    /// The translation component of the transform.
    public var translation: CGVector

    /// Creates components with default values (identity transform components).
    @inlinable
    public init() {
        self.scale = CGSize(width: 1, height: 1)
        self.horizontalShear = 0
        self.rotation = 0
        self.translation = CGVector()
    }

    /// Creates components with the specified values.
    @inlinable
    public init(scale: CGSize, horizontalShear: CGFloat, rotation: CGFloat, translation: CGVector) {
        self.scale = scale
        self.horizontalShear = horizontalShear
        self.rotation = rotation
        self.translation = translation
    }

    /// Creates components with the specified values (Double version).
    @inlinable
    public init(scale: CGSize, horizontalShear: Double, rotation: Double, translation: CGVector) {
        self.scale = scale
        self.horizontalShear = CGFloat(horizontalShear)
        self.rotation = CGFloat(rotation)
        self.translation = translation
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
        scale = try container.decode(CGSize.self, forKey: .scale)
        horizontalShear = try container.decode(CGFloat.self, forKey: .horizontalShear)
        rotation = try container.decode(CGFloat.self, forKey: .rotation)
        translation = try container.decode(CGVector.self, forKey: .translation)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(scale, forKey: .scale)
        try container.encode(horizontalShear, forKey: .horizontalShear)
        try container.encode(rotation, forKey: .rotation)
        try container.encode(translation, forKey: .translation)
    }
}
