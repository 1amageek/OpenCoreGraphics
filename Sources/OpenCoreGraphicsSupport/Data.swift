#if hasFeature(Embedded)
import COpenCoreGraphicsSupport

public struct Data: RandomAccessCollection, MutableCollection, RangeReplaceableCollection, Equatable, Hashable, Sendable {
    public typealias Element = UInt8
    public typealias Index = Int

    private var storage: [UInt8]

    public init() {
        storage = []
    }

    public init<S: Sequence>(_ elements: S) where S.Element == UInt8 {
        storage = Array(elements)
    }

    public init(count: Int) {
        storage = [UInt8](repeating: 0, count: count)
    }

    public init(capacity: Int) {
        storage = []
        storage.reserveCapacity(capacity)
    }

    public init(repeating repeatedValue: UInt8, count: Int) {
        storage = [UInt8](repeating: repeatedValue, count: count)
    }

    public init(bytes: UnsafeRawPointer, count: Int) {
        let buffer = UnsafeRawBufferPointer(start: bytes, count: count)
        storage = Array(buffer)
    }

    public init<SourceType>(buffer: UnsafeBufferPointer<SourceType>) {
        let rawBuffer = UnsafeRawBufferPointer(buffer)
        storage = Array(rawBuffer)
    }

    public init<SourceType>(_ buffer: UnsafeBufferPointer<SourceType>) {
        self.init(buffer: buffer)
    }

    public init(contentsOf url: URL) throws {
        var bytes: UnsafeMutablePointer<UInt8>?
        var count = 0
        let result = url.path.withCString { path in
            ocg_read_file(path, &bytes, &count)
        }
        guard result == 0 else {
            throw DataIOError.readFailed(path: url.path, code: result)
        }
        guard let bytes else {
            storage = []
            return
        }
        defer { ocg_release_bytes(bytes) }
        // File I/O transfers ownership from C; materialization into the Swift CoW
        // owner is required so the C allocation can be released at this boundary.
        storage = Array(UnsafeBufferPointer(start: bytes, count: count))
    }

    public var startIndex: Int { storage.startIndex }
    public var endIndex: Int { storage.endIndex }

    public func index(after index: Int) -> Int {
        storage.index(after: index)
    }

    public func index(before index: Int) -> Int {
        storage.index(before: index)
    }

    public subscript(position: Int) -> UInt8 {
        get { storage[position] }
        set { storage[position] = newValue }
    }

    public mutating func replaceSubrange<C: Collection>(
        _ subrange: Range<Int>,
        with newElements: C
    ) where C.Element == UInt8 {
        storage.replaceSubrange(subrange, with: newElements)
    }

    public mutating func append(_ byte: UInt8) {
        storage.append(byte)
    }

    public mutating func append(_ data: Data) {
        storage.append(contentsOf: data.storage)
    }

    public mutating func append<C: Collection>(_ bytes: C) where C.Element == UInt8 {
        storage.append(contentsOf: bytes)
    }

    public mutating func append<S: Sequence>(contentsOf bytes: S) where S.Element == UInt8 {
        storage.append(contentsOf: bytes)
    }

    public mutating func reserveCapacity(_ minimumCapacity: Int) {
        storage.reserveCapacity(minimumCapacity)
    }

    public func withUnsafeBytes<Result>(
        _ body: (UnsafeRawBufferPointer) throws -> Result
    ) rethrows -> Result {
        try storage.withUnsafeBytes(body)
    }

    public mutating func withUnsafeMutableBytes<Result>(
        _ body: (UnsafeMutableRawBufferPointer) throws -> Result
    ) rethrows -> Result {
        try storage.withUnsafeMutableBytes(body)
    }

    public func write(to url: URL) throws {
        let result = storage.withUnsafeBytes { buffer in
            url.path.withCString { path in
                ocg_write_file(
                    path,
                    buffer.baseAddress?.assumingMemoryBound(to: UInt8.self),
                    buffer.count
                )
            }
        }
        guard result == 0 else {
            throw DataIOError.writeFailed(path: url.path, code: result)
        }
    }
}
#endif
