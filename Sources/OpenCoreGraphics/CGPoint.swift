//
//  CGPoint.swift
//  OpenCoreGraphics
//
//  Created by OpenCoreGraphics contributors.
//

import Foundation

/// A structure that contains a point in a two-dimensional coordinate system.
@frozen
public struct CGPoint: Sendable {

    /// The x-coordinate of the point.
    public var x: CGFloat

    /// The y-coordinate of the point.
    public var y: CGFloat

    /// Creates a point with coordinates (0, 0).
    @inlinable
    public init() {
        self.x = 0.0
        self.y = 0.0
    }

    /// Creates a point with the specified coordinates.
    @inlinable
    public init(x: CGFloat, y: CGFloat) {
        self.x = x
        self.y = y
    }

    /// Creates a point with the specified coordinates.
    @inlinable
    public init(x: Double, y: Double) {
        self.x = CGFloat(x)
        self.y = CGFloat(y)
    }

    /// Creates a point with the specified coordinates.
    @inlinable
    public init(x: Int, y: Int) {
        self.x = CGFloat(x)
        self.y = CGFloat(y)
    }

    /// The point with coordinates (0, 0).
    @inlinable
    public static var zero: CGPoint {
        return CGPoint()
    }

    /// Returns whether two points are equal.
    @inlinable
    public func equalTo(_ point2: CGPoint) -> Bool {
        return self == point2
    }

    /// Returns the point resulting from an affine transformation of an existing point.
    @inlinable
    public func applying(_ t: CGAffineTransform) -> CGPoint {
        return CGPoint(
            x: t.a * x + t.c * y + t.tx,
            y: t.b * x + t.d * y + t.ty
        )
    }

    // MARK: - Dictionary Representation

    /// Returns a dictionary representation of this point.
    public var dictionaryRepresentation: [String: Any] {
        return [
            "X": x.native,
            "Y": y.native
        ]
    }

    /// Creates a point from a dictionary representation.
    ///
    /// - Parameter dict: A dictionary containing "X" and "Y" keys with numeric values.
    public init?(dictionaryRepresentation dict: [String: Any]) {
        guard let x = dict["X"] as? Double,
              let y = dict["Y"] as? Double else {
            return nil
        }
        self.init(x: x, y: y)
    }
}

// MARK: - Global Functions

/// Returns whether two points are equal.
@inlinable
public func CGPointEqualToPoint(_ point1: CGPoint, _ point2: CGPoint) -> Bool {
    return point1 == point2
}

// MARK: - Equatable

extension CGPoint: Equatable {
    @inlinable
    public static func == (lhs: CGPoint, rhs: CGPoint) -> Bool {
        return lhs.x == rhs.x && lhs.y == rhs.y
    }
}

// MARK: - Hashable

extension CGPoint: Hashable {
    @inlinable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(x)
        hasher.combine(y)
    }
}

// MARK: - CustomDebugStringConvertible

extension CGPoint: CustomDebugStringConvertible {
    public var debugDescription: String {
        return "(\(x.native), \(y.native))"
    }
}

// MARK: - CustomReflectable

extension CGPoint: CustomReflectable {
    public var customMirror: Mirror {
        return Mirror(self, children: ["x": x, "y": y], displayStyle: .`struct`)
    }
}

// MARK: - Codable

extension CGPoint: Codable {
    enum CodingKeys: String, CodingKey {
        case x
        case y
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let x = try container.decode(CGFloat.self, forKey: .x)
        let y = try container.decode(CGFloat.self, forKey: .y)
        self.init(x: x, y: y)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(x, forKey: .x)
        try container.encode(y, forKey: .y)
    }
}
