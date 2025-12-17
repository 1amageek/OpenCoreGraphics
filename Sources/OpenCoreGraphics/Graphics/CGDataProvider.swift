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

    /// The provider type.
    private let providerType: ProviderType

    /// User-provided info pointer (for callback-based providers).
    public var info: UnsafeMutableRawPointer? {
        switch providerType {
        case .direct:
            return nil
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
    }

    /// Creates a data provider from a URL.
    public init?(url: URL) {
        guard let data = try? Data(contentsOf: url) else { return nil }
        self.providerType = .direct(data)
    }

    /// Creates a data provider from a file path.
    public init?(filename: String) {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: filename)) else { return nil }
        self.providerType = .direct(data)
    }

    /// Creates a data provider from a file path (C string).
    public init?(filename: UnsafePointer<CChar>) {
        let path = String(cString: filename)
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return nil }
        self.providerType = .direct(data)
    }

    /// Creates a direct-access data provider that uses data your program supplies.
    public init?(dataInfo: UnsafeMutableRawPointer?,
                 data: UnsafeRawPointer,
                 size: Int,
                 releaseData: CGDataProviderReleaseDataCallback?) {
        let buffer = UnsafeBufferPointer(start: data.assumingMemoryBound(to: UInt8.self), count: size)
        let dataCopy = Data(buffer: buffer)
        self.providerType = .direct(dataCopy)
        // Note: In a full implementation, we would store releaseData and call it on deinit
    }

    // MARK: - Sequential Access Initializer

    /// Creates a sequential-access data provider.
    public init?(sequentialInfo: UnsafeMutableRawPointer?,
                 callbacks: UnsafePointer<CGDataProviderSequentialCallbacks>) {
        guard callbacks.pointee.getBytes != nil else { return nil }
        self.providerType = .sequential(info: sequentialInfo, callbacks: callbacks.pointee)
    }

    // MARK: - Direct Access Callback Initializer

    /// Creates a direct-access data provider.
    public init?(directInfo: UnsafeMutableRawPointer?,
                 size: Int64,
                 callbacks: UnsafePointer<CGDataProviderDirectCallbacks>) {
        self.providerType = .directCallbacks(info: directInfo, size: size, callbacks: callbacks.pointee)
    }

    deinit {
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

    /// The underlying data.
    public var data: Data? {
        switch providerType {
        case .direct(let data):
            return data
        case .sequential, .directCallbacks:
            // Would need to read all data from callbacks
            return nil
        }
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

