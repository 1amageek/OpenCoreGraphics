//
//  CGLayer.swift
//  OpenCoreGraphics
//
//  Created by OpenCoreGraphics contributors.
//


import Foundation


/// An offscreen context for reusing content drawn with Core Graphics.
///
/// CGLayer objects provide an efficient method for offscreen rendering
/// of content that you plan to reuse. For example, you might use layers
/// to create offscreen images for patterns or backgrounds. When you draw
/// into a CGLayer object, you can then draw the contents of that object
/// into any graphics context.
public class CGLayer: @unchecked Sendable {

    /// The size of the layer, in points.
    public let size: CGSize

    /// The graphics context associated with the layer.
    public private(set) var context: CGContext?

    // MARK: - Initializers

    /// Creates a layer object that is associated with a graphics context.
    ///
    /// - Parameters:
    ///   - context: The graphics context to use as a model for the layer.
    ///   - size: The size, in default user space units, of the layer.
    ///   - auxiliaryInfo: Reserved for future use.
    /// - Returns: A new layer object, or nil if it cannot be created.
    public init?(context: CGContext, size: CGSize, auxiliaryInfo: [String: Any]? = nil) {
        guard size.width > 0, size.height > 0 else { return nil }

        self.size = size

        // Create an internal context for the layer
        let width = max(1, Int(ceil(size.width)))
        let height = max(1, Int(ceil(size.height)))
        let bitsPerComponent = context.bitsPerComponent
        let bytesPerRow = width * ((context.bitsPerPixel + 7) / 8)

        if let colorSpace = context.colorSpace {
            self.context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: bitsPerComponent,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: context.bitmapInfo
            )
        } else {
            // Fall back to device RGB
            self.context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: .deviceRGB,
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
            )
        }
    }

}

// MARK: - Factory Functions

/// Creates a layer object that is associated with a graphics context.
public func CGLayerCreateWithContext(_ context: CGContext, _ size: CGSize,
                                      _ auxiliaryInfo: [String: Any]?) -> CGLayer? {
    return CGLayer(context: context, size: size, auxiliaryInfo: auxiliaryInfo)
}

/// Returns the graphics context associated with a layer.
public func CGLayerGetContext(_ layer: CGLayer) -> CGContext? {
    return layer.context
}

/// Returns the size of a layer.
public func CGLayerGetSize(_ layer: CGLayer) -> CGSize {
    return layer.size
}
