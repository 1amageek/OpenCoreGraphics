// OpenCoreGraphics smoke-test loader.
// The build script stages runtime.mjs from the resolved JavaScriptKit checkout
// so the JavaScript and WebAssembly ABI versions remain identical.

import { SwiftRuntime } from "./runtime.mjs";
import { WASI, File, OpenFile, ConsoleStdout } from "https://cdn.jsdelivr.net/npm/@bjorn3/browser_wasi_shim@0.4.1/+esm";

const statusEl = document.getElementById("status");
const errorEl = document.getElementById("error");

function setStatus(msg) {
    statusEl.textContent = msg;
    console.log("[OCGSmoke]", msg);
}

function showError(msg) {
    errorEl.textContent = msg;
    errorEl.style.display = "block";
    statusEl.style.color = "#ff6b6b";
    statusEl.textContent = "Error";
    console.error("[OCGSmoke]", msg);
}

async function main() {
    try {
        setStatus("Loading WASM module...");
        const response = await fetch("OCGSmoke.wasm");
        if (!response.ok) {
            throw new Error("Failed to load OCGSmoke.wasm: " + response.status);
        }
        const wasmBytes = await response.arrayBuffer();
        setStatus("WASM loaded (" + (wasmBytes.byteLength / 1024).toFixed(1) + " KB)");

        const swift = new SwiftRuntime();

        const wasi = new WASI([], [], [
            new OpenFile(new File([])),
            ConsoleStdout.lineBuffered((line) => console.log("[Swift]", line)),
            ConsoleStdout.lineBuffered((line) => console.error("[Swift]", line)),
        ]);

        let wasmMemory = null;
        const textDecoder = new TextDecoder("utf-8");
        const textEncoder = new TextEncoder();

        let tmpRetString, tmpRetBytes, tmpRetException;
        let tmpRetOptionalBool, tmpRetOptionalInt, tmpRetOptionalFloat;
        let tmpRetOptionalDouble, tmpRetOptionalHeapObject;

        const i32Stack = [];
        const i64Stack = [];
        const f32Stack = [];
        const f64Stack = [];
        const stringStack = [];
        const pointerStack = [];

        const decodeString = (ptr, len) => {
            const bytes = new Uint8Array(wasmMemory.buffer, ptr, len);
            return textDecoder.decode(bytes);
        };

        const bjs = {
            swift_js_return_string: (ptr, len) => { tmpRetString = decodeString(ptr, len); },
            swift_js_init_memory: (sourceId, bytesPtr) => {
                const source = swift.memory.getObject(sourceId);
                swift.memory.release(sourceId);
                const bytes = new Uint8Array(wasmMemory.buffer, bytesPtr);
                bytes.set(source);
            },
            swift_js_make_js_string: (ptr, len) => swift.memory.retain(decodeString(ptr, len)),
            swift_js_init_memory_with_result: (ptr, len) => {
                const target = new Uint8Array(wasmMemory.buffer, ptr, len);
                target.set(tmpRetBytes);
                tmpRetBytes = undefined;
            },
            swift_js_throw: (id) => { tmpRetException = swift.memory.retainByRef(id); },
            swift_js_retain: (id) => swift.memory.retainByRef(id),
            swift_js_release: (id) => { swift.memory.release(id); },
            swift_js_push_i32: (v) => { i32Stack.push(v | 0); },
            swift_js_push_i64: (v) => { i64Stack.push(v); },
            swift_js_push_f32: (v) => { f32Stack.push(Math.fround(v)); },
            swift_js_push_f64: (v) => { f64Stack.push(v); },
            swift_js_push_string: (ptr, len) => { stringStack.push(decodeString(ptr, len)); },
            swift_js_push_pointer: (pointer) => { pointerStack.push(pointer); },
            swift_js_push_typed_array: () => {
                throw new Error("Unexpected BridgeJS typed-array call");
            },
            swift_js_pop_i32: () => i32Stack.pop(),
            swift_js_pop_i64: () => i64Stack.pop(),
            swift_js_pop_f32: () => f32Stack.pop(),
            swift_js_pop_f64: () => f64Stack.pop(),
            swift_js_pop_pointer: () => pointerStack.pop(),
            swift_js_return_optional_bool: (isSome, value) => {
                tmpRetOptionalBool = isSome === 0 ? null : value !== 0;
            },
            swift_js_return_optional_int: (isSome, value) => {
                tmpRetOptionalInt = isSome === 0 ? null : value | 0;
            },
            swift_js_get_optional_int_presence: () => tmpRetOptionalInt != null ? 1 : 0,
            swift_js_get_optional_int_value: () => {
                const value = tmpRetOptionalInt;
                tmpRetOptionalInt = undefined;
                return value;
            },
            swift_js_return_optional_float: (isSome, value) => {
                tmpRetOptionalFloat = isSome === 0 ? null : Math.fround(value);
            },
            swift_js_get_optional_float_presence: () => tmpRetOptionalFloat != null ? 1 : 0,
            swift_js_get_optional_float_value: () => {
                const value = tmpRetOptionalFloat;
                tmpRetOptionalFloat = undefined;
                return value;
            },
            swift_js_return_optional_double: (isSome, value) => {
                tmpRetOptionalDouble = isSome === 0 ? null : value;
            },
            swift_js_get_optional_double_presence: () => tmpRetOptionalDouble != null ? 1 : 0,
            swift_js_get_optional_double_value: () => {
                const value = tmpRetOptionalDouble;
                tmpRetOptionalDouble = undefined;
                return value;
            },
            swift_js_return_optional_string: (isSome, ptr, len) => {
                tmpRetString = isSome === 0 ? null : decodeString(ptr, len);
            },
            swift_js_get_optional_string: () => {
                const str = tmpRetString;
                tmpRetString = undefined;
                if (str == null) return -1;
                const bytes = textEncoder.encode(str);
                tmpRetBytes = bytes;
                return bytes.length;
            },
            swift_js_return_optional_object: (isSome, objectId) => {
                tmpRetString = isSome === 0 ? null : swift.memory.getObject(objectId);
            },
            swift_js_return_optional_heap_object: (isSome, pointer) => {
                tmpRetOptionalHeapObject = isSome === 0 ? null : pointer;
            },
            swift_js_get_optional_heap_object_pointer: () => {
                const pointer = tmpRetOptionalHeapObject;
                tmpRetOptionalHeapObject = undefined;
                return pointer || 0;
            },
            swift_js_make_promise: () => {
                throw new Error("Unexpected BridgeJS promise call");
            },
            swift_js_closure_unregister: () => {},
        };

        const importObject = {
            wasi_snapshot_preview1: wasi.wasiImport,
            javascript_kit: swift.wasmImports,
            bjs: bjs,
        };

        setStatus("Instantiating WASM...");
        const { instance } = await WebAssembly.instantiate(wasmBytes, importObject);
        wasmMemory = instance.exports.memory;
        swift.setInstance(instance);
        wasi.initialize(instance);

        setStatus("Starting setup...");
        if (instance.exports.setup) {
            instance.exports.setup();
        }

        setTimeout(() => setStatus("Running..."), 500);
    } catch (err) {
        showError(err.message || "Unknown error");
        console.error("WASM Error:", err);
    }
}

main();
