//
//  CGContextRendererDelegate.swift
//  OpenCoreGraphics
//
//  Created by OpenCoreGraphics contributors.
//

import Foundation

// MARK: - Drawing State

/// Encapsulates the current drawing state needed by renderers.
///
/// This structure provides renderers with all the context state needed to properly
/// render drawing operations, including clipping, shadows, and transformations.
public struct CGDrawingState: Sendable {

    /// The current clipping paths.
    ///
    /// Multiple clip paths represent successive `clip()` calls that should be intersected.
    /// Renderers should apply all paths as an intersection (AND operation).
    /// Each path in the array narrows the clipping region further.
    ///
    /// For GPU renderers, this typically means:
    /// - Render each clip path to a stencil buffer
    /// - Use stencil test to restrict drawing to the intersection
    public var clipPaths: [CGPath]

    /// Convenience property for backward compatibility.
    /// Returns the first clip path, or nil if no clipping is active.
    public var clipPath: CGPath? {
        return clipPaths.first
    }

    /// Returns whether any clipping is active.
    public var hasClipping: Bool {
        return !clipPaths.isEmpty
    }

    /// The current transformation matrix.
    ///
    /// This is provided for operations that need to apply CTM to coordinates.
    /// Note: For path-based operations, the path is already transformed.
    public var ctm: CGAffineTransform

    /// The shadow offset in user space.
    public var shadowOffset: CGSize

    /// The blur radius of the shadow.
    public var shadowBlur: CGFloat

    /// The shadow color, or nil if no shadow.
    public var shadowColor: CGColor?

    /// Whether anti-aliasing should be applied.
    public var shouldAntialias: Bool

    /// Creates a drawing state with default values (no clipping, no shadow, identity CTM).
    public init() {
        self.clipPaths = []
        self.ctm = .identity
        self.shadowOffset = .zero
        self.shadowBlur = 0
        self.shadowColor = nil
        self.shouldAntialias = true
    }

    /// Creates a drawing state with the specified values.
    public init(
        clipPaths: [CGPath],
        ctm: CGAffineTransform,
        shadowOffset: CGSize,
        shadowBlur: CGFloat,
        shadowColor: CGColor?,
        shouldAntialias: Bool = true
    ) {
        self.clipPaths = clipPaths
        self.ctm = ctm
        self.shadowOffset = shadowOffset
        self.shadowBlur = shadowBlur
        self.shadowColor = shadowColor
        self.shouldAntialias = shouldAntialias
    }

    /// Creates a drawing state with a single clip path (convenience initializer).
    public init(
        clipPath: CGPath?,
        ctm: CGAffineTransform,
        shadowOffset: CGSize,
        shadowBlur: CGFloat,
        shadowColor: CGColor?,
        shouldAntialias: Bool = true
    ) {
        self.clipPaths = clipPath.map { [$0] } ?? []
        self.ctm = ctm
        self.shadowOffset = shadowOffset
        self.shadowBlur = shadowBlur
        self.shadowColor = shadowColor
        self.shouldAntialias = shouldAntialias
    }

    /// Returns whether a shadow should be drawn.
    public var hasShadow: Bool {
        return shadowColor != nil && (shadowOffset != .zero || shadowBlur > 0)
    }
}

