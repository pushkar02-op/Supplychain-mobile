import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: './flows',
  timeout: 60_000,
  expect: {
    timeout: 10_000
  },
  fullyParallel: false,
  retries: 0,
  reporter: [
    ['list'],
    ['html', { outputFolder: 'playwright-report', open: 'never' }]
  ],
  use: {
    baseURL: 'http://localhost:8080',
    browserName: 'chromium',
    headless: false,
    launchOptions: {
      args: [
        '--disable-gpu',
        '--disable-software-rasterizer',
        '--disable-dev-shm-usage',
        '--disable-web-security',
        '--no-sandbox',
        '--disable-features=IsolateOrigins,site-per-process',
        '--disable-site-isolation-trials',
        '--disable-features=RendererCodeIntegrity',
        '--disable-blink-features=AutomationControlled',
      ],
    },
    viewport: { width: 1280, height: 800 },
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
    trace: 'retain-on-failure',
  }
});
