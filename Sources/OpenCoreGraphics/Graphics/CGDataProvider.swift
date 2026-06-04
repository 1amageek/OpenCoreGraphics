//
//  CGDataProvider.swift
//  OpenCoreGraphics
//
//  Created by OpenCoreGraphics contributors.
//


import Foundation


// MARK: - Sequential Callbacks

/// A callback function that moves the current position in the data stream back to the beginning.
public typealias CGDataProviderRewindCallback = (UnsafeMutableRawPointer?) -> Void

/// A callback function that copies from a provider data stream into a Core Graphics buffer.
public typealias CGDataProviderGetBytesCallback = (
    UnsafeMutableRawPointer?,       // info
    UnsafeMutableRawPointer?,       // buffer
    Int                             // count
) -> Int

/// A callback function that advances the current position in the data stream supplied by the provider.
public typealias CGDataProviderSkipForwardCallback = (
    UnsafeMutableRawPointer?,       // info
    Int64                           // count
) -> Int64

/// A callback function that releases any private data or resources associated with the data provider.
public typealias CGDataProviderReleaseInfoCallback = (UnsafeMutableRawPointer?) -> Void

/// Defines a structure containing pointers to client-defined callback functions
/// that manage the sending of data for a sequential-access data provider.
public struct CGDataProviderSequentialCallbacks: @unchecked Sendable {
    /// The version of the structure. Set to 0.
    public var version: UInt32

    /// A pointer to the callback function that copies data from the provider.
    public var getBytes: CGDataProviderGetBytesCallback?

    /// A pointer to the callback function that advances the current position.
    public var skipForward: CGDataProviderSkipForwardCallback?

    /// A pointer to the callback function that moves the position back to the beginning.
    public var rewind: CGDataProviderRewindCallback?

    /// A pointer to the callback function that releases private data.
    public var releaseInfo: CGDataProviderReleaseInfoCallback?

    /// Creates an empty sequential callbacks structure.
    public init() {
        self.version = 0
        self.getBytes = nil
        self.skipForward = nil
        self.rewind = nil
        self.releaseInfo = nil
    }

    /// Creates sequential callbacks.
    public init(version: UInt32 = 0,
                getBytes: CGDataProviderGetBytesCallback?,
                skipForward: CGDataProviderSkipForwardCallback?,
                rewind: CGDataProviderRewindCallback?,
                releaseInfo: CGDataProviderReleaseInfoCallback?) {
        self.version = version
        self.getBytes = getBytes
        self.skipForward = skipForward
        self.rewind = rewind
        self.releaseInfo = releaseInfo
    }
}

// MARK: - Direct Access Callbacks

/// A callback function that returns a generic pointer to the provider data.
public typealias CGDataProviderGetBytePointerCallback = (UnsafeMutableRawPointer?) -> UnsafeRawPointer?

/// A callback function that copies data from the provider into a Core Graphics buffer.
public typealias CGDataProviderGetBytesAtPositionCallback = (
    UnsafeMutableRawPointer?,       // info
    UnsafeMutableRawPointer?,       // buffer
    Int64,                          // position
    Int                             // count
) -> Int

/// A callback function that releases the pointer Core Graphics obtained by calling CGDataProviderGetBytePointerCallback.
public typealias CGDataProviderReleaseBytePointerCallback = (
    UnsafeMutableRawPointer?,       // info
    UnsafeRawPointer?               // pointer
) -> Void

/// A callback function that releases data you supply to the data provider.
public typealias CGDataProviderReleaseDataCallback = (
    UnsafeMutableRawPointer?,       // info
    UnsafeRawPointer?,              // data
    Int                             // size
) -> Void

/// Defines pointers to client-defined callback functions that manage the sending
/// of data for a direct-access data provider.
public struct CGDataProviderDirectCallbacks: @unchecked Sendable {
    /// The version of the structure. Set to 0.
    public var version: UInt32

    /// A pointer to the callback function that returns a pointer to the provider data.
    public var getBytePointer: CGDataProviderGetBytePointerCallback?

    /// A pointer to the callback function that releases the byte pointer.
    public var releaseBytePointer: CGDataProviderReleaseBytePointerCallback?

    /// A pointer to the callback function that copies data from the provider.
    public var getBytesAtPosition: CGDataProviderGetBytesAtPositionCallback?

    /// A pointer to the callback function that releases private data.
    public var releaseInfo: CGDataProviderReleaseInfoCallback?

