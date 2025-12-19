# CGWebGPU Internal Architecture

このドキュメントは、CGWebGPUモジュールの**内部実装設計**を記述します。
ここに記載される最適化機構は全て内部実装であり、公開APIではありません。

---

## レイヤー構造

```
┌─────────────────────────────────────────────────────────────────┐
│                         User Code                                │
│                   context.fill(rect)                            │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    OpenCoreGraphics                              │
│                                                                  │
│  責務:                                                           │
│  - CoreGraphics API互換                                         │
│  - 描画状態管理（色、線幅、変換行列など）                        │
│  - パス構築（CGPath, CGMutablePath）                            │
│  - 色空間管理（CGColorSpace, CGColor）                          │
│                                                                  │
│  このレイヤーは最適化を行わない（純粋なAPIレイヤー）             │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ CGContextRendererDelegate
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                       CGWebGPU                                   │
│                                                                  │
│  責務:                                                           │
│  - WebGPU APIを使用したレンダリング                              │
│  - GPU固有の最適化（本ドキュメントの対象）                       │
│                                                                  │
│  最適化は全てこのレイヤー内部に閉じる                            │
└─────────────────────────────────────────────────────────────────┘
```

---

## 公開API

CGWebGPUが公開するAPIは最小限です：

```swift
/// WebGPUベースのレンダラー
/// CGContextRendererDelegateを実装し、CGContextに接続して使用する
public final class CGWebGPUContextRenderer: CGContextStatefulRendererDelegate {

    // MARK: - 初期化

    /// レンダラーを作成
    public init(device: GPUDevice, textureFormat: GPUTextureFormat, ...)

    /// パイプラインを初期化（事前ウォームアップ）
    public func setup()

    // MARK: - 設定

    /// ビューポートサイズ
    public var viewportWidth: CGFloat
    public var viewportHeight: CGFloat

    /// レンダーターゲット
    public func setRenderTarget(_ textureView: GPUTextureView?)

    // MARK: - フレーム管理

    /// フレーム開始（BufferPoolのリングバッファを進める）
    public func beginFrame()

    // MARK: - CGContextRendererDelegate（自動的に呼ばれる）

    public func fill(path: CGPath, color: CGColor, ...)
    public func stroke(path: CGPath, color: CGColor, ...)
    public func draw(image: CGImage, in rect: CGRect, ...)
    public func clear(rect: CGRect)
    // ... 他のDelegate メソッド
}
```

**ユーザーが意識するのはこれだけです。** 内部最適化は透過的に適用されます。

---

## 内部アーキテクチャ

以下は全て `internal` または `private` であり、公開されません。

### 全体構造

```
CGWebGPUContextRenderer (public)
│
├── PipelineRegistry (internal)
│   └── パイプラインのキャッシュと管理
│
├── TextureManager (internal)
│   └── CGImageテクスチャの管理
│
├── GeometryCache (internal)
│   └── テッセレーション結果のキャッシュ
│
├── BufferPool (internal)
│   └── 頂点バッファの再利用
│
└── PathTessellator (internal)
    └── パスから頂点への変換
```

---

### 1. PipelineRegistry

パイプラインの作成とキャッシュ。

```swift
internal final class PipelineRegistry {

    /// パイプラインタイプ
    enum PipelineType: Hashable {
        case blend(CGBlendMode)      // 通常描画（ブレンドモード別）
        case clipped(CGBlendMode)    // クリッピング適用描画
        case stencilWrite            // ステンシル書き込み用
        case image                   // 画像描画用
        case pattern                 // パターン描画用
        case blurHorizontal          // 水平ブラー（シャドウ用）
        case blurVertical            // 垂直ブラー（シャドウ用）
        case shadowComposite         // シャドウ合成用
    }

    private var pipelines: [PipelineType: GPURenderPipeline] = [:]
    private var shaderModules: [String: GPUShaderModule] = [:]

    /// ブレンドモード用パイプライン取得
    func getPipeline(for mode: CGBlendMode) -> GPURenderPipeline?

    /// クリッピング用パイプライン取得
    func getClippedPipeline(for mode: CGBlendMode) -> GPURenderPipeline?

    /// 汎用パイプライン取得
    func getPipeline(_ type: PipelineType) -> GPURenderPipeline?

    /// 事前ウォームアップ（全パイプライン一括作成）
    func warmUp()
}
```

**設計意図:**
- パイプライン作成は高コスト → キャッシュで再利用
- 初回フレームのスタッター防止 → 事前ウォームアップ
- 12以上のブレンドモードをサポート

