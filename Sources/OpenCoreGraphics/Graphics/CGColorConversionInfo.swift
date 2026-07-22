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

    /// Image-specific luminance scaling based on gain-map metadata.
    case imageSpecificLumaScaling = 1

    /// A reference-white-preserving curve that rolls off HDR highlights.
    case referenceWhiteBased = 2

    /// Tone mapping based on ITU-R recommendations.
    case ituRecommended = 3

    /// OpenEXR gamma tone mapping.
    case exrGamma = 4

    /// No tone mapping. Extended values are clipped to the destination range.
    case none = 5
}

/// The OpenEXR defog option key.
public let kCGEXRToneMappingGammaDefog = "kCGEXRToneMappingGammaDefog"

/// The OpenEXR exposure option key.
public let kCGEXRToneMappingGammaExposure = "kCGEXRToneMappingGammaExposure"

/// The OpenEXR low-knee option key.
public let kCGEXRToneMappingGammaKneeLow = "kCGEXRToneMappingGammaKneeLow"

/// The OpenEXR high-knee option key.
public let kCGEXRToneMappingGammaKneeHigh = "kCGEXRToneMappingGammaKneeHigh"

/// The ITU HLG OOTF option key.
public let kCGUse100nitsHLGOOTF = "kCGUse100nitsHLGOOTF"

/// The ITU BT.1886 transfer-function option key.
public let kCGUseBT1886ForCoreVideoGamma = "kCGUseBT1886ForCoreVideoGamma"

/// The ITU SDR-to-HDR boost option key.
public let kCGSkipBoostToHDR = "kCGSkipBoostToHDR"

/// The legacy HDR conversion option key.
public let kCGUseLegacyHDREcosystem = "kCGUseLegacyHDREcosystem"

// MARK: - CGColorBufferFormat

/// A structure describing the format of a color buffer.
public struct CGColorBufferFormat: Sendable {
    /// The version of the structure.
    public var version: UInt32

    /// The number of bits per component.
    public var bitsPerComponent: Int

    /// The number of bits per pixel.
    public var bitsPerPixel: Int

    /// The bytes per row.
    public var bytesPerRow: Int

    /// The bitmap info.
    public var bitmapInfo: CGBitmapInfo

    /// Creates an empty color buffer format.
    public init() {
        self.version = 0
        self.bitmapInfo = []
        self.bitsPerComponent = 0
        self.bitsPerPixel = 0
        self.bytesPerRow = 0
    }

    /// Creates a color buffer format.
    public init(
        version: UInt32,
        bitmapInfo: CGBitmapInfo,
        bitsPerComponent: Int,
        bitsPerPixel: Int,
        bytesPerRow: Int
    ) {
        self.version = version
        self.bitmapInfo = bitmapInfo
        self.bitsPerComponent = bitsPerComponent
        self.bitsPerPixel = bitsPerPixel
        self.bytesPerRow = bytesPerRow
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
        guard Self.supportsConversion(from: src, to: dst) else { return nil }
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
        guard Self.supportsConversion(from: optionsSrc, to: dst) else { return nil }
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
        CGColorBufferConverter.convert(
            width: width,
            height: height,
            destinationBuffer: dstBuffer,
            destinationFormat: dstFormat,
            destinationColorSpace: destinationColorSpace,
            sourceBuffer: srcBuffer,
            sourceFormat: srcFormat,
            sourceColorSpace: sourceColorSpace,
            intent: intent,
            options: options
        )
    }

    private static func supportsConversion(from source: CGColorSpace, to destination: CGColorSpace) -> Bool {
        let unsupportedModels: Set<CGColorSpaceModel> = [.unknown, .indexed, .pattern]
        guard !unsupportedModels.contains(source.model),
              !unsupportedModels.contains(destination.model),
              destination.supportsOutput else {
            return false
        }

        guard source.copyICCData() == nil || source.colorProfile != nil,
              destination.copyICCData() == nil || destination.colorProfile != nil else {
            return false
        }
        if source.copyICCData() != nil || destination.copyICCData() != nil {
            guard let sourceProfile = source.colorProfile,
                  let destinationProfile = destination.colorProfile,
                  sourceProfile.supportsToPCS(intent: .defaultIntent),
                  destinationProfile.supportsFromPCS(intent: .defaultIntent) else {
                return false
            }
        }
        guard source.model != .deviceN || source.colorProfile != nil,
              destination.model != .deviceN || destination.colorProfile != nil else {
            return false
        }

        return true
    }

    // MARK: - Type ID

    /// Returns the Core Foundation type identifier for a color conversion info data type.
    public class var typeID: UInt {
        return CGTypeIdentifier.colorConversionInfo
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
