//
//  CGPointConformances.swift
//  CGExtensions
//
//  Protocol conformances for CGPoint on Darwin platforms.
//  On non-Darwin platforms, swift-corelibs-foundation already provides these.
//

import Foundation

#if canImport(Darwin)
extension CGPoint: @retroactive Equatable {
    @inlinable
    public static func == (lhs: CGPoint, rhs: CGPoint) -> Bool {
        return lhs.x == rhs.x && lhs.y == rhs.y
    }
}

extension CGPoint: @retroactive Hashable {
    @inlinable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(x)
        hasher.combine(y)
    }
}

extension CGPoint: @retroactive Codable {
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

extension CGPoint: @retroactive CustomDebugStringConvertible {
    public var debugDescription: String {
        return "(\(x), \(y))"
    }
}
#endif

// MARK: - Extension Methods

#if canImport(Darwin)
extension CGPoint {
    /// The point with location (0,0).
    public static var zero: CGPoint { CGPoint(x: 0, y: 0) }
}
#endif

extension CGPoint {
    /// Returns whether two points are equal.
    @inlinable
    public func equalTo(_ point2: CGPoint) -> Bool {
        return self.x == point2.x && self.y == point2.y
    }
}
