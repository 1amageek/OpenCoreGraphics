//
//  CGAffineTransform.swift
//  OpenCoreGraphics
//
//  Created by OpenCoreGraphics contributors.
//

import Foundation

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

    /// Creates an affine transformation matrix with all entries set to zero.
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

    /// Creates an affine transformation matrix with the specified values.
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
        // Reconstruct the matrix from components:
        // M = T * R * Sh * S
        // where T = translation, R = rotation, Sh = shear, S = scale
        let cosR = cos(components.rotation.native)
        let sinR = sin(components.rotation.native)
        let scaleX = components.scale.width.native
        let scaleY = components.scale.height.native
        let shear = components.horizontalShear.native

        // Combined matrix calculation
        self.a = CGFloat(cosR * scaleX)
        self.b = CGFloat(sinR * scaleX)
        self.c = CGFloat((cosR * shear - sinR) * scaleY)
        self.d = CGFloat((sinR * shear + cosR) * scaleY)
        self.tx = components.translation.dx
        self.ty = components.translation.dy
    }

    /// Creates an affine transformation matrix with the specified translation values.
    @inlinable
    public init(translationX tx: CGFloat, y ty: CGFloat) {
        self.a = 1
        self.b = 0
        self.c = 0
        self.d = 1
        self.tx = tx
        self.ty = ty
    }

    /// Creates an affine transformation matrix with the specified scaling values.
    @inlinable
    public init(scaleX sx: CGFloat, y sy: CGFloat) {
        self.a = sx
        self.b = 0
        self.c = 0
        self.d = sy
        self.tx = 0
        self.ty = 0
    }

    /// Creates an affine transformation matrix with the specified rotation value.
    @inlinable
    public init(rotationAngle angle: CGFloat) {
        let cosAngle = CGFloat(cos(angle.native))
        let sinAngle = CGFloat(sin(angle.native))
        self.a = cosAngle
        self.b = sinAngle
        self.c = -sinAngle
        self.d = cosAngle
        self.tx = 0
        self.ty = 0
    }

    // MARK: - Type Properties

    /// The identity transform.
    @inlinable
    public static var identity: CGAffineTransform {
        return CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 0, ty: 0)
    }

    // MARK: - Instance Properties

    /// Returns whether this transform is the identity transform.
    @inlinable
    public var isIdentity: Bool {
        return a == 1 && b == 0 && c == 0 && d == 1 && tx == 0 && ty == 0
    }

    // MARK: - Instance Methods

    /// Returns an affine transformation matrix constructed by translating an existing
    /// affine transform.
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

    /// Returns an affine transformation matrix constructed by scaling an existing
    /// affine transform.
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

    /// Returns an affine transformation matrix constructed by rotating an existing
    /// affine transform.
    @inlinable
    public func rotated(by angle: CGFloat) -> CGAffineTransform {
        let cosAngle = CGFloat(cos(angle.native))
        let sinAngle = CGFloat(sin(angle.native))
        return CGAffineTransform(
            a: a * cosAngle + c * sinAngle,
            b: b * cosAngle + d * sinAngle,
            c: c * cosAngle - a * sinAngle,
            d: d * cosAngle - b * sinAngle,
            tx: tx,
            ty: ty
        )
    }

    /// Returns an affine transformation matrix constructed by inverting an existing
    /// affine transform.
    @inlinable
    public func inverted() -> CGAffineTransform {
        let determinant = a * d - b * c
        if determinant == 0 {
            return self
        }
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

    /// Returns an affine transformation matrix constructed by combining two existing
    /// affine transforms.
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

    /// Decomposes the affine transform into its component parts.
    @inlinable
    public func decomposed() -> CGAffineTransformComponents {
        // Extract translation
        let translation = CGVector(dx: tx, dy: ty)

        // Calculate scale and rotation
        let scaleX = sqrt(a.native * a.native + b.native * b.native)
        let scaleY = sqrt(c.native * c.native + d.native * d.native)

        // Determine sign of scale based on determinant
        let det = a.native * d.native - b.native * c.native
        let signY = det < 0 ? -1.0 : 1.0

        let scale = CGSize(width: scaleX, height: scaleY * signY)

        // Calculate rotation
        let rotation = atan2(b.native, a.native)

        // Calculate shear
        let cosR = cos(rotation)
        let sinR = sin(rotation)
        var shear = 0.0
        if abs(cosR) > 0.0001 {
            shear = (c.native / (scaleY * signY) + sinR) / cosR
        }

        return CGAffineTransformComponents(
            scale: scale,
            horizontalShear: CGFloat(shear),
            rotation: CGFloat(rotation),
            translation: translation
        )
    }
}

// MARK: - Equatable

extension CGAffineTransform: Equatable {
    @inlinable
    public static func == (lhs: CGAffineTransform, rhs: CGAffineTransform) -> Bool {
        return lhs.a == rhs.a &&
               lhs.b == rhs.b &&
               lhs.c == rhs.c &&
               lhs.d == rhs.d &&
               lhs.tx == rhs.tx &&
               lhs.ty == rhs.ty
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
        a = try container.decode(CGFloat.self, forKey: .a)
        b = try container.decode(CGFloat.self, forKey: .b)
        c = try container.decode(CGFloat.self, forKey: .c)
        d = try container.decode(CGFloat.self, forKey: .d)
        tx = try container.decode(CGFloat.self, forKey: .tx)
        ty = try container.decode(CGFloat.self, forKey: .ty)
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
        return "CGAffineTransform(a: \(a.native), b: \(b.native), c: \(c.native), d: \(d.native), tx: \(tx.native), ty: \(ty.native))"
    }
}