---

### 2. TextureManager

CGImageからGPUテクスチャへの変換と管理。

```swift
internal final class TextureManager {

    struct TextureEntry {
        let texture: GPUTexture
        let textureView: GPUTextureView
        let width: Int
        let height: Int
        var lastAccess: UInt64
        var memorySize: Int { width * height * 4 }  // RGBA8
    }

    private var cache: [ObjectIdentifier: TextureEntry] = [:]

    /// 最大キャッシュ数（デフォルト: 100）
    private let capacity: Int

    /// 最大メモリ使用量（デフォルト: 256MB）
    var maxMemoryUsage: Int

    /// 現在のメモリ使用量
    private(set) var totalMemoryUsage: Int

    /// テクスチャ取得（キャッシュから）
    func getTexture(for image: CGImage) -> GPUTextureView?

    /// テクスチャ取得（なければ作成）
    func getOrCreateTexture(for image: CGImage) -> GPUTextureView?

    /// キャッシュクリア
    func clear()
}
```

**設計意図:**
- テクスチャ作成・アップロードは高コスト → キャッシュ
- 数量制限とメモリ制限 → LRUエビクション
- ObjectIdentifierでCGImageを識別

---

### 3. GeometryCache

テッセレーション結果のキャッシュ。

```swift
internal final class GeometryCache {

    /// パスのハッシュ
    struct PathHash: Hashable {
        let value: Int
    }

    /// キャッシュエントリ
    struct CachedGeometry {
        let vertices: [Float]     // position + color (6 floats per vertex)
        let vertexCount: Int      // vertices.count / 6
        let bounds: CGRect
        let isFill: Bool
        var lastAccess: UInt64
    }

    private var cache: [PathHash: CachedGeometry] = [:]
    private var accessOrder: [PathHash] = []  // LRU順序

    /// 最大キャッシュ数（デフォルト: 500）
    private let capacity: Int

    /// 統計情報
    private(set) var hits: Int = 0
    private(set) var misses: Int = 0
    var hitRate: Double { /* hits / (hits + misses) */ }

    /// ハッシュ計算（パス要素 + 変換 + fill/stroke）
    func computeHash(path: CGPath, transform: CGAffineTransform, isFill: Bool) -> PathHash

    /// キャッシュから取得
    func get(_ hash: PathHash) -> CachedGeometry?

    /// キャッシュに保存
    func store(_ geometry: CachedGeometry, for hash: PathHash)

    /// キャッシュから取得 or テッセレート
    func getOrTessellate(
        path: CGPath,
        transform: CGAffineTransform,
        isFill: Bool,
        color: CGColor,
        tessellator: PathTessellator
    ) -> CachedGeometry?
}
```

**設計意図:**
- テッセレーションはCPU負荷が高い → 同じパスは再利用
- 静的UIでは初回のみテッセレーション
- ヒット率の統計でキャッシュ効果を測定可能

---

### 4. BufferPool

GPUバッファの再利用プール。

```swift
internal final class BufferPool {

    /// バッファアロケーション結果
    struct Allocation {
        let buffer: GPUBuffer
        let offset: UInt64
        let size: UInt64
    }

    /// 設定
    struct Configuration {
        var frameCount: Int = 3                    // リングバッファのフレーム数
        var initialBufferSize: Int = 1024 * 1024  // 初期1MB
        var maxBufferSize: Int = 64 * 1024 * 1024 // 最大64MB
        var growthFactor: Double = 2.0            // 拡張倍率
    }

    private var buffers: [GPUBuffer]
    private var writeOffsets: [UInt64]
    private var bufferSizes: [Int]
    private var currentFrame: Int = 0

    /// フレーム開始（リングバッファを進める）
    func advanceFrame()

    /// バッファ確保
    func acquire(size: Int) -> Allocation?

    /// データ書き込み付き確保
    func acquireAndWrite(data: [Float]) -> Allocation?

    /// 統計情報
    var currentFrameIndex: Int
    var allocationsThisFrame: Int
    var currentFrameUsage: (used: UInt64, capacity: Int)
    var totalMemoryAllocated: Int
}
```

**設計意図:**
- バッファ作成は高コスト → プールで再利用
- フレーム間の競合防止 → リングバッファ（3フレーム）
- バッファ不足時の自動拡張（最大64MB）

---

## データフロー

### 描画コマンドの処理

