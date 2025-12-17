//
//  CGSizeConformances.swift
//  CGExtensions
//
//  Protocol conformances for CGSize on Darwin platforms.
//  On non-Darwin platforms, swift-corelibs-foundation already provides these.
//

import Foundation

#if canImport(Darwin)
extension CGSize: @retroactive Equatable {
    @inlinable
    public static func == (lhs: CGSize, rhs: CGSize) -> Bool {
        return lhs.width == rhs.width && lhs.height == rhs.height
    }
}

extension CGSize: @retroactive Hashable {
    @inlinable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(width)
        hasher.combine(height)
    }
}

extension CGSize: @retroactive Codable {
    enum CodingKeys: String, CodingKey {
        case width
        case height
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let width = try container.decode(CGFloat.self, forKey: .width)
        let height = try container.decode(CGFloat.self, forKey: .height)
        self.init(width: width, height: height)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(width, forKey: .width)
        try container.encode(height, forKey: .height)
    }
}

extension CGSize: @retroactive CustomDebugStringConvertible {
    public var debugDescription: String {
        return "(\(width), \(height))"
    }
}
#endif

// MARK: - Extension Methods (available on all platforms)

extension CGSize {
    /// The size whose width and height are both zero.
    public static var zero: CGSize { CGSize(width: 0, height: 0) }

    /// Returns whether two sizes are equal.
    @inlinable
    public func equalTo(_ size2: CGSize) -> Bool {
        return self.width == size2.width && self.height == size2.height
    }
}