    /// Creates an empty direct callbacks structure.
    public init() {
        self.version = 0
        self.getBytePointer = nil
        self.releaseBytePointer = nil
        self.getBytesAtPosition = nil
        self.releaseInfo = nil
    }

    /// Creates direct callbacks.
    public init(version: UInt32 = 0,
                getBytePointer: CGDataProviderGetBytePointerCallback?,
                releaseBytePointer: CGDataProviderReleaseBytePointerCallback?,
                getBytesAtPosition: CGDataProviderGetBytesAtPositionCallback?,
                releaseInfo: CGDataProviderReleaseInfoCallback?) {
        self.version = version
        self.getBytePointer = getBytePointer
        self.releaseBytePointer = releaseBytePointer
        self.getBytesAtPosition = getBytesAtPosition
        self.releaseInfo = releaseInfo
    }
}

// MARK: - CGDataProvider

/// An abstraction for data-reading tasks that eliminates the need to manage a raw memory buffer.
public class CGDataProvider: @unchecked Sendable {

    /// The type of data provider.
    private enum ProviderType {
        case direct(Data)
        case sequential(info: UnsafeMutableRawPointer?, callbacks: CGDataProviderSequentialCallbacks)
        case directCallbacks(info: UnsafeMutableRawPointer?, size: Int64, callbacks: CGDataProviderDirectCallbacks)
    }

    /// A captured `releaseData` callback plus the caller-owned buffer it references.
    ///
    /// Stored verbatim at init time so that `deinit` can honour Apple's contract of
    /// firing the callback exactly once when the provider is torn down — caller
    /// ownership of the buffer is only released through this callback.
    private struct DataReleaseHandle {
        let info: UnsafeMutableRawPointer?
        let data: UnsafeRawPointer
        let size: Int
        let callback: CGDataProviderReleaseDataCallback
    }

    /// The provider type.
    private let providerType: ProviderType

    /// Stored release callback for the `dataInfo:data:size:releaseData:` initializer.
    private let directReleaseHandle: DataReleaseHandle?

    /// User-provided info pointer (for callback-based providers).
    public var info: UnsafeMutableRawPointer? {
        switch providerType {
        case .direct:
            return directReleaseHandle?.info
        case .sequential(let info, _):
            return info
        case .directCallbacks(let info, _, _):
            return info
        }
    }

    // MARK: - Direct Data Initializers

    /// Creates a data provider from data.
    public init(data: Data) {
        self.providerType = .direct(data)
        self.directReleaseHandle = nil
    }

