//
//  CGImageAlphaInfo.swift
//  OpenCoreGraphics
//
//  Created by OpenCoreGraphics contributors.
//


/// Storage options for alpha component data.
///
/// A `CGImageAlphaInfo` constant specifies:
/// 1. Whether a bitmap contains an alpha channel
/// 2. Where the alpha bits are located in the image data
/// 3. Whether the alpha value is premultiplied

public enum CGImageAlphaInfo: UInt32, Sendable, CaseIterable {
    /// There is no alpha channel.
    case none = 0

    /// The alpha component is stored in the least significant bits of each pixel
    /// and the color components have already been multiplied by this alpha value.
    /// For example, premultiplied RGBA.
    case premultipliedLast = 1

    /// The alpha component is stored in the most significant bits of each pixel
    /// and the color components have already been multiplied by this alpha value.
    /// For example, premultiplied ARGB.
    case premultipliedFirst = 2

    /// The alpha component is stored in the least significant bits of each pixel.
    /// For example, non-premultiplied RGBA.
    case last = 3

    /// The alpha component is stored in the most significant bits of each pixel.
    /// For example, non-premultiplied ARGB.
    case first = 4

    /// There is no alpha channel. If the total size of the pixel is greater than
    /// the space required for the number of color components in the color space,
    /// the least significant bits are ignored.
    case noneSkipLast = 5

    /// There is no alpha channel. If the total size of the pixel is greater than
    /// the space required for the number of color components in the color space,
    /// the most significant bits are ignored.
    case noneSkipFirst = 6

    /// There is no color data, only an alpha channel.
    case alphaOnly = 7
}

// MARK: - CGImageByteOrderInfo

/// Byte ordering of pixel data in images.
public enum CGImageByteOrderInfo: UInt32, Sendable, CaseIterable {
    /// The default byte order.
    case orderDefault = 0

    /// 16-bit, little-endian format.
    case order16Little = 4096  // 1 << 12

    /// 32-bit, little-endian format.
    case order32Little = 8192  // 2 << 12

    /// 16-bit, big-endian format.
    case order16Big = 12288  // 3 << 12

    /// 32-bit, big-endian format.
    case order32Big = 16384  // 4 << 12

    /// The byte order mask.
    case orderMask = 28672  // 0x7000

    /// 16-bit, host-endian format.
    #if _endian(little)
    public static let order16Host: CGImageByteOrderInfo = .order16Little
    #else
    public static let order16Host: CGImageByteOrderInfo = .order16Big
    #endif

    /// 32-bit, host-endian format.
    #if _endian(little)
    public static let order32Host: CGImageByteOrderInfo = .order32Little
    #else
    public static let order32Host: CGImageByteOrderInfo = .order32Big
    #endif
}

// MARK: - CGImagePixelFormatInfo

/// Pixel format information for images.
public enum CGImagePixelFormatInfo: UInt32, Sendable, CaseIterable {
    /// The pixel format mask.
    case mask = 983040  // 0xF0000

    /// The pixel format is packed (standard format).
    case packed = 0

    /// RGB data uses 555 format (5 bits per component, 1 bit unused).
    case RGB555 = 65536  // 1 << 16

    /// RGB data uses 565 format (5 bits red, 6 bits green, 5 bits blue).
    case RGB565 = 131072  // 2 << 16

    /// RGB data uses 101010 format (10 bits per component, 2 bits unused).
    case RGB101010 = 196608  // 3 << 16

    /// RGB data uses CIF10 format.
    case RGBCIF10 = 262144  // 4 << 16
}


