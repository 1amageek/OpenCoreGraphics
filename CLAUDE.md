# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

OpenCoreGraphics is a Swift library that provides **full API compatibility with Apple's CoreGraphics framework** for WebAssembly (WASM) environments.

### Core Principle: Full Compatibility

**The API must be 100% compatible with CoreGraphics.** This means:
- Identical type names, method signatures, and property names
- Same behavior and semantics as CoreGraphics
- Code written for CoreGraphics should compile and work without modification when using OpenCoreGraphics

### How `canImport` Works

Users of this library will write code like:

```swift
#if canImport(CoreGraphics)
import CoreGraphics
#else
import OpenCoreGraphics
#endif

// This code works in both environments
let rect = CGRect(x: 0, y: 0, width: 100, height: 100)
```

- **When CoreGraphics is available** (iOS, macOS, etc.): Users import CoreGraphics directly
- **When CoreGraphics is NOT available** (WASM): Users import OpenCoreGraphics, which provides identical APIs

This library exists so that cross-platform Swift code can use CoreGraphics APIs even in WASM environments where Apple's CoreGraphics is not available.

## Build Commands

```bash
# Build the package
swift build

# Run tests
swift test

# Run a specific test
swift test --filter <TestName>

# Build for WASM (requires SwiftWasm toolchain)
swift build --triple wasm32-unknown-wasi
```

## Architecture

### Implementation Approach

This library provides standalone implementations of CoreGraphics types for WASM environments. Each type must exactly mirror the CoreGraphics API:

```swift
// Example: CGPoint must match CoreGraphics.CGPoint exactly
public struct CGPoint: Sendable, Hashable, Codable {
    public var x: CGFloat
    public var y: CGFloat

    public init()
    public init(x: CGFloat, y: CGFloat)

    public static var zero: CGPoint { get }
    // ... all other CoreGraphics.CGPoint APIs
}
```

**Important**: Always refer to Apple's official CoreGraphics documentation to ensure API signatures match exactly.

### Type Categories to Implement

1. **Geometric Data Types**: `CGFloat`, `CGPoint`, `CGSize`, `CGRect`, `CGVector`, `CGAffineTransform`
2. **2D Drawing**: `CGContext`, `CGImage`, `CGPath`, `CGMutablePath`, `CGLayer`
3. **Colors**: `CGColor`, `CGColorSpace`, `CGColorModel`, `CGComponent`, `CGBitmapLayout`
4. **Utility**: `CGGradient`, `CGPattern`, `CGDataProvider`, `CGDataConsumer`

### Protocol Conformances

All value types should conform to: `Sendable`, `Hashable`, `Equatable`, `Codable`

Enum types should additionally conform to: `RawRepresentable` (with `UInt32` raw value)

### Implementation Policy

- **Do NOT implement deprecated APIs** - Only implement current, non-deprecated CoreGraphics APIs
- Focus on APIs that are meaningful for WASM environments (skip macOS-only display/window services)

## Testing

Uses Swift Testing framework (not XCTest). Test syntax:

```swift
import Testing
@testable import OpenCoreGraphics

@Test func testCGPointEquality() {
    let p1 = CGPoint(x: 1.0, y: 2.0)
    let p2 = CGPoint(x: 1.0, y: 2.0)
    #expect(p1 == p2)
}
```
