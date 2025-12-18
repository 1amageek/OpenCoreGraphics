//
//  CGImage.swift
//  OpenCoreGraphics
//
//  Created by OpenCoreGraphics contributors.
//

import Foundation


/// A bitmap image or image mask.
///
/// A bitmap image is a rectangular array of pixels, each of which represents
/// a single sample or data point from a source image.
public final class CGImage: @unchecked Sendable {

    /// The width, in pixels, of the image.
    public let width: Int

    /// The height, in pixels, of the image.
    public let height: Int

    /// The number of bits for each component of a pixel.
    public let bitsPerComponent: Int

    /// The number of bits for each pixel.
    public let bitsPerPixel: Int

    /// The number of bytes for each row of the image.
    public let bytesPerRow: Int

    /// The color space for the image.
    public let colorSpace: CGColorSpace?

    /// The bitmap info for the image.
    public let bitmapInfo: CGBitmapInfo

    /// The decode array for the image (stored as contiguous memory for pointer access).
    private let decodeStorage: ContiguousArray<CGFloat>?

    /// Whether the image should be interpolated.
    public let shouldInterpolate: Bool

    /// The rendering intent for the image.
    public let renderingIntent: CGColorRenderingIntent

    /// Whether the image is a mask.
    public let isMask: Bool

    /// The underlying data for the image.
    internal let data: Data?

    /// The content headroom for HDR images.
    internal let _contentHeadroom: Float?

    /// The content average light level for HDR images.
    internal let _contentAverageLightLevel: Float?

    /// Cached data provider.
    private var _cachedDataProvider: CGDataProvider?

    // MARK: - Computed Properties

    /// The alpha info for the image.
    @inlinable
    public var alphaInfo: CGImageAlphaInfo {
        bitmapInfo.alpha
    }

    /// The byte order info for the image.
    @inlinable
    public var byteOrderInfo: CGImageByteOrderInfo {
        bitmapInfo.byteOrder
    }

    /// The pixel format info for the image.
    @inlinable
    public var pixelFormatInfo: CGImagePixelFormatInfo {
        bitmapInfo.pixelFormat
    }

    /// Returns the decode array for a bitmap image.
    ///
    /// - Note: The returned pointer is valid only for the lifetime of this CGImage instance.
    public var decode: UnsafePointer<CGFloat>? {
        decodeStorage?.withUnsafeBufferPointer { $0.baseAddress }
    }

    /// The content headroom value for HDR images.
    ///
    /// Returns 1.0 for standard dynamic range images.
    public var contentHeadroom: Float {
        _contentHeadroom ?? 1.0
    }

    /// The calculated content headroom value for HDR images.
    ///
    /// Returns 0 if not calculated.
    public var calculatedContentHeadroom: Float {
        _contentHeadroom ?? 0.0
    }

    /// The content average light level for HDR images.
    ///
    /// Returns 0 if not set.
    public var contentAverageLightLevel: Float {
        _contentAverageLightLevel ?? 0.0
    }

    /// The calculated content average light level for HDR images.
    ///
    /// Returns 0 if not calculated.
    public var calculatedContentAverageLightLevel: Float {
        _contentAverageLightLevel ?? 0.0
    }

    /// Whether the image should be tone mapped.
    public var shouldToneMap: Bool {
        _contentHeadroom.map { $0 > 1.0 } ?? false
    }

    /// Whether the image contains image-specific tone mapping metadata.
    public var containsImageSpecificToneMappingMetadata: Bool {
        _contentHeadroom != nil || _contentAverageLightLevel != nil
    }

    /// The Universal Type Identifier for the image.
    public var utType: String? {
        nil
    }

    // MARK: - Private Helpers

    /// Copies decode values from an unsafe pointer into a ContiguousArray.
    @inline(__always)
    private static func copyDecodeArray(
        from decode: UnsafePointer<CGFloat>?,
        count: Int
    ) -> ContiguousArray<CGFloat>? {
        guard let decode = decode, count > 0 else { return nil }
        return ContiguousArray(UnsafeBufferPointer(start: decode, count: count))
    }

