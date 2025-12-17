//
//  CGContext.swift
//  OpenCoreGraphics
//
//  Created by OpenCoreGraphics contributors.
//

import Foundation


/// A Quartz 2D drawing destination.
public class CGContext: @unchecked Sendable {

    // MARK: - Properties

    /// The width of the bitmap context in pixels.
    public let width: Int

    /// The height of the bitmap context in pixels.
    public let height: Int

    /// The color space for the context.
    public let colorSpace: CGColorSpace?

    /// The bitmap info for the context.
    public let bitmapInfo: CGBitmapInfo

    /// Returns the alpha information associated with the context.
    public var alphaInfo: CGImageAlphaInfo {
        return bitmapInfo.alphaInfo
    }

    /// The bits per component for the context.
    public let bitsPerComponent: Int

    /// The bits per pixel for the context.
    public let bitsPerPixel: Int

    /// The bytes per row for the context.
    public let bytesPerRow: Int

    /// The underlying pixel data.
    internal var data: UnsafeMutableRawPointer?

    // MARK: - Graphics State

    /// The current graphics state.
    private var currentState: GraphicsState

    /// Stack of saved graphics states.
    private var stateStack: [GraphicsState] = []

    /// The current path being constructed.
    private var currentPath: CGMutablePath = CGMutablePath()

    // MARK: - Graphics State Structure

    private struct GraphicsState {
        var ctm: CGAffineTransform = .identity
        var clipPath: CGPath?
        var fillColor: CGColor = .black
        var strokeColor: CGColor = .black
        var lineWidth: CGFloat = 1.0
        var lineCap: CGLineCap = .butt
        var lineJoin: CGLineJoin = .miter
        var miterLimit: CGFloat = 10.0
        var lineDash: (phase: CGFloat, lengths: [CGFloat])? = nil
        var flatness: CGFloat = 0.5
        var alpha: CGFloat = 1.0
        var blendMode: CGBlendMode = .normal
        var interpolationQuality: CGInterpolationQuality = .default
        var shouldAntialias: Bool = true
        var shouldSmoothFonts: Bool = true
        var allowsAntialiasing: Bool = true
        var textDrawingMode: CGTextDrawingMode = .fill
        var textPosition: CGPoint = .zero
        var textMatrix: CGAffineTransform = .identity
        var characterSpacing: CGFloat = 0.0
        var shadowOffset: CGSize = .zero
        var shadowBlur: CGFloat = 0.0
        var shadowColor: CGColor?
        var fillColorSpace: CGColorSpace?
        var strokeColorSpace: CGColorSpace?
        var edrTargetHeadroom: Float = 1.0
        var contentToneMappingInfo: CGContentToneMappingInfo? = nil
    }

    // MARK: - Initializers

    /// Creates a bitmap graphics context.
    public init?(data: UnsafeMutableRawPointer?, width: Int, height: Int,
                 bitsPerComponent: Int, bytesPerRow: Int, space: CGColorSpace,
                 bitmapInfo: CGBitmapInfo) {
        guard width > 0, height > 0 else { return nil }
        guard bitsPerComponent > 0 else { return nil }

        self.width = width
        self.height = height
        self.bitsPerComponent = bitsPerComponent
        self.colorSpace = space
        self.bitmapInfo = bitmapInfo
        self.bytesPerRow = bytesPerRow

        // Calculate bits per pixel based on color space and bitmap info
        let componentsPerPixel = space.numberOfComponents + (bitmapInfo.alphaInfo != .none ? 1 : 0)
        self.bitsPerPixel = bitsPerComponent * componentsPerPixel

        // Allocate or use provided data
        if let data = data {
            self.data = data
        } else {
            let totalBytes = bytesPerRow * height
            self.data = UnsafeMutableRawPointer.allocate(byteCount: totalBytes, alignment: MemoryLayout<UInt8>.alignment)
            // Initialize to transparent
            self.data?.initializeMemory(as: UInt8.self, repeating: 0, count: totalBytes)
        }

        self.currentState = GraphicsState()
        self.currentState.fillColorSpace = space
        self.currentState.strokeColorSpace = space
    }

    deinit {
        // Note: In a real implementation, we'd track whether we own the data
        // and free it appropriately
    }

    // MARK: - Creating Images