```
context.fill(path, color)
         │
         ▼
CGWebGPUContextRenderer.fill(path, color, ...)
         │
         ├─── PathTessellator.tessellateFill(path)
         │           └── パスを三角形に分割
         │
         ├─── BufferPool.acquireAndWrite(vertices)
         │           └── GPUバッファに書き込み（Allocation返却）
         │
         ├─── PipelineRegistry.getPipeline(for: blendMode)
         │           └── パイプライン取得（キャッシュ or 作成）
         │
         └─── GPU描画コマンド発行
                      │
                      ├── setPipeline
                      ├── setVertexBuffer(buffer, offset)
                      └── draw
```

### 画像描画

```
context.draw(image, in: rect)
         │
         ▼
CGWebGPUContextRenderer.draw(image, rect, ...)
         │
         ├─── TextureManager.getOrCreateTexture(image)
         │           │
         │           ├── hit  → キャッシュからテクスチャビュー取得
         │           └── miss → 作成 → アップロード → キャッシュ
         │
         ├─── 頂点生成（rect → quad vertices）
         │
         ├─── BufferPool.acquireAndWrite(vertices)
         │
         └─── GPU描画コマンド発行
```

### フレームライフサイクル

```
renderer.beginFrame()        // BufferPool.advanceFrame()
         │
         ├─── context.fill(...)
         ├─── context.stroke(...)
         ├─── context.draw(image, ...)
         │
         └─── renderer.present()
                      └─── CommandBufferをsubmit
```

---

## 将来の最適化（検討事項）

以下は現時点では実装しませんが、将来的に検討可能な最適化です：

### コマンドバッチング

```
現在: 描画ごとに即時submit
将来: フレーム内でバッチ化 → 1回のsubmit
```

### ステートソート

```
現在: 描画順 = 呼び出し順
将来: パイプラインでソート → ステート変更削減
```

### インスタンシング

```
現在: 同じ形状でも個別draw
将来: 同一形状をインスタンス化 → drawcall削減
```

### テクスチャアトラス

```
現在: 画像ごとに個別テクスチャ
将来: アトラスに統合 → バインドグループ切り替え削減
```

これらの最適化を追加しても、公開APIは変更されません。

---

## 設計原則

### 1. 透過性

最適化はユーザーから見えない。APIは変わらない。

```swift
// 最適化前も最適化後も同じコード
context.setFillColor(.red)
context.fill(rect)
```

### 2. 段階的適用

最適化は段階的に追加可能。基本機能が先。

```
Phase 1: 基本動作 ✅ 完了
Phase 2: キャッシュ導入 ✅ 完了
  - PipelineRegistry（パイプラインキャッシュ）
  - TextureManager（テクスチャキャッシュ）
  - BufferPool（頂点バッファプール）
  - GeometryCache（テッセレーションキャッシュ - 準備済み）
Phase 3: バッチング（将来）
Phase 4: 高度な最適化（将来）
```

### 3. 測定駆動

最適化は測定に基づいて行う。推測で最適化しない。

```
1. プロファイリングでボトルネック特定
2. 仮説を立てる
3. 最適化を実装
4. 効果を測定
5. 効果がなければ削除
```

---

## ファイル構成

```
Sources/CGWebGPU/
├── CGWebGPUContextRenderer.swift  # 公開API + メイン実装
├── Shaders.swift                   # WGSLシェーダー
├── Vertex.swift                    # 頂点構造体
├── PathTessellator.swift           # パステッセレーション
├── StrokeGenerator.swift           # ストローク生成
├── EarClipping.swift               # 三角形分割
│
├── Internal/                        # 内部実装（実装済み）
│   ├── PipelineRegistry.swift      # パイプライン管理
│   ├── TextureManager.swift        # テクスチャキャッシュ
│   ├── GeometryCache.swift         # ジオメトリキャッシュ
│   └── BufferPool.swift            # バッファプール
│
└── ARCHITECTURE.md                  # 本ドキュメント
```

---

## まとめ

- **公開API**: `CGWebGPUContextRenderer` のみ（`init`, `setup`, `beginFrame`, `setRenderTarget`, プロパティ）
- **内部最適化**: 全て非公開、透過的に適用
  - PipelineRegistry: パイプラインのキャッシュと事前ウォームアップ
  - TextureManager: CGImageテクスチャのLRUキャッシュ
  - BufferPool: 頂点バッファのリングバッファプール
  - GeometryCache: テッセレーション結果のキャッシュ（準備済み）
- **責務分離**: OpenCoreGraphicsはAPI、CGWebGPUはレンダリング
- **現在のフェーズ**: Phase 2（キャッシュ導入）完了