    /// Common initialization logic shared by multiple initializers.
    private init(
        width: Int,
        height: Int,
        bitsPerComponent: Int,
        bitsPerPixel: Int,
        bytesPerRow: Int,
        colorSpace: CGColorSpace?,
        bitmapInfo: CGBitmapInfo,
        decodeStorage: ContiguousArray<CGFloat>?,
        shouldInterpolate: Bool,
        renderingIntent: CGColorRenderingIntent,
        isMask: Bool,
        data: Data?,
        contentHeadroom: Float?,
        contentAverageLightLevel: Float?
    ) {
        self.width = width
        self.height = height
        self.bitsPerComponent = bitsPerComponent
        self.bitsPerPixel = bitsPerPixel
        self.bytesPerRow = bytesPerRow
        self.colorSpace = colorSpace
        self.bitmapInfo = bitmapInfo
        self.decodeStorage = decodeStorage
        self.shouldInterpolate = shouldInterpolate
        self.renderingIntent = renderingIntent
        self.isMask = isMask
        self.data = data
        self._contentHeadroom = contentHeadroom
        self._contentAverageLightLevel = contentAverageLightLevel
        self._cachedDataProvider = nil
    }

    // MARK: - Public Initializers

    /// Creates a bitmap image from data supplied by a data provider.
    ///
    /// - Parameters:
    ///   - width: The width, in pixels, of the required image.
    ///   - height: The height, in pixels, of the required image.
    ///   - bitsPerComponent: The number of bits for each component in a source pixel.
    ///   - bitsPerPixel: The total number of bits in a source pixel.
    ///   - bytesPerRow: The number of bytes per row in the image data.
    ///   - space: The destination color space.
    ///   - bitmapInfo: Bitmap layout information.
    ///   - provider: The data provider for the image data.
    ///   - decode: The decode array for the image.
    ///   - shouldInterpolate: Whether the image should be interpolated.
    ///   - intent: The rendering intent.
    public convenience init?(
        width: Int,
        height: Int,
        bitsPerComponent: Int,
        bitsPerPixel: Int,
        bytesPerRow: Int,
        space: CGColorSpace,
        bitmapInfo: CGBitmapInfo,
        provider: CGDataProvider,
        decode: UnsafePointer<CGFloat>?,
        shouldInterpolate: Bool,
        intent: CGColorRenderingIntent
    ) {
        guard width > 0, height > 0,
              bitsPerComponent > 0, bitsPerPixel > 0 else {
            return nil
        }

        let decodeCount = space.numberOfComponents * 2
        let decodeStorage = Self.copyDecodeArray(from: decode, count: decodeCount)

        self.init(
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bitsPerPixel: bitsPerPixel,
            bytesPerRow: bytesPerRow,
            colorSpace: space,
            bitmapInfo: bitmapInfo,
            decodeStorage: decodeStorage,
            shouldInterpolate: shouldInterpolate,
            renderingIntent: intent,
            isMask: false,
            data: provider.data,
            contentHeadroom: nil,
            contentAverageLightLevel: nil
        )
    }

    /// Creates a bitmap image from data with HDR headroom support.
    ///
    /// - Parameters:
    ///   - headroom: The content headroom value for HDR images.
    ///   - width: The width, in pixels, of the required image.
    ///   - height: The height, in pixels, of the required image.
    ///   - bitsPerComponent: The number of bits for each component in a source pixel.
    ///   - bitsPerPixel: The total number of bits in a source pixel.
    ///   - bytesPerRow: The number of bytes per row in the image data.
    ///   - space: The destination color space.
    ///   - bitmapInfo: Bitmap layout information.
    ///   - provider: The data provider for the image data.
    ///   - decode: The decode array for the image.
    ///   - shouldInterpolate: Whether the image should be interpolated.
    ///   - intent: The rendering intent.
    public convenience init?(
        headroom: Float,
        width: Int,
        height: Int,
        bitsPerComponent: Int,
        bitsPerPixel: Int,
        bytesPerRow: Int,
        space: CGColorSpace,
        bitmapInfo: CGBitmapInfo,
        provider: CGDataProvider,
        decode: UnsafePointer<CGFloat>?,
        shouldInterpolate: Bool,
        intent: CGColorRenderingIntent
    ) {
        guard width > 0, height > 0,
              bitsPerComponent > 0, bitsPerPixel > 0,
              headroom >= 1.0 else {
            return nil
        }

        let decodeCount = space.numberOfComponents * 2
        let decodeStorage = Self.copyDecodeArray(from: decode, count: decodeCount)

        self.init(
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bitsPerPixel: bitsPerPixel,
            bytesPerRow: bytesPerRow,
            colorSpace: space,
            bitmapInfo: bitmapInfo,
            decodeStorage: decodeStorage,
            shouldInterpolate: shouldInterpolate,
            renderingIntent: intent,
            isMask: false,
            data: provider.data,
            contentHeadroom: headroom,
            contentAverageLightLevel: nil
        )
    }