    /// Creates a data provider from a URL.
    public init?(url: URL) {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            print("CGDataProvider: failed to read \(url): \(error)")
            return nil
        }
        self.providerType = .direct(data)
        self.directReleaseHandle = nil
    }

    /// Creates a data provider from a file path.
    public init?(filename: String) {
        let url = URL(fileURLWithPath: filename)
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            print("CGDataProvider: failed to read \(filename): \(error)")
            return nil
        }
        self.providerType = .direct(data)
        self.directReleaseHandle = nil
    }

    /// Creates a data provider from a file path (C string).
    public init?(filename: UnsafePointer<CChar>) {
        let path = String(cString: filename)
        let url = URL(fileURLWithPath: path)
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            print("CGDataProvider: failed to read \(path): \(error)")
            return nil
        }
        self.providerType = .direct(data)
        self.directReleaseHandle = nil
    }

    /// Creates a direct-access data provider that uses data your program supplies.
    ///
    /// The caller retains ownership of `data`; the `releaseData` callback, if supplied,
    /// is invoked exactly once when this provider is deallocated so the caller can free
    /// the buffer. The buffer bytes are snapshotted into an internal `Data` copy so
    /// readers can continue to access the contents through `data` even after
    /// deallocation of the original buffer.
    public init?(dataInfo: UnsafeMutableRawPointer?,
                 data: UnsafeRawPointer,
                 size: Int,
                 releaseData: CGDataProviderReleaseDataCallback?) {
        guard size >= 0 else { return nil }
        let buffer = UnsafeBufferPointer(start: data.assumingMemoryBound(to: UInt8.self), count: size)
        let dataCopy = Data(buffer: buffer)
        self.providerType = .direct(dataCopy)
        if let releaseData {
            self.directReleaseHandle = DataReleaseHandle(
                info: dataInfo,
                data: data,
                size: size,
                callback: releaseData
            )
        } else {
            self.directReleaseHandle = nil
        }
    }

    // MARK: - Sequential Access Initializer

    /// Creates a sequential-access data provider.
    public init?(sequentialInfo: UnsafeMutableRawPointer?,
                 callbacks: UnsafePointer<CGDataProviderSequentialCallbacks>) {
        guard callbacks.pointee.getBytes != nil else { return nil }
        self.providerType = .sequential(info: sequentialInfo, callbacks: callbacks.pointee)
        self.directReleaseHandle = nil
    }

    // MARK: - Direct Access Callback Initializer

    /// Creates a direct-access data provider.
    public init?(directInfo: UnsafeMutableRawPointer?,
                 size: Int64,
                 callbacks: UnsafePointer<CGDataProviderDirectCallbacks>) {
        guard size >= 0 else { return nil }
        let cbks = callbacks.pointee
        guard cbks.getBytePointer != nil || cbks.getBytesAtPosition != nil else { return nil }
        self.providerType = .directCallbacks(info: directInfo, size: size, callbacks: cbks)
        self.directReleaseHandle = nil
    }

    deinit {
        if let handle = directReleaseHandle {
            handle.callback(handle.info, handle.data, handle.size)
        }
        switch providerType {
        case .direct:
            break
        case .sequential(let info, let callbacks):
            callbacks.releaseInfo?(info)
        case .directCallbacks(let info, _, let callbacks):
            callbacks.releaseInfo?(info)
        }
    }

    // MARK: - Properties

    /// Returns a snapshot of the underlying data as a Swift `Data` value.
    internal func copyData() -> Data? {
        switch providerType {
        case .direct(let data):
            return data
        case .sequential(let info, let callbacks):
            return _drainSequentialProvider(info: info, callbacks: callbacks)
        case .directCallbacks(let info, let size, let callbacks):
            return _drainDirectCallbackProvider(info: info, size: size, callbacks: callbacks)
        }
    }

    /// Returns a copy of the provider's data.
    public var data: Data? {
        copyData()
    }

    /// The number of bytes of data.
    public var size: Int {
        switch providerType {
        case .direct(let data):
            return data.count
        case .sequential:
            return 0 // Unknown for sequential
        case .directCallbacks(_, let size, _):
            return Int(size)
        }
    }

    // MARK: - Callback Drainers

    private func _drainDirectCallbackProvider(info: UnsafeMutableRawPointer?,
                                              size: Int64,
                                              callbacks: CGDataProviderDirectCallbacks) -> Data? {
        guard size <= Int64(Int.max) else { return nil }
        let byteCount = Int(size)
        guard byteCount > 0 else { return Data() }

        if let getBytePointer = callbacks.getBytePointer,
           let basePointer = getBytePointer(info) {
            let buffer = UnsafeBufferPointer(
                start: basePointer.assumingMemoryBound(to: UInt8.self),
                count: byteCount
            )
            let copy = Data(buffer: buffer)
            callbacks.releaseBytePointer?(info, basePointer)
            return copy
        }

        guard let getBytesAt = callbacks.getBytesAtPosition else { return nil }
        var buffer = [UInt8](repeating: 0, count: byteCount)
        let read = buffer.withUnsafeMutableBufferPointer { raw -> Int in
            guard let base = raw.baseAddress else { return 0 }
            return getBytesAt(info, UnsafeMutableRawPointer(base), 0, byteCount)
        }
        guard read == byteCount else { return nil }
        return Data(buffer)
    }

    private func _drainSequentialProvider(info: UnsafeMutableRawPointer?,
                                          callbacks: CGDataProviderSequentialCallbacks) -> Data? {
        guard let getBytes = callbacks.getBytes else { return nil }
        callbacks.rewind?(info)
        var accumulated = Data()
        let chunkSize = 4096
        var chunk = [UInt8](repeating: 0, count: chunkSize)
        while true {
            let read = chunk.withUnsafeMutableBufferPointer { raw -> Int in
                guard let base = raw.baseAddress else { return 0 }
                return getBytes(info, UnsafeMutableRawPointer(base), chunkSize)
            }
            if read <= 0 { break }
            accumulated.append(contentsOf: chunk.prefix(read))
            if read < chunkSize { break }
        }
        return accumulated
    }

    // MARK: - Type ID

    /// Returns the Core Foundation type identifier for data providers.
    public class var typeID: UInt {
        return 0 // Placeholder
    }
}

// MARK: - Equatable

extension CGDataProvider: Equatable {
    public static func == (lhs: CGDataProvider, rhs: CGDataProvider) -> Bool {
        return lhs === rhs
    }
}

// MARK: - Hashable

extension CGDataProvider: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}
