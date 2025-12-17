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
# Build the package (macOS)
swift build

# Run tests (macOS)
swift test

# Build for WASM
swift build --swift-sdk swift-6.2.3-RELEASE_wasm
```

## Architecture

### Platform Differences: Foundation, CoreGraphics, and swift-corelibs-foundation

Understanding the relationship between these frameworks is critical:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                     Apple Platforms (macOS/iOS)                         │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌─────────────────────┐    ┌─────────────────────────────────────┐    │
│  │     Foundation      │    │          CoreGraphics               │    │
│  ├─────────────────────┤    ├─────────────────────────────────────┤    │
│  │ CGFloat ❌ protocols │    │ CGFloat ✅ Equatable,Hashable,etc   │    │
│  │ CGPoint ❌ protocols │    │ CGPoint ✅ Equatable,Hashable,etc   │    │
│  │ CGSize  ❌ protocols │    │ CGSize  ✅ Equatable,Hashable,etc   │    │
│  │ CGRect  ❌ protocols │    │ CGRect  ✅ Equatable,Hashable,etc   │    │
│  │                     │    │ CGAffineTransform ✅                 │    │
│  │                     │    │ CGVector ✅                          │    │
│  │                     │    │ CGPath (class) ✅                    │    │
│  └─────────────────────┘    └─────────────────────────────────────┘    │
│                                                                         │
│  ※ Foundation provides basic geometry types WITHOUT protocol           │
│    conformances. CoreGraphics provides full implementations.            │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│                              WASM                                        │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌─────────────────────────────────────┐                                │
│  │    swift-corelibs-foundation        │    CoreGraphics: ❌ N/A        │
│  ├─────────────────────────────────────┤                                │
│  │ CGFloat ✅ Equatable,Hashable,etc   │                                │
│  │ CGPoint ✅ Equatable,Hashable,etc   │                                │
│  │ CGSize  ✅ Equatable,Hashable,etc   │                                │
│  │ CGRect  ✅ Equatable,Hashable,etc   │                                │
│  │                                     │                                │
│  │ CGAffineTransform: ❌ N/A           │                                │
│  │ CGVector: ❌ N/A                    │                                │
│  │ CGPath: ❌ N/A                      │                                │
│  └─────────────────────────────────────┘                                │
│                                                                         │
│  ※ swift-corelibs-foundation provides geometry types WITH              │
│    protocol conformances (CoreGraphics-compatible).                     │
│    But does NOT provide CGAffineTransform, CGVector, CGPath, etc.       │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### Types Available Through Foundation on macOS (CoreFoundation/CFCGTypes.h)

On macOS, `import Foundation` implicitly makes certain CoreGraphics types available through CoreFoundation:

**Types available via Foundation (need `#if !canImport(CoreGraphics)` guard):**

| Type | Available | Source |
|------|-----------|--------|
| CGFloat | ✅ | CoreFoundation/CFCGTypes.h |
| CGPoint | ✅ | CoreFoundation/CFCGTypes.h |
| CGSize | ✅ | CoreFoundation/CFCGTypes.h |
| CGRect | ✅ | CoreFoundation/CFCGTypes.h |
| CGVector | ✅ | CoreFoundation/CFCGTypes.h |
| CGAffineTransform | ✅ | CoreFoundation/CFCGTypes.h |
| CGAffineTransformComponents | ✅ | CoreFoundation/CFCGTypes.h |

**Types NOT available via Foundation (no guard needed - CoreGraphics only):**

| Type | Available | Category |
|------|-----------|----------|
| CGColorSpace | ❌ | Color |
| CGColor | ❌ | Color |
| CGColorSpaceModel | ❌ | Color |
| CGColorRenderingIntent | ❌ | Color |
| CGPath | ❌ | Path |
| CGMutablePath | ❌ | Path |
| CGPathFillRule | ❌ | Path |
| CGPathElementType | ❌ | Path |
| CGContext | ❌ | Context |
| CGBlendMode | ❌ | Context |
| CGLineCap | ❌ | Context |
| CGLineJoin | ❌ | Context |
| CGInterpolationQuality | ❌ | Context |
| CGTextDrawingMode | ❌ | Context |
| CGImage | ❌ | Image |
| CGBitmapInfo | ❌ | Image |
| CGImageAlphaInfo | ❌ | Image |
| CGGradient | ❌ | Drawing |
| CGPattern | ❌ | Drawing |
| CGShading | ❌ | Drawing |
| CGLayer | ❌ | Layer |
| CGDataProvider | ❌ | Data |
| CGDataConsumer | ❌ | Data |
| CGFont | ❌ | Font |
| CGFunction | ❌ | Function |
| CGPDFDocument | ❌ | PDF |
| CGPDFPage | ❌ | PDF |
| CGError | ❌ | Error |

