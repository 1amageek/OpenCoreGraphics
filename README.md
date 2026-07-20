# OpenCoreGraphics

A Swift library implementing CoreGraphics-compatible APIs and WebGPU rendering for WebAssembly (WASM) environments.

## Overview

OpenCoreGraphics enables cross-platform Swift code to use a broad CoreGraphics-compatible surface where Apple's framework is unavailable. Compatibility remains a target contract and is validated per API and rendering path.

## Verified Status

| Evidence | Result |
|---|---|
| Native package | 920 tests passed |
| Browser | Real WebGPU path, image-mask, callback-pattern, HDR tone mapping, image rendering, and pixel readback passed |
| Color management | Named RGB/gray/HDR, calibrated RGB/gray, and ICC matrix/TRC, LUT, and floating-point multi-process profiles convert through D50 XYZ or Lab PCS; CICP HLG/PQ metadata uses its interoperable HDR rendering |
| Font outlines | Static TrueType `glyf`, OpenType CFF1/Type2, and CFF2 variable outlines execute through the normal `CGContext` path; CFF1 and multi-axis CFF2 bounds are checked against Apple CoreText |
| Remaining boundary | TrueType `gvar`, variable HVAR/VVAR metrics, PostScript font subsetting/encoding, and PDF are not complete |

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
    colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
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

On WASM, OpenCoreGraphics uses WebGPU for hardware-accelerated rendering. Call `setupGraphicsContext()` once at application startup to initialize WebGPU.

```swift
import OpenCoreGraphics

@main
struct MyApp {
    static func main() async throws {
        // Initialize WebGPU (call once at startup)
        try await setupGraphicsContext()

        // Now use CGContext normally
        let context = CGContext(
            data: nil,
            width: 400,
            height: 300,
            bitsPerComponent: 8,
            bytesPerRow: 400 * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        )!

        context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 100, height: 100))

        // GPU readback
        let image = await context.makeImageAsync()
    }
}
```

#### Error Handling

`setupGraphicsContext()` throws `GraphicsContextError` if initialization fails:

```swift
do {
    try await setupGraphicsContext()
} catch GraphicsContextError.webGPUNotSupported {
    // Browser doesn't support WebGPU
} catch GraphicsContextError.adapterNotAvailable {
    // Failed to get WebGPU adapter
} catch GraphicsContextError.deviceNotAvailable {
    // Failed to get WebGPU device
}
```

#### Browser Requirements

WebGPU is required for WASM rendering. Supported browsers:
- Chrome 113+
- Edge 113+
- Firefox 139+ (with flags)
- Safari 18+ (macOS Sequoia / iOS 18)

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

### PDF Declarations
- `CGPDFDocument`, `CGPDFPage`, `CGPDFObject`, `CGPDFScanner` are present for source compatibility, but parser, writer, and renderer paths are not implemented and do not advertise success.

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

# Run focused tests with a 30-second process timeout
perl -e 'alarm 30; exec @ARGV' -- \
  xcodebuild test -scheme OpenCoreGraphics -destination 'platform=macOS' \
  -only-testing:OpenCoreGraphicsTests

# Build for WASM (requires Swift SDK for WASM)
swift build --swift-sdk swift-6.3.1-RELEASE_wasm

# Run the real-browser WebGPU suite
cd Tests/e2e && npm test
```

### Installing Swift WASM SDK

```bash
# Install the Swift WASM SDK
swift sdk install https://github.com/aspect-build/aspect-wasm32-wasi-release/releases/latest/download/swift-wasm32-wasi.artifactbundle.zip

# List installed SDKs
swift sdk list
```

## Requirements

- Swift 6.3.1+
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

Named RGB/gray/HDR and calibrated spaces convert through a D50 profile connection space. HLG uses the BT.2100 inverse OETF and luminance-coupled OOTF with the 203-nit extended-linear reference. ICC v2/v4 profiles support matrix/TRC, `mft1`, `mft2`, `mAB`, `mBA`, and floating-point `D2B`/`B2D` multi-process transforms. The `mpet` executor supports segmented curve sets, arbitrary channel matrices, multidimensional float CLUTs, `bACS`/`eACS` pass-through elements, direct absolute-colorimetric transforms, XYZ/Lab PCS, rendering-intent overrides, CICP HDR metadata, and CMYK/DeviceN profiles. Invalid known elements and channel contracts are rejected; unknown future elements use the ICC-defined integer-table fallback.

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
