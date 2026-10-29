import { AxeBuilder } from '@axe-core/playwright';
import { PAGES, expect, gotoReady, horizontalOverflow, seedPreferences, test, Theme } from './fixtures';
import { freezeTime, seedEntries, workDay } from './seed';

/**
 * Restliche automatisierbare Punkte der Prüfmatrix aus #429: Textskalierung, Querformat, Touch-Zielgrößen und
 * Dialoge mit axe. Seiten mit Einträgen, damit Listen, Kalender und Banner mitgeprüft werden.
 */

const ENTRIES = [workDay('2026-03-10'), workDay('2026-03-11', { isHomeOffice: true }), workDay('2026-03-18')];

test.beforeEach(async ({ page }) => {
  await seedPreferences(page, 'de', 'light');
  await freezeTime(page);
  await seedEntries(page, ENTRIES);
});

test.describe('Textskalierung 200 %', () => {
  for (const width of [375, 768]) {
    for (const path of ['/dashboard', '/reports', '/settings']) {
      test(`${path} bei ${width}px ohne horizontalen Überlauf`, async ({ page }) => {
        await page.setViewportSize({ width, height: 800 });
        await gotoReady(page, path);
        await page.addStyleTag({ content: 'html { font-size: 200% !important; }' });
        expect(await horizontalOverflow(page)).toBeLessThanOrEqual(0);
      });
    }
  }
});

test.describe('Querformat auf dem Smartphone (667×375)', () => {
  for (const path of PAGES) {
    test(`${path} ohne horizontalen Überlauf`, async ({ page }) => {
      await page.setViewportSize({ width: 667, height: 375 });
      await gotoReady(page, path);
      expect(await horizontalOverflow(page)).toBeLessThanOrEqual(0);
    });
  }
});

test.describe('Touch-Zielgrößen (WCAG 2.5.8, mindestens 24×24 px)', () => {
  for (const path of ['/dashboard', '/reports', '/settings']) {
    test(`${path} bei 375px`, async ({ page }) => {
      await page.setViewportSize({ width: 375, height: 800 });
      await gotoReady(page, path);
      const tooSmall = await page.evaluate(() => {
        const sel = 'button, a[href], [role="button"], [role="tab"], [role="menuitem"], input:not([type="hidden"]), mat-slide-toggle, [role="gridcell"]';
        const bad: string[] = [];
        document.querySelectorAll<HTMLElement>(sel).forEach(el => {
          // Eingaben in Material-Feldern: die Klickfläche ist das ganze Feld, nicht das innere <input>.
          const r = (el.closest('mat-form-field') ?? el).getBoundingClientRect();
          const visible = r.width > 0 && r.height > 0 && getComputedStyle(el).visibility !== 'hidden';
          if (visible && (r.width < 24 || r.height < 24)) {
            bad.push(`${el.tagName.toLowerCase()}${el.className ? '.' + String(el.className).split(' ')[0] : ''} ${Math.round(r.width)}×${Math.round(r.height)}`);
          }
        });
        return bad;
      });
      expect(tooSmall).toEqual([]);
    });
  }
});

test.describe('Dialoge (axe, Fokus)', () => {
  test.skip(({ browserName }) => browserName !== 'chromium', 'axe läuft nur in Chromium');

  for (const theme of ['light', 'dark'] as Theme[]) {
    test(`Schnelleintrag-Dialog (${theme})`, async ({ page }) => {
      await page.emulateMedia({ colorScheme: theme });
      await gotoReady(page, '/reports');
      await page.getByRole('button', { name: /Schnelleintrag|Eintrag hinzufügen|Eintrag/ }).first().click();
      const dialog = page.getByRole('dialog');
      await expect(dialog).toBeVisible();
      // Der Fokus liegt im Dialog, nicht auf der Seite dahinter.
      await expect.poll(() => page.evaluate(() => !!document.activeElement?.closest('[role="dialog"]'))).toBe(true);
      const result = await new AxeBuilder({ page }).include('[role="dialog"]').withTags(['wcag2a', 'wcag2aa']).analyze();
      const serious = result.violations
        .filter(v => v.impact === 'serious' || v.impact === 'critical')
        .map(v => `${v.id}: ${v.nodes.length}× (${v.nodes[0]?.target.join(' ')})`);
      expect(serious).toEqual([]);
      // Escape schließt den Dialog.
      await page.keyboard.press('Escape');
      await expect(dialog).toBeHidden();
    });
  }
});
