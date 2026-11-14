import { AxeBuilder } from '@axe-core/playwright';
import { Page, Route } from '@playwright/test';
import { EMULATORS_ENABLED, expect, test } from './account';
import { trendResponse } from './trend-data';

/** Tab „Trend“ (#531) mit Konto: Premium sieht die Diagramme (gemockte API-Antwort), Free die gesperrte Karte. */

test.skip(!EMULATORS_ENABLED, 'Firebase-Emulatoren aus (E2E_EMULATORS=1 setzen)');
test.beforeEach(({}, testInfo) => {
  test.skip(testInfo.project.name !== 'chromium', 'Tests mit Konto laufen nur in Chromium');
});

const CORS = {
  'access-control-allow-origin': '*',
  'access-control-allow-headers': '*',
  'access-control-allow-methods': 'GET,OPTIONS',
};

/** Ersetzt den Trend-Endpunkt des Fake-Backends (später registrierte Routen haben Vorrang) und zählt die Aufrufe. */
async function mockTrend(page: Page): Promise<string[]> {
  const calls: string[] = [];
  await page.route('http://localhost:5100/api/reports/trend/**', async (route: Route) => {
    if (route.request().method() === 'OPTIONS') return route.fulfill({ status: 204, headers: CORS });
    const url = new URL(route.request().url());
    calls.push(`${url.pathname}?${url.searchParams.toString()}`);
    const [y, m, d] = url.pathname.split('/').slice(-3).map(Number);
    return route.fulfill({
      status: 200,
      headers: { ...CORS, 'content-type': 'application/json' },
      body: JSON.stringify(trendResponse(y, m, d, url.searchParams.get('granularity') ?? 'week', { gaps: [3] })),
    });
  });
  return calls;
}

async function openTrend(page: Page): Promise<void> {
  await page.getByRole('tab', { name: 'Trend' }).click();
}

test('Premium: Wochen-Trend und beide Diagramme, Umschalten auf 12 Monate', async ({ page, account }) => {
  const calls = await mockTrend(page);
  await account.setPremium(true);
  await account.signIn({ path: '/reports' });
  await openTrend(page);

  const view = page.locator('app-trend-view');
  await expect(view.getByText('+02:30 h gegenüber dem Durchschnitt der letzten 4 Wochen')).toBeVisible();
  await expect(view.locator('app-bar-chart .chart-slot')).toHaveCount(12);
  await expect(view.locator('app-line-chart .chart-slot')).toHaveCount(12);
  await expect(view.locator('app-bar-chart .chart-slot.is-gap')).toHaveCount(1);
  await expect(view.locator('app-bar-chart .chart-slot').last()).toHaveClass(/is-partial/);
  expect(calls.at(-1)).toContain('granularity=week');

  // Tastatur: Fokus auf den jüngsten Balken, Pfeil links zeigt den Wert des Vorgängers.
  await view.locator('app-bar-chart .chart-slot[tabindex="0"]').focus();
  await page.keyboard.press('ArrowLeft');
  await expect(view.locator('app-bar-chart .chart-detail')).toContainText('Ist 41:30 · Soll 40:00');

  await view.getByRole('radio', { name: '12 Monate' }).click();
  await expect(view.getByRole('heading', { name: 'Arbeitszeit je Monat' })).toBeVisible();
  expect(calls.at(-1)).toContain('granularity=month');
});

test('Premium: axe ohne ernste Verstöße in der Trend-Ansicht', async ({ page, account }) => {
  await mockTrend(page);
  await account.setPremium(true);
  await account.signIn({ path: '/reports' });
  await openTrend(page);
  await expect(page.locator('app-trend-view app-bar-chart .chart-slot')).toHaveCount(12);
  const result = await new AxeBuilder({ page }).include('app-trend-view').withTags(['wcag2a', 'wcag2aa']).analyze();
  const serious = result.violations
    .filter(v => v.impact === 'serious' || v.impact === 'critical')
    .map(v => `${v.id}: ${v.nodes.slice(0, 3).map(n => n.target.join(' ')).join(' | ')}`);
  expect(serious).toEqual([]);
});

test('Free: gesperrte Karte, kein Aufruf des Trend-Endpunkts', async ({ page, account }) => {
  const calls = await mockTrend(page);
  await account.signIn({ path: '/reports' });
  await openTrend(page);
  await expect(page.locator('.mat-mdc-tab-body-active .premium-overlay')).toContainText('Trend — Premium');
  await expect(page.locator('app-trend-view')).toHaveCount(0);
  expect(calls).toEqual([]);
});