    /// Creates an image from the contents of the bitmap context.
    public func makeImage() -> CGImage? {
        guard let data = data, let colorSpace = colorSpace else { return nil }

        let totalBytes = bytesPerRow * height
        let dataCopy = Data(bytes: data, count: totalBytes)
        let provider = CGDataProvider(data: dataCopy)

        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bitsPerPixel: bitsPerPixel,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo,
            provider: provider,
            decode: nil,
            shouldInterpolate: currentState.interpolationQuality != .none,
            intent: .defaultIntent
        )
    }

    // MARK: - Managing Graphics State

    /// Saves the current graphics state.
    public func saveGState() {
        stateStack.append(currentState)
    }

    /// Restores the most recently saved graphics state.
    public func restoreGState() {
        if let state = stateStack.popLast() {
            currentState = state
        }
    }

    // MARK: - Current Transformation Matrix (CTM)

    /// The current transformation matrix.
    public var ctm: CGAffineTransform {
        return currentState.ctm
    }

    /// Translates the origin of the user coordinate system.
    public func translateBy(x tx: CGFloat, y ty: CGFloat) {
        currentState.ctm = currentState.ctm.translatedBy(x: tx, y: ty)
    }

    /// Scales the user coordinate system.
    public func scaleBy(x sx: CGFloat, y sy: CGFloat) {
        currentState.ctm = currentState.ctm.scaledBy(x: sx, y: sy)
    }

    /// Rotates the user coordinate system.
    public func rotate(by angle: CGFloat) {
        currentState.ctm = currentState.ctm.rotated(by: angle)
    }

    /// Concatenates the current transformation matrix with an affine transformation.
    public func concatenate(_ transform: CGAffineTransform) {
        currentState.ctm = currentState.ctm.concatenating(transform)
    }

    // MARK: - Path Operations

    /// Begins a new subpath at the specified point.
    public func move(to point: CGPoint) {
        currentPath.move(to: point)
    }

    /// Appends a straight line segment to the current path.
    public func addLine(to point: CGPoint) {
        currentPath.addLine(to: point)
    }

    /// Adds a sequence of connected straight-line segments to the current path.
    public func addLines(between points: [CGPoint]) {
        currentPath.addLines(between: points)
    }

    /// Adds a rectangular subpath to the current path.
    public func addRect(_ rect: CGRect) {
        currentPath.addRect(rect)
    }

    /// Adds a set of rectangular subpaths to the current path.
    public func addRects(_ rects: [CGRect]) {
        currentPath.addRects(rects)
    }

    /// Adds an ellipse that fits inside the specified rectangle.
    public func addEllipse(in rect: CGRect) {
        currentPath.addEllipse(in: rect)
    }

    /// Adds an arc of a circle to the current path.
    public func addArc(center: CGPoint, radius: CGFloat, startAngle: CGFloat,
                       endAngle: CGFloat, clockwise: Bool) {
        currentPath.addArc(center: center, radius: radius, startAngle: startAngle,
                          endAngle: endAngle, clockwise: clockwise)
    }

    /// Adds an arc of a circle to the current path, specified with a radius and angles.
    public func addArc(tangent1End: CGPoint, tangent2End: CGPoint, radius: CGFloat) {
        currentPath.addArc(tangent1End: tangent1End, tangent2End: tangent2End, radius: radius)
    }

    /// Adds a cubic Bézier curve to the current path.
    public func addCurve(to end: CGPoint, control1: CGPoint, control2: CGPoint) {
        currentPath.addCurve(to: end, control1: control1, control2: control2)
    }

    /// Adds a quadratic Bézier curve to the current path.
    public func addQuadCurve(to end: CGPoint, control: CGPoint) {
        currentPath.addQuadCurve(to: end, control: control)
    }

    /// Adds a previously created path to the current path.
    public func addPath(_ path: CGPath) {
        currentPath.addPath(path)
    }

    /// Closes and completes the current subpath.
    public func closePath() {
        currentPath.closeSubpath()
    }

    /// Replaces the current path with a rectangle.
    public func beginPath() {
        currentPath = CGMutablePath()
    }

    /// Returns a copy of the current path.
    public var path: CGPath? {
        return currentPath.copy()
    }

    /// Returns whether the current path is empty.
    public var isPathEmpty: Bool {
        return currentPath.isEmpty
    }

    /// Returns the current point in the current path.
    public var currentPointOfPath: CGPoint {
        return currentPath.currentPoint
    }

    /// Returns the bounding box of the current path.
    public var boundingBoxOfPath: CGRect {
        return currentPath.boundingBox
    }

    /// Returns whether the specified point is inside the current path.
    public func pathContains(_ point: CGPoint, mode: CGPathFillRule = .winding) -> Bool {
        return currentPath.contains(point, using: mode)
    }

    /// Checks to see whether the specified point is contained in the current path.
    ///
    /// - Parameters:
    ///   - point: The point to test.
    ///   - mode: The drawing mode to use for the test.
    /// - Returns: `true` if the point is contained in the path; otherwise, `false`.
    public func pathContains(_ point: CGPoint, mode: CGPathDrawingMode) -> Bool {
        switch mode {
        case .fill, .fillStroke:
            return currentPath.contains(point, using: .winding)
        case .eoFill, .eoFillStroke:
            return currentPath.contains(point, using: .evenOdd)
        case .stroke:
            // For stroke mode, we'd need to check if point is within stroke width of path
            // For now, return false as this requires complex implementation
            return false
        }
    }

    /// Replaces the path in the graphics context with the stroked version of the path.
    public func replacePathWithStrokedPath() {
        // In a real implementation, this would create a new path that represents
        // the stroked version of the current path
        // For now, this is a placeholder
    }

    // MARK: - Drawing Paths

    /// Paints the area within the current path, using the specified fill rule.
    public func fillPath(using rule: CGPathFillRule = .winding) {
        // In a real implementation, this would rasterize the path
        currentPath = CGMutablePath()
    }

    /// Paints a line along the current path.
    public func strokePath() {
        // In a real implementation, this would rasterize the path stroke
        currentPath = CGMutablePath()
    }

    /// Draws the current path using the specified mode.
    public func drawPath(using mode: CGPathDrawingMode) {
        switch mode {
        case .fill:
            fillPath(using: .winding)
        case .eoFill:
            fillPath(using: .evenOdd)
        case .stroke:
            strokePath()
        case .fillStroke:
            fillPath(using: .winding)
            strokePath()
        case .eoFillStroke:
            fillPath(using: .evenOdd)
            strokePath()
        }
    }

    /// Fills the specified rectangle.
    public func fill(_ rect: CGRect) {
        beginPath()
        addRect(rect)
        fillPath()
    }

    /// Fills the specified rectangles.
    public func fill(_ rects: [CGRect]) {
        for rect in rects {
            fill(rect)
        }
    }

    /// Paints a line along the specified rectangle.
    public func stroke(_ rect: CGRect) {
        beginPath()
        addRect(rect)
        strokePath()
    }

    /// Strokes the specified rectangle with the specified line width.
    public func stroke(_ rect: CGRect, width: CGFloat) {
        let savedWidth = currentState.lineWidth
        currentState.lineWidth = width
        stroke(rect)
        currentState.lineWidth = savedWidth
    }

    /// Paints an ellipse that fits inside the specified rectangle.
    public func fillEllipse(in rect: CGRect) {
        beginPath()
        addEllipse(in: rect)
        fillPath()
    }

    /// Strokes an ellipse that fits inside the specified rectangle.
    public func strokeEllipse(in rect: CGRect) {
        beginPath()
        addEllipse(in: rect)
        strokePath()
    }

    /// Strokes the specified line segments.
    public func strokeLineSegments(between points: [CGPoint]) {
        guard points.count >= 2 else { return }
        for i in stride(from: 0, to: points.count - 1, by: 2) {
            beginPath()
            move(to: points[i])
            addLine(to: points[i + 1])
            strokePath()
        }
    }

    /// Clears the specified rectangle.
    public func clear(_ rect: CGRect) {
        // In a real implementation, this would clear the rectangle to transparent
    }

    // MARK: - Clipping

    /// Modifies the current clipping path by intersecting it with the current path.
    public func clip(using rule: CGPathFillRule = .winding) {
        currentState.clipPath = currentPath.copy()
        currentPath = CGMutablePath()
    }

    /// Modifies the current clipping path by intersecting it with the specified rectangle.
    public func clip(to rect: CGRect) {
        beginPath()
        addRect(rect)
        clip()
    }

    /// Modifies the current clipping path by intersecting it with the specified rectangles.
    public func clip(to rects: [CGRect]) {
        beginPath()
        addRects(rects)
        clip()
    }

    /// Returns the bounding box of the current clipping path.
    public var boundingBoxOfClipPath: CGRect {
        return currentState.clipPath?.boundingBox ?? CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height))
    }

    /// Maps a mask into the specified rectangle and intersects it with the current clipping area.
    ///
    /// - Parameters:
    ///   - rect: The rectangle to map the mask into.
    ///   - mask: The image to use as a mask.
    public func clip(to rect: CGRect, mask: CGImage) {
        // In a real implementation, this would intersect the mask with the current clip
    }

    // MARK: - Transparency Layers

    /// Begins a transparency layer.
    ///
    /// - Parameter auxiliaryInfo: An optional dictionary of auxiliary information.
    public func beginTransparencyLayer(auxiliaryInfo: [String: Any]?) {
        saveGState()
        // In a real implementation, this would begin compositing to an offscreen buffer
    }

    /// Begins a transparency layer whose contents are bounded by the specified rectangle.
    ///
    /// - Parameters:
    ///   - rect: The bounding rectangle for the transparency layer.
    ///   - auxiliaryInfo: An optional dictionary of auxiliary information.
    public func beginTransparencyLayer(in rect: CGRect, auxiliaryInfo: [String: Any]?) {
        saveGState()
        clip(to: rect)
        // In a real implementation, this would begin compositing to an offscreen buffer
    }

    /// Ends a transparency layer.
    public func endTransparencyLayer() {
        restoreGState()
        // In a real implementation, this would composite the offscreen buffer back
    }

    // MARK: - Color and Color Space

    /// Sets the current fill color space.
    public func setFillColorSpace(_ space: CGColorSpace) {
        currentState.fillColorSpace = space
    }

    /// Sets the current stroke color space.
    public func setStrokeColorSpace(_ space: CGColorSpace) {
        currentState.strokeColorSpace = space
    }

    /// Sets the current fill color.
    public func setFillColor(_ color: CGColor) {
        currentState.fillColor = color
    }

    /// Sets the current stroke color.
    public func setStrokeColor(_ color: CGColor) {
        currentState.strokeColor = color
    }

    /// Sets the current fill color using components.
    public func setFillColor(_ components: [CGFloat]) {
        if let space = currentState.fillColorSpace {
            currentState.fillColor = CGColor(space: space, componentArray: components)
        }
    }

    /// Sets the current stroke color using components.
    public func setStrokeColor(_ components: [CGFloat]) {
        if let space = currentState.strokeColorSpace {
            currentState.strokeColor = CGColor(space: space, componentArray: components)
        }
    }

    /// Sets the current fill color to a grayscale value.
    public func setFillColor(gray: CGFloat, alpha: CGFloat) {
        currentState.fillColor = CGColor(gray: gray, alpha: alpha)
    }

    /// Sets the current stroke color to a grayscale value.
    public func setStrokeColor(gray: CGFloat, alpha: CGFloat) {
        currentState.strokeColor = CGColor(gray: gray, alpha: alpha)
    }

    /// Sets the current fill color to an RGB value.
    public func setFillColor(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        currentState.fillColor = CGColor(red: red, green: green, blue: blue, alpha: alpha)
    }

    /// Sets the current stroke color to an RGB value.
    public func setStrokeColor(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        currentState.strokeColor = CGColor(red: red, green: green, blue: blue, alpha: alpha)
    }

    /// Sets the current fill color to a CMYK value.
    public func setFillColor(cyan: CGFloat, magenta: CGFloat, yellow: CGFloat, black: CGFloat, alpha: CGFloat) {
        currentState.fillColor = CGColor(genericCMYKCyan: cyan, magenta: magenta, yellow: yellow, black: black, alpha: alpha)
    }

    /// Sets the current stroke color to a CMYK value.
    public func setStrokeColor(cyan: CGFloat, magenta: CGFloat, yellow: CGFloat, black: CGFloat, alpha: CGFloat) {
        currentState.strokeColor = CGColor(genericCMYKCyan: cyan, magenta: magenta, yellow: yellow, black: black, alpha: alpha)
    }

    // MARK: - Stroke and Fill Properties

    /// The current line width.
    public var lineWidth: CGFloat {
        get { return currentState.lineWidth }
    }

    /// Sets the line width for the graphics context.
    public func setLineWidth(_ width: CGFloat) {
        currentState.lineWidth = width
    }

    /// The current line cap style.
    public var lineCap: CGLineCap {
        return currentState.lineCap
    }

    /// Sets the style for the endpoints of lines drawn in a graphics context.
    public func setLineCap(_ cap: CGLineCap) {
        currentState.lineCap = cap
    }

    /// The current line join style.
    public var lineJoin: CGLineJoin {
        return currentState.lineJoin
    }

    /// Sets the style for the joins of connected lines.
    public func setLineJoin(_ join: CGLineJoin) {
        currentState.lineJoin = join
    }

    /// The current miter limit.
    public var miterLimit: CGFloat {
        return currentState.miterLimit
    }

    /// Sets the miter limit for the context.
    public func setMiterLimit(_ limit: CGFloat) {
        currentState.miterLimit = limit
    }

    /// The current flatness value.
    public var flatness: CGFloat {
        return currentState.flatness
    }

    /// Sets the pattern for dashed lines.
    public func setLineDash(phase: CGFloat, lengths: [CGFloat]) {
        if lengths.isEmpty {
            currentState.lineDash = nil
        } else {
            currentState.lineDash = (phase, lengths)
        }
    }

    /// Sets the accuracy of curved paths in a graphics context.
    public func setFlatness(_ flatness: CGFloat) {
        currentState.flatness = flatness
    }

    /// Sets the pattern phase of the context.
    ///
    /// - Parameter phase: The pattern phase, which specifies how to position the pattern relative to the origin.
    public func setPatternPhase(_ phase: CGSize) {
        // In a real implementation, this would affect pattern rendering
    }

    /// Sets the fill pattern in the specified graphics context.
    ///
    /// - Parameters:
    ///   - pattern: The pattern to use for filling.
    ///   - colorComponents: The color components to use with the pattern.
    public func setFillPattern(_ pattern: CGPattern, colorComponents: UnsafePointer<CGFloat>) {
        // In a real implementation, this would set the fill pattern
    }

    /// Sets the stroke pattern in the specified graphics context.
    ///
    /// - Parameters:
    ///   - pattern: The pattern to use for stroking.
    ///   - colorComponents: The color components to use with the pattern.
    public func setStrokePattern(_ pattern: CGPattern, colorComponents: UnsafePointer<CGFloat>) {
        // In a real implementation, this would set the stroke pattern
    }

    // MARK: - Transparency and Compositing

    /// The current alpha value.
    public var alpha: CGFloat {
        return currentState.alpha
    }

    /// Sets the opacity level for objects drawn in a graphics context.
    public func setAlpha(_ alpha: CGFloat) {
        currentState.alpha = alpha
    }

    /// The current blend mode.
    public var blendMode: CGBlendMode {
        return currentState.blendMode
    }

    /// Sets the compositing mode for a graphics context.
    public func setBlendMode(_ mode: CGBlendMode) {
        currentState.blendMode = mode
    }

    /// Sets the rendering intent in the current graphics state.
    ///
    /// - Parameter intent: The rendering intent to use.
    public func setRenderingIntent(_ intent: CGColorRenderingIntent) {
        // In a real implementation, this would affect color rendering
    }

    // MARK: - Image Quality

    /// Sets the level of interpolation quality.
    public func setInterpolationQuality(_ quality: CGInterpolationQuality) {
        currentState.interpolationQuality = quality
    }

    /// The current interpolation quality.
    public var interpolationQuality: CGInterpolationQuality {
        return currentState.interpolationQuality
    }

    // MARK: - Antialiasing

    /// Whether antialiasing is enabled.
    public var shouldAntialias: Bool {
        return currentState.shouldAntialias
    }

    /// Sets antialiasing on or off for a graphics context.
    public func setShouldAntialias(_ shouldAntialias: Bool) {
        currentState.shouldAntialias = shouldAntialias
    }

    /// Whether antialiasing is allowed.
    public var allowsAntialiasing: Bool {
        return currentState.allowsAntialiasing
    }

    /// Sets whether or not to allow antialiasing.
    public func setAllowsAntialiasing(_ allowsAntialiasing: Bool) {
        currentState.allowsAntialiasing = allowsAntialiasing
    }

    // MARK: - Font Settings

    /// Enables or disables font smoothing.
    public func setShouldSmoothFonts(_ shouldSmoothFonts: Bool) {
        currentState.shouldSmoothFonts = shouldSmoothFonts
    }

    /// Sets whether or not to allow font smoothing for a graphics context.
    public func setAllowsFontSmoothing(_ allowsFontSmoothing: Bool) {
        // In a real implementation, this would control font smoothing permission
    }

    /// Sets whether or not to allow subpixel positioning for a graphics context.
    public func setAllowsFontSubpixelPositioning(_ allowsSubpixelPositioning: Bool) {
        // In a real implementation, this would control subpixel positioning
    }

    /// Sets whether or not to allow subpixel quantization for a graphics context.
    public func setAllowsFontSubpixelQuantization(_ allowsSubpixelQuantization: Bool) {
        // In a real implementation, this would control subpixel quantization
    }

    /// Enables or disables subpixel positioning in a graphics context.
    public func setShouldSubpixelPositionFonts(_ shouldSubpixelPositionFonts: Bool) {
        // In a real implementation, this would enable/disable subpixel positioning
    }

    /// Enables or disables subpixel quantization in a graphics context.
    public func setShouldSubpixelQuantizeFonts(_ shouldSubpixelQuantizeFonts: Bool) {
        // In a real implementation, this would enable/disable subpixel quantization
    }

    // MARK: - Shadow

    /// Sets the shadow in the context.
    public func setShadow(offset: CGSize, blur: CGFloat) {
        currentState.shadowOffset = offset
        currentState.shadowBlur = blur
        currentState.shadowColor = CGColor.black
    }

    /// Sets the shadow with a specified color.
    public func setShadow(offset: CGSize, blur: CGFloat, color: CGColor?) {
        currentState.shadowOffset = offset
        currentState.shadowBlur = blur
        currentState.shadowColor = color
    }

    // MARK: - Drawing Images

    /// Draws an image in the specified rectangle.
    public func draw(_ image: CGImage, in rect: CGRect) {
        // In a real implementation, this would composite the image into the context
    }

    /// Draws an image in the specified rectangle, creating a tiled pattern.
    public func draw(_ image: CGImage, in rect: CGRect, byTiling: Bool) {
        if byTiling {
            // Draw tiled
            var x = rect.minX
            while x < rect.maxX {
                var y = rect.minY
                while y < rect.maxY {
                    let tileRect = CGRect(x: x, y: y, width: CGFloat(image.width), height: CGFloat(image.height))
                    draw(image, in: tileRect)
                    y = y + CGFloat(image.height)
                }
                x = x + CGFloat(image.width)
            }
        } else {
            draw(image, in: rect)
        }
    }

    // MARK: - Drawing Gradients

    /// Draws a linear gradient.
    public func drawLinearGradient(_ gradient: CGGradient, start: CGPoint, end: CGPoint,
                                   options: CGGradientDrawingOptions) {
        // In a real implementation, this would rasterize the gradient
    }

    /// Draws a radial gradient.
    public func drawRadialGradient(_ gradient: CGGradient, startCenter: CGPoint, startRadius: CGFloat,
                                   endCenter: CGPoint, endRadius: CGFloat,
                                   options: CGGradientDrawingOptions) {
        // In a real implementation, this would rasterize the radial gradient
    }

    // MARK: - Drawing PDF Content

    /// Draws the content of a PDF page into the current graphics context.
    ///
    /// - Parameter page: The PDF page to draw.
    public func drawPDFPage(_ page: CGPDFPage) {
        // In a real implementation, this would render the PDF page
    }

    // MARK: - Text Drawing

    /// The current text drawing mode.
    public var textDrawingMode: CGTextDrawingMode {
        return currentState.textDrawingMode
    }

    /// Sets the text drawing mode.
    public func setTextDrawingMode(_ mode: CGTextDrawingMode) {
        currentState.textDrawingMode = mode
    }

    /// Sets the current text position.
    public func setTextPosition(x: CGFloat, y: CGFloat) {
        currentState.textPosition = CGPoint(x: x, y: y)
    }

    /// The current text position.
    public var textPosition: CGPoint {
        return currentState.textPosition
    }

    /// Sets the text matrix.
    public func setTextMatrix(_ transform: CGAffineTransform) {
        currentState.textMatrix = transform
    }

    /// The current text matrix.
    public var textMatrix: CGAffineTransform {
        return currentState.textMatrix
    }

    /// The current character spacing.
    public var characterSpacing: CGFloat {
        return currentState.characterSpacing
    }

    /// Sets the spacing between characters.
    public func setCharacterSpacing(_ spacing: CGFloat) {
        currentState.characterSpacing = spacing
    }

    // MARK: - Converting Coordinates

    /// Returns the affine transform that maps user space to device space.
    public var userSpaceToDeviceSpaceTransform: CGAffineTransform {
        return currentState.ctm
    }

    /// Converts a point from user space to device space.
    public func convertToDeviceSpace(_ point: CGPoint) -> CGPoint {
        return point.applying(currentState.ctm)
    }

    /// Converts a point from device space to user space.
    public func convertToUserSpace(_ point: CGPoint) -> CGPoint {
        return point.applying(currentState.ctm.inverted())
    }

    /// Converts a size from user space to device space.
    public func convertToDeviceSpace(_ size: CGSize) -> CGSize {
        return size.applying(currentState.ctm)
    }

    /// Converts a size from device space to user space.
    public func convertToUserSpace(_ size: CGSize) -> CGSize {
        return size.applying(currentState.ctm.inverted())
    }

    /// Converts a rectangle from user space to device space.
    public func convertToDeviceSpace(_ rect: CGRect) -> CGRect {
        return rect.applying(currentState.ctm)
    }

    /// Converts a rectangle from device space to user space.
    public func convertToUserSpace(_ rect: CGRect) -> CGRect {
        return rect.applying(currentState.ctm.inverted())
    }

    // MARK: - Adding a Rounded Rectangle

    /// Adds a rounded rectangle to the current path.
    public func addRoundedRect(in rect: CGRect, cornerWidth: CGFloat, cornerHeight: CGFloat) {
        currentPath.addRoundedRect(in: rect, cornerWidth: cornerWidth, cornerHeight: cornerHeight)
    }

    // MARK: - Flushing

    /// Forces all pending drawing operations in a window context to be rendered immediately.
    public func flush() {
        // In a bitmap context, this is a no-op
    }

    /// Marks a context for an update.
    public func synchronize() {
        // In a bitmap context, this is a no-op
    }

    // MARK: - HDR Support

    /// Sets the EDR (Extended Dynamic Range) target headroom for the context.
    ///
    /// The headroom value specifies how much brighter than SDR white the brightest
    /// pixels in the context can be. A value of 1.0 means SDR (no extended range).
    /// Values greater than 1.0 enable HDR rendering.
    ///
    /// - Parameter headroom: The target headroom value. Must be >= 1.0.
    public func setEDRTargetHeadroom(_ headroom: Float) {
        currentState.edrTargetHeadroom = max(1.0, headroom)
    }

    /// The current EDR target headroom for the context.
    public var edrTargetHeadroom: Float {
        return currentState.edrTargetHeadroom
    }

    /// The content tone mapping info for the context.
    ///
    /// This property controls how HDR content is tone mapped when drawn
    /// to the context. Set to `nil` to use default tone mapping behavior.
    public var contentToneMappingInfo: CGContentToneMappingInfo? {
        get { return currentState.contentToneMappingInfo }
        set { currentState.contentToneMappingInfo = newValue }
    }

    // MARK: - PDF Context Methods

    /// Begins a new page in a PDF graphics context.
    ///
    /// - Parameter pageInfo: An optional dictionary containing page-specific information.
    public func beginPDFPage(_ pageInfo: [String: Any]?) {
        // In a real implementation, this would start a new PDF page
    }

    /// Ends the current page in the PDF graphics context.
    public func endPDFPage() {
        // In a real implementation, this would end the current PDF page
    }

    /// Closes a PDF graphics context and writes the accumulated document data to its destination.
    public func closePDF() {
        // In a real implementation, this would finalize and write the PDF
    }

    /// Sets a destination to jump to when a point in the current page of a PDF graphics context is clicked.
    ///
    /// - Parameters:
    ///   - name: The name of the destination.
    ///   - point: The point in the current page that links to the destination.
    public func addDestination(_ name: String, at point: CGPoint) {
        // In a real implementation, this would add a named destination
    }

    /// Sets a destination to jump to when a rectangle in the current PDF page is clicked.
    ///
    /// - Parameters:
    ///   - name: The name of the destination to jump to.
    ///   - rect: The rectangle that triggers the jump.
    public func setDestination(_ name: String, for rect: CGRect) {
        // In a real implementation, this would set up a link to a destination
    }

    /// Sets the URL associated with a rectangle in a PDF graphics context.
    ///
    /// - Parameters:
    ///   - url: The URL to link to.
    ///   - rect: The rectangle that triggers the link.
    public func setURL(_ url: URL, for rect: CGRect) {
        // In a real implementation, this would create a URL link in the PDF
    }

    /// Associates a document metadata stream with a PDF context.
    ///
    /// - Parameter metadata: The metadata to add to the document.
    public func addDocumentMetadata(_ metadata: Data?) {
        // In a real implementation, this would add document metadata
    }
}

