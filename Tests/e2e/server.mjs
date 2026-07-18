// Zero-dep static server for the OpenCoreGraphics smoke-test.
// Serves Examples/SmokeTest/web/* plus the freshly built OCGSmoke.wasm.
//
// build.sh lays the artifact out as:
//   Examples/SmokeTest/web/         -> index.html, app.js, runtime.mjs (checked in)
//   Examples/SmokeTest/web/OCGSmoke.wasm (produced by build.sh, gitignored)
// This server mounts that directory root-level so `fetch('OCGSmoke.wasm')`
// in app.js resolves without any URL rewriting.

import { createServer } from "node:http";
import { readFile, stat } from "node:fs/promises";
import { extname, join, normalize, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = fileURLToPath(new URL(".", import.meta.url));
const PROJECT_ROOT = resolve(__dirname, "..", "..");
const WEB_ROOT = join(PROJECT_ROOT, "Examples", "SmokeTest", "web");

const MIME = {
    ".html": "text/html; charset=utf-8",
    ".js": "application/javascript; charset=utf-8",
    ".mjs": "application/javascript; charset=utf-8",
    ".wasm": "application/wasm",
    ".json": "application/json; charset=utf-8",
    ".css": "text/css; charset=utf-8",
    ".map": "application/json; charset=utf-8"
};

function resolvePhysical(urlPath) {
    const clean = normalize(decodeURIComponent(urlPath.split("?")[0]));
    const rel = clean === "/" ? "index.html" : clean.replace(/^\/+/, "");
    const full = join(WEB_ROOT, rel);
    if (!full.startsWith(WEB_ROOT)) return null;
    return full;
}

async function serve(req, res) {
    const filePath = resolvePhysical(req.url);
    if (!filePath) {
        res.writeHead(403); res.end("Forbidden"); return;
    }
    try {
        const stats = await stat(filePath);
        if (!stats.isFile()) {
            res.writeHead(404); res.end("Not Found"); return;
        }
        const data = await readFile(filePath);
        const mime = MIME[extname(filePath).toLowerCase()] ?? "application/octet-stream";
        res.writeHead(200, {
            "Content-Type": mime,
            "Content-Length": data.length,
            "Cross-Origin-Opener-Policy": "same-origin",
            "Cross-Origin-Embedder-Policy": "require-corp"
        });
        res.end(data);
    } catch (err) {
        if (err.code === "ENOENT") {
            res.writeHead(404); res.end(`Not Found: ${req.url}`);
        } else {
            res.writeHead(500); res.end(`Internal Error: ${err.message}`);
        }
    }
}

async function preflight() {
    const wasmFile = join(WEB_ROOT, "OCGSmoke.wasm");
    try {
        await stat(wasmFile);
    } catch {
        console.error(
            `\n✗ OCGSmoke.wasm missing at ${wasmFile}\n` +
            `  Build it first:\n` +
            `    ./build.sh\n` +
            `  (or manually: cd ../../Examples/SmokeTest && \\\n` +
            `    export PATH="$HOME/.swiftly/bin:$PATH" && \\\n` +
            `    swift package resolve --version 0.52.1 JavaScriptKit && \\\n` +
            `    swift build --product OCGSmoke --swift-sdk swift-6.3.1-RELEASE_wasm -c release && \\\n` +
            `    cp .build/wasm32-unknown-wasip1/release/OCGSmoke.wasm web/)\n`
        );
        process.exit(1);
    }
}

const PORT = Number(process.env.E2E_PORT ?? 8766);
await preflight();
createServer(serve).listen(PORT, "127.0.0.1", () => {
    console.log(`OpenCoreGraphics E2E server listening on http://127.0.0.1:${PORT}`);
    console.log(`  /              -> ${WEB_ROOT}`);
});
