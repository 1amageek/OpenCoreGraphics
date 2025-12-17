//
//  CGRect.swift
//  OpenCoreGraphics
//
//  Created by OpenCoreGraphics contributors.
//

import Foundation

/// A structure that contains the location and dimensions of a rectangle.
@frozen
public struct CGRect: Sendable {

    /// A point that specifies the coordinates of the rectangle's origin.
    public var origin: CGPoint

    /// A size that specifies the height and width of the rectangle.
    public var size: CGSize

    /// Creates a rectangle with origin (0,0) and size (0,0).
    @inlinable
    public init() {
        self.origin = CGPoint()
        self.size = CGSize()
    }

    /// Creates a rectangle with the specified origin and size.
    @inlinable
    public init(origin: CGPoint, size: CGSize) {
        self.origin = origin
        self.size = size
    }

    /// Creates a rectangle with the specified coordinates and dimensions.
    @inlinable
    public init(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
        self.origin = CGPoint(x: x, y: y)
        self.size = CGSize(width: width, height: height)
    }

    /// Creates a rectangle with the specified coordinates and dimensions.
    @inlinable
    public init(x: Double, y: Double, width: Double, height: Double) {
        self.origin = CGPoint(x: x, y: y)
        self.size = CGSize(width: width, height: height)
    }

    /// Creates a rectangle with the specified coordinates and dimensions.
    @inlinable
    public init(x: Int, y: Int, width: Int, height: Int) {
        self.origin = CGPoint(x: x, y: y)
        self.size = CGSize(width: width, height: height)
    }

    // MARK: - Special Values

    /// The rectangle whose origin and size are both zero.
    @inlinable
    public static var zero: CGRect {
        return CGRect()
    }

