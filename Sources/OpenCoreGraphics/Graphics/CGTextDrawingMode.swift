//
//  CGTextDrawingMode.swift
//  OpenCoreGraphics
//
//  Created by OpenCoreGraphics contributors.
//


/// Modes for rendering text.
public enum CGTextDrawingMode: Int32, Sendable {
    /// Perform a fill operation on the text.
    case fill = 0

    /// Perform a stroke operation on the text.
    case stroke = 1

    /// Perform fill, then stroke operations on the text.
    case fillStroke = 2

    /// Do not draw the text, but do update the text position.
    case invisible = 3

    /// Perform a fill operation, then intersect the text with the
    /// current clipping path.
    case fillClip = 4

    /// Perform a stroke operation, then intersect the text with the
    /// current clipping path.
    case strokeClip = 5

    /// Perform fill and stroke operations, then intersect the text with
    /// the current clipping path.
    case fillStrokeClip = 6

    /// Intersect the text with the current clipping path.
    case clip = 7
}