// MARK: - PDF Context Initializers

extension CGContext {
    /// Creates a URL-based PDF graphics context.
    ///
    /// - Parameters:
    ///   - url: The URL where the PDF file will be written.
    ///   - mediaBox: The default size and location of a page.
    ///   - auxiliaryInfo: Additional information for the PDF context.
    public convenience init?(_ url: URL, mediaBox: UnsafePointer<CGRect>?, _ auxiliaryInfo: [String: Any]?) {
        // PDF context creation not supported in this implementation
        return nil
    }

    /// Creates a PDF graphics context that writes to a data consumer.
    ///
    /// - Parameters:
    ///   - consumer: The data consumer that receives the PDF data.
    ///   - mediaBox: The default size and location of a page.
    ///   - auxiliaryInfo: Additional information for the PDF context.
    public convenience init?(consumer: CGDataConsumer, mediaBox: UnsafePointer<CGRect>?, _ auxiliaryInfo: [String: Any]?) {
        // PDF context creation not supported in this implementation
        return nil
    }
}

// MARK: - Factory Functions

/// Creates a bitmap graphics context.
public func CGBitmapContextCreate(_ data: UnsafeMutableRawPointer?, _ width: Int, _ height: Int,
                                   _ bitsPerComponent: Int, _ bytesPerRow: Int,
                                   _ space: CGColorSpace, _ bitmapInfo: UInt32) -> CGContext? {
    return CGContext(data: data, width: width, height: height, bitsPerComponent: bitsPerComponent,
                     bytesPerRow: bytesPerRow, space: space, bitmapInfo: CGBitmapInfo(rawValue: bitmapInfo))
}

