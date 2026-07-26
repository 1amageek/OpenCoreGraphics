//
//  WebGPUUploadStaging.swift
//  OpenCoreGraphics
//
//  Reusable JavaScript typed-array storage for WebGPU uploads.
//

#if arch(wasm32)
import Foundation
@_spi(JSObject_id) import JavaScriptKit
import _CJavaScriptKit

/// Owns JavaScript typed arrays used at synchronous WebGPU upload boundaries.
///
/// Swift 6.4 release-WASM cannot reliably lower JavaScriptKit's generic
/// `JSTypedArray<Float32>([Float])` initializer. Float uploads therefore use
/// persistent length-keyed arrays and indexed writes. Byte uploads retain the
/// zero-copy Swift-side path and perform the single required copy directly
/// into JavaScript-owned storage.
internal final class WebGPUUploadStaging {
    private struct Float32Entry {
        let count: Int
        let array: JSObject
    }

    private let float32Constructor: JSObject
    private let uint8Constructor: JSObject
    private let float32Capacity = 16
    private var float32Entries: [Float32Entry] = []

    init?() {
        guard let float32Constructor = JSObject.global.Float32Array.object,
              let uint8Constructor = JSObject.global.Uint8Array.object else {
            return nil
        }
        self.float32Constructor = float32Constructor
        self.uint8Constructor = uint8Constructor
    }

    /// Copies scalar values into a reusable JavaScript `Float32Array`.
    ///
    /// WebGPU's `writeBuffer` copies the supplied range synchronously, so the
    /// returned array can be overwritten by the next upload after that call
    /// returns.
    func float32Array(copying values: borrowing [Float]) -> JSObject {
        let array: JSObject
        if let index = float32Entries.firstIndex(
            where: { $0.count == values.count }
        ) {
            let existing = float32Entries.remove(at: index)
            float32Entries.append(existing)
            array = existing.array
        } else {
            array = float32Constructor.new(values.count)
            if float32Entries.count == float32Capacity {
                float32Entries.removeFirst()
            }
            float32Entries.append(
                Float32Entry(
                    count: values.count,
                    array: array
                )
            )
        }

        for index in values.indices {
            array[index] = .number(Double(values[index]))
        }
        return array
    }

    /// Copies initialized `Data` bytes into JavaScript-owned `Uint8Array`
    /// storage without first materializing a Swift `[UInt8]`.
    ///
    /// Memory invariants:
    /// - `Data` owns the initialized source bytes for the closure duration.
    /// - The pointer is scoped to `withUnsafeBytes` and never escapes.
    /// - `UInt8` has stride and alignment one; the checked `Int32` length is
    ///   the exact initialized byte range passed to JavaScriptKit.
    /// - `swjs_create_typed_array` synchronously copies into storage owned and
    ///   eventually released by JavaScript, so Swift performs no deallocation.
    /// - The `Uint8Array` constructor fixes the bound element type and prevents
    ///   aliasing the source as a wider value.
    func uint8Array(copying data: Data) -> JSObject? {
        guard let length = Int32(exactly: data.count) else {
            return nil
        }
        return data.withUnsafeBytes { bytes in
            let reference = swjs_create_typed_array(
                uint8Constructor.id,
                bytes.baseAddress,
                length
            )
            return JSObject(id: reference)
        }
    }
}
#endif
