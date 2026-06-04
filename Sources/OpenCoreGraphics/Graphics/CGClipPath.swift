//
//  CGClipPath.swift
//  OpenCoreGraphics
//
//  A clipping region entry that preserves both the path and its fill rule.
//

import Foundation

/// A clipping region entry that pairs a path with the fill rule used to
/// interpret its interior.
///
/// Stored inside `CGDrawingState.clipPaths` to preserve the fill rule that
/// was passed to `CGContext.clip(using:)`. Without this, even-odd clipping
/// silently collapses to winding when the renderer tessellates the path.
internal struct CGClipPath: Sendable {
    /// The clipping path (already transformed by the CTM).
    let path: CGPath

    /// The fill rule used to interpret the path's interior.
    let rule: CGPathFillRule

    init(path: CGPath, rule: CGPathFillRule) {
        self.path = path
        self.rule = rule
    }
}
