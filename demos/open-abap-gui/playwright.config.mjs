import {defineConfig, devices} from "@playwright/test";

const port = process.env.PORT ?? 3123;

export default defineConfig({
  testDir: "tests",
  fullyParallel: false,
  workers: 1,
  retries: process.env.CI ? 1 : 0,
  reporter: process.env.CI ? "list" : [["list"], ["html", {open: "never"}]],
  use: {
    baseURL: `http://localhost:${port}`,
    trace: "retain-on-failure",
    screenshot: "only-on-failure",
  },
  projects: [{name: "chromium", use: {...devices["Desktop Chrome"]}}],
  webServer: {
    command: "node express.mjs",
    url: `http://localhost:${port}`,
    env: {PORT: String(port)},
    reuseExistingServer: !process.env.CI,
    timeout: 60_000,
  },
});