    /// A rectangle that has infinite extent.
    public static var infinite: CGRect {
        return CGRect(
            x: -CGFloat.greatestFiniteMagnitude / 2,
            y: -CGFloat.greatestFiniteMagnitude / 2,
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
    }

    /// The null rectangle, representing an invalid value.
    public static var null: CGRect {
        return CGRect(
            x: CGFloat.infinity,
            y: CGFloat.infinity,
            width: 0.0,
            height: 0.0
        )
    }

    // MARK: - Geometric Properties

    /// The width of the rectangle.
    @inlinable
    public var width: CGFloat {
        return size.width
    }

    /// The height of the rectangle.
    @inlinable
    public var height: CGFloat {
        return size.height
    }

    /// The x-coordinate of the rectangle's minimum x value.
    @inlinable
    public var minX: CGFloat {
        return size.width >= 0 ? origin.x : origin.x + size.width
    }

    /// The x-coordinate of the rectangle's midpoint.
    @inlinable
    public var midX: CGFloat {
        return origin.x + size.width / 2
    }

    /// The x-coordinate of the rectangle's maximum x value.
    @inlinable
    public var maxX: CGFloat {
        return size.width >= 0 ? origin.x + size.width : origin.x
    }

    /// The y-coordinate of the rectangle's minimum y value.
    @inlinable
    public var minY: CGFloat {
        return size.height >= 0 ? origin.y : origin.y + size.height
    }

    /// The y-coordinate of the rectangle's midpoint.
    @inlinable
    public var midY: CGFloat {
        return origin.y + size.height / 2
    }

    /// The y-coordinate of the rectangle's maximum y value.
    @inlinable
    public var maxY: CGFloat {
        return size.height >= 0 ? origin.y + size.height : origin.y
    }

    // MARK: - State Properties

    /// Returns whether a rectangle has zero width or height, or is a null rectangle.
    @inlinable
    public var isEmpty: Bool {
        return isNull || size.width == 0 || size.height == 0
    }

    /// Returns whether a rectangle is infinite.
    @inlinable
    public var isInfinite: Bool {
        return self == CGRect.infinite
    }

    /// Returns whether the rectangle is equal to the null rectangle.
    @inlinable
    public var isNull: Bool {
        return origin.x.isInfinite && origin.y.isInfinite
    }

    // MARK: - Derived Rectangles

    /// Returns the smallest rectangle that results from converting the source rectangle values to integers.
    @inlinable
    public var integral: CGRect {
        if isNull { return self }
        let standardized = self.standardized
        let x = standardized.origin.x.rounded(.down)
        let y = standardized.origin.y.rounded(.down)
        let maxX = (standardized.origin.x + standardized.size.width).rounded(.up)
        let maxY = (standardized.origin.y + standardized.size.height).rounded(.up)
        return CGRect(x: x, y: y, width: maxX - x, height: maxY - y)
    }

    /// Returns a rectangle with a positive width and height.
    @inlinable
    public var standardized: CGRect {
        if isNull { return self }
        var rect = self
        if rect.size.width < 0 {
            rect.origin.x += rect.size.width
            rect.size.width = -rect.size.width
        }
        if rect.size.height < 0 {
            rect.origin.y += rect.size.height
            rect.size.height = -rect.size.height
        }
        return rect
    }

    // MARK: - Instance Methods

    /// Returns whether two rectangles are equal.
    @inlinable
    public func equalTo(_ rect2: CGRect) -> Bool {
        return self == rect2
    }

    /// Returns whether a rectangle contains a specified point.
    @inlinable
    public func contains(_ point: CGPoint) -> Bool {
        if isNull || isEmpty { return false }
        let standardized = self.standardized
        return point.x >= standardized.minX &&
               point.x < standardized.maxX &&
               point.y >= standardized.minY &&
               point.y < standardized.maxY
    }

    /// Returns whether the first rectangle contains the second rectangle.
    @inlinable
    public func contains(_ rect2: CGRect) -> Bool {
        if isNull || rect2.isNull { return false }
        return union(rect2) == self
    }

    /// Returns the intersection of two rectangles.
    @inlinable
    public func intersection(_ r2: CGRect) -> CGRect {
        if isNull || r2.isNull { return CGRect.null }

        let r1 = self.standardized
        let r2 = r2.standardized

        let x1 = max(r1.minX, r2.minX)
        let x2 = min(r1.maxX, r2.maxX)
        let y1 = max(r1.minY, r2.minY)
        let y2 = min(r1.maxY, r2.maxY)

        if x2 < x1 || y2 < y1 {
            return CGRect.null
        }

        return CGRect(x: x1, y: y1, width: x2 - x1, height: y2 - y1)
    }

    /// Returns whether two rectangles intersect.
    @inlinable
    public func intersects(_ r2: CGRect) -> Bool {
        return !intersection(r2).isNull
    }

    /// Returns the smallest rectangle that contains the two source rectangles.
    @inlinable
    public func union(_ r2: CGRect) -> CGRect {
        if isNull { return r2 }
        if r2.isNull { return self }

        let r1 = self.standardized
        let r2 = r2.standardized

        let x1 = min(r1.minX, r2.minX)
        let x2 = max(r1.maxX, r2.maxX)
        let y1 = min(r1.minY, r2.minY)
        let y2 = max(r1.maxY, r2.maxY)

        return CGRect(x: x1, y: y1, width: x2 - x1, height: y2 - y1)
    }

    /// Returns a rectangle that is smaller or larger than the source rectangle,
    /// with the same center point.
    @inlinable
    public func insetBy(dx: CGFloat, dy: CGFloat) -> CGRect {
        if isNull { return self }
        var rect = self.standardized
        rect.origin.x += dx
        rect.origin.y += dy
        rect.size.width -= dx * 2
        rect.size.height -= dy * 2
        if rect.size.width < 0 || rect.size.height < 0 {
            return CGRect.null
        }
        return rect
    }

    /// Returns a rectangle with an origin that is offset from that of the source rectangle.
    @inlinable
    public func offsetBy(dx: CGFloat, dy: CGFloat) -> CGRect {
        if isNull { return self }
        var rect = self
        rect.origin.x += dx
        rect.origin.y += dy
        return rect
    }

    /// Creates two rectangles by dividing the original rectangle.
    @inlinable
    public func divided(atDistance: CGFloat, from edge: CGRectEdge) -> (slice: CGRect, remainder: CGRect) {
        if isNull {
            return (CGRect.null, CGRect.null)
        }

        let rect = self.standardized
        let distance = max(0, atDistance)

        switch edge {
        case .minXEdge:
            let sliceWidth = min(distance, rect.width)
            let slice = CGRect(x: rect.minX, y: rect.minY, width: sliceWidth, height: rect.height)
            let remainder = CGRect(x: rect.minX + sliceWidth, y: rect.minY, width: rect.width - sliceWidth, height: rect.height)
            return (slice, remainder)

        case .maxXEdge:
            let sliceWidth = min(distance, rect.width)
            let slice = CGRect(x: rect.maxX - sliceWidth, y: rect.minY, width: sliceWidth, height: rect.height)
            let remainder = CGRect(x: rect.minX, y: rect.minY, width: rect.width - sliceWidth, height: rect.height)
            return (slice, remainder)

        case .minYEdge:
            let sliceHeight = min(distance, rect.height)
            let slice = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: sliceHeight)
            let remainder = CGRect(x: rect.minX, y: rect.minY + sliceHeight, width: rect.width, height: rect.height - sliceHeight)
            return (slice, remainder)

        case .maxYEdge:
            let sliceHeight = min(distance, rect.height)
            let slice = CGRect(x: rect.minX, y: rect.maxY - sliceHeight, width: rect.width, height: sliceHeight)
            let remainder = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height - sliceHeight)
            return (slice, remainder)
        }
    }

    /// Returns the rectangle resulting from an affine transformation of an existing rectangle.
    @inlinable
    public func applying(_ t: CGAffineTransform) -> CGRect {
        if isNull { return self }
        if t.isIdentity { return self }

        // Transform all four corners
        let p1 = CGPoint(x: minX, y: minY).applying(t)
        let p2 = CGPoint(x: maxX, y: minY).applying(t)
        let p3 = CGPoint(x: minX, y: maxY).applying(t)
        let p4 = CGPoint(x: maxX, y: maxY).applying(t)

        // Find bounding box of transformed corners
        let minX = min(min(p1.x, p2.x), min(p3.x, p4.x))
        let maxX = max(max(p1.x, p2.x), max(p3.x, p4.x))
        let minY = min(min(p1.y, p2.y), min(p3.y, p4.y))
        let maxY = max(max(p1.y, p2.y), max(p3.y, p4.y))

        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    // MARK: - Dictionary Representation

    /// Returns a dictionary representation of this rectangle.
    public var dictionaryRepresentation: [String: Any] {
        return [
            "X": origin.x.native,
            "Y": origin.y.native,
            "Width": size.width.native,
            "Height": size.height.native
        ]
    }

    /// Creates a rectangle from a dictionary representation.
    ///
    /// - Parameter dict: A dictionary containing "X", "Y", "Width", and "Height" keys with numeric values.
    public init?(dictionaryRepresentation dict: [String: Any]) {
        guard let x = dict["X"] as? Double,
              let y = dict["Y"] as? Double,
              let width = dict["Width"] as? Double,
              let height = dict["Height"] as? Double else {
            return nil
        }
        self.init(x: x, y: y, width: width, height: height)
    }
}

