# CGDataConsumer 修正依頼

## 概要

`CGDataConsumer`の`init?(data:)`イニシャライザで、書き込んだデータを外部から取得できない問題があります。

## 問題

### 現象

```swift
let mutableData = NSMutableData()
let consumer = CGDataConsumer(data: mutableData as Data)

// データを書き込む
consumer?.putBytes(buffer, count: 4)

// 元のNSMutableDataは空のまま
print(mutableData.length)  // → 0（期待値: 4）
```

### 原因

`CGDataConsumer.swift:98-100`:

```swift
public init?(data: Data = Data()) {
    self.consumerType = .data
    self.accumulatedData = data  // Dataは値型なのでコピーが作成される
}
```

`Data`は値型のため、渡されたデータのコピーが内部に保存されます。書き込みは内部の`accumulatedData`に行われますが、元のデータには反映されません。

## 影響

- `CGImageDestinationCreateWithDataConsumer`で作成したDestinationにエンコードしても、元のDataにデータが反映されない
- Apple's ImageIOとの動作の違い（ImageIOは`CFMutableData`の参照を保持する）

## 提案する修正

### 方法1: dataプロパティの追加（推奨）

書き込まれたデータを取得できるプロパティを追加:

```swift
/// Returns the accumulated data written to this consumer.
/// Only available for data-backed consumers.
public var data: Data? {
    switch consumerType {
    case .data, .url:
        return accumulatedData
    case .callback:
        return nil
    }
}
```

**メリット:**
- 既存のAPIを壊さない
- WASMでも動作する
- シンプルな変更

**使用例:**
```swift
let consumer = CGDataConsumer(data: Data())
consumer?.putBytes(buffer, count: 4)
let result = consumer?.data  // 書き込まれたデータを取得
```

### 方法2: NSMutableData対応（Apple互換）

```swift
private enum ConsumerType {
    case callback(info: UnsafeMutableRawPointer?, callbacks: CGDataConsumerCallbacks)
    case url(URL)
    case data
    case mutableData(NSMutableData)  // 追加
}

/// Creates a data consumer that writes to an NSMutableData object.
public init?(mutableData: NSMutableData) {
    self.consumerType = .mutableData(mutableData)
}

// putBytes内で分岐追加
case .mutableData(let mutableData):
    mutableData.append(buffer, length: count)
    return count
```

**メリット:**
- Apple's ImageIOと同じ動作
- 既存コードとの互換性

**デメリット:**
- WASMでNSMutableDataが使えるか要確認

## 推奨

**方法1（dataプロパティの追加）を推奨します。**

理由:
1. WASMでの動作が保証される
2. 既存APIを壊さない
3. 変更が最小限

## 関連ファイル

- `Sources/OpenCoreGraphics/Graphics/CGDataConsumer.swift`

## テストケース

修正後、以下のテストがパスすることを確認:

```swift
@Test func writeToConsumer() {
    let consumer = CGDataConsumer(data: Data())!
    let bytes: [UInt8] = [0x01, 0x02, 0x03, 0x04]
    bytes.withUnsafeBytes { buffer in
        consumer.putBytes(buffer.baseAddress, count: buffer.count)
    }
    #expect(consumer.data == Data([0x01, 0x02, 0x03, 0x04]))
}
```