/// Returns the data associated with the bitmap context.
public func CGBitmapContextGetData(_ context: CGContext) -> UnsafeMutableRawPointer? {
    return context.data
}

/// Returns the width of the bitmap context.
public func CGBitmapContextGetWidth(_ context: CGContext) -> Int {
    return context.width
}

/// Returns the height of the bitmap context.
public func CGBitmapContextGetHeight(_ context: CGContext) -> Int {
    return context.height
}

/// Returns the bits per component of the bitmap context.
public func CGBitmapContextGetBitsPerComponent(_ context: CGContext) -> Int {
    return context.bitsPerComponent
}

/// Returns the bits per pixel of the bitmap context.
public func CGBitmapContextGetBitsPerPixel(_ context: CGContext) -> Int {
    return context.bitsPerPixel
}

/// Returns the bytes per row of the bitmap context.
public func CGBitmapContextGetBytesPerRow(_ context: CGContext) -> Int {
    return context.bytesPerRow
}

/// Returns the color space of the bitmap context.
public func CGBitmapContextGetColorSpace(_ context: CGContext) -> CGColorSpace? {
    return context.colorSpace
}

/// Returns the bitmap info of the bitmap context.
public func CGBitmapContextGetBitmapInfo(_ context: CGContext) -> CGBitmapInfo {
    return context.bitmapInfo
}

