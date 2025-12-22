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

    /// Internal storage for the layer content
    private var content: Data?

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
        let width = Int(size.width)
        let height = Int(size.height)
        let bitsPerComponent = context.bitsPerComponent
        let bytesPerRow = width * (context.bitsPerPixel / 8)

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

    /// Internal initializer
    private init(size: CGSize, context: CGContext?) {
        self.size = size
        self.context = context
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

// MARK: - CGContext Extension for Layer Drawing

extension CGContext {
    /// Draws the contents of a layer object at the specified point.
    public func draw(_ layer: CGLayer, at point: CGPoint) {
        draw(layer, in: CGRect(origin: point, size: layer.size))
    }

    /// Draws the contents of a layer object into the specified rectangle.
    public func draw(_ layer: CGLayer, in rect: CGRect) {
        // In a real implementation, this would composite the layer's content
        // into this context at the specified rectangle
        guard let layerContext = layer.context,
              let layerImage = layerContext.makeImage() else { return }
        draw(layerImage, in: rect)
    }
}


