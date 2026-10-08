import { expect, gotoReady, seedPreferences, test } from './fixtures';
import { freezeTime, seedEntries, workDay } from './seed';

/** Layout-Regressionen (#429), gefunden beim Durchsehen der Screenshots bei 320/768 px. Laufen ohne Konto. */

test.beforeEach(async ({ page }) => {
  await seedPreferences(page, 'de', 'light');
  await freezeTime(page);
  await seedEntries(page, [workDay('2026-03-10'), workDay('2026-03-17'), workDay('2026-03-18')]);
});

test('Dashboard: Label und Wert der Überstunden stoßen bei 320 px nicht aneinander', async ({ page }) => {
  await page.setViewportSize({ width: 320, height: 700 });
  await gotoReady(page, '/dashboard');
  const rows = page.locator('.stat-row');
  await expect(rows.first()).toBeVisible();
  for (let i = 0; i < await rows.count(); i++) {
    const label = await rows.nth(i).locator('.stat-label').boundingBox();
    const value = await rows.nth(i).locator('.stat-value').boundingBox();
    expect(value!.x - (label!.x + label!.width), `Zeile ${i}`).toBeGreaterThanOrEqual(8);
  }
});

test('Kalender: Eintrags-Punkt berührt die Ziffer bei 320 px nicht', async ({ page }) => {
  await page.setViewportSize({ width: 320, height: 700 });
  await gotoReady(page, '/reports');
  const cell = page.locator('[role="gridcell"][data-date="2026-03-10"]');
  const digit = await cell.locator('.day-number').boundingBox();
  const dot = await cell.locator('.entry-dot').boundingBox();
  expect(dot!.y).toBeGreaterThanOrEqual(digit!.y + digit!.height);
});

test('Kalender: auf 768 px nicht über die volle Breite gezogen (quadratische Zellen)', async ({ page }) => {
  await page.setViewportSize({ width: 768, height: 1000 });
  await gotoReady(page, '/reports');
  const card = await page.locator('.calendar-card').boundingBox();
  expect(card!.width).toBeLessThanOrEqual(440);
  const row = await page.locator('.calendar-week:not(.weekday-row)').first().boundingBox();
  expect(row!.height).toBeLessThanOrEqual(70);
});

test.describe('Einstellungen bei 320 px', () => {
  test('Titel werden nicht abgeschnitten', async ({ page }) => {
    await page.setViewportSize({ width: 320, height: 700 });
    await gotoReady(page, '/settings');
    const titles = page.locator('.mdc-list-item__primary-text');
    expect(await titles.count()).toBeGreaterThan(0);
    for (let i = 0; i < await titles.count(); i++) {
      const clipped = await titles.nth(i).evaluate(e => e.scrollWidth > e.clientWidth + 1);
      expect(clipped, `Titel ${i}: ${await titles.nth(i).innerText()}`).toBe(false);
    }
  });

  test('Chevron der Listenzeilen ist eine 24-px-Icon-Schrift und damit sichtbar', async ({ page }) => {
    await gotoReady(page, '/settings');
    const chevron = page.locator('button[mat-list-item] mat-icon.mdc-list-item__end').first();
    const style = await chevron.evaluate(e => ({ ff: getComputedStyle(e).fontFamily, fs: getComputedStyle(e).fontSize }));
    expect(style.ff).toContain('Material Icons');
    expect(style.fs).toBe('24px');
  });
});