**Important**: Types available through Foundation on macOS are C structs without Swift extensions (no `.identity`, `.zero`, `applying()`, etc.). CoreGraphics adds these Swift extensions.

### Files Requiring `#if !canImport(CoreGraphics)` Guard

Based on the above analysis:

**MUST have guard** (types exist in CoreFoundation):
- `CGAffineTransform.swift`
- `CGAffineTransformComponents.swift`
- `CGVector.swift`

**NO guard needed** (types only exist in CoreGraphics):
- All other CG* files (CGColorSpace, CGColor, CGPath, CGContext, etc.)

### Testing Strategy and Protocol Conformances

**Important:** Tests run on macOS using Foundation (not CoreGraphics).

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         Testing Environment                              │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  macOS (テスト実行環境)                                                  │
│  ├── Foundation を使用                                                  │
│  ├── CGPoint/CGSize/CGRect に Equatable/Hashable/Codable がない         │
│  └── canImport(CoreGraphics) = true                                    │
│                                                                         │
│  WASM (本番環境)                                                         │
│  ├── swift-corelibs-foundation を使用                                   │
│  ├── CGPoint/CGSize/CGRect に Equatable/Hashable/Codable がある         │
│  └── canImport(CoreGraphics) = false                                   │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

**Solution: Add protocol conformances for macOS testing**

Since tests use Foundation on macOS (which lacks protocol conformances), we must add them. But on WASM, swift-corelibs-foundation already provides these conformances, so adding them would cause duplicate declaration errors.

```swift
// Protocol conformances for macOS testing
// On WASM, swift-corelibs-foundation already provides these
#if canImport(CoreGraphics)
extension CGPoint: Equatable {
    public static func == (lhs: CGPoint, rhs: CGPoint) -> Bool {
        return lhs.x == rhs.x && lhs.y == rhs.y
    }
}

extension CGPoint: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(x)
        hasher.combine(y)
    }
}

// CGSize, CGRect similarly...
#endif
```

**Key insight:**
- `#if canImport(CoreGraphics)` = true on macOS → Add protocol conformances for testing
- `#if canImport(CoreGraphics)` = false on WASM → Don't add (swift-corelibs-foundation already has them)

### Types Provided by swift-corelibs-foundation (Detailed)

swift-corelibs-foundation (WASM environment) provides the following CoreGraphics-compatible types:

| Type | Protocol Conformances | Notes |
|------|----------------------|-------|
| **CGFloat** | Equatable, Hashable, Codable, Sendable, BinaryFloatingPoint, ExpressibleByFloatLiteral, ExpressibleByIntegerLiteral, CustomStringConvertible, CustomDebugStringConvertible, Strideable | Implemented as Float (32-bit) or Double (64-bit) |
| **CGPoint** | Equatable, Hashable, Codable, Sendable, CustomDebugStringConvertible | Struct with x, y (CGFloat) |
| **CGSize** | Equatable, Hashable, Codable, Sendable, CustomDebugStringConvertible | Struct with width, height (CGFloat) |
| **CGRect** | Equatable, Hashable, Codable, Sendable, CustomDebugStringConvertible | Struct with origin (CGPoint), size (CGSize). Also provides minX, midX, maxX, minY, midY, maxY, width, height properties |
| **AffineTransform** | Equatable, Hashable, Codable, Sendable | **NOT CGAffineTransform**. Has m11, m12, m21, m22, tX, tY properties |

**Important**: swift-corelibs-foundation provides `AffineTransform`, but this is a **different type** from `CGAffineTransform`. CoreGraphics-compatible `CGAffineTransform` is NOT provided.

### Types NOT Provided by swift-corelibs-foundation

The following types do not exist in swift-corelibs-foundation and must be implemented by OpenCoreGraphics:

| Type | Category |
|------|----------|
| CGAffineTransform | Transform |
| CGAffineTransformComponents | Transform |
| CGVector | Geometry |
| CGPath | Path |
| CGMutablePath | Path |
| CGColor | Color |
| CGColorSpace | Color Space |
| CGColorSpaceModel | Color Space |
| CGColorRenderingIntent | Color Space |
| CGContext | Drawing Context |
| CGImage | Image |
| CGGradient | Gradient |
| CGPattern | Pattern |
| CGLayer | Layer |
| CGDataProvider | Data |
| CGDataConsumer | Data |
| CGPDFDocument | PDF |
| CGPDFPage | PDF |
| All other CG* types | - |

