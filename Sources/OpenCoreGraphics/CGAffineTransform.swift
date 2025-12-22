//
//  CGAffineTransform.swift
//  OpenCoreGraphics
//
//  Created by OpenCoreGraphics contributors.
//

import Foundation

#if arch(wasm32)

/// An affine transformation matrix for use in drawing 2D graphics.
@frozen
public struct CGAffineTransform: Sendable {

    /// The entry at position [1,1] in the matrix.
    public var a: CGFloat

    /// The entry at position [1,2] in the matrix.
    public var b: CGFloat

    /// The entry at position [2,1] in the matrix.
    public var c: CGFloat

    /// The entry at position [2,2] in the matrix.
    public var d: CGFloat

    /// The entry at position [3,1] in the matrix.
    public var tx: CGFloat

    /// The entry at position [3,2] in the matrix.
    public var ty: CGFloat

    /// Creates an affine transformation matrix with all values set to zero.
    @inlinable
    public init() {
        self.a = 0
        self.b = 0
        self.c = 0
        self.d = 0
        self.tx = 0
        self.ty = 0
    }

    /// Creates an affine transformation matrix with the specified values.
    @inlinable
    public init(a: CGFloat, b: CGFloat, c: CGFloat, d: CGFloat, tx: CGFloat, ty: CGFloat) {
        self.a = a
        self.b = b
        self.c = c
        self.d = d
        self.tx = tx
        self.ty = ty
    }

    /// Creates an affine transformation matrix with the specified values (positional).
    @inlinable
    public init(_ a: CGFloat, _ b: CGFloat, _ c: CGFloat, _ d: CGFloat, _ tx: CGFloat, _ ty: CGFloat) {
        self.a = a
        self.b = b
        self.c = c
        self.d = d
        self.tx = tx
        self.ty = ty
    }

    /// Creates an affine transformation matrix from components.
    @inlinable
    public init(_ components: CGAffineTransformComponents) {
        self = components.transform
    }

    /// Creates an affine transformation matrix from a translation.
    @inlinable
    public init(translationX tx: CGFloat, y ty: CGFloat) {
        self.init(a: 1, b: 0, c: 0, d: 1, tx: tx, ty: ty)
    }

    /// Creates an affine transformation matrix from scaling values.
    @inlinable
    public init(scaleX sx: CGFloat, y sy: CGFloat) {
        self.init(a: sx, b: 0, c: 0, d: sy, tx: 0, ty: 0)
    }

    /// Creates an affine transformation matrix from a rotation value.
    @inlinable
    public init(rotationAngle angle: CGFloat) {
        let cosAngle = cos(angle)
        let sinAngle = sin(angle)
        self.init(a: cosAngle, b: sinAngle, c: -sinAngle, d: cosAngle, tx: 0, ty: 0)
    }

    /// The identity transform.
    public static let identity = CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 0, ty: 0)

    /// Returns whether this transform is the identity transform.
    @inlinable
    public var isIdentity: Bool {
        return a == 1 && b == 0 && c == 0 && d == 1 && tx == 0 && ty == 0
    }

    /// Returns an affine transformation matrix constructed by translating an existing one.
    @inlinable
    public func translatedBy(x tx: CGFloat, y ty: CGFloat) -> CGAffineTransform {
        return CGAffineTransform(
            a: a,
            b: b,
            c: c,
            d: d,
            tx: self.tx + a * tx + c * ty,
            ty: self.ty + b * tx + d * ty
        )
    }

    /// Returns an affine transformation matrix constructed by scaling an existing one.
    @inlinable
    public func scaledBy(x sx: CGFloat, y sy: CGFloat) -> CGAffineTransform {
        return CGAffineTransform(
            a: a * sx,
            b: b * sx,
            c: c * sy,
            d: d * sy,
            tx: tx,
            ty: ty
        )
    }

    /// Returns an affine transformation matrix constructed by rotating an existing one.
    @inlinable
    public func rotated(by angle: CGFloat) -> CGAffineTransform {
        let cosAngle = cos(angle)
        let sinAngle = sin(angle)
        return CGAffineTransform(
            a: a * cosAngle + c * sinAngle,
            b: b * cosAngle + d * sinAngle,
            c: c * cosAngle - a * sinAngle,
            d: d * cosAngle - b * sinAngle,
            tx: tx,
            ty: ty
        )
    }

    /// Returns an affine transformation matrix constructed by inverting an existing one.
    ///
    /// If the transform is singular (non-invertible, i.e., determinant is zero),
    /// returns the identity transform. This matches CoreGraphics behavior and
    /// ensures `convertToUserSpace()` returns predictable results.
    @inlinable
    public func inverted() -> CGAffineTransform {
        let determinant = a * d - b * c
        guard determinant != 0 else { return .identity }
        let invDet = 1.0 / determinant
        return CGAffineTransform(
            a: d * invDet,
            b: -b * invDet,
            c: -c * invDet,
            d: a * invDet,
            tx: (c * ty - d * tx) * invDet,
            ty: (b * tx - a * ty) * invDet
        )
    }

    /// Returns an affine transformation matrix constructed by combining two existing ones.
    @inlinable
    public func concatenating(_ t2: CGAffineTransform) -> CGAffineTransform {
        return CGAffineTransform(
            a: a * t2.a + b * t2.c,
            b: a * t2.b + b * t2.d,
            c: c * t2.a + d * t2.c,
            d: c * t2.b + d * t2.d,
            tx: tx * t2.a + ty * t2.c + t2.tx,
            ty: tx * t2.b + ty * t2.d + t2.ty
        )
    }
}