/// Creates an image from the bitmap context.
public func CGBitmapContextCreateImage(_ context: CGContext) -> CGImage? {
    return context.makeImage()
}

// MARK: - CGContext.AuxiliaryInfo

extension CGContext {
    /// Auxiliary information for creating graphics contexts.
    public struct AuxiliaryInfo: Hashable, Sendable {
        /// The maximum bit depth for the context.
        public var maximumBitDepth: CGComponent

        /// Creates an empty auxiliary info structure.
        public init() {
            self.maximumBitDepth = .unknown
        }

        /// Creates auxiliary info with the specified maximum bit depth.
        ///
        /// - Parameter maximumBitDepth: The maximum bit depth for the context.
        public init(maximumBitDepth: CGComponent) {
            self.maximumBitDepth = maximumBitDepth
        }
    }
}

// MARK: - PDF Context Auxiliary Dictionary Keys

/// The corresponding value is a string that represents the name of the person who created the document.
public let kCGPDFContextAuthor: String = "kCGPDFContextAuthor"

/// The corresponding value is a string that represents the name of the application used to produce the document.
public let kCGPDFContextCreator: String = "kCGPDFContextCreator"

/// The corresponding value is a string that represents the title of the document.
public let kCGPDFContextTitle: String = "kCGPDFContextTitle"

