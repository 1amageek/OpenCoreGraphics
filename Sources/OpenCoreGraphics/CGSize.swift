//
//  CGSize.swift
//  OpenCoreGraphics
//
//  Created by OpenCoreGraphics contributors.
//

import Foundation

/// A structure that contains width and height values.
public struct CGSize: Sendable {

    /// A width value.
    public var width: CGFloat

    /// A height value.
    public var height: CGFloat

    /// Creates a size with zero width and height.
    @inlinable
    public init() {
        self.width = 0.0
        self.height = 0.0
    }

    /// Creates a size with the specified width and height.
    @inlinable
    public init(width: CGFloat, height: CGFloat) {
        self.width = width
        self.height = height
    }

    /// Creates a size with the specified width and height.
    @inlinable
    public init(width: Double, height: Double) {
        self.width = CGFloat(width)
        self.height = CGFloat(height)
    }

    /// Creates a size with the specified width and height.
    @inlinable
    public init(width: Int, height: Int) {
        self.width = CGFloat(width)
        self.height = CGFloat(height)
    }

    /// The size whose width and height are both zero.
    @inlinable
    public static var zero: CGSize {
        return CGSize()
    }

    /// Returns whether two sizes are equal.
    @inlinable
    public func equalTo(_ size2: CGSize) -> Bool {
        return self == size2
    }

    /// Returns the size resulting from an affine transformation of an existing size.
    @inlinable
    public func applying(_ t: CGAffineTransform) -> CGSize {
        return CGSize(
            width: t.a * width + t.c * height,
            height: t.b * width + t.d * height
        )
    }

    // MARK: - Dictionary Representation

    /// Returns a dictionary representation of this size.
    public var dictionaryRepresentation: CFDictionary {
        let dict: [CFString: Any] = [
            "Width" as CFString: width.native,
            "Height" as CFString: height.native
        ]
        return dict as CFDictionary
    }

    /// Creates a size from a dictionary representation.
    ///
    /// - Parameter dict: A dictionary containing "Width" and "Height" keys with numeric values.
    public init?(dictionaryRepresentation dict: CFDictionary) {
        guard let dictionary = dict as? [String: Any],
              let width = dictionary["Width"] as? Double,
              let height = dictionary["Height"] as? Double else {
            return nil
        }
        self.init(width: width, height: height)
    }
}

// MARK: - Global Functions

/// Returns whether two sizes are equal.
@inlinable
public func CGSizeEqualToSize(_ size1: CGSize, _ size2: CGSize) -> Bool {
    return size1 == size2
}

// MARK: - Equatable

extension CGSize: Equatable {
    @inlinable
    public static func == (lhs: CGSize, rhs: CGSize) -> Bool {
        return lhs.width == rhs.width && lhs.height == rhs.height
    }
}

// MARK: - Hashable

extension CGSize: Hashable {
    @inlinable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(width)
        hasher.combine(height)
    }
}

// MARK: - CustomDebugStringConvertible

extension CGSize: CustomDebugStringConvertible {
    public var debugDescription: String {
        return "(\(width.native), \(height.native))"
    }
}

// MARK: - CustomReflectable

extension CGSize: CustomReflectable {
    public var customMirror: Mirror {
        return Mirror(self, children: ["width": width, "height": height], displayStyle: .`struct`)
    }
}

// MARK: - Codable

extension CGSize: Codable {
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
