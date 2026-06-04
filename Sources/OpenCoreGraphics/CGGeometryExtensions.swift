//
//  CGGeometryExtensions.swift
//  OpenCoreGraphics
//
//  Extensions for geometry types to work with CGAffineTransform.
//


import Foundation

// These `applying(_:)` methods are defined unconditionally because
// OpenCoreGraphics does not `import CoreGraphics`: the Swift extension
// surface of CoreGraphics is not automatically visible through Foundation
// on Apple platforms, and this module's own sources depend on these methods.
// Downstream code that imports both CoreGraphics and OpenCoreGraphics will
// see CoreGraphics's implementations take precedence via visibility rules;
// these are source-compatible (identical signature and semantics) with
// Apple's CoreGraphics.

// MARK: - CGPoint Extensions

extension CGPoint {
    /// Returns the point resulting from an affine transformation of an existing point.
    @inlinable
    public func applying(_ t: CGAffineTransform) -> CGPoint {
        return CGPoint(
            x: t.a * x + t.c * y + t.tx,
            y: t.b * x + t.d * y + t.ty
        )
    }
}

// MARK: - CGSize Extensions

extension CGSize {
    /// Returns the size resulting from an affine transformation of an existing size.
    @inlinable
    public func applying(_ t: CGAffineTransform) -> CGSize {
        return CGSize(
            width: t.a * width + t.c * height,
            height: t.b * width + t.d * height
        )
    }
}

// MARK: - CGRect Extensions

extension CGRect {
    /// Returns the rectangle resulting from an affine transformation of an existing rectangle.
    @inlinable
    public func applying(_ t: CGAffineTransform) -> CGRect {
        if t.isIdentity { return self }

        // Transform all four corners
        let p1 = CGPoint(x: minX, y: minY).applying(t)
        let p2 = CGPoint(x: maxX, y: minY).applying(t)
        let p3 = CGPoint(x: minX, y: maxY).applying(t)
        let p4 = CGPoint(x: maxX, y: maxY).applying(t)

        // Find bounding box of transformed corners
        let newMinX = Swift.min(Swift.min(p1.x, p2.x), Swift.min(p3.x, p4.x))
        let newMaxX = Swift.max(Swift.max(p1.x, p2.x), Swift.max(p3.x, p4.x))
        let newMinY = Swift.min(Swift.min(p1.y, p2.y), Swift.min(p3.y, p4.y))
        let newMaxY = Swift.max(Swift.max(p1.y, p2.y), Swift.max(p3.y, p4.y))

        return CGRect(x: newMinX, y: newMinY, width: newMaxX - newMinX, height: newMaxY - newMinY)
    }
}

