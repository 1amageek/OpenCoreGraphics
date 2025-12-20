# OpenCoreGraphics

A Swift library that provides **full API compatibility with Apple's CoreGraphics framework** for WebAssembly (WASM) environments.

## Overview

OpenCoreGraphics enables cross-platform Swift code to use CoreGraphics APIs in WASM environments where Apple's CoreGraphics is not available. The API is designed to be 100% compatible with CoreGraphics, allowing code to compile and work without modification.

## Installation

Add OpenCoreGraphics to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/1amageek/OpenCoreGraphics.git", from: "1.0.0")
]
```

Then add it to your target:

```swift
.target(
    name: "YourTarget",
    dependencies: ["OpenCoreGraphics"]
)
```

## Usage

Use conditional imports to support both Apple platforms and WASM:

```swift
#if canImport(CoreGraphics)
import CoreGraphics
#else
import OpenCoreGraphics
#endif
```

### Drawing with CGContext

```swift
// Create a bitmap context
let context = CGContext(
    data: nil,
    width: 400,
    height: 300,
    bitsPerComponent: 8,
    bytesPerRow: 400 * 4,
    space: CGColorSpace(name: CGColorSpace.sRGB)!,
    bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
)!

// Draw shapes
context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
context.fill(CGRect(x: 50, y: 50, width: 100, height: 80))

context.setStrokeColor(CGColor(red: 0, green: 0, blue: 1, alpha: 1))
context.setLineWidth(3)
context.strokeEllipse(in: CGRect(x: 200, y: 50, width: 100, height: 100))

// Get the rendered image
let image = context.makeImage()
```

### Path Drawing

```swift
let path = CGMutablePath()
path.move(to: CGPoint(x: 100, y: 100))
path.addLine(to: CGPoint(x: 200, y: 100))
path.addLine(to: CGPoint(x: 150, y: 200))
path.closeSubpath()

context.addPath(path)
context.setFillColor(.red)
context.fillPath()
```

### Gradients

```swift
let gradient = CGGradient(
    colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
    colors: [CGColor.red, CGColor.blue],
    locations: [0, 1]
)!

context.drawLinearGradient(
    gradient,
    start: CGPoint(x: 0, y: 0),
    end: CGPoint(x: 400, y: 300),
    options: []
)
```

### Transforms

```swift
context.saveGState()
context.translateBy(x: 200, y: 150)
context.rotate(by: .pi / 4)
context.scaleBy(x: 2, y: 2)
context.fill(CGRect(x: -25, y: -25, width: 50, height: 50))
context.restoreGState()
```

### WASM Usage

On WASM, OpenCoreGraphics uses WebGPU for hardware-accelerated rendering. WebGPU initialization is handled automatically.

**Option 1: Standard API with async image creation**
```swift
// Create context using standard CoreGraphics API
let context = CGContext(
    data: nil,
    width: 400,
    height: 300,
    bitsPerComponent: 8,
    bytesPerRow: 400 * 4,
    space: CGColorSpace(name: CGColorSpace.sRGB)!,
    bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
)!

// Draw normally
context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
context.fill(CGRect(x: 0, y: 0, width: 100, height: 100))

// Use async for GPU readback - WebGPU is initialized automatically
let image = await context.makeImageAsync()
```

**Option 2: Async factory method (recommended for WASM)**
```swift
// Creates context with WebGPU fully initialized
let context = await CGContext.create(
    data: nil,
    width: 400,
    height: 300,
    bitsPerComponent: 8,
    bytesPerRow: 400 * 4,
    space: CGColorSpace(name: CGColorSpace.sRGB)!,
    bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
)

// Draw and get image
context?.setFillColor(.red)
context?.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
let image = await context?.makeImageAsync()
```

## Implemented Types

### Geometric Data Types
- `CGFloat`, `CGPoint`, `CGSize`, `CGRect`, `CGVector`
- `CGAffineTransform`, `CGAffineTransformComponents`

### 2D Drawing
- `CGContext`, `CGImage`, `CGPath`, `CGMutablePath`, `CGLayer`

### Colors & Color Spaces
- `CGColor`, `CGColorSpace`, `CGColorSpaceModel`, `CGColorConversionInfo`
- `CGComponent`, `CGBitmapInfo`, `CGImageAlphaInfo`

### Gradients & Patterns
- `CGGradient`, `CGShading`, `CGPattern`, `CGFunction`

### Data Handling
- `CGDataProvider`, `CGDataConsumer`

### PDF Support
- `CGPDFDocument`, `CGPDFPage`, `CGPDFObject`, `CGPDFScanner`

### Fonts
- `CGFont`

### Enums & Options
- `CGBlendMode`, `CGTextDrawingMode`, `CGInterpolationQuality`
- `CGGradientDrawingOptions`, `CGPathFillRule`, `CGLineCap`, `CGLineJoin`
- And more...

## Building

```bash
# Build the package
swift build

# Run tests
swift test

# Build for WASM (requires Swift SDK for WASM)
swift build --swift-sdk <your-wasm-sdk>

# Example with specific SDK
swift build --swift-sdk swift-6.2.3-RELEASE_wasm
```

### Installing Swift WASM SDK

```bash
# Install the Swift WASM SDK
swift sdk install https://github.com/aspect-build/aspect-wasm32-wasi-release/releases/latest/download/swift-wasm32-wasi.artifactbundle.zip

# List installed SDKs
swift sdk list
```

## Requirements

- Swift 6.0+
- For WASM builds: Swift WASM SDK

## WASM Compatibility

This library is designed with WASM compatibility as a primary goal. All implementations use pure Swift types that work seamlessly in WebAssembly environments.

### Pure Swift Implementation

OpenCoreGraphics is built entirely with Swift standard types:

- `String` for names and identifiers
- `Data` for binary data
- `[String: Any]` for property lists and dictionaries
- `UInt` for type identifiers

### Supported Color Spaces

All standard color space names are available as `String` constants:

```swift
CGColorSpace.sRGB                    // "kCGColorSpaceSRGB"
CGColorSpace.displayP3               // "kCGColorSpaceDisplayP3"
CGColorSpace.genericGrayGamma2_2     // "kCGColorSpaceGenericGrayGamma2_2"
CGColorSpace.genericCMYK             // "kCGColorSpaceGenericCMYK"
// ... and many more
```

## Design Principles

1. **Full API Compatibility**: Identical type names, method signatures, and property names as CoreGraphics
2. **WASM First**: Uses pure Swift types that work in WebAssembly environments
3. **Same Behavior**: Consistent semantics with Apple's implementation
4. **Modern Swift**: All value types are `@frozen` and conform to `Sendable`, `Hashable`, `Equatable`, and `Codable`
5. **No Deprecated APIs**: Only current, non-deprecated CoreGraphics APIs are implemented
6. **Performance Optimized**: Uses `@inlinable` for performance-critical methods

## Protocol Conformances

All geometric value types (`CGFloat`, `CGPoint`, `CGSize`, `CGRect`, `CGVector`, `CGAffineTransform`) conform to:

- `Sendable` - Thread-safe
- `Hashable` - Can be used in Sets and as Dictionary keys
- `Equatable` - Equality comparison
- `Codable` - JSON serialization support

Additionally, `CGFloat` conforms to all numeric protocols:
- `FloatingPoint`, `BinaryFloatingPoint`
- `SignedNumeric`, `Numeric`
- `Comparable`, `Strideable`

## License

MIT License
