//
//  CGContentInfo.swift
//  OpenCoreGraphics
//
//  Created by OpenCoreGraphics contributors.
//

#if arch(wasm32)

import Foundation


/// Information about the content characteristics of an image or drawing.
public struct CGContentInfo: Sendable {
    /// The deepest image component type used in the content.
    public var deepestImageComponent: CGComponent

    /// The color models present in the content.
    public var contentColorModels: CGColorModel

    /// Whether the content uses wide gamut colors.
    public var hasWideGamut: Bool

    /// Whether the content has transparency.
    public var hasTransparency: Bool

    /// The largest content headroom value (for HDR content).
    public var largestContentHeadroom: Float

    // MARK: - Initializers

    /// Creates content info with default values.
    public init() {
        self.deepestImageComponent = .unknown
        self.contentColorModels = []
        self.hasWideGamut = false
        self.hasTransparency = false
        self.largestContentHeadroom = 1.0
    }

    /// Creates content info with specified values.
    public init(deepestImageComponent: CGComponent,
                contentColorModels: CGColorModel,
                hasWideGamut: Bool,
                hasTransparency: Bool,
                largestContentHeadroom: Float) {
        self.deepestImageComponent = deepestImageComponent
        self.contentColorModels = contentColorModels
        self.hasWideGamut = hasWideGamut
        self.hasTransparency = hasTransparency
        self.largestContentHeadroom = largestContentHeadroom
    }
}

#endif

