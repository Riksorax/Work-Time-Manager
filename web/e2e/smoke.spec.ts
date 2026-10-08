import { AxeBuilder } from '@axe-core/playwright';
import { PAGES, VIEWPORTS, expect, gotoReady, horizontalOverflow, seedPreferences, test, Lang, Theme } from './fixtures';

const LANGS: Lang[] = ['de', 'en'];
const THEMES: Theme[] = ['light', 'dark'];

test.describe('Seiten laden ohne Fehler', () => {
  for (const path of PAGES) {
    for (const lang of LANGS) {
      for (const theme of THEMES) {
        test(`${path} (${lang}, ${theme})`, async ({ page, consoleErrors }) => {
          await seedPreferences(page, lang, theme);
          await gotoReady(page, path);

          await expect(page.locator('html')).toHaveClass(theme === 'dark' ? /dark-theme/ : /^((?!dark-theme).)*$/);
          expect(consoleErrors).toEqual([]);
        });
      }
    }
  }
});

test.describe('Kein horizontaler Überlauf', () => {
  for (const path of PAGES) {
    for (const vp of VIEWPORTS) {
      test(`${path} bei ${vp.width}px`, async ({ page }) => {
        await page.setViewportSize(vp);
        await seedPreferences(page, 'de', 'light');
        await gotoReady(page, path);
        expect(await horizontalOverflow(page)).toBeLessThanOrEqual(0);
      });
    }
  }
});

test.describe('Barrierefreiheit (axe)', () => {
  // Nur Chromium: axe-Ergebnisse sind browserunabhängig, ein Lauf genügt.
  test.skip(({ browserName }) => browserName !== 'chromium', 'axe läuft nur in Chromium');

  for (const path of PAGES) {
    for (const theme of THEMES) {
      test(`${path} (${theme}) hat keine schwerwiegenden Verstöße`, async ({ page }) => {
        await seedPreferences(page, 'de', theme);
        await gotoReady(page, path);
        const result = await new AxeBuilder({ page }).withTags(['wcag2a', 'wcag2aa']).analyze();
        const serious = result.violations
          .filter(v => v.impact === 'serious' || v.impact === 'critical')
          .map(v => `${v.id}: ${v.nodes.length}× (${v.nodes[0]?.target.join(' ')})`);
        expect(serious).toEqual([]);
      });
    }
  }
});
