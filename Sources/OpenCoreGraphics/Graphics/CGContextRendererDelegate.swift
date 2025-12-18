//
//  CGContextRendererDelegate.swift
//  OpenCoreGraphics
//
//  Created by OpenCoreGraphics contributors.
//

import Foundation

/// Protocol for rendering backends that execute CGContext drawing operations.
///
/// This protocol enables pluggable rendering backends (such as WebGPU, Metal, Canvas2D)
/// to receive drawing commands from CGContext and render them to their respective targets.
///
/// The delegate receives only the parameters necessary for rendering, keeping
/// CGContext's internal GraphicsState private.
///
/// ## Example Usage
///
/// ```swift
/// class WebGPURenderer: CGContextRendererDelegate {
///     func fill(path: CGPath, color: CGColor, alpha: CGFloat,
///               blendMode: CGBlendMode, rule: CGPathFillRule) {
///         // Tessellate path and render with WebGPU
///     }
///     // ... implement other methods
/// }
///
/// let context = CGContext(...)!
/// context.rendererDelegate = myWebGPURenderer
/// context.setFillColor(.red)
/// context.addRect(CGRect(x: 0, y: 0, width: 100, height: 100))
/// context.fillPath()  // Calls delegate with transformed path and current fill color
/// ```
public protocol CGContextRendererDelegate: AnyObject, Sendable {

    // MARK: - Path Drawing

    /// Called when `fillPath()` is invoked on the context.
    ///
    /// The path is already transformed by the current transformation matrix (CTM).
    ///
    /// - Parameters:
    ///   - path: The path to fill (already transformed by CTM).
    ///   - color: The fill color.
    ///   - alpha: The global alpha value.
    ///   - blendMode: The blend mode for compositing.
    ///   - rule: The fill rule (winding or even-odd).
    func fill(
        path: CGPath,
        color: CGColor,
        alpha: CGFloat,
        blendMode: CGBlendMode,
        rule: CGPathFillRule
    )

    /// Called when `strokePath()` is invoked on the context.
    ///
    /// The path is already transformed by the current transformation matrix (CTM).
    ///
    /// - Parameters:
    ///   - path: The path to stroke (already transformed by CTM).
    ///   - color: The stroke color.
    ///   - lineWidth: The width of the stroke.
    ///   - lineCap: The line cap style.
    ///   - lineJoin: The line join style.
    ///   - miterLimit: The miter limit for joins.
    ///   - dashPhase: The dash pattern phase.
    ///   - dashLengths: The dash pattern lengths (empty for solid line).
    ///   - alpha: The global alpha value.
    ///   - blendMode: The blend mode for compositing.
    func stroke(
        path: CGPath,
        color: CGColor,
        lineWidth: CGFloat,
        lineCap: CGLineCap,
        lineJoin: CGLineJoin,
        miterLimit: CGFloat,
        dashPhase: CGFloat,
        dashLengths: [CGFloat],
        alpha: CGFloat,
        blendMode: CGBlendMode
    )

    // MARK: - Clearing

    /// Called when `clear()` is invoked on the context.
    ///
    /// - Parameter rect: The rectangle to clear (in user space coordinates).
    func clear(rect: CGRect)

    // MARK: - Image Drawing

    /// Called when drawing an image.
    ///
    /// - Parameters:
    ///   - image: The image to draw.
    ///   - rect: The destination rectangle.
    ///   - alpha: The global alpha value.
    ///   - blendMode: The blend mode for compositing.
    ///   - interpolationQuality: The interpolation quality for scaling.
    func draw(
        image: CGImage,
        in rect: CGRect,
        alpha: CGFloat,
        blendMode: CGBlendMode,
        interpolationQuality: CGInterpolationQuality
    )

    // MARK: - Gradient Drawing

    /// Called when drawing a linear gradient.
    ///
    /// - Parameters:
    ///   - gradient: The gradient to draw.
    ///   - start: The starting point.
    ///   - end: The ending point.
    ///   - options: Drawing options.
    func drawLinearGradient(
        _ gradient: CGGradient,
        start: CGPoint,
        end: CGPoint,
        options: CGGradientDrawingOptions
    )

    /// Called when drawing a radial gradient.
    ///
    /// - Parameters:
    ///   - gradient: The gradient to draw.
    ///   - startCenter: The center of the starting circle.
    ///   - startRadius: The radius of the starting circle.
    ///   - endCenter: The center of the ending circle.
    ///   - endRadius: The radius of the ending circle.
    ///   - options: Drawing options.
    func drawRadialGradient(
        _ gradient: CGGradient,
        startCenter: CGPoint,
        startRadius: CGFloat,
        endCenter: CGPoint,
        endRadius: CGFloat,
        options: CGGradientDrawingOptions
    )
}

// MARK: - Default Implementations

extension CGContextRendererDelegate {
    /// Default implementation does nothing.
    public func clear(rect: CGRect) {}

    /// Default implementation does nothing.
    public func draw(
        image: CGImage,
        in rect: CGRect,
        alpha: CGFloat,
        blendMode: CGBlendMode,
        interpolationQuality: CGInterpolationQuality
    ) {}

    /// Default implementation does nothing.
    public func drawLinearGradient(
        _ gradient: CGGradient,
        start: CGPoint,
        end: CGPoint,
        options: CGGradientDrawingOptions
    ) {}

    /// Default implementation does nothing.
    public func drawRadialGradient(
        _ gradient: CGGradient,
        startCenter: CGPoint,
        startRadius: CGFloat,
        endCenter: CGPoint,
        endRadius: CGFloat,
        options: CGGradientDrawingOptions
    ) {}
}
