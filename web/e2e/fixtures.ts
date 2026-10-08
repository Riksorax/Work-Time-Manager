import { test as base, expect, Page } from '@playwright/test';

export type Lang = 'de' | 'en';
export type Theme = 'light' | 'dark';

/** Seitenpfade der Kern-Oberfläche (ohne Konto erreichbar). */
export const PAGES = ['/dashboard', '/reports', '/settings', '/auth/login', '/gibt-es-nicht'] as const;

/** Viewports der Prüfmatrix aus #429. */
export const VIEWPORTS = [320, 375, 768, 1024, 1440].map(width => ({ width, height: 800 }));

/** Schreibt Sprache und Theme in localStorage, bevor die App bootet. */
export async function seedPreferences(page: Page, lang: Lang, theme: Theme): Promise<void> {
  await page.addInitScript(([l, t]) => {
    // Nur beim ersten Laden setzen, damit Neuladen die App-Auswahl prüft.
    if (localStorage.getItem('locale') === null) localStorage.setItem('locale', l);
    if (localStorage.getItem('theme') === null) localStorage.setItem('theme', t);
  }, [lang, theme]);
}

/** Console-Fehler, die nicht von der App selbst stammen (Platzhalter-Firebase, fehlende API). */
const IGNORED_ERRORS = [/firebase/i, /ERR_CONNECTION_REFUSED/i, /Failed to load resource/i, /localhost:5000/i, /net::ERR/i];

export const test = base.extend<{ consoleErrors: string[] }>({
  consoleErrors: async ({ page }, use) => {
    const errors: string[] = [];
    page.on('pageerror', e => errors.push(e.message));
    page.on('console', m => {
      if (m.type() === 'error' && !IGNORED_ERRORS.some(r => r.test(m.text()))) errors.push(m.text());
    });
    await use(errors);
  },
});

/** Wartet, bis Angular gebootet und die Seite gerendert ist. */
export async function gotoReady(page: Page, path: string): Promise<void> {
  await page.goto(path);
  await expect(page.locator('app-root')).not.toBeEmpty();
  await page.waitForLoadState('networkidle');
}

/** Horizontales Scrollen auf Seitenebene ist ein Layoutfehler. */
export async function horizontalOverflow(page: Page): Promise<number> {
  return page.evaluate(() => document.documentElement.scrollWidth - document.documentElement.clientWidth);
}

export { expect };
