//
//  CGVector.swift
//  OpenCoreGraphics
//
//  Created by OpenCoreGraphics contributors.
//

/// A structure that contains a two-dimensional vector.
public struct CGVector: Sendable {

    /// The x component of the vector.
    public var dx: CGFloat

    /// The y component of the vector.
    public var dy: CGFloat

    /// Creates a vector whose components are both zero.
    @inlinable
    public init() {
        self.dx = 0.0
        self.dy = 0.0
    }

    /// Creates a vector with the specified components.
    @inlinable
    public init(dx: CGFloat, dy: CGFloat) {
        self.dx = dx
        self.dy = dy
    }

    /// Creates a vector with the specified components.
    @inlinable
    public init(dx: Double, dy: Double) {
        self.dx = CGFloat(dx)
        self.dy = CGFloat(dy)
    }

    /// Creates a vector with the specified components.
    @inlinable
    public init(dx: Int, dy: Int) {
        self.dx = CGFloat(dx)
        self.dy = CGFloat(dy)
    }

    /// The vector whose components are both zero.
    @inlinable
    public static var zero: CGVector {
        return CGVector()
    }
}

// MARK: - Equatable

extension CGVector: Equatable {
    @inlinable
    public static func == (lhs: CGVector, rhs: CGVector) -> Bool {
        return lhs.dx == rhs.dx && lhs.dy == rhs.dy
    }
}

// MARK: - Hashable

extension CGVector: Hashable {
    @inlinable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(dx)
        hasher.combine(dy)
    }
}

// MARK: - CustomDebugStringConvertible

extension CGVector: CustomDebugStringConvertible {
    public var debugDescription: String {
        return "(\(dx.native), \(dy.native))"
    }
}

// MARK: - Codable

extension CGVector: Codable {
    enum CodingKeys: String, CodingKey {
        case dx
        case dy
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let dx = try container.decode(CGFloat.self, forKey: .dx)
        let dy = try container.decode(CGFloat.self, forKey: .dy)
        self.init(dx: dx, dy: dy)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(dx, forKey: .dx)
        try container.encode(dy, forKey: .dy)
    }
}