// MARK: - Renderer Delegate Protocol

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

    // MARK: - Shading Drawing

    /// Called when drawing a shading.
    ///
    /// CGShading provides more control than CGGradient by using a CGFunction
    /// to compute colors at arbitrary positions.
    ///
    /// - Parameters:
    ///   - shading: The shading to draw.
    ///   - alpha: The global alpha value.
    ///   - blendMode: The blend mode for compositing.
    func drawShading(
        _ shading: CGShading,
        alpha: CGFloat,
        blendMode: CGBlendMode
    )

    // MARK: - Pattern Drawing

    /// Called when filling a path with a pattern.
    ///
    /// - Parameters:
    ///   - path: The path to fill (already transformed by CTM).
    ///   - pattern: The pattern to use for filling.
    ///   - patternSpace: The color space for the pattern.
    ///   - colorComponents: Color components for uncolored patterns (nil for colored patterns).
    ///   - patternPhase: The pattern phase offset for positioning the pattern.
    ///   - alpha: The global alpha value.
    ///   - blendMode: The blend mode for compositing.
    ///   - rule: The fill rule (winding or even-odd).
    func fillWithPattern(
        path: CGPath,
        pattern: CGPattern,
        patternSpace: CGColorSpace,
        colorComponents: [CGFloat]?,
        patternPhase: CGSize,
        alpha: CGFloat,
        blendMode: CGBlendMode,
        rule: CGPathFillRule
    )

    /// Called when stroking a path with a pattern.
    ///
    /// - Parameters:
    ///   - path: The path to stroke (already transformed by CTM).
    ///   - pattern: The pattern to use for stroking.
    ///   - patternSpace: The color space for the pattern.
    ///   - colorComponents: Color components for uncolored patterns (nil for colored patterns).
    ///   - patternPhase: The pattern phase offset for positioning the pattern.
    ///   - lineWidth: The width of the stroke.
    ///   - lineCap: The line cap style.
    ///   - lineJoin: The line join style.
    ///   - miterLimit: The miter limit for joins.
    ///   - dashPhase: The dash pattern phase.
    ///   - dashLengths: The dash pattern lengths (empty for solid line).
    ///   - alpha: The global alpha value.
    ///   - blendMode: The blend mode for compositing.
    func strokeWithPattern(
        path: CGPath,
        pattern: CGPattern,
        patternSpace: CGColorSpace,
        colorComponents: [CGFloat]?,
        patternPhase: CGSize,
        lineWidth: CGFloat,
        lineCap: CGLineCap,
        lineJoin: CGLineJoin,
        miterLimit: CGFloat,
        dashPhase: CGFloat,
        dashLengths: [CGFloat],
        alpha: CGFloat,
        blendMode: CGBlendMode
    )

    // MARK: - Transparency Layers

    /// Called when beginning a transparency layer.
    ///
    /// Transparency layers allow you to composite a group of drawing operations
    /// as a single unit with a specific alpha value and blend mode.
    ///
    /// Renderers should:
    /// 1. Create an offscreen buffer for subsequent drawing operations
    /// 2. Save the current render target
    /// 3. Set the offscreen buffer as the new render target
    ///
    /// - Parameters:
    ///   - rect: The bounding rectangle for the layer (nil for full context bounds).
    ///   - auxiliaryInfo: Optional dictionary with additional configuration.
    func beginTransparencyLayer(in rect: CGRect?, auxiliaryInfo: [String: Any]?)

    /// Called when ending a transparency layer.
    ///
    /// Renderers should:
    /// 1. Composite the offscreen buffer back to the previous render target
    /// 2. Apply the specified alpha and blend mode during compositing
    /// 3. Restore the previous render target
    ///
    /// - Parameters:
    ///   - alpha: The alpha value to apply when compositing the layer.
    ///   - blendMode: The blend mode to use when compositing.
    func endTransparencyLayer(alpha: CGFloat, blendMode: CGBlendMode)

    // MARK: - Image Readback

    /// Creates an image from the current render target contents.
    ///
    /// This method allows GPU-based renderers to read back rendered content
    /// as a CGImage. It performs a GPU readback operation, which can be
    /// expensive and should be used sparingly.
    ///
    /// ## Implementation Notes for GPU Renderers
    ///
    /// To support this method, GPU renderers should:
    /// 1. Maintain an internal render texture with `CopySrc` usage
    /// 2. Copy the texture contents to a staging buffer
    /// 3. Map the buffer and read pixel data
    /// 4. Create a CGImage from the pixel data
    ///
    /// ```swift
    /// func makeImage(width: Int, height: Int, colorSpace: CGColorSpace) async -> CGImage? {
    ///     // 1. Create staging buffer with MapRead | CopyDst usage
    ///     // 2. Copy texture to buffer
    ///     // 3. Map buffer and read pixels
    ///     // 4. Create CGImage from pixel data
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - width: The width of the image in pixels.
    ///   - height: The height of the image in pixels.
    ///   - colorSpace: The color space for the resulting image.
    /// - Returns: A CGImage containing the rendered content, or nil if readback fails.
    func makeImage(width: Int, height: Int, colorSpace: CGColorSpace) async -> CGImage?
}

