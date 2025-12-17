//
//  CGInterpolationQuality.swift
//  OpenCoreGraphics
//
//  Created by OpenCoreGraphics contributors.
//


/// Levels of interpolation quality for rendering images.
///
/// Interpolation quality determines the algorithm used when scaling images.
/// Higher quality settings produce smoother results but may be slower.
public enum CGInterpolationQuality: Int32, Sendable {
    /// The default interpolation quality.
    case `default` = 0

    /// No interpolation.
    case none = 1

    /// A low level of interpolation quality. May be faster than other settings.
    case low = 2

    /// A medium level of interpolation quality. This setting is optimized for
    /// performance and quality.
    case medium = 4

    /// A high level of interpolation quality. May be slower than other settings.
    case high = 3
}


