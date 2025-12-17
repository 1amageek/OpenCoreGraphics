//
//  CGBitmapParameters.swift
//  OpenCoreGraphics
//
//  Created by OpenCoreGraphics contributors.
//

import Foundation


// MARK: - __CGBitmapParameters (Internal Backing Type)

/// Internal backing type for CGBitmapParameters.
public struct __CGBitmapParameters: Sendable {
    /// The color space for the bitmap.
    public var colorSpace: CGColorSpace

    /// The bitmap info flags.
    public var bitmapInfo: CGBitmapInfo

    /// The number of bits per component.
    public var bitsPerComponent: Int

    /// The number of bits per pixel.
    public var bitsPerPixel: Int

    /// The number of bytes per row.
    public var bytesPerRow: Int

    /// The width of the bitmap in pixels.
    public var width: Int

    /// The height of the bitmap in pixels.
    public var height: Int

    /// Creates a new bitmap parameters backing store.
    public init(
        colorSpace: CGColorSpace,
        bitmapInfo: CGBitmapInfo = [],
        bitsPerComponent: Int = 8,
        bitsPerPixel: Int = 32,
        bytesPerRow: Int = 0,
        width: Int = 0,
        height: Int = 0
    ) {
        self.colorSpace = colorSpace
        self.bitmapInfo = bitmapInfo
        self.bitsPerComponent = bitsPerComponent
        self.bitsPerPixel = bitsPerPixel
        self.bytesPerRow = bytesPerRow
        self.width = width
        self.height = height
    }
}

// MARK: - CGBitmapParameters

/// A structure that encapsulates bitmap parameters for creating bitmap contexts and images.
@dynamicMemberLookup
public struct CGBitmapParameters: Sendable {

    /// The internal backing store.
    private var backing: __CGBitmapParameters

    // MARK: - Initializers

    /// Creates bitmap parameters with the specified color space.
    public init(colorSpace: CGColorSpace) {
        self.backing = __CGBitmapParameters(colorSpace: colorSpace)
    }

    /// Creates bitmap parameters with the specified backing parameters.
    public init(_ parameters: __CGBitmapParameters) {
        self.backing = parameters
    }

    /// Creates bitmap parameters with full configuration.
    public init(
        colorSpace: CGColorSpace,
        bitmapInfo: CGBitmapInfo = [],
        bitsPerComponent: Int = 8,
        bitsPerPixel: Int = 32,
        bytesPerRow: Int = 0,
        width: Int = 0,
        height: Int = 0
    ) {
        self.backing = __CGBitmapParameters(
            colorSpace: colorSpace,
            bitmapInfo: bitmapInfo,
            bitsPerComponent: bitsPerComponent,
            bitsPerPixel: bitsPerPixel,
            bytesPerRow: bytesPerRow,
            width: width,
            height: height
        )
    }

    // MARK: - Properties

    /// The color space for the bitmap.
    public var colorSpace: CGColorSpace {
        get { backing.colorSpace }
        set { backing.colorSpace = newValue }
    }

    // MARK: - Dynamic Member Lookup

    /// Provides read access to properties of the backing parameters.
    public subscript<T>(dynamicMember keyPath: KeyPath<__CGBitmapParameters, T>) -> T {
        backing[keyPath: keyPath]
    }

    /// Provides read-write access to properties of the backing parameters.
    public subscript<T>(dynamicMember keyPath: WritableKeyPath<__CGBitmapParameters, T>) -> T {
        get { backing[keyPath: keyPath] }
        set { backing[keyPath: keyPath] = newValue }
    }
}

// MARK: - Equatable

extension CGBitmapParameters: Equatable {
    public static func == (lhs: CGBitmapParameters, rhs: CGBitmapParameters) -> Bool {
        return lhs.backing.colorSpace == rhs.backing.colorSpace &&
               lhs.backing.bitmapInfo == rhs.backing.bitmapInfo &&
               lhs.backing.bitsPerComponent == rhs.backing.bitsPerComponent &&
               lhs.backing.bitsPerPixel == rhs.backing.bitsPerPixel &&
               lhs.backing.bytesPerRow == rhs.backing.bytesPerRow &&
               lhs.backing.width == rhs.backing.width &&
               lhs.backing.height == rhs.backing.height
    }
}

// MARK: - Hashable

extension CGBitmapParameters: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(backing.colorSpace)
        hasher.combine(backing.bitmapInfo)
        hasher.combine(backing.bitsPerComponent)
        hasher.combine(backing.bitsPerPixel)
        hasher.combine(backing.bytesPerRow)
        hasher.combine(backing.width)
        hasher.combine(backing.height)
    }
}

// MARK: - CustomDebugStringConvertible

extension CGBitmapParameters: CustomDebugStringConvertible {
    public var debugDescription: String {
        return """
        CGBitmapParameters(
            colorSpace: \(backing.colorSpace),
            bitmapInfo: \(backing.bitmapInfo),
            bitsPerComponent: \(backing.bitsPerComponent),
            bitsPerPixel: \(backing.bitsPerPixel),
            bytesPerRow: \(backing.bytesPerRow),
            width: \(backing.width),
            height: \(backing.height)
        )
        """
    }
}

