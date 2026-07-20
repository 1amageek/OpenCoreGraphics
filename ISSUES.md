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

### #3 シャドウ情報がレンダラーへ渡らない
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

### #11 パスクリッピングが未実装
**状態**: 修正済み

ステンシルバッファベースのクリッピングを実装：
- depth24plusStencil8 形式のステンシルテクスチャ
- クリップパスをステンシルバッファに書き込むパイプライン
- ステンシルテスト付きのレンダリングパイプライン
- 複数のクリップパスの交差をサポート

画像マスクによる連続 alpha クリッピングも実装済みであり、逆 alpha / DeviceGray alpha / decode / 補間 / 複数マスク合成を画素テストで検証する。

---

### #12 パス形状と画像 alpha のシャドウが未実装
**状態**: 修正済み

マルチパス Gaussian ブラーシャドウを実装：
- 分離可能 Gaussian ブラー（水平パス + 垂直パス）
- シャドウマスクテクスチャへのレンダリング
- シャドウコンポジットシェーダー（オフセットとカラー適用）
- shadowOffset, shadowBlur, shadowColor のサポート
- 画像 texture の alpha を shadow mask に描画し、透明画素が影を生成しないことをブラウザ画素 readback で検証
- DeviceGray の shadow color を DeviceRGB に変換し、成分数の誤解釈を防止

### #13 HDR tone mapping と統計 API が実処理に未接続
**状態**: 修正済み

- `CGToneMapping` を現行 SDK の case / raw value に修正
- Linear / sRGB / PQ / HLG の transfer function を復号
- reference-white / ITU / EXR / none の tone mapping と option 検証を実装
- `CGContext.draw(_:in:by:options:)` と通常描画の `contentToneMappingInfo` 経路を接続
- `copyWithCalculatedHDRStats()`、最大輝度、平均輝度を実画素から計算
- native の Apple 実測画素比較と Chromium WebGPU readback で検証

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

### 正確性に関わる未解決項目

- `CGContext.clip(to:mask:)`: image mask の逆 alpha、DeviceGray の通常 alpha、decode、補間、複数 mask の積算を実装済み。path・gradient・shading・image・layer・pattern の WebGPU pipeline に連続値を適用し、ブラウザ画素 readback で検証済み
- `CGPattern`: callback を独立した GPU context の cell texture へ描画し、matrix / phase / step、colored / uncolored、path clip、image-mask clip を反映する tiling を実装済み。手続き的 checkerboard と非互換な `renderCell*` API は削除済み
- ICC: profile data の保持だけで、profile に基づく色変換は未実装
- PDF: package の責務境界上、parser / writer / renderer は実装していない

### パフォーマンス最適化
- 頂点バッファのプーリング
- ドローコールのバッチング
- テクスチャアトラスの活用

### 追加機能
- TrueType `glyf` の単純・複合 glyph 描画は実装済み。CFF/CFF2 と variation outline は未実装
- PDF 出力 (CGPDFContext)
- CGLayer の WASM GPU texture 直接合成は実装済み。全描画意味論との同等性検証は継続する

---

## 関連ファイル

- `Sources/OpenCoreGraphics/Graphics/CGContext.swift`
- `Sources/OpenCoreGraphics/Graphics/CGContextRendererDelegate.swift`
- `Sources/OpenCoreGraphics/Graphics/CGPattern.swift`
- `Sources/OpenCoreGraphics/Graphics/CGShading.swift`
- `Sources/OpenCoreGraphics/Rendering/WebGPU/CGWebGPUContextRenderer.swift`
- `Sources/OpenCoreGraphics/Rendering/WebGPU/Shaders.swift`
