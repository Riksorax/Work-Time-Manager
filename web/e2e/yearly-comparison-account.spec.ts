import { AxeBuilder } from '@axe-core/playwright';
import { Page, Route } from '@playwright/test';
import { EMULATORS_ENABLED, expect, test } from './account';
import { horizontalOverflow } from './fixtures';
import { yearlyComparisonResponse } from './yearly-comparison-data';

/** Jahresvergleich im Jahres-Tab (#530) mit Konto: Premium sieht die Karte (gemockte API-Antwort), Free die gesperrte Karte. */

test.skip(!EMULATORS_ENABLED, 'Firebase-Emulatoren aus (E2E_EMULATORS=1 setzen)');
test.beforeEach(({}, testInfo) => {
  test.skip(testInfo.project.name !== 'chromium', 'Tests mit Konto laufen nur in Chromium');
});

const CORS = {
  'access-control-allow-origin': '*',
  'access-control-allow-headers': '*',
  'access-control-allow-methods': 'GET,OPTIONS',
};

/** Ersetzt den Endpunkt des Fake-Backends (später registrierte Routen haben Vorrang) und zählt die Aufrufe. */
async function mockComparison(page: Page): Promise<string[]> {
  const calls: string[] = [];
  await page.route('http://localhost:5100/api/reports/yearly-comparison/**', async (route: Route) => {
    if (route.request().method() === 'OPTIONS') return route.fulfill({ status: 204, headers: CORS });
    const url = new URL(route.request().url());
    calls.push(`${url.pathname}?${url.searchParams.toString()}`);
    const year = Number(url.pathname.split('/').at(-1));
    return route.fulfill({
      status: 200,
      headers: { ...CORS, 'content-type': 'application/json' },
      body: JSON.stringify(yearlyComparisonResponse(year, { until: url.searchParams.get('until') })),
    });
  });
  return calls;
}

async function openYear(page: Page): Promise<void> {
  await page.getByRole('tab', { name: 'Jahr' }).click();
}

/** Laufendes Jahr und heutiger Tag `MM-dd` aus der Uhr des Browsers (nicht aus dem Testprozess). */
async function browserToday(page: Page): Promise<{ year: number; mmdd: string }> {
  return page.evaluate(() => {
    const d = new Date();
    return {
      year: d.getFullYear(),
      mmdd: `${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`,
    };
  });
}

test('Premium: Vergleich mit Stichtag im laufenden Jahr, Vorjahr ohne Stichtag', async ({ page, account }) => {
  const calls = await mockComparison(page);
  await account.setPremium(true);
  await account.signIn({ path: '/reports' });
  await openYear(page);
  const today = await browserToday(page);

  const card = page.locator('app-yearly-comparison-card');
  await expect(card.getByRole('heading', { name: `Vergleich ${today.year} mit ${today.year - 1}` })).toBeVisible();
  await expect(card.getByRole('table')).toBeVisible();
  await expect(card.getByRole('rowheader')).toHaveCount(6);
  await expect(card.getByRole('columnheader', { name: 'Differenz' })).toBeVisible();
  await expect(card.locator('.yc-until')).toContainText('beide Jahre jeweils bis');
  expect(calls.at(-1)).toBe(`/api/reports/yearly-comparison/${today.year}?until=${today.mmdd}`);

  await page.getByRole('button', { name: 'Vorheriges Jahr' }).click();
  await expect(card.getByRole('heading', { name: `Vergleich ${today.year - 1} mit ${today.year - 2}` })).toBeVisible();
  await expect(card.locator('.yc-until')).toHaveCount(0);
  expect(calls.at(-1)).toBe(`/api/reports/yearly-comparison/${today.year - 1}?`);
});

test('Premium: axe ohne ernste Verstöße, kein Überlauf bei 320 px', async ({ page, account }) => {
  await mockComparison(page);
  await account.setPremium(true);
  await page.setViewportSize({ width: 320, height: 800 });
  await account.signIn({ path: '/reports' });
  await openYear(page);
  await expect(page.locator('app-yearly-comparison-card table')).toBeVisible();
  expect(await horizontalOverflow(page)).toBeLessThanOrEqual(0);
  const result = await new AxeBuilder({ page }).include('app-yearly-comparison-card').withTags(['wcag2a', 'wcag2aa']).analyze();
  const serious = result.violations
    .filter(v => v.impact === 'serious' || v.impact === 'critical')
    .map(v => `${v.id}: ${v.nodes.slice(0, 3).map(n => n.target.join(' ')).join(' | ')}`);
  expect(serious).toEqual([]);
});

test('Premium: Karte erscheint im Druck (Druckbereich wird nicht vom Tab-Container abgeschnitten)', async ({ page, account }) => {
  await mockComparison(page);
  await account.setPremium(true);
  await page.setViewportSize({ width: 1280, height: 1600 });
  await account.signIn({ path: '/reports' });
  await openYear(page);
  await expect(page.locator('app-yearly-comparison-card table')).toBeVisible();

  await page.emulateMedia({ media: 'print' });
  await expect(page.locator('.print-area .print-only')).toBeVisible();
  // Treffertest in der Mitte der Tabelle: abgeschnittene oder unsichtbare Elemente sind nicht trefferbar.
  // Wiederholt geprüft: Layout und Tab-Animation können nach dem Medienwechsel noch nachlaufen.
  await expect.poll(() => page.locator('app-yearly-comparison-card table').evaluate(table => {
    const r = table.getBoundingClientRect();
    return !!document.elementFromPoint(r.left + r.width / 2, r.top + r.height / 2)?.closest('app-yearly-comparison-card');
  })).toBe(true);
  await expect(page.locator('app-yearly-comparison-card .yc-error button')).toHaveCount(0);
});

test('Free: gesperrte Karte, kein Aufruf des Endpunkts, axe', async ({ page, account }) => {
  const calls = await mockComparison(page);
  await account.signIn({ path: '/reports' });
  await openYear(page);
  const locked = page.locator('app-yearly-comparison-locked');
  await expect(locked).toContainText('Vergleich mit dem Vorjahr — Premium');
  await expect(page.locator('app-yearly-comparison-card')).toHaveCount(0);
  const result = await new AxeBuilder({ page }).include('app-yearly-comparison-locked').withTags(['wcag2a', 'wcag2aa']).analyze();
  expect(result.violations.filter(v => v.impact === 'serious' || v.impact === 'critical')).toEqual([]);
  expect(calls).toEqual([]);
});
