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

# Build for WASM (requires SwiftWasm toolchain)
swift build --triple wasm32-unknown-wasi
```

## Requirements

- Swift 6.2+
- For WASM builds: [SwiftWasm](https://swiftwasm.org/) toolchain

## Design Principles

1. **Full API Compatibility**: Identical type names, method signatures, and property names as CoreGraphics
2. **Same Behavior**: Consistent semantics with Apple's implementation
3. **Modern Swift**: Conformance to `Sendable`, `Hashable`, `Equatable`, and `Codable` protocols
4. **No Deprecated APIs**: Only current, non-deprecated CoreGraphics APIs are implemented

## License

MIT License