// MARK: - Equatable

extension CGAffineTransform: Equatable {
    @inlinable
    public static func == (lhs: CGAffineTransform, rhs: CGAffineTransform) -> Bool {
        return lhs.a == rhs.a && lhs.b == rhs.b && lhs.c == rhs.c &&
               lhs.d == rhs.d && lhs.tx == rhs.tx && lhs.ty == rhs.ty
    }
}

// MARK: - Hashable

extension CGAffineTransform: Hashable {
    @inlinable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(a)
        hasher.combine(b)
        hasher.combine(c)
        hasher.combine(d)
        hasher.combine(tx)
        hasher.combine(ty)
    }
}

// MARK: - Codable

extension CGAffineTransform: Codable {
    enum CodingKeys: String, CodingKey {
        case a, b, c, d, tx, ty
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.a = try container.decode(CGFloat.self, forKey: .a)
        self.b = try container.decode(CGFloat.self, forKey: .b)
        self.c = try container.decode(CGFloat.self, forKey: .c)
        self.d = try container.decode(CGFloat.self, forKey: .d)
        self.tx = try container.decode(CGFloat.self, forKey: .tx)
        self.ty = try container.decode(CGFloat.self, forKey: .ty)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(a, forKey: .a)
        try container.encode(b, forKey: .b)
        try container.encode(c, forKey: .c)
        try container.encode(d, forKey: .d)
        try container.encode(tx, forKey: .tx)
        try container.encode(ty, forKey: .ty)
    }
}

// MARK: - CustomDebugStringConvertible

extension CGAffineTransform: CustomDebugStringConvertible {
    public var debugDescription: String {
        return "CGAffineTransform(a: \(a), b: \(b), c: \(c), d: \(d), tx: \(tx), ty: \(ty))"
    }
}

// MARK: - Decomposition

extension CGAffineTransform {
    /// Decomposes this transform into its component parts.
    public func decomposed() -> CGAffineTransformComponents {
        // Extract translation
        let translation = CGVector(dx: tx, dy: ty)

        // Extract scale
        let scaleX = sqrt(a * a + b * b)
        let scaleY = sqrt(c * c + d * d)

        // Determine sign of scale based on determinant
        let determinant = a * d - b * c
        let signY: CGFloat = determinant < 0 ? -1 : 1

        let scale = CGSize(width: scaleX, height: scaleY * signY)

        // Extract rotation
        let rotation = atan2(b, a)

        // Extract shear
        let shear = (a * c + b * d) / (scaleX * scaleY)

        return CGAffineTransformComponents(
            scale: scale,
            horizontalShear: shear,
            rotation: rotation,
            translation: translation
        )
    }
}

#else

extension CGAffineTransform {

    /// The identity transform.
    public static let identity = CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 0, ty: 0)

    /// Returns whether this transform is the identity transform.
    @inlinable
    public var isIdentity: Bool {
        return a == 1 && b == 0 && c == 0 && d == 1 && tx == 0 && ty == 0
    }

    /// Returns an affine transformation matrix constructed by translating an existing one.
    @inlinable
    public func translatedBy(x tx: CGFloat, y ty: CGFloat) -> CGAffineTransform {
        return CGAffineTransform(
            a: a,
            b: b,
            c: c,
            d: d,
            tx: self.tx + a * tx + c * ty,
            ty: self.ty + b * tx + d * ty
        )
    }

    /// Returns an affine transformation matrix constructed by scaling an existing one.
    @inlinable
    public func scaledBy(x sx: CGFloat, y sy: CGFloat) -> CGAffineTransform {
        return CGAffineTransform(
            a: a * sx,
            b: b * sx,
            c: c * sy,
            d: d * sy,
            tx: tx,
            ty: ty
        )
    }

    /// Returns an affine transformation matrix constructed by rotating an existing one.
    @inlinable
    public func rotated(by angle: CGFloat) -> CGAffineTransform {
        let cosAngle = cos(angle)
        let sinAngle = sin(angle)
        return CGAffineTransform(
            a: a * cosAngle + c * sinAngle,
            b: b * cosAngle + d * sinAngle,
            c: c * cosAngle - a * sinAngle,
            d: d * cosAngle - b * sinAngle,
            tx: tx,
            ty: ty
        )
    }

    /// Returns an affine transformation matrix constructed by inverting an existing one.
    ///
    /// If the transform is singular (non-invertible, i.e., determinant is zero),
    /// returns the identity transform. This matches CoreGraphics behavior and
    /// ensures `convertToUserSpace()` returns predictable results.
    @inlinable
    public func inverted() -> CGAffineTransform {
        let determinant = a * d - b * c
        guard determinant != 0 else { return .identity }
        let invDet = 1.0 / determinant
        return CGAffineTransform(
            a: d * invDet,
            b: -b * invDet,
            c: -c * invDet,
            d: a * invDet,
            tx: (c * ty - d * tx) * invDet,
            ty: (b * tx - a * ty) * invDet
        )
    }

    /// Returns an affine transformation matrix constructed by combining two existing ones.
    @inlinable
    public func concatenating(_ t2: CGAffineTransform) -> CGAffineTransform {
        return CGAffineTransform(
            a: a * t2.a + b * t2.c,
            b: a * t2.b + b * t2.d,
            c: c * t2.a + d * t2.c,
            d: c * t2.b + d * t2.d,
            tx: tx * t2.a + ty * t2.c + t2.tx,
            ty: tx * t2.b + ty * t2.d + t2.ty
        )
    }
}

#endif
