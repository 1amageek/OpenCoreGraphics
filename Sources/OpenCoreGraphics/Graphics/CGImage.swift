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

    /// Stable heap-allocated decode pointer for safe access via `decode` property.
    private let _decodePointer: UnsafeMutableBufferPointer<CGFloat>?

    /// Whether the image should be interpolated.
    public let shouldInterpolate: Bool

    /// The rendering intent for the image.
    public let renderingIntent: CGColorRenderingIntent

    /// Whether the image is a mask.
    public let isMask: Bool

    /// The underlying data for the image.
    public let data: Data?

    /// The content headroom for HDR images.
    internal let _contentHeadroom: Float?

    /// The content average light level for HDR images.
    internal let _contentAverageLightLevel: Float?

    /// The original data provider supplied at initialization time, retained so
    /// that `dataProvider` can return the caller's provider rather than fabricating
    /// a fresh in-memory one — callers may rely on identity (e.g. comparing
    /// providers) or on the provider's `info` / release callbacks staying alive.
    private let _retainedProvider: CGDataProvider?

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
    /// - Note: The returned pointer is valid for the lifetime of this CGImage instance.
    public var decode: UnsafePointer<CGFloat>? {
        guard let pointer = _decodePointer?.baseAddress else { return nil }
        return UnsafePointer(pointer)
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
        calculatedHDRStats()?.headroom ?? 0
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
        calculatedHDRStats()?.averageLightLevel ?? 0
    }

    /// Whether the image should be tone mapped.
    public var shouldToneMap: Bool {
        _contentHeadroom.map { $0 > 1.0 } ?? false
    }

    internal var requiresToneMappingFor8BitOutput: Bool {
        bitsPerComponent > 8 || shouldToneMap || colorSpace?.isHDR() == true
    }

    /// Whether the image contains image-specific tone mapping metadata.
    public var containsImageSpecificToneMappingMetadata: Bool {
        false
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
        contentAverageLightLevel: Float?,
        retainedProvider: CGDataProvider? = nil
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
        self._retainedProvider = retainedProvider

        // Allocate stable heap buffer for decode pointer access
        if let storage = decodeStorage, !storage.isEmpty {
            let buffer = UnsafeMutableBufferPointer<CGFloat>.allocate(capacity: storage.count)
            _ = buffer.initialize(from: storage)
            self._decodePointer = buffer
        } else {
            self._decodePointer = nil
        }
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
            contentAverageLightLevel: nil,
            retainedProvider: provider
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
        let isFloatExtended = space.name?.contains("Extended") == true
            && bitmapInfo.isFloatComponents
            && (bitsPerComponent == 16 || bitsPerComponent == 32)
        let isPQOrHLG = space.name?.contains("_PQ") == true || space.name?.contains("_HLG") == true
        guard width > 0, height > 0,
              bitsPerComponent > 0, bitsPerPixel > 0,
              headroom.isFinite,
              headroom == 0 || headroom >= 1,
              isFloatExtended || isPQOrHLG else {
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
            contentHeadroom: headroom == 0 ? nil : headroom,
            contentAverageLightLevel: nil,
            retainedProvider: provider
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
            contentAverageLightLevel: nil,
            retainedProvider: provider
        )
    }

    // MARK: - Copying Images

    /// Creates a copy of the image.
    public func copy() -> CGImage? {
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
        guard !isMask,
              let sourceColorSpace = self.colorSpace,
              let sourceData = data ?? dataProvider?.data else {
            return nil
        }

        let componentCount = colorSpace.numberOfComponents + 1
        let destinationBitmapInfo = CGBitmapInfo(
            rawValue: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        let destinationFormat = CGColorBufferFormat(
            version: 0,
            bitmapInfo: destinationBitmapInfo,
            bitsPerComponent: 8,
            bitsPerPixel: componentCount * 8,
            bytesPerRow: width * componentCount
        )
        var convertedData = Data(count: destinationFormat.bytesPerRow * height)
        let converted = sourceData.withUnsafeBytes { sourceBuffer -> Bool in
            guard let sourceBase = sourceBuffer.baseAddress else { return false }
            return convertedData.withUnsafeMutableBytes { destinationBuffer -> Bool in
                guard let destinationBase = destinationBuffer.baseAddress else { return false }
                return CGColorBufferConverter.convert(
                    width: width,
                    height: height,
                    destinationBuffer: destinationBase,
                    destinationFormat: destinationFormat,
                    destinationColorSpace: colorSpace,
                    sourceBuffer: sourceBase,
                    sourceFormat: colorBufferFormat,
                    sourceColorSpace: sourceColorSpace,
                    intent: renderingIntent,
                    options: nil
                )
            }
        }
        guard converted else { return nil }

        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: destinationFormat.bitsPerComponent,
            bitsPerPixel: destinationFormat.bitsPerPixel,
            bytesPerRow: destinationFormat.bytesPerRow,
            colorSpace: colorSpace,
            bitmapInfo: destinationBitmapInfo,
            decodeStorage: nil,
            shouldInterpolate: shouldInterpolate,
            renderingIntent: renderingIntent,
            isMask: false,
            data: convertedData,
            contentHeadroom: _contentHeadroom,
            contentAverageLightLevel: _contentAverageLightLevel
        )
    }

    /// Creates a copy of the image with the specified content average light level.
    ///
    /// - Parameter contentAverageLightLevel: The content average light level value.
    /// - Returns: A new image with the specified content average light level.
    public func copy(contentAverageLightLevel: Float) -> CGImage? {
        guard !isMask,
              colorSpace?.model == .rgb,
              contentAverageLightLevel.isFinite,
              contentAverageLightLevel >= 0 else {
            return nil
        }
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
        guard let stats = calculatedHDRStats() else { return nil }
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
            data: data ?? dataProvider?.data,
            contentHeadroom: max(1, stats.headroom),
            contentAverageLightLevel: stats.averageLightLevel
        )
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

        // Try to get source data from data or dataProvider
        let sourceData: Data
        if let directData = data {
            sourceData = directData
        } else if let provider = dataProvider, let providerData = provider.data {
            sourceData = providerData
        } else {
            return nil
        }

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
        guard !isMask,
              mask.isMask || Self.isValidGrayMaskImage(mask),
              let source = rgba8Data(),
              let maskBuffer = CGImageMaskBuffer(
                width: width,
                height: height,
                clips: [
                    CGImageMaskClip(
                        rect: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)),
                        transform: .identity,
                        image: mask
                    )
                ]
              ) else {
            return nil
        }

        var result = source
        let applied = result.withUnsafeMutableBytes { resultBuffer -> Bool in
            guard let resultBytes = resultBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return false
            }
            return maskBuffer.rgba8.withUnsafeBytes { maskBuffer -> Bool in
                guard let maskBytes = maskBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                    return false
                }
                for pixel in 0..<(width * height) {
                    let offset = pixel * 4
                    let coverage = UInt16(maskBytes[offset])
                    for component in 0..<4 {
                        let value = UInt16(resultBytes[offset + component])
                        resultBytes[offset + component] = UInt8((value * coverage + 127) / 255)
                    }
                }
                return true
            }
        }
        guard applied else { return nil }
        return makeRGBA8Image(data: result)
    }

    /// Creates a copy of the image with the specified color values masked.
    ///
    /// - Parameter components: The color components to mask.
    /// - Returns: A new image with the specified colors masked.
    public func copy(maskingColorComponents components: [CGFloat]) -> CGImage? {
        guard !isMask,
              let sourceColorSpace = colorSpace,
              components.count == sourceColorSpace.numberOfComponents * 2,
              let sourceData = data ?? dataProvider?.data,
              let sourceLayout = CGColorBufferConverter.Layout(
                format: colorBufferFormat,
                colorSpace: sourceColorSpace,
                width: width
              ),
              sourceData.count >= sourceLayout.bytesPerRow * height,
              let rgba8 = rgba8Data() else {
            return nil
        }

        for index in stride(from: 0, to: components.count, by: 2) {
            guard components[index] <= components[index + 1] else { return nil }
        }

        var result = rgba8
        let applied = sourceData.withUnsafeBytes { sourceBuffer -> Bool in
            guard let sourceBytes = sourceBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return false
            }
            return result.withUnsafeMutableBytes { resultBuffer -> Bool in
                guard let resultBytes = resultBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                    return false
                }
                for y in 0..<height {
                    for x in 0..<width {
                        let sourceOffset = y * sourceLayout.bytesPerRow + x * sourceLayout.bytesPerPixel
                        guard let pixel = CGColorBufferConverter.decodePixel(
                            sourceBytes,
                            offset: sourceOffset,
                            layout: sourceLayout
                        ) else {
                            return false
                        }

                        let matches = pixel.components.enumerated().allSatisfy { index, value in
                            let decodedValue: CGFloat
                            if let decodeStorage = decodeStorage {
                                let lower = decodeStorage[index * 2]
                                let upper = decodeStorage[index * 2 + 1]
                                decodedValue = lower + value * (upper - lower)
                            } else {
                                decodedValue = value
                            }
                            return decodedValue >= components[index * 2]
                                && decodedValue <= components[index * 2 + 1]
                        }
                        if matches {
                            let resultOffset = (y * width + x) * 4
                            resultBytes[resultOffset] = 0
                            resultBytes[resultOffset + 1] = 0
                            resultBytes[resultOffset + 2] = 0
                            resultBytes[resultOffset + 3] = 0
                        }
                    }
                }
                return true
            }
        }
        guard applied else { return nil }
        return makeRGBA8Image(data: result)
    }

    private var colorBufferFormat: CGColorBufferFormat {
        CGColorBufferFormat(
            version: 0,
            bitmapInfo: bitmapInfo,
            bitsPerComponent: bitsPerComponent,
            bitsPerPixel: bitsPerPixel,
            bytesPerRow: bytesPerRow
        )
    }

    private func calculatedHDRStats() -> (headroom: Float, averageLightLevel: Float)? {
        guard !isMask,
              width > 0,
              height > 0,
              let sourceColorSpace = colorSpace,
              sourceColorSpace.model == .rgb,
              let sourceData = data ?? dataProvider?.data,
              let sourceLayout = CGColorBufferConverter.Layout(
                format: colorBufferFormat,
                colorSpace: sourceColorSpace,
                width: width
              ),
              sourceData.count >= sourceLayout.bytesPerRow * height else {
            return nil
        }

        let transferFunction = CGImageTransferFunction(colorSpace: sourceColorSpace)
        var maximumLuminance: CGFloat = 0
        var luminanceSum: Double = 0
        let decoded = sourceData.withUnsafeBytes { sourceBuffer -> Bool in
            guard let sourceBytes = sourceBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return false
            }
            for y in 0..<height {
                for x in 0..<width {
                    let offset = y * sourceLayout.bytesPerRow + x * sourceLayout.bytesPerPixel
                    guard let pixel = CGColorBufferConverter.decodePixel(
                        sourceBytes,
                        offset: offset,
                        layout: sourceLayout
                    ), pixel.components.count == 3 else {
                        return false
                    }
                    let decodedComponents = applyingDecodeArray(to: pixel.components)
                    let linear = decodedComponents.map(transferFunction.decode)
                    let luminance = max(sourceColorSpace.luminance(of: linear), 0)
                    maximumLuminance = max(maximumLuminance, luminance)
                    luminanceSum += Double(luminance)
                }
            }
            return true
        }
        guard decoded else { return nil }
        let pixelCount = Double(width * height)
        return (Float(maximumLuminance), Float(luminanceSum / pixelCount))
    }

    private func applyingDecodeArray(to components: [CGFloat]) -> [CGFloat] {
        guard let decodeStorage else { return components }
        return components.enumerated().map { index, value in
            let lower = decodeStorage[index * 2]
            let upper = decodeStorage[index * 2 + 1]
            return lower + value * (upper - lower)
        }
    }

    private func rgba8Data() -> Data? {
        guard let sourceColorSpace = colorSpace,
              let destinationColorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let sourceData = data ?? dataProvider?.data,
              sourceData.count >= bytesPerRow * height else {
            return nil
        }

        let destinationFormat = CGColorBufferFormat(
            version: 0,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4
        )
        var result = Data(count: width * height * 4)
        let converted = sourceData.withUnsafeBytes { sourceBuffer -> Bool in
            guard let sourceBase = sourceBuffer.baseAddress else { return false }
            return result.withUnsafeMutableBytes { resultBuffer -> Bool in
                guard let resultBase = resultBuffer.baseAddress else { return false }
                return CGColorBufferConverter.convert(
                    width: width,
                    height: height,
                    destinationBuffer: resultBase,
                    destinationFormat: destinationFormat,
                    destinationColorSpace: destinationColorSpace,
                    sourceBuffer: sourceBase,
                    sourceFormat: colorBufferFormat,
                    sourceColorSpace: sourceColorSpace,
                    intent: renderingIntent,
                    options: nil
                )
            }
        }
        return converted ? result : nil
    }

    private func makeRGBA8Image(data: Data) -> CGImage? {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: space,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: CGDataProvider(data: data),
            decode: nil,
            shouldInterpolate: shouldInterpolate,
            intent: renderingIntent
        )
    }

    internal func toneMapped(
        by method: CGToneMapping,
        targetHeadroom: Float,
        options: [String: Any]?
    ) -> CGImage? {
        guard !isMask,
              width > 0,
              height > 0,
              targetHeadroom.isFinite,
              targetHeadroom >= 1,
              let sourceColorSpace = colorSpace,
              sourceColorSpace.model == .rgb,
              let sourceData = data ?? dataProvider?.data,
              let sourceLayout = CGColorBufferConverter.Layout(
                format: colorBufferFormat,
                colorSpace: sourceColorSpace,
                width: width
              ),
              sourceData.count >= sourceLayout.bytesPerRow * height,
              let configuration = ToneMappingConfiguration(
                method: method,
                sourceColorSpace: sourceColorSpace,
                sourceHeadroom: _contentHeadroom ?? calculatedHDRStats()?.headroom,
                targetHeadroom: targetHeadroom,
                hasImageSpecificMetadata: containsImageSpecificToneMappingMetadata,
                options: options
              ) else {
            return nil
        }

        var output = Data(count: width * height * 4)
        let converted = sourceData.withUnsafeBytes { sourceBuffer -> Bool in
            guard let sourceBytes = sourceBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return false
            }
            return output.withUnsafeMutableBytes { outputBuffer -> Bool in
                guard let outputBytes = outputBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                    return false
                }
                for y in 0..<height {
                    for x in 0..<width {
                        let sourceOffset = y * sourceLayout.bytesPerRow + x * sourceLayout.bytesPerPixel
                        guard let pixel = CGColorBufferConverter.decodePixel(
                            sourceBytes,
                            offset: sourceOffset,
                            layout: sourceLayout
                        ), pixel.components.count == 3 else {
                            return false
                        }
                        let mapped = configuration.map(applyingDecodeArray(to: pixel.components))
                        let destinationOffset = (y * width + x) * 4
                        outputBytes[destinationOffset] = Self.sRGBByte(mapped[0], alpha: pixel.alpha)
                        outputBytes[destinationOffset + 1] = Self.sRGBByte(mapped[1], alpha: pixel.alpha)
                        outputBytes[destinationOffset + 2] = Self.sRGBByte(mapped[2], alpha: pixel.alpha)
                        outputBytes[destinationOffset + 3] = Self.byte(pixel.alpha)
                    }
                }
                return true
            }
        }
        guard converted else { return nil }
        return makeRGBA8Image(data: output)
    }

    private static func sRGBByte(_ linearComponent: CGFloat, alpha: CGFloat) -> UInt8 {
        let clamped = min(max(linearComponent, 0), 1)
        let encoded: CGFloat
        if clamped <= 0.0031308 {
            encoded = clamped * 12.92
        } else {
            encoded = 1.055 * pow(clamped, 1 / 2.4) - 0.055
        }
        return byte(encoded * min(max(alpha, 0), 1))
    }

    private static func byte(_ component: CGFloat) -> UInt8 {
        UInt8((min(max(component, 0), 1) * 255).rounded())
    }

    private static func isValidGrayMaskImage(_ image: CGImage) -> Bool {
        guard image.colorSpace?.model == .monochrome else { return false }
        switch image.alphaInfo {
        case .none, .noneSkipFirst, .noneSkipLast:
            return true
        case .premultipliedFirst, .premultipliedLast, .first, .last, .alphaOnly:
            return false
        }
    }

    // MARK: - Getting the Data Provider

    /// Returns the data provider for the image.
    ///
    /// When this image was constructed from a provider, the original provider is
    /// returned verbatim so callers see consistent identity and so any release
    /// callbacks the provider holds stay alive for as long as the image does.
    /// Otherwise a fresh in-memory provider is synthesized from the pixel data.
    public var dataProvider: CGDataProvider? {
        if let retained = _retainedProvider {
            return retained
        }
        guard let data = data else { return nil }
        return CGDataProvider(data: data)
    }

    deinit {
        _decodePointer?.deallocate()
    }

    // MARK: - Type ID

    /// Returns the type identifier for CGImage objects.
    public class var typeID: UInt {
        CGTypeIdentifier.image
    }
}

