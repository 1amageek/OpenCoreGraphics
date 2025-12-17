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

// This code works in both environments
let rect = CGRect(x: 0, y: 0, width: 100, height: 100)
let point = CGPoint(x: 50, y: 50)
let containsPoint = rect.contains(point)
```

## Implemented Types

### Geometric Data Types
- `CGFloat`, `CGPoint`, `CGSize`, `CGRect`, `CGVector`
- `CGAffineTransform`, `CGAffineTransformComponents`

### 2D Drawing
- `CGContext`, `CGImage`, `CGPath`, `CGMutablePath`, `CGLayer`

### Colors & Color Spaces
- `CGColor`, `CGColorSpace`, `CGColorModel`, `CGColorConversionInfo`
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

This library is designed with WASM compatibility as a primary goal. Unlike Apple's CoreGraphics which relies on CoreFoundation types, OpenCoreGraphics uses pure Swift types that work in WASM environments.

### Type Mappings

CoreFoundation types are not available in WASM. This library uses Swift standard types instead:

| CoreGraphics (Apple) | OpenCoreGraphics | Notes |
|---------------------|------------------|-------|
| `CFString` | `String` | Toll-free bridged on Apple platforms |
| `CFDictionary` | `[String: Any]` | Dictionary representation |
| `CFData` | `Data` | Swift Foundation Data |
| `CFTypeID` | `UInt` | Type identifier |
| `CFURL` | `URL` | Swift Foundation URL |
| `NSData` | `Data` | Swift Foundation Data |

### API Differences

Some APIs use Swift types instead of CoreFoundation types:

```swift
// CGColorSpace color space names
// Apple: CFString
// OpenCoreGraphics: String
let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)  // String type

// Dictionary representations
// Apple: CFDictionary
// OpenCoreGraphics: [String: Any]
let dict: [String: Any] = point.dictionaryRepresentation

// PDF context keys
// Apple: CFString constants
// OpenCoreGraphics: String constants
let authorKey: String = kCGPDFContextAuthor
```

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
