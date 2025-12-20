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

### 設計原則: CoreGraphicsと完全に同じ使い方

ユーザーはネイティブでもWASMでも**完全に同じコード**を書きます。初期化関数やレンダラー設定は不要です。

```swift
#if canImport(CoreGraphics)
import CoreGraphics
#else
import OpenCoreGraphics
#endif

// これだけ。初期化関数は不要。CoreGraphicsと完全に同じAPI。
let context = CGContext(
    data: nil,
    width: 800,
    height: 600,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: CGColorSpace(name: CGColorSpace.sRGB)!,
    bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
)!

context.setFillColor(.red)
context.fill(CGRect(x: 0, y: 0, width: 100, height: 100))

let image = context.makeImage()  // WASMでもネイティブでも動作
```

### Native vs WASM: 根本的な違い

**このライブラリはWASM専用です。** ネイティブプラットフォームではAppleのCoreGraphicsを直接使用します。

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    ネイティブ (macOS/iOS/tvOS/watchOS)                   │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ユーザーコード                                                          │
│       │                                                                 │
│       ▼                                                                 │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │              Apple CoreGraphics (システム提供)                    │   │
│  ├─────────────────────────────────────────────────────────────────┤   │
│  │  • Quartz 2D エンジン                                            │   │
│  │  • ハードウェアアクセラレーション (Metal/GPU)                      │   │
│  │  • フォントレンダリング (Core Text 連携)                          │   │
│  │  • PDF 生成・解析                                                 │   │
│  │  • 画像フォーマット対応 (ImageIO 連携)                            │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
│  OpenCoreGraphics: 使用しない (canImport(CoreGraphics) = true)         │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│                              WASM                                        │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ユーザーコード                                                          │
│       │                                                                 │
│       ▼                                                                 │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                      OpenCoreGraphics                            │   │
│  ├─────────────────────────────────────────────────────────────────┤   │
│  │  Graphics/ (全アーキテクチャ)                                     │   │
│  │  • CoreGraphics 互換 API (CGContext, CGPath, CGColor, etc.)     │   │
│  │  • 状態管理 (CTM, クリッピング, シャドウ)                          │   │
│  │                                                                  │   │
│  │  Rendering/WebGPU/ (#if arch(wasm32) のみ)                       │   │
│  │  • WebGPU によるGPUレンダリング (自動設定)                        │   │
│  │  • パステッセレーション                                           │   │
│  │  • ブレンドモード (Porter-Duff)                                   │   │
│  │  • グラデーション・シェーディング                                  │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
│  ※ WebGPUレンダラーは内部で自動設定される（ユーザーは意識しない）       │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

| 環境 | CoreGraphics | OpenCoreGraphics | レンダリング |
|------|--------------|------------------|-------------|
| **macOS/iOS** | ✅ システム提供 | ❌ 使用しない | Apple Quartz 2D |
| **WASM** | ❌ 存在しない | ✅ 使用する | WebGPU (内部で自動設定) |

**重要**: OpenCoreGraphics のコードは `#if !canImport(CoreGraphics)` で囲まれており、ネイティブ環境ではコンパイルされません。

### モジュール構成

```
Sources/OpenCoreGraphics/
├── Graphics/                    # 全プラットフォーム共通
│   ├── CGContext.swift          # #if arch(wasm32) で自動的にWebGPUを設定
│   ├── CGPath.swift
│   ├── CGColor.swift
│   ├── CGImage.swift
│   └── ...
│
└── Rendering/                   # WASM専用 (#if arch(wasm32))
    └── WebGPU/
        ├── WebGPURendererManager.swift  # internal - レンダラーライフサイクル管理
        ├── CGWebGPUContextRenderer.swift
        ├── PathTessellator.swift
        ├── EarClipping.swift
        ├── StrokeGenerator.swift
        ├── Shaders.swift
        └── Internal/
            ├── BufferPool.swift
            ├── TextureManager.swift
            └── ...
```

### 内部レンダラー設定

`CGContext` の初期化時に、WASMアーキテクチャでは自動的にWebGPUレンダラーが設定されます。

```swift
// CGContext.swift (内部実装)
public final class CGContext {

    // internal - ユーザーには公開しない
    weak var rendererDelegate: CGContextRendererDelegate?

    public init?(data: UnsafeMutableRawPointer?, width: Int, height: Int, ...) {
        // 既存の初期化コード
        ...

        // WASMでは自動的にWebGPUレンダラーを設定
        #if arch(wasm32)
        self.rendererDelegate = WebGPURendererManager.shared.createRenderer(
            width: width,
            height: height
        )
        #endif
    }
}
```

**重要**: `rendererDelegate` は `internal` です。ユーザーがレンダラーを意識したり設定したりする必要はありません。

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

### CoreFoundation (CF) Types Policy

**Do NOT use or emulate CoreFoundation types.** Use Swift native types instead.

#### Rationale

1. **CoreFoundation is unavailable on WASM** - CF types (`CFData`, `CFMutableData`, `CFString`, `CFArray`, etc.) do not exist in the WASM environment
2. **Modern Swift prefers native types** - Even on Apple platforms, Swift code uses `Data` instead of `CFData`, `String` instead of `CFString`
3. **Reference semantics are not required** - CF's reference-based patterns (e.g., `CFMutableData` for in-place modification) can be replaced with Swift-idiomatic approaches

#### Type Mapping

| CoreFoundation Type | Use Instead | Notes |
|---------------------|-------------|-------|
| `CFData` | `Data` | Value type, use properties to expose results |
| `CFMutableData` | `Data` (mutable var) | Do not emulate reference semantics |
| `CFString` | `String` | Swift native string |
| `CFArray` | `[T]` | Swift native array |
| `CFDictionary` | `[K: V]` | Swift native dictionary |
| `CFNumber` | `Int`, `Double`, etc. | Swift native numeric types |

#### Example: CGDataConsumer

Instead of emulating `CFMutableData` reference semantics:

```swift
// ❌ Don't try to emulate CFMutableData behavior
let mutableData = NSMutableData()
let consumer = CGDataConsumer(data: mutableData)  // Won't work as expected

// ✅ Use a property to retrieve the result
let consumer = CGDataConsumer()
consumer.putBytes(buffer, count: length)
let result = consumer.data  // Get the accumulated data via property
```

#### What Compatibility Means

**API Surface Compatibility:**
- Same type names (`CGDataConsumer`, `CGDataProvider`, `CGImage`, etc.)
- Same method signatures
- Same behavior for the same inputs

**NOT Required:**
- Internal use of CF types
- CF-style reference semantics
- `CFTypeID` or other CF runtime features

### Legacy API Policy

**Do NOT implement legacy/deprecated CoreGraphics APIs.** Follow Apple's modern framework design.

#### Framework Responsibility Separation

Apple's modern design separates concerns across frameworks:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    Modern Apple Framework Design                         │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│   [ User Code ]                                                         │
│        │                                                                │
│        ├──────────────────┬──────────────────┐                         │
│        ▼                  ▼                  ▼                          │
│   ┌─────────┐      ┌─────────────┐    ┌─────────────┐                  │
│   │ ImageIO │      │ CoreGraphics │    │   PDFKit    │                  │
│   │         │      │              │    │             │                  │
│   │ Decode/ │      │ Represent/   │    │ Parse/      │                  │
│   │ Encode  │      │ Draw         │    │ Render PDF  │                  │
│   └────┬────┘      └──────────────┘    └─────────────┘                  │
│        │                  ▲                                             │
│        │                  │                                             │
│        └──────────────────┘                                             │
│              CGImage                                                    │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

| Framework | Responsibility |
|-----------|---------------|
| **CoreGraphics** | Image representation (`CGImage`), drawing (`CGContext`), geometry |
| **ImageIO** | Image format decoding/encoding (JPEG, PNG, HEIC, etc.) |
| **PDFKit** | PDF document parsing and rendering |

#### Legacy APIs NOT Implemented

The following CoreGraphics APIs are considered legacy and are **intentionally not implemented**:

| Legacy API | Modern Alternative | Reason |
|------------|-------------------|--------|
| `CGImage(jpegDataProviderSource:...)` | ImageIO | Apple docs: "Use Image I/O instead" |
| `CGImage(pngDataProviderSource:...)` | ImageIO | Apple docs: "Use Image I/O instead" |
| `CGPDFDocument` / `CGPDFPage` parsing | PDFKit | Complex parsing belongs in dedicated framework |

#### WASM Implementation Strategy

For WASM environments, create separate modules following Apple's design:

```swift
// ❌ Wrong: Implement decoders in CoreGraphics
let image = CGImage(pngDataProviderSource: provider, ...)  // Not available

// ✅ Correct: Use dedicated module for decoding
import OpenImageIO  // Separate module for WASM
let image = ImageSource(data: pngData).createImage()  // Returns CGImage
```

This separation provides:
- **Cleaner architecture** - Each module has single responsibility
- **Smaller binaries** - Users only import what they need
- **Independent updates** - Decoders can be updated without affecting core graphics

### Rendering Architecture: 内部実装詳細 (WASM専用)

**このセクションはライブラリ開発者向けの内部実装詳細です。ユーザーはレンダリングアーキテクチャを意識する必要はありません。**

OpenCoreGraphics uses a delegate pattern for rendering internally. All drawing operations in `CGContext` are forwarded to an internal `rendererDelegate` that implements the actual rendering.

```
┌─────────────────────────────────────────────────────────────────────────┐
│                     Internal Rendering Architecture                      │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  User Code (CoreGraphicsと完全に同じAPI)                                 │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │  let context = CGContext(...)  // 自動的にWebGPUレンダラーを設定  │   │
│  │  context.setFillColor(.red)                                     │   │
│  │  context.fill(CGRect(x: 0, y: 0, width: 100, height: 100))      │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                              │                                          │
│                              ▼                                          │
│  CGContext                                                              │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │  • Manages graphics state (CTM, colors, line properties, etc.)  │   │
│  │  • Builds paths                                                  │   │
│  │  • Applies CTM to paths/coordinates                              │   │
│  │  • Forwards drawing commands to rendererDelegate (internal)     │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                              │                                          │
│                              ▼                                          │
│  rendererDelegate (internal)                                            │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │  CGWebGPUContextRenderer (自動設定)                              │   │
│  │  • Tessellates paths into triangles                              │   │
│  │  • Uploads vertices to GPU                                       │   │
│  │  • Executes WebGPU render passes                                 │   │
│  │  • Handles clipping via stencil buffer                           │   │
│  │  • Implements blend modes via pipeline states                    │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

#### Key Design Decisions

1. **レンダラーは内部で自動設定される**
   - `CGContext.init()` 内で `#if arch(wasm32)` により自動的に設定
   - ユーザーはレンダラーを意識しない
   - `rendererDelegate` は `internal` アクセス修飾子

2. **CGContext does NOT render directly to pixels**
   - The internal `data` buffer is NOT updated by drawing operations
   - All rendering is delegated to `rendererDelegate`
   - Use `makeImageAsync()` for GPU readback

3. **Two delegate protocols (internal)**
   - `CGContextRendererDelegate`: Basic protocol with essential drawing methods
   - `CGContextStatefulRendererDelegate`: Extended protocol with full state (clip paths, shadows)

4. **State is passed to delegates**
   - CTM is applied to paths/coordinates before delegation
   - Clip paths are passed as an array (for intersection)
   - Shadow parameters are included in `CGDrawingState`

#### CGContextStatefulRendererDelegate

For full feature support (clipping, shadows, transparency layers), renderers should adopt `CGContextStatefulRendererDelegate`:

```swift
public protocol CGContextStatefulRendererDelegate: CGContextRendererDelegate {
    func fill(path: CGPath, color: CGColor, alpha: CGFloat,
              blendMode: CGBlendMode, rule: CGPathFillRule,
              state: CGDrawingState)

    func stroke(path: CGPath, color: CGColor, lineWidth: CGFloat, ...,
                state: CGDrawingState)

    func beginTransparencyLayer(in rect: CGRect?, auxiliaryInfo: [String: Any]?,
                                 state: CGDrawingState)

    func endTransparencyLayer(alpha: CGFloat, blendMode: CGBlendMode,
                               state: CGDrawingState)
    // ... other methods
}
```

#### CGDrawingState Structure

```swift
public struct CGDrawingState: Sendable {
    /// Multiple clip paths (intersection of all)
    public var clipPaths: [CGPath]

    /// Current transformation matrix
    public var ctm: CGAffineTransform

    /// Shadow parameters
    public var shadowOffset: CGSize
    public var shadowBlur: CGFloat
    public var shadowColor: CGColor?

    /// Convenience properties
    public var hasClipping: Bool { !clipPaths.isEmpty }
    public var hasShadow: Bool { shadowColor != nil && ... }
}
```

#### Implications for Implementation

**When adding new drawing features:**
1. Add the method to `CGContextRendererDelegate` protocol
2. Add a stateful version to `CGContextStatefulRendererDelegate`
3. Add default implementation that forwards to non-stateful version
4. Update `CGContext` to call the delegate method
5. Implement in `CGWebGPUContextRenderer`

**When modifying existing features:**
- Ensure CTM is applied consistently to coordinates/paths
- Pass full state via `CGDrawingState` for stateful delegates
- Update documentation to reflect delegate-based behavior

#### 実装状況 (WASM/WebGPU)

WASMでもネイティブと同等の機能をサポートしています。

| Feature | Status | Notes |
|---------|--------|-------|
| Blend modes | ✅ 実装済み | 12+ Porter-Duff modes via `GPUBlendState` |
| Gradients | ✅ 実装済み | Linear and radial gradients with extend options |
| Shading | ✅ 実装済み | Axial and radial shading with `extendStart`/`extendEnd` |
| Image rendering | ✅ 実装済み | `imagePipeline` with texture sampling |
| Clipping | ✅ 実装済み | Stencil buffer with `depth24plusStencil8` format |
| Shadows | ✅ 実装済み | Multi-pass Gaussian blur (separable) |
| Pattern rendering | ✅ 実装済み | GPU-based procedural tiling shader |
| `makeImage()` | ✅ 実装済み | GPU readback via `makeImageAsync()` |

#### makeImage() の使用方法

WASMでは `makeImageAsync()` を使用してGPU readbackを行います。レンダラーの設定は不要です。

```swift
// CoreGraphicsと完全に同じAPI
let context = CGContext(
    data: nil,
    width: 800,
    height: 600,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: CGColorSpace(name: CGColorSpace.sRGB)!,
    bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
)!

// 描画
context.setFillColor(.red)
context.fill(CGRect(x: 0, y: 0, width: 100, height: 100))

// GPU からの読み取り (WASMでは内部的にWebGPU readbackを実行)
let image = await context.makeImageAsync()
```

**注意**: 同期版の `makeImage()` はWASMでは空の画像を返す可能性があります。非同期版の `makeImageAsync()` を使用してください。
