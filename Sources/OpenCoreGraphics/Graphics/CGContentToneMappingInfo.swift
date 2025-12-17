//
//  CGContentToneMappingInfo.swift
//  OpenCoreGraphics
//
//  Created by OpenCoreGraphics contributors.
//

import Foundation


/// Tone mapping information for HDR content.
public enum CGContentToneMappingInfo: Sendable {
    /// No tone mapping.
    case none

    /// Default tone mapping with options.
    case `default`(DefaultOptions)

    /// EXR gamma tone mapping with options.
    case exrGamma(EXRGammaOptions)

    /// Image-specific luma scaling tone mapping.
    case imageSpecificLumaScaling(DefaultOptions)

    /// ITU recommended tone mapping with options.
    case ituRecommended(ITURecommendedOptions)

    /// Reference white based tone mapping.
    case referenceWhiteBased(DefaultOptions)

    // MARK: - DynamicRange

    /// Dynamic range options for tone mapping.
    public enum DynamicRange: Sendable {
        /// Standard dynamic range.
        case standard

        /// High dynamic range.
        case high

        /// Constrained dynamic range.
        case constrained
    }

    // MARK: - LightLevel

    /// Light level specification for tone mapping.
    public enum LightLevel: Sendable {
        /// Absolute light level in nits.
        case nits(Int)

        /// Relative light level as a factor.
        case relative(Float)
    }

    // MARK: - DefaultOptions

    /// Default options for tone mapping.
    public struct DefaultOptions: Sendable {
        /// The average light level of the content.
        public var contentAverageLightLevel: LightLevel

        /// The preferred dynamic range for output.
        public var preferredDynamicRange: DynamicRange

        /// Creates default options with default values.
        public init() {
            self.contentAverageLightLevel = .relative(1.0)
            self.preferredDynamicRange = .standard
        }

        /// Creates default options with specified values.
        public init(contentAverageLightLevel: LightLevel, preferredDynamicRange: DynamicRange) {
            self.contentAverageLightLevel = contentAverageLightLevel
            self.preferredDynamicRange = preferredDynamicRange
        }
    }

    // MARK: - EXRGammaOptions

    /// Options for EXR gamma tone mapping.
    public struct EXRGammaOptions: Sendable {
        /// Defog amount.
        public var defog: Float

        /// Exposure adjustment.
        public var exposure: Float

        /// Knee high point.
        public var kneeHigh: Float

        /// Knee low point.
        public var kneeLow: Float

        /// Creates EXR gamma options with default values.
        public init() {
            self.defog = 0.0
            self.exposure = 0.0
            self.kneeHigh = 5.0
            self.kneeLow = 0.0
        }

        /// Creates EXR gamma options with specified values.
        public init(defog: Float, exposure: Float, kneeHigh: Float, kneeLow: Float) {
            self.defog = defog
            self.exposure = exposure
            self.kneeHigh = kneeHigh
            self.kneeLow = kneeLow
        }
    }

    // MARK: - ITURecommendedOptions

    /// Options for ITU recommended tone mapping.
    public struct ITURecommendedOptions: Sendable {
        /// Whether to skip boosting to HDR.
        public var skipBoostToHDR: Bool

        /// Whether to use 100 nits HLG OOTF.
        public var use100nitsHLGOOTF: Bool

        /// Whether to use BT.1886 for CoreVideo gamma.
        public var useBT1886ForCoreVideoGamma: Bool

        /// Whether to use legacy HDR ecosystem.
        public var useLegacyHDREcosystem: Bool

        /// Creates ITU recommended options with default values.
        public init() {
            self.skipBoostToHDR = false
            self.use100nitsHLGOOTF = false
            self.useBT1886ForCoreVideoGamma = false
            self.useLegacyHDREcosystem = false
        }

        /// Creates ITU recommended options with specified values.
        public init(skipBoostToHDR: Bool, use100nitsHLGOOTF: Bool,
                    useBT1886ForCoreVideoGamma: Bool, useLegacyHDREcosystem: Bool) {
            self.skipBoostToHDR = skipBoostToHDR
            self.use100nitsHLGOOTF = use100nitsHLGOOTF
            self.useBT1886ForCoreVideoGamma = useBT1886ForCoreVideoGamma
            self.useLegacyHDREcosystem = useLegacyHDREcosystem
        }
    }
}

// MARK: - Equatable