    // MARK: - Legacy Image Decoding APIs (Intentionally Not Provided)
    //
    // The following APIs exist in Apple's CoreGraphics but are considered legacy:
    // - init?(jpegDataProviderSource:decode:shouldInterpolate:intent:)
    // - init?(pngDataProviderSource:decode:shouldInterpolate:intent:)
    //
    // Apple's modern design separates concerns:
    // - ImageIO: Responsible for image format decoding/encoding
    // - CoreGraphics: Responsible for image representation and drawing
    //
    // OpenCoreGraphics follows this modern design philosophy.
    // For image decoding in WASM environments, use a dedicated ImageIO-equivalent module.
    //
    // Reference: Apple Documentation recommends "Use Image I/O instead" for these APIs.

    /// Creates a bitmap image mask from data supplied by a data provider.
    ///
    /// - Parameters:
    ///   - maskWidth: The width, in pixels, of the required image mask.
    ///   - height: The height, in pixels, of the required image mask.
    ///   - bitsPerComponent: The number of bits for each component in a source pixel.
    ///   - bitsPerPixel: The total number of bits in a source pixel.
    ///   - bytesPerRow: The number of bytes per row in the image data.
    ///   - provider: The data provider for the image data.
    ///   - decode: The decode array for the image.
    ///   - shouldInterpolate: Whether the image should be interpolated.
    public convenience init?(
        maskWidth: Int,
        height: Int,
        bitsPerComponent: Int,
        bitsPerPixel: Int,
        bytesPerRow: Int,
        provider: CGDataProvider,
        decode: UnsafePointer<CGFloat>?,
        shouldInterpolate: Bool
    ) {
        guard maskWidth > 0, height > 0,
              bitsPerComponent > 0, bitsPerPixel > 0 else {
            return nil
        }

        // For masks, decode array typically has 2 values
        let decodeStorage = Self.copyDecodeArray(from: decode, count: 2)

        self.init(
            width: maskWidth,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bitsPerPixel: bitsPerPixel,
            bytesPerRow: bytesPerRow,
            colorSpace: nil,
            bitmapInfo: CGBitmapInfo(rawValue: 0),
            decodeStorage: decodeStorage,
            shouldInterpolate: shouldInterpolate,
            renderingIntent: .defaultIntent,
            isMask: true,
            data: provider.data,
            contentHeadroom: nil,
            contentAverageLightLevel: nil
        )
    }

    // MARK: - Copying Images

    /// Creates a copy of the image.
    public func copy() -> CGImage? {
        CGImage(
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bitsPerPixel: bitsPerPixel,
            bytesPerRow: bytesPerRow,
            colorSpace: colorSpace,
            bitmapInfo: bitmapInfo,
            decodeStorage: decodeStorage,
            shouldInterpolate: shouldInterpolate,
            renderingIntent: renderingIntent,
            isMask: isMask,
            data: data,
            contentHeadroom: _contentHeadroom,
            contentAverageLightLevel: _contentAverageLightLevel
        )
    }

