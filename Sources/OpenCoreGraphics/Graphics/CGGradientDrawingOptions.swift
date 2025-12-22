//
//  CGGradientDrawingOptions.swift
//  OpenCoreGraphics
//
//  Created by OpenCoreGraphics contributors.
//


/// Options for drawing gradients.

public struct CGGradientDrawingOptions: OptionSet, Sendable {
    public let rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    /// The fill should extend beyond the starting location.
    /// The color that extends is the first stop color.
    public static let drawsBeforeStartLocation = CGGradientDrawingOptions(rawValue: 1 << 0)

    /// The fill should extend beyond the ending location.
    /// The color that extends is the last stop color.
    public static let drawsAfterEndLocation = CGGradientDrawingOptions(rawValue: 1 << 1)
}