private enum CGImageTransferFunction {
    case linear
    case sRGB
    case perceptualQuantizer
    case hybridLogGamma

    init(colorSpace: CGColorSpace) {
        let name = colorSpace.name ?? ""
        if name.contains("_PQ") {
            self = .perceptualQuantizer
        } else if name.contains("_HLG") {
            self = .hybridLogGamma
        } else if name.contains("Linear") || name.contains("ACESCG") {
            self = .linear
        } else {
            self = .sRGB
        }
    }

    var impliedHeadroom: Float {
        switch self {
        case .perceptualQuantizer: return 100
        case .hybridLogGamma: return 12
        case .linear, .sRGB: return 1
        }
    }

    func decode(_ component: CGFloat) -> CGFloat {
        switch self {
        case .linear:
            return component
        case .sRGB:
            let sign: CGFloat = component < 0 ? -1 : 1
            let magnitude = abs(component)
            if magnitude <= 0.04045 {
                return component / 12.92
            }
            return sign * pow((magnitude + 0.055) / 1.055, 2.4)
        case .perceptualQuantizer:
            let m1: CGFloat = 2610 / 16384
            let m2: CGFloat = 2523 / 32
            let c1: CGFloat = 3424 / 4096
            let c2: CGFloat = 2413 / 128
            let c3: CGFloat = 2392 / 128
            let power = pow(min(max(component, 0), 1), 1 / m2)
            let denominator = c2 - c3 * power
            guard denominator > 0 else { return 100 }
            return pow(max(power - c1, 0) / denominator, 1 / m1) * 100
        case .hybridLogGamma:
            let value = min(max(component, 0), 1)
            if value <= 0.5 {
                return value * value / 3
            }
            let a: CGFloat = 0.17883277
            let b: CGFloat = 0.28466892
            let c: CGFloat = 0.55991073
            return (exp((value - c) / a) + b) / 12
        }
    }
}

