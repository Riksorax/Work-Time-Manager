import { AxeBuilder } from '@axe-core/playwright';
import { expect, gotoReady, test } from './fixtures';

/** Tab „Trend“ (#531) ohne Konto: Hinweis zur Anmeldung, Tab-Leiste passt auf Handy-Breite. Mit Konto: trend-account.spec.ts. */

test('nicht angemeldet: Trend-Tab zeigt den Anmelde-Hinweis', async ({ page }) => {
  await gotoReady(page, '/reports');
  await page.getByRole('tab', { name: 'Trend' }).click();
  await expect(page.locator('.mat-mdc-tab-body-active .auth-gate-card')).toContainText('Melde dich an, um den Trend');
  await expect(page.locator('app-trend-view')).toHaveCount(0);
});

test('nicht angemeldet: axe ohne ernste Verstöße im Trend-Tab', async ({ page, browserName }) => {
  test.skip(browserName !== 'chromium', 'axe läuft nur in Chromium');
  await gotoReady(page, '/reports');
  await page.getByRole('tab', { name: 'Trend' }).click();
  await expect(page.locator('.mat-mdc-tab-body-active .auth-gate-card')).toBeVisible();
  const result = await new AxeBuilder({ page }).withTags(['wcag2a', 'wcag2aa']).analyze();
  const serious = result.violations.filter(v => v.impact === 'serious' || v.impact === 'critical').map(v => v.id);
  expect(serious).toEqual([]);
});

for (const width of [320, 375]) {
  test(`Reports: alle sechs Tabs sind bei ${width}px ohne Blättern sichtbar (ohne Konto)`, async ({ page }) => {
    await page.setViewportSize({ width, height: 800 });
    await gotoReady(page, '/reports');
    for (const name of ['Täglich', 'Wöchentlich', 'Monatlich', 'Jahr', 'Trend', 'Insights']) {
      const box = await page.getByRole('tab', { name, exact: true }).boundingBox();
      expect(box!.x, `${name} links`).toBeGreaterThanOrEqual(0);
      expect(box!.x + box!.width, `${name} rechts`).toBeLessThanOrEqual(width);
    }
    await expect(page.locator('.mat-mdc-tab-header-pagination-controls-enabled')).toHaveCount(0);
  });
}
