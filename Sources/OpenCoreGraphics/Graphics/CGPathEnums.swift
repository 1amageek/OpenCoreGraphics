//
//  CGPathEnums.swift
//  OpenCoreGraphics
//
//  Created by OpenCoreGraphics contributors.
//

import Foundation


// MARK: - CGLineCap

/// Styles for rendering the endpoint of a stroked line.
public enum CGLineCap: Int32, Sendable {
    /// A line with a squared-off end.
    case butt = 0
    /// A line with a rounded end.
    case round = 1
    /// A line with a squared-off end that extends past the endpoint of the line.
    case square = 2
}

// MARK: - CGLineJoin

/// Junction types for stroked lines.
public enum CGLineJoin: Int32, Sendable {
    /// A join with a sharp (angled) corner.
    case miter = 0
    /// A join with a rounded end.
    case round = 1
    /// A join with a squared-off end.
    case bevel = 2
}

// MARK: - CGPathFillRule

/// Rules for determining which regions are interior to a path.
public enum CGPathFillRule: Int, Sendable {
    /// A rule that considers a region to be interior if the number of path
    /// crossings is odd.
    case winding = 0
    /// A rule that considers a region to be interior based on the direction
    /// of the path.
    case evenOdd = 1
}

// MARK: - CGPathElementType

/// The type of element found in a path.
public enum CGPathElementType: Int32, Sendable {
    /// The path element that starts a new subpath.
    case moveToPoint = 0
    /// The path element that adds a line from the current point to a new point.
    case addLineToPoint = 1
    /// The path element that adds a quadratic curve from the current point
    /// to the specified point.
    case addQuadCurveToPoint = 2
    /// The path element that adds a cubic curve from the current point
    /// to the specified point.
    case addCurveToPoint = 3
    /// The path element that closes and completes a subpath.
    case closeSubpath = 4
}

// MARK: - CGPathElement

/// A data structure that provides information about a path element.
public struct CGPathElement {
    /// The type of path element.
    public var type: CGPathElementType
    /// A pointer to an array of one or more points that serve as arguments.
    /// For `moveToPoint` and `addLineToPoint`, there is one point.
    /// For `addQuadCurveToPoint`, there are two points.
    /// For `addCurveToPoint`, there are three points.
    /// For `closeSubpath`, there are no points.
    public var points: UnsafeMutablePointer<CGPoint>?

    /// Creates a path element.
    public init(type: CGPathElementType, points: UnsafeMutablePointer<CGPoint>?) {
        self.type = type
        self.points = points
    }
}

// MARK: - CGPathApplierFunction

/// Defines a callback function that can view an element in a graphics path.
public typealias CGPathApplierFunction = (UnsafeMutableRawPointer?, UnsafePointer<CGPathElement>) -> Void

// MARK: - CGPathDrawingMode

/// Options for rendering a path.
public enum CGPathDrawingMode: Int32, Sendable {
    /// Render the area contained within the path using the non-zero winding rule.
    case fill = 0
    /// Render the area within the path using the even-odd rule.
    case eoFill = 1
    /// Render a line along the path.
    case stroke = 2
    /// Fill, then stroke the path, using the nonzero winding number rule.
    case fillStroke = 3
    /// Fill, then stroke the path, using the even-odd rule.
    case eoFillStroke = 4
}

