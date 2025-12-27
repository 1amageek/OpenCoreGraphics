//
//  CGRectConformances.swift
//  CGExtensions
//
//  Protocol conformances for CGRect on Darwin platforms.
//  On non-Darwin platforms, swift-corelibs-foundation already provides these.
//

#if canImport(Darwin)
import Foundation
// MARK: - Basic Properties (Darwin only - CoreGraphics provides these)

extension CGRect {
    /// Creates a rectangle with coordinates and dimensions specified as floating-point values.
    public init(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
        self.init(origin: CGPoint(x: x, y: y), size: CGSize(width: width, height: height))
    }

    /// The width of the rectangle.
    public var width: CGFloat { size.width }

    /// The height of the rectangle.
    public var height: CGFloat { size.height }

    /// The x-coordinate of the rectangle's origin.
    public var minX: CGFloat {
        size.width >= 0 ? origin.x : origin.x + size.width
    }

    /// The y-coordinate of the rectangle's origin.
    public var minY: CGFloat {
        size.height >= 0 ? origin.y : origin.y + size.height
    }

    /// The x-coordinate that establishes the center of the rectangle.
    public var midX: CGFloat { origin.x + size.width / 2 }

    /// The y-coordinate that establishes the center of the rectangle.
    public var midY: CGFloat { origin.y + size.height / 2 }

    /// The largest x-coordinate of the rectangle.
    public var maxX: CGFloat {
        size.width >= 0 ? origin.x + size.width : origin.x
    }

    /// The largest y-coordinate of the rectangle.
    public var maxY: CGFloat {
        size.height >= 0 ? origin.y + size.height : origin.y
    }
}

extension CGRect: Equatable {

    public static func == (lhs: CGRect, rhs: CGRect) -> Bool {
        return lhs.origin == rhs.origin && lhs.size == rhs.size
    }
}

extension CGRect: Hashable {

    public func hash(into hasher: inout Hasher) {
        hasher.combine(origin)
        hasher.combine(size)
    }
}

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

extension CGRect: CustomDebugStringConvertible {
    public var debugDescription: String {
        return "(\(origin.x), \(origin.y), \(size.width), \(size.height))"
    }
}


// MARK: - CGRectEdge

/// Coordinates that establish the edges of a rectangle.
public enum CGRectEdge: UInt32, Sendable {
    case minXEdge = 0
    case minYEdge = 1
    case maxXEdge = 2
    case maxYEdge = 3
}

// MARK: - Static Properties (Darwin only - swift-corelibs-foundation provides these on non-Darwin)

extension CGRect {
    /// The rectangle whose origin and size are both zero.
    public static var zero: CGRect { CGRect(origin: .zero, size: .zero) }

    /// A rectangle that has infinite extent.
    public static var infinite: CGRect {
        CGRect(origin: CGPoint(x: -CGFloat.infinity, y: -CGFloat.infinity), size: CGSize(width: CGFloat.infinity, height: CGFloat.infinity))
    }

    /// The null rectangle, representing an invalid value.
    public static var null: CGRect {
        CGRect(origin: CGPoint(x: CGFloat.infinity, y: CGFloat.infinity), size: CGSize(width: 0, height: 0))
    }
}

// MARK: - Extension Methods (Darwin only - swift-corelibs-foundation provides these on non-Darwin)

extension CGRect {
    /// Returns whether two rectangles are equal.
    @inlinable
    public func equalTo(_ rect2: CGRect) -> Bool {
        return self.origin.x == rect2.origin.x && self.origin.y == rect2.origin.y &&
               self.size.width == rect2.size.width && self.size.height == rect2.size.height
    }

    /// Returns whether a rectangle has zero width or height, or is a null rectangle.
    @inlinable
    public var isEmpty: Bool {
        return size.width == 0 || size.height == 0 || isNull
    }

    /// Returns whether the rectangle is infinite.
    @inlinable
    public var isInfinite: Bool {
        return origin.x == -CGFloat.infinity && origin.y == -CGFloat.infinity &&
               size.width == CGFloat.infinity && size.height == CGFloat.infinity
    }

    /// Returns whether the rectangle is equal to the null rectangle.
    @inlinable
    public var isNull: Bool {
        return origin.x.isNaN || origin.y.isNaN ||
               size.width.isNaN || size.height.isNaN ||
               (origin.x == CGFloat.infinity && origin.y == CGFloat.infinity)
    }