/// The corresponding value is a string that represents the subject of the document.
public let kCGPDFContextSubject: String = "kCGPDFContextSubject"

/// The corresponding value is an array of strings that represent the keywords for the document.
public let kCGPDFContextKeywords: String = "kCGPDFContextKeywords"

/// The corresponding value is a string that represents the owner password for the document.
public let kCGPDFContextOwnerPassword: String = "kCGPDFContextOwnerPassword"

/// The corresponding value is a string that represents the user password for the document.
public let kCGPDFContextUserPassword: String = "kCGPDFContextUserPassword"

/// The corresponding value is a number that represents the encryption key length.
public let kCGPDFContextEncryptionKeyLength: String = "kCGPDFContextEncryptionKeyLength"

/// Whether the document allows printing when unlocked with the user password.
public let kCGPDFContextAllowsPrinting: String = "kCGPDFContextAllowsPrinting"

/// Whether the document allows copying when unlocked with the user password.
public let kCGPDFContextAllowsCopying: String = "kCGPDFContextAllowsCopying"

/// The output intent for the document.
public let kCGPDFContextOutputIntent: String = "kCGPDFContextOutputIntent"

/// An array of output intents for the document.
public let kCGPDFContextOutputIntents: String = "kCGPDFContextOutputIntents"

// MARK: - PDF Context Box Keys

