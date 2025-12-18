# OpenCoreGraphics - 発見された論理矛盾と問題点

このドキュメントは、プロジェクトのコードレビューで発見された論理矛盾と問題点をまとめたものです。

---

## 重大度の定義

- **高**: 機能が全く動作しない、またはクラッシュの可能性がある
- **中**: 機能が部分的に動作しない、または期待と異なる動作をする
- **低**: 軽微な問題、または将来的な改善が望ましい

---

## 問題一覧

### 1. `makeImage()` が常に空の画像を返す

**重大度**: 高
**ファイル**: `Sources/OpenCoreGraphics/Graphics/CGContext.swift`

**問題の説明**:
- `CGContext` は `data` バッファ（ピクセルデータ）を保持している
- しかし、描画操作（`fillPath()`, `strokePath()` など）は `rendererDelegate` を呼び出すだけで、`data` バッファには何も書き込まない
- `makeImage()` は `data` バッファから画像を作成するが、バッファは初期化時にゼロで埋められたまま

**影響**:
- `CGContext.makeImage()` は常に透明（全てゼロ）の画像を返す
- `CGPattern.renderCell()` も同様に空の画像を返す（内部で `CGContext` を使用）

**該当コード**:
```swift
// CGContext.swift:147-167
public func makeImage() -> CGImage? {
    guard let data = data, let colorSpace = colorSpace else { return nil }
    // data は描画操作で更新されないため、常にゼロ
    let dataCopy = Data(bytes: data, count: totalBytes)
    // ...
}
```

**修正案**:
1. ソフトウェアラスタライザーを実装して `data` バッファに描画する
2. または、`makeImage()` のドキュメントに制限事項を明記し、delegate パターンでは使用できないことを説明

---

### 2. クリッピングパス (`clipPath`) が機能しない

**重大度**: 高
**ファイル**: `Sources/OpenCoreGraphics/Graphics/CGContext.swift`, `Sources/OpenCoreGraphics/Graphics/CGContextRendererDelegate.swift`

**問題の説明**:
- `clip()` メソッドは `clipPath` を `GraphicsState` に保存する
- しかし、`clipPath` は `CGContextRendererDelegate` のメソッドに渡されない
- レンダラーはクリッピング情報を受け取れないため、クリッピングが適用されない

**該当コード**:
```swift
// CGContext.swift:510-512
public func clip(using rule: CGPathFillRule = .winding) {
    currentState.clipPath = currentPath.copy()  // 保存するだけ
    currentPath = CGMutablePath()
}

// CGContextRendererDelegate.swift - clipPath パラメータがない
func fill(
    path: CGPath,
    color: CGColor,
    alpha: CGFloat,
    blendMode: CGBlendMode,
    rule: CGPathFillRule
)  // clipPath がない
```

**修正案**:
delegate メソッドに `clipPath: CGPath?` パラメータを追加する

---

### 3. シャドウが機能しない

**重大度**: 中
**ファイル**: `Sources/OpenCoreGraphics/Graphics/CGContext.swift`, `Sources/OpenCoreGraphics/Graphics/CGContextRendererDelegate.swift`

**問題の説明**:
- `GraphicsState` には `shadowOffset`, `shadowBlur`, `shadowColor` が保存される
- しかし、これらの値は delegate メソッドに渡されない

**該当コード**:
```swift
// GraphicsState には含まれている
var shadowOffset: CGSize = .zero
var shadowBlur: CGFloat = 0.0
var shadowColor: CGColor?

// しかし delegate メソッドには渡されない
```

**修正案**:
delegate メソッドにシャドウパラメータを追加する、またはシャドウ情報を含む構造体を渡す

---

### 4. CTM（Current Transformation Matrix）が一貫して適用されない

**重大度**: 高
**ファイル**: `Sources/OpenCoreGraphics/Graphics/CGContext.swift`

**問題の説明**:
- `fillPath()` と `strokePath()` はパスに CTM を適用してから delegate に渡す
- しかし、`draw(_ image: CGImage, in rect: CGRect)` は rect に CTM を適用しない
- `drawLinearGradient` と `drawRadialGradient` も start/end 座標に CTM を適用しない

**一貫性のない動作**:
```swift
// fillPath() - CTM を適用する ✓
let transformedPath: CGPath
if currentState.ctm.isIdentity {
    transformedPath = pathCopy
} else {
    var ctm = currentState.ctm
    transformedPath = withUnsafePointer(to: &ctm) { ptr in
        pathCopy.copy(using: ptr) ?? pathCopy
    }
}

// draw(image:) - CTM を適用しない ✗
public func draw(_ image: CGImage, in rect: CGRect) {
    rendererDelegate?.draw(
        image: image,
        in: rect,  // CTM が適用されていない
        // ...
    )
}
```

**修正案**:
すべての描画操作で座標/矩形に CTM を適用する

---

### 5. `blendMode` が WebGPU レンダラーで無視される

**重大度**: 中
**ファイル**: `Sources/CGWebGPU/CGWebGPUContextRenderer.swift`

**問題の説明**:
- `blendMode` パラメータはすべての delegate メソッドで受け取られる
- しかし、WebGPU レンダラーはこの値を使用していない
- 常にデフォルトのブレンドモードで描画される

