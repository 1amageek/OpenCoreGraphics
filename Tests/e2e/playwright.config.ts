import { defineConfig, devices } from "@playwright/test";

const PORT = Number(process.env.E2E_PORT ?? 8766);
const BASE_URL = `http://127.0.0.1:${PORT}`;

export default defineConfig({
    testDir: "./specs",
    fullyParallel: false,
    forbidOnly: !!process.env.CI,
    retries: process.env.CI ? 1 : 0,
    reporter: [["list"], ["html", { open: "never" }]],
    timeout: 60_000,
    expect: { timeout: 15_000 },
    use: {
        baseURL: BASE_URL,
        trace: "retain-on-failure",
        screenshot: "only-on-failure",
        // WebGPU in headless Chromium requires these flags. On Linux CI the
        // SwiftShader Vulkan backend provides a software rasteriser; add
        // --use-vulkan=swiftshader there if needed.
        launchOptions: {
            args: [
                "--enable-unsafe-webgpu",
                "--enable-webgpu-developer-features"
            ]
        }
    },
    projects: [
        {
            name: "chromium",
            use: { ...devices["Desktop Chrome"] }
        }
    ],
    webServer: {
        command: "node server.mjs",
        port: PORT,
        reuseExistingServer: !process.env.CI,
        timeout: 30_000,
        stdout: "pipe",
        stderr: "pipe"
    }
});