private extension CGColorSpace {
    var rgbLuminanceCoefficients: (red: CGFloat, green: CGFloat, blue: CGFloat) {
        let name = name ?? ""
        if name.contains("ITUR_2020") || name.contains("ITUR_2100") {
            return (0.2627, 0.6780, 0.0593)
        }
        if name.contains("DisplayP3") || name.contains("DCIP3") {
            return (0.22897456, 0.69173852, 0.07928691)
        }
        if name.contains("ACESCG") {
            return (0.27222872, 0.67408177, 0.05368952)
        }
        return (0.2126, 0.7152, 0.0722)
    }

    func luminance(of components: [CGFloat]) -> CGFloat {
        let coefficients = rgbLuminanceCoefficients
        return components[0] * coefficients.red
            + components[1] * coefficients.green
            + components[2] * coefficients.blue
    }
}

private struct ToneMappingConfiguration {

    private let method: CGToneMapping
    private let transferFunction: CGImageTransferFunction
    private let luminanceCoefficients: (red: CGFloat, green: CGFloat, blue: CGFloat)
    private let sourceHeadroom: CGFloat
    private let targetHeadroom: CGFloat
    private let exrDefog: CGFloat
    private let exrExposure: CGFloat
    private let exrKneeLow: CGFloat
    private let exrKneeHigh: CGFloat
    private let use100nitsHLGOOTF: Bool
    private let useBT1886Gamma: Bool
    private let useLegacyHDREcosystem: Bool