**該当コード**:
```swift
public func fill(
    path: CGPath,
    color: CGColor,
    alpha: CGFloat,
    blendMode: CGBlendMode,  // 受け取るが...
    rule: CGPathFillRule
) {
    // blendMode は使用されない
    let batch = tessellator.tessellateFill(path, color: effectiveColor)
    renderBatch(batch, to: target, pipeline: pipeline)
}
```

**修正案**:
`blendMode` に応じて異なる GPU パイプライン（ブレンドステート）を使用する

---

### 6. `CGShading` の `extendStart`/`extendEnd` が無視される

**重大度**: 低
**ファイル**: `Sources/CGWebGPU/CGWebGPUContextRenderer.swift`

**問題の説明**:
- `CGShading` には `extendStart` と `extendEnd` プロパティがある
- WebGPU レンダラーはこれらの値を参照していない
- シェーディングの範囲外の描画動作が正しくない

**修正案**:
シェーディング描画時に `extendStart`/`extendEnd` を考慮する

---

### 7. `draw(_ image: CGImage, in rect: CGRect, byTiling: Bool)` で無限ループのリスク

**重大度**: 中
**ファイル**: `Sources/OpenCoreGraphics/Graphics/CGContext.swift`

**問題の説明**:
- 画像の幅または高さが 0 の場合、while ループが永遠に終わらない

**該当コード**:
```swift
public func draw(_ image: CGImage, in rect: CGRect, byTiling: Bool) {
    if byTiling {
        var x = rect.minX
        while x < rect.maxX {
            var y = rect.minY
            while y < rect.maxY {
                // ...
                y = y + CGFloat(image.height)  // image.height が 0 なら無限ループ
            }
            x = x + CGFloat(image.width)  // image.width が 0 なら無限ループ
        }
    }
}
```

**修正案**:
```swift
guard image.width > 0, image.height > 0 else { return }
```

---

### 8. `drawLinearGradient` / `drawRadialGradient` が未実装

**重大度**: 中
**ファイル**: `Sources/CGWebGPU/CGWebGPUContextRenderer.swift`

**問題の説明**:
- これらのメソッドは TODO コメントがあるだけで実装されていない
- `CGGradient` を使用したグラデーション描画ができない

**該当コード**:
```swift
public func drawLinearGradient(
    _ gradient: CGGradient,
    start: CGPoint,
    end: CGPoint,
    options: CGGradientDrawingOptions
) {
    // TODO: Implement gradient rendering with specialized shader
}
```

**修正案**:
`CGGradient` の色情報を使用してグラデーションを描画する実装を追加

---

### 9. `clear(rect:)` が未実装

**重大度**: 低
**ファイル**: `Sources/CGWebGPU/CGWebGPUContextRenderer.swift`

**問題の説明**:
- `clear` メソッドは TODO コメントがあるだけで実装されていない

**該当コード**:
```swift
public func clear(rect: CGRect) {
    // TODO: Implement clear with transparent color
}
```

---

### 10. `draw(image:in:)` が未実装

**重大度**: 中
**ファイル**: `Sources/CGWebGPU/CGWebGPUContextRenderer.swift`

**問題の説明**:
- 画像描画が未実装

**該当コード**:
```swift
public func draw(
    image: CGImage,
    in rect: CGRect,
    alpha: CGFloat,
    blendMode: CGBlendMode,
    interpolationQuality: CGInterpolationQuality
) {
    // TODO: Implement image rendering with texture sampling
}
```

---

## アーキテクチャ上の根本問題

### CGContext の二重性

現在の `CGContext` には矛盾した設計があります：

1. **ビットマップコンテキストとしての側面**:
   - `data` バッファを保持
   - `makeImage()` メソッドを提供
   - 初期化時にピクセルデータを割り当て

2. **描画コマンド記録器としての側面**:
   - すべての描画操作は `rendererDelegate` に委譲
   - `data` バッファには何も書き込まない

**結果**: ビットマップコンテキストとして使おうとすると機能しない

### 推奨される解決策

#### オプション A: ソフトウェアラスタライザーを追加
- `CGContext` に基本的なソフトウェア描画機能を実装
- `rendererDelegate` がない場合は `data` バッファに直接描画
- `makeImage()` が正しく動作するようになる

#### オプション B: 設計の明確化
- `CGContext` を純粋なコマンド記録器として再定義
- `data` バッファと `makeImage()` を削除または非推奨化
- ドキュメントで delegate パターンを明確に説明

#### オプション C: 両方をサポート
- `rendererDelegate` がある場合は委譲
- ない場合はソフトウェア描画にフォールバック

---

## 修正の優先順位

1. **高優先度** (機能が動作しない):
   - 問題 #1: `makeImage()` の問題（またはドキュメント化）
   - 問題 #2: クリッピングパスの問題
   - 問題 #4: CTM の一貫性

2. **中優先度** (部分的に動作しない):
   - 問題 #3: シャドウ
   - 問題 #5: blendMode
   - 問題 #7: 無限ループリスク
   - 問題 #8, #9, #10: 未実装メソッド

3. **低優先度** (軽微な問題):
   - 問題 #6: extendStart/extendEnd

---

## 関連ファイル

- `Sources/OpenCoreGraphics/Graphics/CGContext.swift`
- `Sources/OpenCoreGraphics/Graphics/CGContextRendererDelegate.swift`
- `Sources/OpenCoreGraphics/Graphics/CGPattern.swift`
- `Sources/OpenCoreGraphics/Graphics/CGShading.swift`
- `Sources/CGWebGPU/CGWebGPUContextRenderer.swift`