extension CGContentToneMappingInfo: Equatable {
    public static func == (lhs: CGContentToneMappingInfo, rhs: CGContentToneMappingInfo) -> Bool {
        switch (lhs, rhs) {
        case (.none, .none):
            return true
        case let (.default(lhsOpts), .default(rhsOpts)):
            return lhsOpts == rhsOpts
        case let (.exrGamma(lhsOpts), .exrGamma(rhsOpts)):
            return lhsOpts == rhsOpts
        case let (.imageSpecificLumaScaling(lhsOpts), .imageSpecificLumaScaling(rhsOpts)):
            return lhsOpts == rhsOpts
        case let (.ituRecommended(lhsOpts), .ituRecommended(rhsOpts)):
            return lhsOpts == rhsOpts
        case let (.referenceWhiteBased(lhsOpts), .referenceWhiteBased(rhsOpts)):
            return lhsOpts == rhsOpts
        default:
            return false
        }
    }
}

// MARK: - Hashable

extension CGContentToneMappingInfo: Hashable {
    public func hash(into hasher: inout Hasher) {
        switch self {
        case .none:
            hasher.combine(0)
        case .default(let opts):
            hasher.combine(1)
            hasher.combine(opts)
        case .exrGamma(let opts):
            hasher.combine(2)
            hasher.combine(opts)
        case .imageSpecificLumaScaling(let opts):
            hasher.combine(3)
            hasher.combine(opts)
        case .ituRecommended(let opts):
            hasher.combine(4)
            hasher.combine(opts)
        case .referenceWhiteBased(let opts):
            hasher.combine(5)
            hasher.combine(opts)
        }
    }
}

// MARK: - Identifiable

extension CGContentToneMappingInfo: Identifiable {
    public var id: Int {
        switch self {
        case .none: return 0
        case .default: return 1
        case .exrGamma: return 2
        case .imageSpecificLumaScaling: return 3
        case .ituRecommended: return 4
        case .referenceWhiteBased: return 5
        }
    }
}

// MARK: - Nested Type Conformances

extension CGContentToneMappingInfo.DynamicRange: Equatable {}
extension CGContentToneMappingInfo.DynamicRange: Hashable {}

extension CGContentToneMappingInfo.LightLevel: Equatable {
    public static func == (lhs: CGContentToneMappingInfo.LightLevel,
                          rhs: CGContentToneMappingInfo.LightLevel) -> Bool {
        switch (lhs, rhs) {
        case let (.nits(lhsVal), .nits(rhsVal)):
            return lhsVal == rhsVal
        case let (.relative(lhsVal), .relative(rhsVal)):
            return lhsVal == rhsVal
        default:
            return false
        }
    }
}

extension CGContentToneMappingInfo.LightLevel: Hashable {
    public func hash(into hasher: inout Hasher) {
        switch self {
        case .nits(let value):
            hasher.combine(0)
            hasher.combine(value)
        case .relative(let value):
            hasher.combine(1)
            hasher.combine(value)
        }
    }
}

extension CGContentToneMappingInfo.DefaultOptions: Equatable {
    public static func == (lhs: CGContentToneMappingInfo.DefaultOptions,
                          rhs: CGContentToneMappingInfo.DefaultOptions) -> Bool {
        return lhs.contentAverageLightLevel == rhs.contentAverageLightLevel &&
               lhs.preferredDynamicRange == rhs.preferredDynamicRange
    }
}

extension CGContentToneMappingInfo.DefaultOptions: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(contentAverageLightLevel)
        hasher.combine(preferredDynamicRange)
    }
}

extension CGContentToneMappingInfo.EXRGammaOptions: Equatable {
    public static func == (lhs: CGContentToneMappingInfo.EXRGammaOptions,
                          rhs: CGContentToneMappingInfo.EXRGammaOptions) -> Bool {
        return lhs.defog == rhs.defog &&
               lhs.exposure == rhs.exposure &&
               lhs.kneeHigh == rhs.kneeHigh &&
               lhs.kneeLow == rhs.kneeLow
    }
}

extension CGContentToneMappingInfo.EXRGammaOptions: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(defog)
        hasher.combine(exposure)
        hasher.combine(kneeHigh)
        hasher.combine(kneeLow)
    }
}

extension CGContentToneMappingInfo.ITURecommendedOptions: Equatable {
    public static func == (lhs: CGContentToneMappingInfo.ITURecommendedOptions,
                          rhs: CGContentToneMappingInfo.ITURecommendedOptions) -> Bool {
        return lhs.skipBoostToHDR == rhs.skipBoostToHDR &&
               lhs.use100nitsHLGOOTF == rhs.use100nitsHLGOOTF &&
               lhs.useBT1886ForCoreVideoGamma == rhs.useBT1886ForCoreVideoGamma &&
               lhs.useLegacyHDREcosystem == rhs.useLegacyHDREcosystem
    }
}

extension CGContentToneMappingInfo.ITURecommendedOptions: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(skipBoostToHDR)
        hasher.combine(use100nitsHLGOOTF)
        hasher.combine(useBT1886ForCoreVideoGamma)
        hasher.combine(useLegacyHDREcosystem)
    }
}