### What This Library Provides for WASM

The library provides CoreGraphics-compatible types that swift-corelibs-foundation does NOT provide:

| Type | swift-corelibs-foundation | This Library |
|------|---------------------------|--------------|
| CGFloat | ✅ Provided (with protocols) | - |
| CGPoint | ✅ Provided (with protocols) | Extensions (`applying()`, etc.) |
| CGSize | ✅ Provided (with protocols) | Extensions (`applying()`, etc.) |
| CGRect | ✅ Provided (with protocols) | Extensions (`applying()`, `insetBy()`, etc.) |
| AffineTransform | ✅ Provided (different type) | - |
| CGAffineTransform | ❌ Not provided | ✅ Full implementation |
| CGAffineTransformComponents | ❌ Not provided | ✅ Full implementation |
| CGVector | ❌ Not provided | ✅ Full implementation |
| CGPath | ❌ Not provided | ✅ Full implementation |
| CGMutablePath | ❌ Not provided | ✅ Full implementation |
| CGColor | ❌ Not provided | ✅ Full implementation |
| CGColorSpace | ❌ Not provided | ✅ Full implementation |
| CGContext | ❌ Not provided | ✅ Full implementation |
| ... | ... | ... |

### Conditional Compilation Rules

**1. Extensions to Foundation types (CGPoint, CGSize, CGRect methods like `applying()`, `zero`, etc.):**

These should be wrapped with `#if !canImport(CoreGraphics)` because CoreGraphics already provides them on Apple platforms.

```swift
#if !canImport(CoreGraphics)
extension CGPoint {
    public static var zero: CGPoint { ... }
    public func applying(_ t: CGAffineTransform) -> CGPoint { ... }
}
#endif
```

**2. New types not in swift-corelibs-foundation (CGVector, CGAffineTransform, CGPath, etc.):**

These should be wrapped with `#if !canImport(CoreGraphics)` to avoid duplicate definitions on Apple platforms.

```swift
#if !canImport(CoreGraphics)
public struct CGAffineTransform { ... }
public struct CGVector { ... }
public class CGPath { ... }
#endif
```

**3. Protocol conformances for Foundation types (for macOS testing):**

These should be wrapped with `#if canImport(CoreGraphics)` because:
- macOS needs them (Foundation lacks conformances)
- WASM doesn't need them (swift-corelibs-foundation already has them)

```swift
#if canImport(CoreGraphics)
extension CGPoint: Equatable { ... }
extension CGPoint: Hashable { ... }
extension CGSize: Equatable { ... }
// etc.
#endif
```

### Protocol Conformances Reference

From Apple's CoreGraphics documentation:

| Type | Conformances |
|------|-------------|
| CGFloat | Equatable, Hashable, Codable, Sendable, BinaryFloatingPoint, ... |
| CGPoint | Equatable, Hashable, Codable, Sendable |
| CGSize | Equatable, Hashable, Codable, Sendable |
| CGRect | Equatable, Hashable, Codable, Sendable |
| CGVector | Equatable, Hashable, Codable, Sendable |
| CGAffineTransform | Equatable, Hashable, Codable, Sendable |
| CGPath | Equatable, Hashable (class, not struct) |

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

### Testing on macOS

- Tests use Foundation (not CoreGraphics directly)
- Protocol conformances are added via `#if canImport(CoreGraphics)` for testing
- The `#if !canImport(CoreGraphics)` blocks are NOT compiled on macOS

### Building for WASM

```bash
swift build --swift-sdk swift-6.2.3-RELEASE_wasm
```

- Uses swift-corelibs-foundation (has protocol conformances)
- `#if canImport(CoreGraphics)` blocks are NOT compiled
- `#if !canImport(CoreGraphics)` blocks ARE compiled

## Implementation Policy

- **NEVER import CoreGraphics** - This library is a replacement for CoreGraphics. Importing CoreGraphics defeats the entire purpose of this library. Use `import Foundation` only.
- **Do NOT implement deprecated APIs** - Only implement current, non-deprecated CoreGraphics APIs
- Focus on APIs that are meaningful for WASM environments (skip macOS-only display/window services)
- Always refer to Apple's official CoreGraphics documentation: https://developer.apple.com/documentation/coregraphics