    /// Returns a rectangle with a positive width and height.
    @inlinable
    public var standardized: CGRect {
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

    /// Returns the smallest rectangle that contains the two source rectangles.
    @inlinable
    public func union(_ rect: CGRect) -> CGRect {
        if isNull { return rect }
        if rect.isNull { return self }

        let r1 = self.standardized
        let r2 = rect.standardized

        let x1 = Swift.min(r1.origin.x, r2.origin.x)
        let y1 = Swift.min(r1.origin.y, r2.origin.y)
        let x2 = Swift.max(r1.origin.x + r1.size.width, r2.origin.x + r2.size.width)
        let y2 = Swift.max(r1.origin.y + r1.size.height, r2.origin.y + r2.size.height)

        return CGRect(origin: CGPoint(x: x1, y: y1), size: CGSize(width: x2 - x1, height: y2 - y1))
    }

    /// Returns the intersection of two rectangles.
    ///
    /// Returns `.null` if the rectangles do not intersect or only touch at edges (zero area).
    @inlinable
    public func intersection(_ rect: CGRect) -> CGRect {
        if isNull || rect.isNull { return .null }

        let r1 = self.standardized
        let r2 = rect.standardized

        let x1 = Swift.max(r1.origin.x, r2.origin.x)
        let y1 = Swift.max(r1.origin.y, r2.origin.y)
        let x2 = Swift.min(r1.origin.x + r1.size.width, r2.origin.x + r2.size.width)
        let y2 = Swift.min(r1.origin.y + r1.size.height, r2.origin.y + r2.size.height)

        // Use >= to return null for zero-area intersections (touching edges only)
        if x1 >= x2 || y1 >= y2 {
            return .null
        }

        return CGRect(origin: CGPoint(x: x1, y: y1), size: CGSize(width: x2 - x1, height: y2 - y1))
    }

    /// Returns whether two rectangles intersect.
    @inlinable
    public func intersects(_ rect: CGRect) -> Bool {
        return !intersection(rect).isNull
    }

    /// Returns whether a rectangle contains a specified point.
    @inlinable
    public func contains(_ point: CGPoint) -> Bool {
        let r = standardized
        return point.x >= r.origin.x && point.x < r.origin.x + r.size.width &&
               point.y >= r.origin.y && point.y < r.origin.y + r.size.height
    }

    /// Returns whether the first rectangle contains the second rectangle.
    @inlinable
    public func contains(_ rect: CGRect) -> Bool {
        return union(rect) == self
    }

    /// Returns a rectangle with an origin that is offset from that of the source rectangle.
    @inlinable
    public func offsetBy(dx: CGFloat, dy: CGFloat) -> CGRect {
        return CGRect(
            origin: CGPoint(x: origin.x + dx, y: origin.y + dy),
            size: size
        )
    }

    /// Returns a rectangle that is smaller or larger than the source rectangle.
    @inlinable
    public func insetBy(dx: CGFloat, dy: CGFloat) -> CGRect {
        let newWidth = size.width - dx * 2
        let newHeight = size.height - dy * 2

        if newWidth < 0 || newHeight < 0 {
            return .null
        }

        return CGRect(
            origin: CGPoint(x: origin.x + dx, y: origin.y + dy),
            size: CGSize(width: newWidth, height: newHeight)
        )
    }

    /// Returns the smallest rectangle that results from converting the source rectangle values to integers.
    @inlinable
    public var integral: CGRect {
        let r = standardized
        let x = r.origin.x.rounded(.down)
        let y = r.origin.y.rounded(.down)
        let maxX = (r.origin.x + r.size.width).rounded(.up)
        let maxY = (r.origin.y + r.size.height).rounded(.up)
        return CGRect(origin: CGPoint(x: x, y: y), size: CGSize(width: maxX - x, height: maxY - y))
    }

    /// Creates two rectangles by dividing the original rectangle.
    @inlinable
    public func divided(atDistance: CGFloat, from edge: CGRectEdge) -> (slice: CGRect, remainder: CGRect) {
        let rect = self.standardized
        let distance = Swift.max(0, atDistance)

        switch edge {
        case .minXEdge:
            let sliceWidth = Swift.min(distance, rect.size.width)
            let slice = CGRect(origin: CGPoint(x: rect.origin.x, y: rect.origin.y), size: CGSize(width: sliceWidth, height: rect.size.height))
            let remainder = CGRect(origin: CGPoint(x: rect.origin.x + sliceWidth, y: rect.origin.y), size: CGSize(width: rect.size.width - sliceWidth, height: rect.size.height))
            return (slice, remainder)

        case .maxXEdge:
            let sliceWidth = Swift.min(distance, rect.size.width)
            let slice = CGRect(origin: CGPoint(x: rect.origin.x + rect.size.width - sliceWidth, y: rect.origin.y), size: CGSize(width: sliceWidth, height: rect.size.height))
            let remainder = CGRect(origin: CGPoint(x: rect.origin.x, y: rect.origin.y), size: CGSize(width: rect.size.width - sliceWidth, height: rect.size.height))
            return (slice, remainder)

        case .minYEdge:
            let sliceHeight = Swift.min(distance, rect.size.height)
            let slice = CGRect(origin: CGPoint(x: rect.origin.x, y: rect.origin.y), size: CGSize(width: rect.size.width, height: sliceHeight))
            let remainder = CGRect(origin: CGPoint(x: rect.origin.x, y: rect.origin.y + sliceHeight), size: CGSize(width: rect.size.width, height: rect.size.height - sliceHeight))
            return (slice, remainder)

        case .maxYEdge:
            let sliceHeight = Swift.min(distance, rect.size.height)
            let slice = CGRect(origin: CGPoint(x: rect.origin.x, y: rect.origin.y + rect.size.height - sliceHeight), size: CGSize(width: rect.size.width, height: sliceHeight))
            let remainder = CGRect(origin: CGPoint(x: rect.origin.x, y: rect.origin.y), size: CGSize(width: rect.size.width, height: rect.size.height - sliceHeight))
            return (slice, remainder)
        }
    }
}
#endif