// MARK: - Default Implementations

extension CGContextRendererDelegate {
    /// Default implementation does nothing.
    public func clear(rect: CGRect) {}

    /// Default implementation does nothing.
    public func beginTransparencyLayer(in rect: CGRect?, auxiliaryInfo: [String: Any]?) {}

    /// Default implementation does nothing.
    public func endTransparencyLayer(alpha: CGFloat, blendMode: CGBlendMode) {}

    /// Default implementation returns nil.
    public func makeImage(width: Int, height: Int, colorSpace: CGColorSpace) async -> CGImage? {
        return nil
    }

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

    /// Default implementation does nothing.
    public func drawShading(
        _ shading: CGShading,
        alpha: CGFloat,
        blendMode: CGBlendMode
    ) {}

    /// Default implementation does nothing.
    public func fillWithPattern(
        path: CGPath,
        pattern: CGPattern,
        patternSpace: CGColorSpace,
        colorComponents: [CGFloat]?,
        patternPhase: CGSize,
        alpha: CGFloat,
        blendMode: CGBlendMode,
        rule: CGPathFillRule
    ) {}

    /// Default implementation does nothing.
    public func strokeWithPattern(
        path: CGPath,
        pattern: CGPattern,
        patternSpace: CGColorSpace,
        colorComponents: [CGFloat]?,
        patternPhase: CGSize,
        lineWidth: CGFloat,
        lineCap: CGLineCap,
        lineJoin: CGLineJoin,
        miterLimit: CGFloat,
        dashPhase: CGFloat,
        dashLengths: [CGFloat],
        alpha: CGFloat,
        blendMode: CGBlendMode
    ) {}
}

// MARK: - Stateful Renderer Delegate

/// Extended protocol for rendering backends that need access to full drawing state.
///
/// This protocol extends `CGContextRendererDelegate` with methods that receive
/// the full drawing state, including clipping path and shadow parameters.
///
/// Renderers that need to support clipping, shadows, or other state-dependent
/// features should conform to this protocol.
///
/// ## Migration Guide
///
/// To adopt this protocol:
/// 1. Conform to `CGContextStatefulRendererDelegate` instead of `CGContextRendererDelegate`
/// 2. Implement the `state`-accepting versions of fill/stroke/draw methods
/// 3. Use `state.clipPath` to apply clipping masks
/// 4. Use `state.shadowColor`, `state.shadowOffset`, `state.shadowBlur` for shadows
///
/// ## Example
///
/// ```swift
/// class MyRenderer: CGContextStatefulRendererDelegate {
///     func fill(path: CGPath, color: CGColor, alpha: CGFloat,
///               blendMode: CGBlendMode, rule: CGPathFillRule,
///               state: CGDrawingState) {
///         // Apply clipping if needed
///         if let clipPath = state.clipPath {
///             applyClipMask(clipPath)
///         }
///         // Draw shadow if needed
///         if state.hasShadow {
///             drawShadow(path, offset: state.shadowOffset,
///                       blur: state.shadowBlur, color: state.shadowColor!)
///         }
///         // Draw the fill
///         fillPath(path, with: color)
///     }
/// }
/// ```
public protocol CGContextStatefulRendererDelegate: CGContextRendererDelegate {

    // MARK: - Stateful Path Drawing