    init?(
        method: CGToneMapping,
        sourceColorSpace: CGColorSpace,
        sourceHeadroom: Float?,
        targetHeadroom: Float,
        hasImageSpecificMetadata: Bool,
        options: [String: Any]?
    ) {
        transferFunction = CGImageTransferFunction(colorSpace: sourceColorSpace)
        luminanceCoefficients = sourceColorSpace.rgbLuminanceCoefficients

        if method == .imageSpecificLumaScaling && !hasImageSpecificMetadata {
            return nil
        }
        if method == .ituRecommended,
           transferFunction != .perceptualQuantizer,
           transferFunction != .hybridLogGamma {
            return nil
        }
        if method == .exrGamma, transferFunction != .linear {
            return nil
        }

        var defog: CGFloat = 0
        var exposure: CGFloat = 0
        var kneeLow: CGFloat = 0
        var kneeHigh: CGFloat = 5
        if method == .exrGamma {
            guard let parsedDefog = Self.number(options?[kCGEXRToneMappingGammaDefog], default: defog),
                  let parsedExposure = Self.number(options?[kCGEXRToneMappingGammaExposure], default: exposure),
                  let parsedKneeLow = Self.number(options?[kCGEXRToneMappingGammaKneeLow], default: kneeLow),
                  let parsedKneeHigh = Self.number(options?[kCGEXRToneMappingGammaKneeHigh], default: kneeHigh),
                  (0...0.01).contains(parsedDefog),
                  (-10...10).contains(parsedExposure),
                  (-2.85...3).contains(parsedKneeLow),
                  (3.5...7.5).contains(parsedKneeHigh) else {
                return nil
            }
            defog = parsedDefog
            exposure = parsedExposure
            kneeLow = parsedKneeLow
            kneeHigh = parsedKneeHigh
        }

        var use100nitsHLGOOTF = false
        var useBT1886Gamma = false
        var useLegacyHDREcosystem = false
        if method == .ituRecommended {
            guard let parsedUse100nitsHLGOOTF = Self.boolean(
                options?[kCGUse100nitsHLGOOTF],
                default: use100nitsHLGOOTF
            ), let parsedUseBT1886Gamma = Self.boolean(
                options?[kCGUseBT1886ForCoreVideoGamma],
                default: useBT1886Gamma
            ), Self.boolean(options?[kCGSkipBoostToHDR], default: false) != nil,
               let parsedUseLegacyHDREcosystem = Self.boolean(
                options?[kCGUseLegacyHDREcosystem],
                default: useLegacyHDREcosystem
               ) else {
                return nil
            }
            use100nitsHLGOOTF = parsedUse100nitsHLGOOTF
            useBT1886Gamma = parsedUseBT1886Gamma
            useLegacyHDREcosystem = parsedUseLegacyHDREcosystem
        }

        self.method = method
        self.sourceHeadroom = CGFloat(sourceHeadroom ?? transferFunction.impliedHeadroom)
        self.targetHeadroom = CGFloat(targetHeadroom)
        self.exrDefog = defog
        self.exrExposure = exposure
        self.exrKneeLow = kneeLow
        self.exrKneeHigh = kneeHigh
        self.use100nitsHLGOOTF = use100nitsHLGOOTF
        self.useBT1886Gamma = useBT1886Gamma
        self.useLegacyHDREcosystem = useLegacyHDREcosystem
    }

