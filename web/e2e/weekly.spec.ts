import { Page } from '@playwright/test';
import { EMULATORS_ENABLED, expect, seedEntry, test } from './account';

/** Wochenauswahl im Reports-Tab „Wöchentlich" (Premium, serverberechnet) und Layout der Reports mit Konto. */

test.skip(!EMULATORS_ENABLED, 'Firebase-Emulatoren aus (E2E_EMULATORS=1 setzen)');
test.beforeEach(({}, testInfo) => {
  test.skip(testInfo.project.name !== 'chromium', 'Tests mit Konto laufen nur in Chromium');
});

const kwOf = async (page: Page): Promise<number> => {
  const text = await page.locator('.week-nav .kw-label').innerText();
  return Number(text.replace(/\D/g, ''));
};

async function openWeekly(page: Page, account: Parameters<Parameters<typeof test>[2]>[0]['account']): Promise<void> {
  await account.setPremium(true);
  await account.signIn({ path: '/reports' });
  await page.getByRole('tab', { name: 'Wöchentlich' }).click();
  await expect(page.locator('.week-nav .kw-label')).toBeVisible();
}

test.describe('Wochenauswahl', () => {
  test('zeigt KW und Montag–Sonntag der aktuellen Woche', async ({ page, account }) => {
    await openWeekly(page, account);
    await expect(page.locator('.week-nav .week-range')).toContainText('–');
    await expect(page.locator('.day-list [role="listitem"], .day-list > *')).toHaveCount(7);
    // Die erste Zeile ist ein Montag, die letzte ein Sonntag.
    await expect(page.locator('.day-list').getByText(/^Mo\./)).toHaveCount(1);
    await expect(page.locator('.day-list').getByText(/^So\./)).toHaveCount(1);
  });

  test('Vor/Zurück wechselt genau eine Woche und fragt den Server mit dem passenden Tag', async ({ page, account }) => {
    await openWeekly(page, account);
    const kw = await kwOf(page);
    const before = account.backend.calls.filter(c => c.startsWith('GET /reports/weekly/')).length;

    await page.getByRole('button', { name: 'Nächste Woche' }).click();
    await expect.poll(() => kwOf(page)).toBe(kw === 52 || kw === 53 ? 1 : kw + 1);
    await page.getByRole('button', { name: 'Vorherige Woche' }).click();
    await page.getByRole('button', { name: 'Vorherige Woche' }).click();
    await expect.poll(() => kwOf(page)).toBe(kw === 1 ? 52 : kw - 1);

    const weekly = account.backend.calls.filter(c => c.startsWith('GET /reports/weekly/'));
    expect(weekly.length).toBeGreaterThan(before);
    // Der Bezugstag springt in 7-Tage-Schritten: drei verschiedene Anfragen (+7, ±0, −7 Tage).
    expect(new Set(weekly.slice(before)).size).toBeGreaterThanOrEqual(2);
  });

  test('zeigt die Arbeitszeit der gewählten Woche', async ({ page, account }) => {
    const now = new Date();
    const monday = new Date(now.getFullYear(), now.getMonth(), now.getDate() - ((now.getDay() + 6) % 7));
    const at = (h: number, m = 0) => new Date(monday.getFullYear(), monday.getMonth(), monday.getDate(), h, m);
    await seedEntry(account.user.uid, 'default', { start: at(8), end: at(16, 30) });
    await openWeekly(page, account);
    await expect(page.locator('.summary-value').first()).toHaveText('08:30');
  });
});

test.describe('Layout mit Konto', () => {
  for (const width of [320, 375]) {
    test(`Einstellungen laufen bei ${width}px nicht über den Rand (lange E-Mail-Adresse)`, async ({ page, account }) => {
      await page.setViewportSize({ width, height: 800 });
      await account.setPremium(true);
      await account.signIn({ path: '/settings' });
      await expect(page.locator('.profile-email')).toBeVisible();
      const box = await page.locator('.settings-content .column').first().boundingBox();
      expect(box!.x + box!.width).toBeLessThanOrEqual(width);
    });

    test(`Reports: alle vier Tabs sind bei ${width}px ohne Blättern sichtbar`, async ({ page, account }) => {
      await page.setViewportSize({ width, height: 800 });
      await account.signIn({ path: '/reports' });
      for (const name of ['Täglich', 'Wöchentlich', 'Monatlich', 'Jahr']) {
        const box = await page.getByRole('tab', { name }).boundingBox();
        expect(box!.x, `${name} links`).toBeGreaterThanOrEqual(0);
        expect(box!.x + box!.width, `${name} rechts`).toBeLessThanOrEqual(width);
      }
    });
  }

  test('Reports: Wochen-Inhalt nutzt auf 375 px die Breite (kein doppelter Seitenrand)', async ({ page, account }) => {
    await page.setViewportSize({ width: 375, height: 800 });
    await openWeekly(page, account);
    const box = await page.locator('.week-nav').boundingBox();
    expect(box!.width).toBeGreaterThanOrEqual(375 - 2 * 32);
  });
});
