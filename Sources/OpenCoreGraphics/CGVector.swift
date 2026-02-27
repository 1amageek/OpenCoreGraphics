//
//  CGVector.swift
//  OpenCoreGraphics
//
//  Created by OpenCoreGraphics contributors.
//


import Foundation

#if arch(wasm32)

/// A structure that contains a two-dimensional vector.
@frozen
public struct CGVector: Sendable {

    /// The x component of the vector.
    public var dx: CGFloat

    /// The y component of the vector.
    public var dy: CGFloat

    /// Creates a vector with the specified components.
    @inlinable
    public init(dx: CGFloat, dy: CGFloat) {
        self.dx = dx
        self.dy = dy
    }

    /// Creates a vector with the specified components.
    @inlinable
    public init(dx: Int, dy: Int) {
        self.dx = CGFloat(dx)
        self.dy = CGFloat(dy)
    }

    /// Creates a vector whose components are both zero.
    @inlinable
    public init() {
        self.dx = 0
        self.dy = 0
    }

    /// The vector whose components are both zero.
    public static let zero = CGVector()
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

// MARK: - CustomDebugStringConvertible

extension CGVector: CustomDebugStringConvertible {
    public var debugDescription: String {
        return "(\(dx), \(dy))"
    }
}

#else

extension CGVector {

    /// The vector whose components are both zero.
    public static let zero = CGVector()
}


// MARK: - Equatable

extension CGVector: @retroactive Equatable {
    @inlinable
    public static func == (lhs: CGVector, rhs: CGVector) -> Bool {
        return lhs.dx == rhs.dx && lhs.dy == rhs.dy
    }
}

// MARK: - Hashable

extension CGVector: @retroactive Hashable {
    @inlinable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(dx)
        hasher.combine(dy)
    }
}

// MARK: - Codable

extension CGVector: @retroactive Codable {
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

// MARK: - CustomDebugStringConvertible

extension CGVector: @retroactive CustomDebugStringConvertible {
    public var debugDescription: String {
        return "(\(dx), \(dy))"
    }
}

#endif
