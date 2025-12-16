//
//  CGBitmapInfo.swift
//  OpenCoreGraphics
//
//  Created by OpenCoreGraphics contributors.
//

/// Component information for a bitmap image.
///
/// Applications that store pixel data in memory using ARGB format must take care
/// in how they read data. If the code is not written correctly, it's possible to
/// misread the data which leads to colors or alpha that appear wrong. The byte order
/// constants specify the byte ordering of pixel formats.
public struct CGBitmapInfo: OptionSet, Sendable, Hashable {
    public let rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    // MARK: - Alpha Info Mask

    /// The mask for extracting the alpha info component.
    public static let alphaInfoMask = CGBitmapInfo(rawValue: 0x1F)

    // MARK: - Float Components

    /// The components are floating-point values.
    public static let floatComponents = CGBitmapInfo(rawValue: 1 << 8)

    /// The mask for extracting float info.
    public static let floatInfoMask = CGBitmapInfo(rawValue: 0xF00)

    // MARK: - Byte Order

    /// The mask for extracting the byte order component.
    public static let byteOrderMask = CGBitmapInfo(rawValue: 0x7000)

    /// The default byte order.
    public static let byteOrderDefault = CGBitmapInfo(rawValue: 0)

    /// 16-bit, little-endian format.
    public static let byteOrder16Little = CGBitmapInfo(rawValue: 1 << 12)

    /// 32-bit, little-endian format.
    public static let byteOrder32Little = CGBitmapInfo(rawValue: 2 << 12)

    /// 16-bit, big-endian format.
    public static let byteOrder16Big = CGBitmapInfo(rawValue: 3 << 12)

    /// 32-bit, big-endian format.
    public static let byteOrder32Big = CGBitmapInfo(rawValue: 4 << 12)

    // MARK: - Convenience Initializers

    /// Creates bitmap info from alpha, component, and byte order settings.
    ///
    /// - Parameters:
    ///   - alpha: The alpha information.
    ///   - component: The component information (integer or float).
    ///   - byteOrder: The byte order information.
    public init(alpha: CGImageAlphaInfo, component: CGImageComponentInfo, byteOrder: CGImageByteOrderInfo) {
        var value = alpha.rawValue
        value |= byteOrder.rawValue
        if component == .float {
            value |= CGBitmapInfo.floatComponents.rawValue
        }
        self.rawValue = value
    }

    /// Creates bitmap info from alpha, component, byte order, and pixel format settings.
    ///
    /// - Parameters:
    ///   - alpha: The alpha information.
    ///   - component: The component information (integer or float).
    ///   - byteOrder: The byte order information.
    ///   - pixelFormat: The pixel format information.
    public init(alpha: CGImageAlphaInfo, component: CGImageComponentInfo, byteOrder: CGImageByteOrderInfo, pixelFormat: CGImagePixelFormatInfo) {
        var value = alpha.rawValue
        value |= byteOrder.rawValue
        value |= pixelFormat.rawValue
        if component == .float {
            value |= CGBitmapInfo.floatComponents.rawValue
        }
        self.rawValue = value
    }

    // MARK: - Properties

    /// Returns the alpha info from this bitmap info.
    public var alpha: CGImageAlphaInfo {
        return CGImageAlphaInfo(rawValue: rawValue & CGBitmapInfo.alphaInfoMask.rawValue) ?? .none
    }

    /// Returns the alpha info from this bitmap info (convenience alias).
    public var alphaInfo: CGImageAlphaInfo {
        return alpha
    }

    /// Returns the byte order info from this bitmap info.
    public var byteOrder: CGImageByteOrderInfo {
        return CGImageByteOrderInfo(rawValue: rawValue & CGBitmapInfo.byteOrderMask.rawValue) ?? .orderDefault
    }

    /// Returns the byte order info from this bitmap info (convenience alias).
    public var byteOrderInfo: CGImageByteOrderInfo {
        return byteOrder
    }

    /// Returns the component info from this bitmap info.
    public var component: CGImageComponentInfo {
        if rawValue & CGBitmapInfo.floatComponents.rawValue != 0 {
            return .float
        }
        return .integer
    }

    /// Returns the pixel format info from this bitmap info.
    public var pixelFormat: CGImagePixelFormatInfo {
        return CGImagePixelFormatInfo(rawValue: rawValue & CGImagePixelFormatInfo.mask.rawValue) ?? .packed
    }

    /// Returns whether the components are floating-point values.
    public var isFloatComponents: Bool {
        return rawValue & CGBitmapInfo.floatComponents.rawValue != 0
    }
}

// MARK: - Host Endian Bitmap Formats

/// 16-bit, host-endian format.
#if _endian(little)
public let kCGBitmapByteOrder16Host: CGBitmapInfo = .byteOrder16Little
#else
public let kCGBitmapByteOrder16Host: CGBitmapInfo = .byteOrder16Big
#endif

/// 32-bit, host-endian format.
#if _endian(little)
public let kCGBitmapByteOrder32Host: CGBitmapInfo = .byteOrder32Little
#else
public let kCGBitmapByteOrder32Host: CGBitmapInfo = .byteOrder32Big
#endif