// MARK: - Global Functions

/// Returns whether two rectangles are equal.
@inlinable
public func CGRectEqualToRect(_ rect1: CGRect, _ rect2: CGRect) -> Bool {
    return rect1 == rect2
}

// MARK: - CGRectEdge

/// Coordinates that establish the edges of a rectangle.
public enum CGRectEdge: UInt32, Sendable {
    case minXEdge = 0
    case minYEdge = 1
    case maxXEdge = 2
    case maxYEdge = 3
}

// MARK: - Equatable

extension CGRect: Equatable {
    @inlinable
    public static func == (lhs: CGRect, rhs: CGRect) -> Bool {
        if lhs.isNull && rhs.isNull { return true }
        if lhs.isNull || rhs.isNull { return false }
        return lhs.origin == rhs.origin && lhs.size == rhs.size
    }
}

// MARK: - Hashable

extension CGRect: Hashable {
    @inlinable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(origin)
        hasher.combine(size)
    }
}

// MARK: - CustomDebugStringConvertible

extension CGRect: CustomDebugStringConvertible {
    public var debugDescription: String {
        return "(\(origin.x.native), \(origin.y.native), \(size.width.native), \(size.height.native))"
    }
}

// MARK: - CustomReflectable

extension CGRect: CustomReflectable {
    public var customMirror: Mirror {
        return Mirror(self, children: ["origin": origin, "size": size], displayStyle: .`struct`)
    }
}

// MARK: - Codable

extension CGRect: Codable {
    enum CodingKeys: String, CodingKey {
        case origin
        case size
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let origin = try container.decode(CGPoint.self, forKey: .origin)
        let size = try container.decode(CGSize.self, forKey: .size)
        self.init(origin: origin, size: size)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(origin, forKey: .origin)
        try container.encode(size, forKey: .size)
    }
}
