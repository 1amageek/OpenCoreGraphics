//
//  CGRenderingBufferProvider.swift
//  OpenCoreGraphics
//
//  Created by OpenCoreGraphics contributors.
//

import Foundation


/// A class that provides rendering buffers for graphics operations.
public final class CGRenderingBufferProvider: Hashable, Equatable, @unchecked Sendable {

    // MARK: - Info Protocol

    /// A protocol that provides information about a rendering buffer.
    public protocol Info: Sendable {
        /// The width of the buffer in pixels.
        var width: Int { get }

        /// The height of the buffer in pixels.
        var height: Int { get }

        /// The bytes per row of the buffer.
        var bytesPerRow: Int { get }

        /// The pixel format of the buffer.
        var pixelFormat: UInt32 { get }

        /// The color space of the buffer.
        var colorSpace: CGColorSpace? { get }

        /// The bitmap info for the buffer.
        var bitmapInfo: CGBitmapInfo { get }
    }

    // MARK: - Properties

    /// The underlying buffer data.
    private let buffer: UnsafeMutableRawPointer?

    /// The width of the buffer.
    public let width: Int

    /// The height of the buffer.
    public let height: Int

    /// The bytes per row.
    public let bytesPerRow: Int

    /// The pixel format.
    public let pixelFormat: UInt32

    /// The color space.
    public let colorSpace: CGColorSpace?

    /// The bitmap info.
    public let bitmapInfo: CGBitmapInfo

    /// The total byte count of the buffer.
    public var byteCount: Int {
        return bytesPerRow * height
    }

    // MARK: - Initializers

    /// Creates a rendering buffer provider with the specified dimensions and format.
    public init?(
        width: Int,
        height: Int,
        bytesPerRow: Int,
        pixelFormat: UInt32,
        colorSpace: CGColorSpace?,
        bitmapInfo: CGBitmapInfo = []
    ) {
        guard width > 0, height > 0, bytesPerRow > 0 else { return nil }

        self.width = width
        self.height = height
        self.bytesPerRow = bytesPerRow
        self.pixelFormat = pixelFormat
        self.colorSpace = colorSpace
        self.bitmapInfo = bitmapInfo

        let totalBytes = bytesPerRow * height
        self.buffer = UnsafeMutableRawPointer.allocate(byteCount: totalBytes, alignment: MemoryLayout<UInt8>.alignment)
        self.buffer?.initializeMemory(as: UInt8.self, repeating: 0, count: totalBytes)
    }

    /// Creates a rendering buffer provider from an Info conforming type.
    public convenience init?(info: some Info) {
        self.init(
            width: info.width,
            height: info.height,
            bytesPerRow: info.bytesPerRow,
            pixelFormat: info.pixelFormat,
            colorSpace: info.colorSpace,
            bitmapInfo: info.bitmapInfo
        )
    }

    /// Creates a rendering buffer provider from bitmap parameters.
    public convenience init?(parameters: CGBitmapParameters) {
        let bytesPerRow = parameters.bytesPerRow > 0 ? parameters.bytesPerRow : (parameters.width * parameters.bitsPerPixel / 8)
        self.init(
            width: parameters.width,
            height: parameters.height,
            bytesPerRow: bytesPerRow,
            pixelFormat: parameters.bitmapInfo.rawValue,
            colorSpace: parameters.colorSpace,
            bitmapInfo: parameters.bitmapInfo
        )
    }

    deinit {
        buffer?.deallocate()
    }

    // MARK: - Buffer Access

    /// Returns a pointer to the buffer data.
    public var data: UnsafeMutableRawPointer? {
        return buffer
    }

    /// Provides access to the buffer data with a closure.
    /// - Parameter body: A closure that takes an unsafe mutable raw buffer pointer.
    /// - Returns: The result of the closure.
    public func withUnsafeMutableBytes<R>(_ body: (UnsafeMutableRawBufferPointer) throws -> R) rethrows -> R {
        let bufferPointer = UnsafeMutableRawBufferPointer(start: buffer, count: byteCount)
        return try body(bufferPointer)
    }

    /// Provides read-only access to the buffer data with a closure.
    /// - Parameter body: A closure that takes an unsafe raw buffer pointer.
    /// - Returns: The result of the closure.
    public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
        let bufferPointer = UnsafeRawBufferPointer(start: buffer, count: byteCount)
        return try body(bufferPointer)
    }

    // MARK: - Equatable

    public static func == (lhs: CGRenderingBufferProvider, rhs: CGRenderingBufferProvider) -> Bool {
        return lhs === rhs
    }

    // MARK: - Hashable

    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}

// MARK: - CGRenderingBufferProvider.Info Default Implementation

extension CGRenderingBufferProvider: CGRenderingBufferProvider.Info {
    // CGRenderingBufferProvider itself conforms to its own Info protocol
}