/// The media box for the document or for a given page.
public let kCGPDFContextMediaBox: String = "kCGPDFContextMediaBox"

/// The crop box for the document or for a given page.
public let kCGPDFContextCropBox: String = "kCGPDFContextCropBox"

/// The bleed box for the document or for a given page.
public let kCGPDFContextBleedBox: String = "kCGPDFContextBleedBox"

/// The trim box for the document or for a given page.
public let kCGPDFContextTrimBox: String = "kCGPDFContextTrimBox"

/// The art box for the document or for a given page.
public let kCGPDFContextArtBox: String = "kCGPDFContextArtBox"

// MARK: - PDF/X Output Intent Keys

/// The output intent subtype. This key is required.
public let kCGPDFXOutputIntentSubtype: String = "kCGPDFXOutputIntentSubtype"

/// The output condition identifier.
public let kCGPDFXOutputConditionIdentifier: String = "kCGPDFXOutputConditionIdentifier"

/// A text string identifying the intended output device or production condition in a human-readable form.
public let kCGPDFXOutputCondition: String = "kCGPDFXOutputCondition"

/// The registry name.
public let kCGPDFXRegistryName: String = "kCGPDFXRegistryName"

/// Additional information about the output condition.
public let kCGPDFXInfo: String = "kCGPDFXInfo"

/// The destination output profile.
public let kCGPDFXDestinationOutputProfile: String = "kCGPDFXDestinationOutputProfile"

