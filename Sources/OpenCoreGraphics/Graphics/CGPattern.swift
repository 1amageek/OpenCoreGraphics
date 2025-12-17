//
//  CGPattern.swift
//  OpenCoreGraphics
//
//  Created by OpenCoreGraphics contributors.
//

import Foundation


// MARK: - CGPatternTiling

/// Different methods for rendering a tiled pattern.
public enum CGPatternTiling: Int32, Sendable {
    /// The pattern cell is not distorted when painted.
    /// The spacing between pattern cells may vary by as much as 1 device pixel.
    case noDistortion = 0

    /// Pattern cells are spaced consistently. The pattern cell may be distorted
    /// by as much as 1 device pixel when the pattern is painted.
    case constantSpacingMinimalDistortion = 1

    /// Pattern cells are spaced consistently, as with constantSpacingMinimalDistortion.
    /// The pattern cell may be distorted additionally to permit a more efficient implementation.
    case constantSpacing = 2

    public init?(rawValue: Int32) {
        switch rawValue {
        case 0: self = .noDistortion
        case 1: self = .constantSpacingMinimalDistortion
        case 2: self = .constantSpacing
        default: return nil
        }
    }
}

// MARK: - CGPatternCallbacks

/// Draws a pattern cell.
public typealias CGPatternDrawPatternCallback = (UnsafeMutableRawPointer?, CGContext?) -> Void

/// Release private data or resources associated with the pattern.
public typealias CGPatternReleaseInfoCallback = (UnsafeMutableRawPointer?) -> Void

/// A structure that holds a version and two callback functions for drawing a custom pattern.
public struct CGPatternCallbacks {
    /// The version of the structure. Set to 0.
    public var version: UInt32

    /// A pointer to the callback function that draws the pattern.
    public var drawPattern: CGPatternDrawPatternCallback?

    /// A pointer to the callback function that releases private data.
    public var releaseInfo: CGPatternReleaseInfoCallback?

    /// Creates pattern callbacks.
    public init(version: UInt32 = 0,
                drawPattern: CGPatternDrawPatternCallback?,
                releaseInfo: CGPatternReleaseInfoCallback?) {
        self.version = version
        self.drawPattern = drawPattern
        self.releaseInfo = releaseInfo
    }
}

// MARK: - CGPattern

/// A 2D pattern to be used for drawing graphics paths.
public class CGPattern: @unchecked Sendable {

    /// The bounding box of the pattern.
    public let bounds: CGRect

    /// The transformation matrix applied to the pattern.
    public let matrix: CGAffineTransform

    /// The horizontal spacing between pattern cells.
    public let xStep: CGFloat

    /// The vertical spacing between pattern cells.
    public let yStep: CGFloat

    /// The tiling mode for the pattern.
    public let tiling: CGPatternTiling

    /// Whether this is a colored pattern.
    public let isColored: Bool

    /// User-provided info pointer.
    internal let info: UnsafeMutableRawPointer?

    /// The callbacks for drawing the pattern.
    internal let callbacks: CGPatternCallbacks

    // MARK: - Initializers

    /// Creates a pattern object.
    ///
    /// - Parameters:
    ///   - info: A pointer to data that you want passed to your callbacks.
    ///   - bounds: The bounding box of the pattern cell.
    ///   - matrix: The transformation matrix to apply to the pattern.
    ///   - xStep: The horizontal spacing between pattern cells.
    ///   - yStep: The vertical spacing between pattern cells.
    ///   - tiling: The tiling mode.
    ///   - isColored: Whether the pattern is colored.
    ///   - callbacks: The callbacks for drawing and releasing the pattern.
    public init?(info: UnsafeMutableRawPointer?,
                 bounds: CGRect,
                 matrix: CGAffineTransform,
                 xStep: CGFloat,
                 yStep: CGFloat,
                 tiling: CGPatternTiling,
                 isColored: Bool,
                 callbacks: UnsafePointer<CGPatternCallbacks>) {
        guard xStep != 0, yStep != 0 else { return nil }
        guard callbacks.pointee.drawPattern != nil else { return nil }

        self.info = info
        self.bounds = bounds
        self.matrix = matrix
        self.xStep = xStep
        self.yStep = yStep
        self.tiling = tiling
        self.isColored = isColored
        self.callbacks = callbacks.pointee
    }

    deinit {
        callbacks.releaseInfo?(info)
    }

    // MARK: - Drawing

    /// Draws the pattern at the specified origin.
    internal func draw(in context: CGContext) {
        callbacks.drawPattern?(info, context)
    }

    // MARK: - Type ID

    /// Returns the type identifier for Core Graphics patterns.
    public class var typeID: UInt {
        return 0 // Placeholder
    }
}

// MARK: - Equatable

extension CGPattern: Equatable {
    public static func == (lhs: CGPattern, rhs: CGPattern) -> Bool {
        return lhs === rhs
    }
}

// MARK: - Hashable

extension CGPattern: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}

