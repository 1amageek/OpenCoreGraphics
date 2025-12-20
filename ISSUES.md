# OpenCoreGraphics - 既知の問題と解決状況

このドキュメントは、プロジェクトで発見された問題とその解決状況をまとめたものです。

---

## 重大度の定義

- **高**: 機能が全く動作しない、またはクラッシュの可能性がある
- **中**: 機能が部分的に動作しない、または期待と異なる動作をする
- **低**: 軽微な問題、または将来的な改善が望ましい

---

## 解決済みの問題

### #1 `makeImage()` が常に空の画像を返す
**状態**: 修正済み

delegate パターンにより、`makeImage()` は内部 bitmap バッファを返すだけでした。

**解決方法**:
1. `CGContext.makeImageAsync()` を追加 - 非同期で delegate の `makeImage()` を呼び出す
2. `CGContextRendererDelegate.makeImage(width:height:colorSpace:)` を追加
3. `CGWebGPUContextRenderer` に GPU readback を実装
4. 外部レンダーターゲットがない場合、自動的に内部テクスチャに描画

**使用例**:
```swift
// WebGPU 初期化
try await setupGraphicsContext()

// CGContext を作成（レンダラーは内部で自動設定）
let context = CGContext(...)!

// 描画
context.setFillColor(.red)
context.fill(CGRect(x: 0, y: 0, width: 100, height: 100))

// GPU からの読み取り
let image = await context.makeImageAsync()
```

---

### #2 クリッピングパス (`clipPath`) が機能しない
**状態**: 修正済み

クリッピングパスは `CGDrawingState` 経由で delegate に渡されるようになりました：
- `CGDrawingState.clipPaths` にすべてのアクティブなクリップパスが含まれる
- `CGContextStatefulRendererDelegate` のメソッドが `state` パラメータを受け取る
- レンダラーはステンシルバッファを使用してクリッピングを適用可能

---

### #3 シャドウが機能しない
**状態**: 修正済み

シャドウ情報が `CGDrawingState` に含まれるようになりました：
- `shadowOffset`, `shadowBlur`, `shadowColor` プロパティ
- 便利な `hasShadow` 計算プロパティ
- すべての stateful delegate メソッドがシャドウ情報を受け取る

---

### #4 CTM（Current Transformation Matrix）が一貫して適用されない
**状態**: 修正済み

CTM が以下の操作に適用されるようになりました：
- `draw(image:in:)` - rect が CTM で変換される
- `drawLinearGradient` - start/end ポイントが変換される
- `drawRadialGradient` - center と radii が変換される

---

### #5 `blendMode` が WebGPU レンダラーで無視される
**状態**: 修正済み

WebGPU レンダラーが 12 種類以上のブレンドモードをサポート：
- Porter-Duff: normal, copy, sourceIn, sourceOut, sourceAtop, destinationOver, destinationIn, destinationOut, destinationAtop, xor
- Additive: plusLighter
- Min/Max: darken, lighten

カスタムシェーダーが必要なモード（multiply, screen, overlay など）は normal ブレンディングにフォールバック。

---

### #6 `CGShading` の `extendStart`/`extendEnd` が無視される
**状態**: 修正済み

`CGShading.extendStart` と `extendEnd` プロパティが処理されるようになりました：
- Axial shading: 開始点より前と終了点より後に色を拡張
- Radial shading: extendStart で中心円を塗りつぶし、extendEnd で外側リングを拡張

---

### #7 `draw(_ image: CGImage, in rect: CGRect, byTiling: Bool)` で無限ループのリスク
**状態**: 修正済み

`CGContext.draw(_ image:in:)` の line 1129-1130 にガードを追加：
```swift
guard image.width > 0, image.height > 0 else { return }
```

---

### #8 `drawLinearGradient` / `drawRadialGradient` が未実装
**状態**: 修正済み

両方のグラデーションタイプが実装されました：
- `drawLinearGradient`: グラデーション軸に沿ったクワッドストリップを頂点カラー補間で作成
- `drawRadialGradient`: 同心円状のリングセグメントをカラー補間で作成
- 両方とも `drawsBeforeStartLocation` と `drawsAfterEndLocation` オプションを処理

---

### #9 `clear(rect:)` が未実装
**状態**: 修正済み

copy ブレンドモードで透明色を使用して実装：
```swift
let transparentColor = CGColor(red: 0, green: 0, blue: 0, alpha: 0)
```

---

### #10 `draw(image:in:)` が未実装
**状態**: 修正済み

テクスチャベースの画像レンダリングを実装：
- CGImage データから GPUTexture への変換
- テクスチャ/サンプラー用のバインドグループ管理
- テクスチャ付きクワッド用の imagePipeline
- 補間品質に応じたサンプラー設定

---

### #11 クリッピングが未実装
**状態**: 修正済み

ステンシルバッファベースのクリッピングを実装：
- depth24plusStencil8 形式のステンシルテクスチャ
- クリップパスをステンシルバッファに書き込むパイプライン
- ステンシルテスト付きのレンダリングパイプライン
- 複数のクリップパスの交差をサポート

---

### #12 シャドウが未実装
**状態**: 修正済み

マルチパス Gaussian ブラーシャドウを実装：
- 分離可能 Gaussian ブラー（水平パス + 垂直パス）
- シャドウマスクテクスチャへのレンダリング
- シャドウコンポジットシェーダー（オフセットとカラー適用）
- shadowOffset, shadowBlur, shadowColor のサポート

---

### #13 パターンレンダリングが未実装
**状態**: 修正済み

GPU ベースのパターンタイリングを実装：
- patternTiling シェーダー（チェッカーボード、ストライプ、ドット）
- xStep/yStep に基づく手続き的タイリング
- カラードパターンとアンカラードパターンのサポート
- パターンフェーズとバウンディングボックスの適用

---

### #14 `makeImage()` GPU readback が未実装
**状態**: 修正済み

GPU readback を実装：
- 内部レンダーテクスチャ（copySrc usage 付き）
- ステージングバッファへのテクスチャコピー
- 非同期バッファマッピングとピクセルデータ読み取り
- BGRA → RGBA 変換と CGImage 作成
- 外部ターゲット未設定時の自動フォールバック
- `CGContext.makeImageAsync()` 非同期 API

## 今後の改善点

### パフォーマンス最適化
- 頂点バッファのプーリング
- ドローコールのバッチング
- テクスチャアトラスの活用

### 追加機能
- フォントレンダリング (CGFont)
- PDF 出力 (CGPDFContext)
- レイヤー機能の完全実装 (CGLayer)

---

## 関連ファイル

- `Sources/OpenCoreGraphics/Graphics/CGContext.swift`
- `Sources/OpenCoreGraphics/Graphics/CGContextRendererDelegate.swift`
- `Sources/OpenCoreGraphics/Graphics/CGPattern.swift`
- `Sources/OpenCoreGraphics/Graphics/CGShading.swift`
- `Sources/CGWebGPU/CGWebGPUContextRenderer.swift`
- `Sources/CGWebGPU/Shaders.swift`
