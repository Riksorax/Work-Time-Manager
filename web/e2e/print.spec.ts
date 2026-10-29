import { expect, gotoReady, test } from './fixtures';

/** Druckansicht der Jahresauswertung (#483): im Druck bleibt nur der Jahresbereich sichtbar. */
test.describe('Jahresauswertung drucken', () => {
  test.beforeEach(({}, testInfo) => {
    test.skip(testInfo.project.name !== 'chromium', 'nur Chromium (Desktop)');
  });

  test('Druckmedium zeigt Titel und Karte, aber weder Navigation noch Tabs noch Button', async ({ page }) => {
    await gotoReady(page, '/reports');
    await page.getByRole('tab', { name: 'Jahr' }).click();
    await expect(page.locator('.print-area')).toBeVisible();
    await expect(page.getByRole('button', { name: /PDF/ })).toBeVisible();
    await expect(page.locator('.print-area .print-only')).toBeHidden();

    await page.emulateMedia({ media: 'print' });
    await expect(page.locator('.print-area .print-only')).toBeVisible();
    await expect(page.locator('.print-area .print-only')).toContainText('Urlaubs- und Krankheitsauswertung');
    await expect(page.getByRole('button', { name: /PDF/ })).toBeHidden();
    await expect(page.locator('mat-sidenav')).toBeHidden();
    await expect(page.getByRole('tab', { name: 'Jahr' })).toBeHidden();
  });
});
