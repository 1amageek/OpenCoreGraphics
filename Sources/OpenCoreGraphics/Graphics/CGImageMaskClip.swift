//
//  CGImageMaskClip.swift
//  OpenCoreGraphics
//

import Foundation

/// An image mask mapped from user space into device space as part of graphics state.
internal struct CGImageMaskClip: Sendable, Equatable {
    let rect: CGRect
    let transform: CGAffineTransform
    let image: CGImage

    var boundingBox: CGRect {
        return rect.applying(transform)
    }

    static func == (lhs: CGImageMaskClip, rhs: CGImageMaskClip) -> Bool {
        return lhs.image === rhs.image
            && lhs.rect == rhs.rect
            && lhs.transform == rhs.transform
    }
}
