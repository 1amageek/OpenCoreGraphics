//
//  CGColorConversionInfo.swift
//  OpenCoreGraphics
//
//  Created by OpenCoreGraphics contributors.
//

import Foundation

// MARK: - CGColorConversionInfoTransformType

/// Constants describing how a color conversion uses color spaces.
public enum CGColorConversionInfoTransformType: UInt32, Sendable {
    /// Specifies a color conversion from a device color space to a color profile.
    case transformFromSpace = 0

    /// Specifies a color conversion from a color profile to a device color space.
    case transformToSpace = 1

    /// Specifies a color conversion between one color profile and another.
    case transformApplySpace = 2
}

// MARK: - CGToneMapping

/// Tone mapping options for HDR color conversion.
public enum CGToneMapping: UInt32, Sendable {
    /// Default tone mapping.
    case `default` = 0

    /// No tone mapping.
    case none = 1

    /// ACES filmic tone mapping.
    case acesFilmic = 2

    /// ITU-R BT.2390 tone mapping.
    case iturBt2390 = 3

    /// Exponential rolloff tone mapping.
    case exponentialRolloff = 4
}

// MARK: - CGColorBufferFormat

/// A structure describing the format of a color buffer.
public struct CGColorBufferFormat: Sendable {
    /// The version of the structure.
    public var version: UInt32

    /// The number of bits per component.
    public var bitsPerComponent: UInt32

    /// The number of bits per pixel.
    public var bitsPerPixel: UInt32

    /// The bytes per row.
    public var bytesPerRow: UInt32

    /// The bitmap info.
    public var bitmapInfo: CGBitmapInfo

    /// Creates a color buffer format.
    public init(version: UInt32 = 0, bitsPerComponent: UInt32, bitsPerPixel: UInt32,
                bytesPerRow: UInt32, bitmapInfo: CGBitmapInfo) {
        self.version = version
        self.bitsPerComponent = bitsPerComponent
        self.bitsPerPixel = bitsPerPixel
        self.bytesPerRow = bytesPerRow
        self.bitmapInfo = bitmapInfo
    }
}

// MARK: - CGColorConversionInfo

/// An object that describes how to convert between color spaces for use by other system services.
///
/// A `CGColorConversionInfo` object specifies a conversion between two or more color spaces,
/// including information about the intent of the conversion.
public class CGColorConversionInfo: @unchecked Sendable {

    /// The source color space.
    public let sourceColorSpace: CGColorSpace

    /// The destination color space.
    public let destinationColorSpace: CGColorSpace

    /// The rendering intent for the conversion.
    public let intent: CGColorRenderingIntent

    /// Options dictionary for the conversion.
    internal let options: [String: Any]?

    // MARK: - Initializers

    /// Creates a conversion between two specified color spaces.
    ///
    /// - Parameters:
    ///   - src: The source color space.
    ///   - dst: The destination color space.
    public init?(src: CGColorSpace, dst: CGColorSpace) {
        self.sourceColorSpace = src
        self.destinationColorSpace = dst
        self.intent = .defaultIntent
        self.options = nil
    }

    /// Creates a conversion between two specified color spaces with options.
    ///
    /// - Parameters:
    ///   - optionsSrc: The source color space.
    ///   - dst: The destination color space.
    ///   - options: A dictionary of options for the conversion.
    public init?(optionsSrc: CGColorSpace, dst: CGColorSpace, options: [String: Any]?) {
        self.sourceColorSpace = optionsSrc
        self.destinationColorSpace = dst
        self.intent = .defaultIntent
        self.options = options
    }

    // MARK: - Conversion

    /// Converts color data from one format to another.
    ///
    /// - Parameters:
    ///   - width: The width of the image in pixels.
    ///   - height: The height of the image in pixels.
    ///   - dstBuffer: The destination buffer.
    ///   - dstFormat: The format of the destination buffer.
    ///   - srcBuffer: The source buffer.
    ///   - srcFormat: The format of the source buffer.
    ///   - options: Conversion options.
    /// - Returns: True if conversion succeeded, false otherwise.
    public func convert(width: Int, height: Int,
                       to dstBuffer: UnsafeMutableRawPointer,
                       format dstFormat: CGColorBufferFormat,
                       from srcBuffer: UnsafeRawPointer,
                       format srcFormat: CGColorBufferFormat,
                       options: [String: Any]?) -> Bool {
        // In a full implementation, this would perform actual color conversion
        // For now, return false to indicate not implemented
        return false
    }

    // MARK: - Type ID

    /// Returns the Core Foundation type identifier for a color conversion info data type.
    public class var typeID: UInt {
        return 0 // Placeholder
    }
}

// MARK: - Equatable

extension CGColorConversionInfo: Equatable {
    public static func == (lhs: CGColorConversionInfo, rhs: CGColorConversionInfo) -> Bool {
        return lhs === rhs
    }
}

// MARK: - Hashable

extension CGColorConversionInfo: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}