    /// Called when `fillPath()` is invoked, with full drawing state.
    ///
    /// - Parameters:
    ///   - path: The path to fill (already transformed by CTM).
    ///   - color: The fill color.
    ///   - alpha: The global alpha value.
    ///   - blendMode: The blend mode for compositing.
    ///   - rule: The fill rule (winding or even-odd).
    ///   - state: The current drawing state including clip path and shadow.
    func fill(
        path: CGPath,
        color: CGColor,
        alpha: CGFloat,
        blendMode: CGBlendMode,
        rule: CGPathFillRule,
        state: CGDrawingState
    )

    /// Called when `strokePath()` is invoked, with full drawing state.
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
    ///   - state: The current drawing state including clip path and shadow.
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
        blendMode: CGBlendMode,
        state: CGDrawingState
    )

    // MARK: - Stateful Clearing

    /// Called when `clear()` is invoked, with full drawing state.
    ///
    /// - Parameters:
    ///   - rect: The rectangle to clear (already transformed by CTM).
    ///   - state: The current drawing state.
    func clear(rect: CGRect, state: CGDrawingState)

    // MARK: - Stateful Image Drawing

    /// Called when drawing an image, with full drawing state.
    ///
    /// - Parameters:
    ///   - image: The image to draw.
    ///   - rect: The destination rectangle (already transformed by CTM).
    ///   - alpha: The global alpha value.
    ///   - blendMode: The blend mode for compositing.
    ///   - interpolationQuality: The interpolation quality for scaling.
    ///   - state: The current drawing state.
    func draw(
        image: CGImage,
        in rect: CGRect,
        alpha: CGFloat,
        blendMode: CGBlendMode,
        interpolationQuality: CGInterpolationQuality,
        state: CGDrawingState
    )

    // MARK: - Stateful Gradient Drawing

    /// Called when drawing a linear gradient, with full drawing state.
    ///
    /// - Parameters:
    ///   - gradient: The gradient to draw.
    ///   - start: The starting point (already transformed by CTM).
    ///   - end: The ending point (already transformed by CTM).
    ///   - options: Drawing options.
    ///   - state: The current drawing state.
    func drawLinearGradient(
        _ gradient: CGGradient,
        start: CGPoint,
        end: CGPoint,
        options: CGGradientDrawingOptions,
        state: CGDrawingState
    )

    /// Called when drawing a radial gradient, with full drawing state.
    ///
    /// - Parameters:
    ///   - gradient: The gradient to draw.
    ///   - startCenter: The center of the starting circle (already transformed by CTM).
    ///   - startRadius: The radius of the starting circle.
    ///   - endCenter: The center of the ending circle (already transformed by CTM).
    ///   - endRadius: The radius of the ending circle.
    ///   - options: Drawing options.
    ///   - state: The current drawing state.
    func drawRadialGradient(
        _ gradient: CGGradient,
        startCenter: CGPoint,
        startRadius: CGFloat,
        endCenter: CGPoint,
        endRadius: CGFloat,
        options: CGGradientDrawingOptions,
        state: CGDrawingState
    )

    // MARK: - Stateful Transparency Layers

    /// Called when beginning a transparency layer, with full drawing state.
    ///
    /// - Parameters:
    ///   - rect: The bounding rectangle for the layer (nil for full context bounds).
    ///   - auxiliaryInfo: Optional dictionary with additional configuration.
    ///   - state: The current drawing state (includes clip path for limiting the layer).
    func beginTransparencyLayer(in rect: CGRect?, auxiliaryInfo: [String: Any]?, state: CGDrawingState)

    /// Called when ending a transparency layer, with full drawing state.
    ///
    /// - Parameters:
    ///   - alpha: The alpha value to apply when compositing the layer.
    ///   - blendMode: The blend mode to use when compositing.
    ///   - state: The current drawing state.
    func endTransparencyLayer(alpha: CGFloat, blendMode: CGBlendMode, state: CGDrawingState)

    // MARK: - Stateful Shading Drawing

    /// Called when drawing a shading, with full drawing state.
    ///
    /// - Parameters:
    ///   - shading: The shading to draw.
    ///   - alpha: The global alpha value.
    ///   - blendMode: The blend mode for compositing.
    ///   - state: The current drawing state.
    func drawShading(
        _ shading: CGShading,
        alpha: CGFloat,
        blendMode: CGBlendMode,
        state: CGDrawingState
    )

    // MARK: - Stateful Pattern Drawing

    /// Called when filling a path with a pattern, with full drawing state.
    ///
    /// - Parameters:
    ///   - path: The path to fill (already transformed by CTM).
    ///   - pattern: The pattern to use for filling.
    ///   - patternSpace: The color space for the pattern.
    ///   - colorComponents: Color components for uncolored patterns (nil for colored patterns).
    ///   - patternPhase: The pattern phase offset for positioning the pattern.
    ///   - alpha: The global alpha value.
    ///   - blendMode: The blend mode for compositing.
    ///   - rule: The fill rule (winding or even-odd).
    ///   - state: The current drawing state.
    func fillWithPattern(
        path: CGPath,
        pattern: CGPattern,
        patternSpace: CGColorSpace,
        colorComponents: [CGFloat]?,
        patternPhase: CGSize,
        alpha: CGFloat,
        blendMode: CGBlendMode,
        rule: CGPathFillRule,
        state: CGDrawingState
    )

    /// Called when stroking a path with a pattern, with full drawing state.
    ///
    /// - Parameters:
    ///   - path: The path to stroke (already transformed by CTM).
    ///   - pattern: The pattern to use for stroking.
    ///   - patternSpace: The color space for the pattern.
    ///   - colorComponents: Color components for uncolored patterns (nil for colored patterns).
    ///   - patternPhase: The pattern phase offset for positioning the pattern.
    ///   - lineWidth: The width of the stroke.
    ///   - lineCap: The line cap style.
    ///   - lineJoin: The line join style.
    ///   - miterLimit: The miter limit for joins.
    ///   - dashPhase: The dash pattern phase.
    ///   - dashLengths: The dash pattern lengths (empty for solid line).
    ///   - alpha: The global alpha value.
    ///   - blendMode: The blend mode for compositing.
    ///   - state: The current drawing state.
    func strokeWithPattern(
        path: CGPath,
        pattern: CGPattern,
        patternSpace: CGColorSpace,
        colorComponents: [CGFloat]?,
        patternPhase: CGSize,
        lineWidth: CGFloat,
        lineCap: CGLineCap,
        lineJoin: CGLineJoin,
        miterLimit: CGFloat,
        dashPhase: CGFloat,
        dashLengths: [CGFloat],
        alpha: CGFloat,
        blendMode: CGBlendMode,
        state: CGDrawingState
    )
}