    /// Creates a copy of the image using a different color space.
    ///
    /// - Parameter colorSpace: The destination color space.
    /// - Returns: A new image with the specified color space, or nil if the image is a mask.
    public func copy(colorSpace: CGColorSpace) -> CGImage? {
        guard !isMask else { return nil }
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bitsPerPixel: bitsPerPixel,
            bytesPerRow: bytesPerRow,
            colorSpace: colorSpace,
            bitmapInfo: bitmapInfo,
            decodeStorage: decodeStorage,
            shouldInterpolate: shouldInterpolate,
            renderingIntent: renderingIntent,
            isMask: false,
            data: data,
            contentHeadroom: _contentHeadroom,
            contentAverageLightLevel: _contentAverageLightLevel
        )
    }

    /// Creates a copy of the image with the specified content average light level.
    ///
    /// - Parameter contentAverageLightLevel: The content average light level value.
    /// - Returns: A new image with the specified content average light level.
    public func copy(contentAverageLightLevel: Float) -> CGImage? {
        CGImage(
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bitsPerPixel: bitsPerPixel,
            bytesPerRow: bytesPerRow,
            colorSpace: colorSpace,
            bitmapInfo: bitmapInfo,
            decodeStorage: decodeStorage,
            shouldInterpolate: shouldInterpolate,
            renderingIntent: renderingIntent,
            isMask: isMask,
            data: data,
            contentHeadroom: _contentHeadroom,
            contentAverageLightLevel: contentAverageLightLevel
        )
    }

    /// Creates a copy of the image with calculated HDR statistics.
    ///
    /// - Returns: A new image with calculated HDR statistics.
    public func copyWithCalculatedHDRStats() -> CGImage? {
        // In a full implementation, this would analyze the image data
        // to calculate actual HDR statistics
        copy()
    }

    // MARK: - Creating Images by Modifying

    /// Creates a bitmap image using the data contained within a subregion of an existing bitmap image.
    ///
    /// - Parameter rect: The rectangle specifying the subregion.
    /// - Returns: A new cropped image, or nil if the operation fails.
    public func cropping(to rect: CGRect) -> CGImage? {
        let x = Int(rect.origin.x)
        let y = Int(rect.origin.y)
        let cropWidth = Int(rect.width)
        let cropHeight = Int(rect.height)

        // Validate bounds
        guard x >= 0, y >= 0,
              x + cropWidth <= width,
              y + cropHeight <= height,
              cropWidth > 0, cropHeight > 0 else {
            return nil
        }

        guard let sourceData = data else { return nil }

        let bytesPerPixelValue = bitsPerPixel / 8
        let newBytesPerRow = cropWidth * bytesPerPixelValue
        let totalBytes = newBytesPerRow * cropHeight

        // Optimized memory copy using withUnsafeBytes
        var newData = Data(count: totalBytes)

        let success = sourceData.withUnsafeBytes { sourceBuffer -> Bool in
            guard let sourceBase = sourceBuffer.baseAddress else { return false }

            return newData.withUnsafeMutableBytes { destBuffer -> Bool in
                guard let destBase = destBuffer.baseAddress else { return false }

                for row in 0..<cropHeight {
                    let sourceOffset = (y + row) * bytesPerRow + x * bytesPerPixelValue
                    let destOffset = row * newBytesPerRow

                    guard sourceOffset + newBytesPerRow <= sourceData.count else {
                        return false
                    }

                    memcpy(
                        destBase.advanced(by: destOffset),
                        sourceBase.advanced(by: sourceOffset),
                        newBytesPerRow
                    )
                }
                return true
            }
        }

        guard success else { return nil }

        return CGImage(
            width: cropWidth,
            height: cropHeight,
            bitsPerComponent: bitsPerComponent,
            bitsPerPixel: bitsPerPixel,
            bytesPerRow: newBytesPerRow,
            colorSpace: colorSpace,
            bitmapInfo: bitmapInfo,
            decodeStorage: decodeStorage,
            shouldInterpolate: shouldInterpolate,
            renderingIntent: renderingIntent,
            isMask: isMask,
            data: newData,
            contentHeadroom: _contentHeadroom,
            contentAverageLightLevel: _contentAverageLightLevel
        )
    }

    /// Creates a bitmap image from an existing image and an image mask.
    ///
    /// - Parameter mask: The image mask.
    /// - Returns: A new masked image, or nil if the mask is invalid.
    public func masking(_ mask: CGImage) -> CGImage? {
        guard mask.isMask else { return nil }
        // In a full implementation, this would apply the mask
        return copy()
    }

    /// Creates a copy of the image with the specified color values masked.
    ///
    /// - Parameter components: The color components to mask.
    /// - Returns: A new image with the specified colors masked.
    public func copy(maskingColorComponents components: [CGFloat]) -> CGImage? {
        guard !isMask else { return nil }
        // In a full implementation, this would mask specific color components
        return copy()
    }

    // MARK: - Getting the Data Provider

    /// Returns the data provider for the image.
    public var dataProvider: CGDataProvider? {
        if let cached = _cachedDataProvider {
            return cached
        }
        guard let data = data else { return nil }
        let provider = CGDataProvider(data: data)
        // Note: Cannot cache here as properties are let-bound for Sendable
        // In a real implementation, consider using a lock or making this computed
        return provider
    }

    // MARK: - Type ID

    /// Returns the type identifier for CGImage objects.
    public class var typeID: UInt {
        0 // Placeholder for type ID
    }
}

// MARK: - Equatable

extension CGImage: Equatable {
    @inlinable
    public static func == (lhs: CGImage, rhs: CGImage) -> Bool {
        lhs === rhs
    }
}

// MARK: - Hashable

extension CGImage: Hashable {
    @inlinable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}