    func map(_ encodedComponents: [CGFloat]) -> [CGFloat] {
        let linear = encodedComponents.map(transferFunction.decode)
        switch method {
        case .none:
            return linear.map { min(max($0 / targetHeadroom, 0), 1) }
        case .exrGamma:
            return linear.map(mapEXRGamma)
        case .ituRecommended:
            return mapLuminance(linear, exponent: useLegacyHDREcosystem ? 2.35 : 2.5)
        case .default, .imageSpecificLumaScaling, .referenceWhiteBased:
            return mapLuminance(linear, exponent: 2.75)
        }
    }

    private func mapLuminance(_ components: [CGFloat], exponent: CGFloat) -> [CGFloat] {
        let luminance = max(
            components[0] * luminanceCoefficients.red
                + components[1] * luminanceCoefficients.green
                + components[2] * luminanceCoefficients.blue,
            0
        )
        guard luminance > 0 else { return [0, 0, 0] }
        if sourceHeadroom <= targetHeadroom {
            return components.map { min(max($0 / targetHeadroom, 0), 1) }
        }
        let normalized = min(luminance / sourceHeadroom, 1)
        var mapped = 1 - pow(1 - normalized, exponent)
        if use100nitsHLGOOTF, transferFunction == .hybridLogGamma {
            mapped *= 0.9
        }
        if useBT1886Gamma {
            mapped = pow(mapped, 2.4 / 2.2)
        }
        let scale = mapped / luminance
        return components.map { min(max($0 * scale, 0), 1) }
    }

    private func mapEXRGamma(_ component: CGFloat) -> CGFloat {
        let exposed = max(component - exrDefog, 0) * pow(2, exrExposure)
        let kneeScale = pow(2, exrKneeLow * 0.1) * 5 / exrKneeHigh
        return min(max(1 - exp(-0.48 * kneeScale * exposed), 0), 1)
    }

    private static func number(_ value: Any?, default defaultValue: CGFloat) -> CGFloat? {
        guard let value else { return defaultValue }
        let result: CGFloat
        switch value {
        case let value as CGFloat: result = value
        case let value as Float: result = CGFloat(value)
        case let value as Double: result = CGFloat(value)
        case let value as Int: result = CGFloat(value)
        default: return nil
        }
        return result.isFinite ? result : nil
    }

    private static func boolean(_ value: Any?, default defaultValue: Bool) -> Bool? {
        guard let value else { return defaultValue }
        return value as? Bool
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