// MARK: - Default Implementations for Stateful Delegate

extension CGContextStatefulRendererDelegate {

    /// Default: forwards to the non-state version.
    public func fill(
        path: CGPath,
        color: CGColor,
        alpha: CGFloat,
        blendMode: CGBlendMode,
        rule: CGPathFillRule,
        state: CGDrawingState
    ) {
        fill(path: path, color: color, alpha: alpha, blendMode: blendMode, rule: rule)
    }

    /// Default: forwards to the non-state version.
    public func stroke(
        path: CGPath,
        color: CGColor,
        lineWidth: CGFloat,
        lineCap: CGLineCap,
        lineJoin: CGLineJoin,
        miterLimit: CGFloat,
        dashPhase: CGFloat,
        dashLengths: [CGFloat],
        alpha: CGFloat,
        blendMode: CGBlendMode,
        state: CGDrawingState
    ) {
        stroke(
            path: path,
            color: color,
            lineWidth: lineWidth,
            lineCap: lineCap,
            lineJoin: lineJoin,
            miterLimit: miterLimit,
            dashPhase: dashPhase,
            dashLengths: dashLengths,
            alpha: alpha,
            blendMode: blendMode
        )
    }

    /// Default: forwards to the non-state version.
    public func clear(rect: CGRect, state: CGDrawingState) {
        clear(rect: rect)
    }

