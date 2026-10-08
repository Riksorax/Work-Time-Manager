import { defineConfig, devices } from '@playwright/test';

/**
 * UI-/E2E-Tests (#429). Die App läuft ohne Konto (localStorage-Modus), die
 * Backend-API wird in den Tests nicht benötigt; Firebase bekommt die
 * Platzhalter aus `src/environments/environment.ts`.
 *
 * Lokal ist nur Chromium vorinstalliert. Firefox/WebKit/Edge laufen in CI
 * (`npx playwright install --with-deps`); lokal gezielt mit
 * `npm run e2e -- --project=chromium`.
 */
const port = 4200;

export default defineConfig({
  testDir: './e2e',
  fullyParallel: true,
  forbidOnly: !!process.env['CI'],
  retries: process.env['CI'] ? 1 : 0,
  reporter: process.env['CI'] ? [['github'], ['html', { open: 'never' }]] : 'list',
  use: {
    baseURL: `http://localhost:${port}`,
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
    // Feste Zeitzone/Sprache, damit Tests nicht vom Runner abhängen.
    timezoneId: 'Europe/Berlin',
    locale: 'de-DE',
  },
  projects: [
    { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
    { name: 'firefox', use: { ...devices['Desktop Firefox'] } },
    { name: 'webkit', use: { ...devices['Desktop Safari'] } },
    { name: 'edge', use: { ...devices['Desktop Edge'], channel: 'msedge' } },
    { name: 'mobile-chrome', use: { ...devices['Pixel 7'] } },
    { name: 'mobile-safari', use: { ...devices['iPhone 14'] } },
  ],
  webServer: {
    command: `npx ng serve --port ${port}`,
    url: `http://localhost:${port}`,
    reuseExistingServer: !process.env['CI'],
    timeout: 180_000,
  },
});
