import { AxeBuilder } from '@axe-core/playwright';
import { Page, Route } from '@playwright/test';
import { EMULATORS_ENABLED, expect, test } from './account';
import { TrendMockOptions, trendResponse } from './trend-data';

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
async function mockTrend(page: Page, opts: TrendMockOptions = {}): Promise<string[]> {
  const calls: string[] = [];
  await page.route('http://localhost:5100/api/reports/trend/**', async (route: Route) => {
    if (route.request().method() === 'OPTIONS') return route.fulfill({ status: 204, headers: CORS });
    const url = new URL(route.request().url());
    calls.push(`${url.pathname}?${url.searchParams.toString()}`);
    const [y, m, d] = url.pathname.split('/').slice(-3).map(Number);
    return route.fulfill({
      status: 200,
      headers: { ...CORS, 'content-type': 'application/json' },
      body: JSON.stringify(trendResponse(y, m, d, url.searchParams.get('granularity') ?? 'week', { gaps: [3], ...opts })),
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

test('Premium: Prognose zum Jahresende unter dem Wochen-Trend, in beiden Zeitfenstern gleich', async ({ page, account }) => {
  await mockTrend(page);
  await account.setPremium(true);
  await account.signIn({ path: '/reports' });
  await openTrend(page);

  const card = page.locator('app-trend-view .trend-forecast');
  await expect(card.getByRole('heading', { name: 'Prognose zum Jahresende' })).toBeVisible();
  await expect(card).toContainText(/Voraussichtlich \+27:30 h zum 31\.12\.\d{4}/);
  await expect(card).toContainText('Aktueller Saldo +18:45 h · im Schnitt +01:15 h pro Woche (letzte 6 Wochen) · noch rund 7 Wochen');
  await expect(card).toContainText('Geplanter Urlaub und Feiertage sind nicht berücksichtigt.');
  const before = await card.innerText();

  await page.locator('app-trend-view').getByRole('radio', { name: '12 Monate' }).click();
  await expect(page.getByRole('heading', { name: 'Arbeitszeit je Monat' })).toBeVisible();
  expect(await card.innerText()).toBe(before);
});

test('Premium: negative Prognose mit Minus, ohne Prognose ein Hinweis', async ({ page, account }) => {
  await mockTrend(page, { forecast: 'negative' });
  await account.setPremium(true);
  await account.signIn({ path: '/reports' });
  await openTrend(page);
  await expect(page.locator('app-trend-view .trend-forecast')).toContainText(/Voraussichtlich -07:45 h zum 31\.12\.\d{4}/);

  await mockTrend(page, { forecast: null });
  await page.reload();
  await openTrend(page);
  const card = page.locator('app-trend-view .trend-forecast');
  await expect(card).toContainText('Für eine Prognose fehlen noch Daten (mindestens 4 der letzten 8 Wochen mit Einträgen).');
  await expect(card).not.toContainText('Voraussichtlich');
});

test('Premium: Prognose-Karte läuft bei 320 px nicht über, axe ohne Befund', async ({ page, account }) => {
  await mockTrend(page);
  await account.setPremium(true);
  await page.setViewportSize({ width: 320, height: 800 });
  await account.signIn({ path: '/reports' });
  await openTrend(page);
  const card = page.locator('app-trend-view .trend-forecast');
  await expect(card).toBeVisible();
  // Der Tab-Inhalt gleitet beim Wechsel herein: erst messen, wenn die Karte ihre Endlage erreicht hat.
  await expect.poll(async () => {
    const box = await card.boundingBox();
    return box ? box.x >= 0 && box.x + box.width <= 320 : false;
  }, { timeout: 5000 }).toBe(true);
  expect(await card.evaluate(e => e.scrollWidth <= e.clientWidth)).toBe(true);
  const result = await new AxeBuilder({ page }).include('app-trend-view .trend-forecast').withTags(['wcag2a', 'wcag2aa']).analyze();
  expect(result.violations.map(v => v.id)).toEqual([]);
});

test('Free: gesperrte Karte, kein Aufruf des Trend-Endpunkts', async ({ page, account }) => {
  const calls = await mockTrend(page);
  await account.signIn({ path: '/reports' });
  await openTrend(page);
  await expect(page.locator('.mat-mdc-tab-body-active .premium-overlay')).toContainText('Trend — Premium');
  await expect(page.locator('app-trend-view')).toHaveCount(0);
  expect(calls).toEqual([]);
});