    /// Default: forwards to the non-state version.
    public func draw(
        image: CGImage,
        in rect: CGRect,
        alpha: CGFloat,
        blendMode: CGBlendMode,
        interpolationQuality: CGInterpolationQuality,
        state: CGDrawingState
    ) {
        draw(image: image, in: rect, alpha: alpha, blendMode: blendMode, interpolationQuality: interpolationQuality)
    }

    /// Default: forwards to the non-state version.
    public func drawLinearGradient(
        _ gradient: CGGradient,
        start: CGPoint,
        end: CGPoint,
        options: CGGradientDrawingOptions,
        state: CGDrawingState
    ) {
        drawLinearGradient(gradient, start: start, end: end, options: options)
    }

    /// Default: forwards to the non-state version.
    public func drawRadialGradient(
        _ gradient: CGGradient,
        startCenter: CGPoint,
        startRadius: CGFloat,
        endCenter: CGPoint,
        endRadius: CGFloat,
        options: CGGradientDrawingOptions,
        state: CGDrawingState
    ) {
        drawRadialGradient(gradient, startCenter: startCenter, startRadius: startRadius,
                           endCenter: endCenter, endRadius: endRadius, options: options)
    }

    /// Default: forwards to the non-state version.
    public func beginTransparencyLayer(in rect: CGRect?, auxiliaryInfo: [String: Any]?, state: CGDrawingState) {
        beginTransparencyLayer(in: rect, auxiliaryInfo: auxiliaryInfo)
    }

    /// Default: forwards to the non-state version.
    public func endTransparencyLayer(alpha: CGFloat, blendMode: CGBlendMode, state: CGDrawingState) {
        endTransparencyLayer(alpha: alpha, blendMode: blendMode)
    }

    /// Default: forwards to the non-state version.
    public func drawShading(
        _ shading: CGShading,
        alpha: CGFloat,
        blendMode: CGBlendMode,
        state: CGDrawingState
    ) {
        drawShading(shading, alpha: alpha, blendMode: blendMode)
    }

    /// Default: forwards to the non-state version.
    public func fillWithPattern(
        path: CGPath,
        pattern: CGPattern,
        patternSpace: CGColorSpace,
        colorComponents: [CGFloat]?,
        patternPhase: CGSize,
        alpha: CGFloat,
        blendMode: CGBlendMode,
        rule: CGPathFillRule,
        state: CGDrawingState
    ) {
        fillWithPattern(
            path: path,
            pattern: pattern,
            patternSpace: patternSpace,
            colorComponents: colorComponents,
            patternPhase: patternPhase,
            alpha: alpha,
            blendMode: blendMode,
            rule: rule
        )
    }

    /// Default: forwards to the non-state version.
    public func strokeWithPattern(
        path: CGPath,
        pattern: CGPattern,
        patternSpace: CGColorSpace,
        colorComponents: [CGFloat]?,
        patternPhase: CGSize,
        lineWidth: CGFloat,
        lineCap: CGLineCap,
        lineJoin: CGLineJoin,
        miterLimit: CGFloat,
        dashPhase: CGFloat,
        dashLengths: [CGFloat],
        alpha: CGFloat,
        blendMode: CGBlendMode,
        state: CGDrawingState
    ) {
        strokeWithPattern(
            path: path,
            pattern: pattern,
            patternSpace: patternSpace,
            colorComponents: colorComponents,
            patternPhase: patternPhase,
            lineWidth: lineWidth,
            lineCap: lineCap,
            lineJoin: lineJoin,
            miterLimit: miterLimit,
            dashPhase: dashPhase,
            dashLengths: dashLengths,
            alpha: alpha,
            blendMode: blendMode
        )
    }
}
