# OpenCoreGraphics Design

## Concurrency and Ownership

OpenCoreGraphics uses checked `Sendable` conformance only when the portable
implementation can prove immutable or synchronized ownership. `CGColor`,
`CGColorSpace`, and `CGGradient` are immutable after initialization and use
checked conformance.

Mutable drawing objects and objects that retain caller-owned pointers or
callbacks intentionally do not conform to `Sendable`. This applies to
`CGContext`, `CGLayer`, `CGPath`, `CGMutablePath`, `CGFont`, `CGPDFDocument`,
`CGPDFPage`, `CGDataProvider`, `CGDataConsumer`, `CGFunction`, `CGPattern`,
`CGImage`, `CGRenderingBufferProvider`, and `CGShading`. This differs from
unchecked concurrency annotations that an Apple SDK importer may expose.
The portable implementation cannot prove that caller-owned callback context
pointers, borrowed pixel storage, or mutable renderer state are safe to move
between tasks.

Callback function values are `@Sendable`, but the object retaining a raw
context pointer remains bound to the caller's ownership domain. Callers must
create an immutable snapshot before moving mutable drawing state across a
concurrency boundary.

`CGContext.makeImageAsync()` and the renderer readback requirement use
`nonisolated(nonsending)`. GPU readback therefore remains on the caller's
isolation domain instead of transferring a non-`Sendable` context or renderer
to the generic executor.

On WebAssembly, the process-wide WebGPU device is protected by
`Synchronization.Mutex` on every access. Renderer objects remain owned by
their contexts and do not claim cross-task safety.

`CGDataConsumer` protects accumulated data and finalization state with a
`Mutex<State>`. File I/O and external callbacks execute after leaving the
critical section. URL-backed consumers reject writes while finalization is in
progress and after successful finalization; write failures remain retryable.

`CGFont` parses and validates its table set before publishing the instance.
The parsed table aggregate and variation coordinates are immutable afterward,
so font reads do not require a recursive lock or target-specific synchronization.

### Shared-State Review Matrix

| Logical state | Target | Storage type | Isolation | Read entry point | Mutation entry point | Shutdown / release |
|---|---|---|---|---|---|---|
| Data consumer bytes and finalization | Native | `Mutex<State>` | `withLock` | `data`, `finalize()` snapshot | `putBytes`, finalization transitions | `deinit` snapshots state before I/O |
| Data consumer bytes and finalization | WASM | `Mutex<State>` | `withLock` | Same source and entry points as Native | Same source and entry points as Native | Same source as Native |
| Data consumer bytes and finalization | Embedded WASM | `Mutex<State>` | `withLock` | Same source and entry points as Native | Same source and entry points as Native | Same source as Native |
| Global WebGPU device | Native | Not compiled | WebGPU source is WASM-only | Not available | Not available | Not available |
| Global WebGPU device | WASM | `Mutex<GPUDevice?>` | `withLock` | `getGlobalDevice()` | `setupGraphicsContext()` | Process-owned WebGPU lifetime |
| Global WebGPU device | Embedded WASM | `Mutex<GPUDevice?>` | `withLock` | Same source as WASM | Same source as WASM | Process-owned WebGPU lifetime |
| Parsed font tables | Native / WASM / Embedded WASM | Immutable `ParsedTables` value | Initialization boundary | Font property and glyph APIs | No mutation after initialization | Released with `CGFont` |
| Software renderer storage | Native / WASM / Embedded WASM | `Mutex<Storage>` | `withLock` | Renderer delegate methods | Renderer delegate methods | Released with renderer owner |
| Renderer command and cache state | WASM / Embedded WASM | Context-owned non-`Sendable` renderer | Single owning context execution path | Renderer delegate methods | Renderer delegate methods | Released with `CGContext` |

## Embedded Support Boundary

The `OpenCoreGraphicsSupport` target re-exports Foundation on ordinary targets
and provides the Foundation-free geometry, byte storage, URL file I/O, string
encoding, time, and C-math subset required by OpenCoreGraphics on Embedded
Swift. Shared mutable framework state keeps the same `Mutex<State>` storage and
entry points on Native, WASM, and Embedded WASM.

The Embedded `Data` owner is a Swift copy-on-write byte array. C file reads
transfer their allocation into this owner once at the file boundary and release
the C allocation exactly once. Subsequent value copies preserve Swift CoW
semantics. The portable attributed-string compatibility type currently carries
only an immutable plain string and is explicitly marked incomplete in source.

## WebGPU Initialization

Applications call `setupGraphicsContext()` before creating a WebGPU-backed
bitmap context. If no initialized device or upload staging buffer is available,
`CGContext` initialization returns `nil`. It does not trap and does not silently
select a software renderer.

The renderer uploads large vertex and texture payloads through reusable typed
JavaScript staging buffers. Texture, geometry, and pipeline caches use bounded
storage and explicit eviction instead of Swift hash tables in the release-WASM
hot path.
