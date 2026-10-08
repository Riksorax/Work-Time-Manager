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
// Tests mit Konto (#429) brauchen die Firebase-Emulatoren (Java + firebase-tools); nur in Chromium, siehe e2e/account.ts.
const withEmulators = process.env['E2E_EMULATORS'] === '1';

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
  webServer: [
    {
      // E2E-Build: Firebase-Emulatoren statt echtem Backend (environment.e2e.ts).
      command: `npx ng serve --configuration e2e --port ${port}`,
      url: `http://localhost:${port}`,
      reuseExistingServer: !process.env['CI'],
      timeout: 180_000,
    },
    ...(withEmulators
      ? [{
          command: 'npx --yes firebase-tools@14.27.0 emulators:start --only auth,firestore --project demo-e2e',
          // Auth startet vor Firestore; ein übrig gebliebener Firestore-Prozess täuscht sonst „läuft schon" vor.
          url: 'http://127.0.0.1:9099',
          reuseExistingServer: !process.env['CI'],
          timeout: 180_000,
          // SIGTERM lässt die Firebase-CLI die Emulatoren (Java-Prozess) sauber beenden.
          gracefulShutdown: { signal: 'SIGTERM' as const, timeout: 15_000 },
        }]
      : []),
  ],
});
