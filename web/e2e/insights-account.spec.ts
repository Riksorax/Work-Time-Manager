import { AxeBuilder } from '@axe-core/playwright';
import { Page, Route } from '@playwright/test';
import { EMULATORS_ENABLED, expect, test } from './account';
import { horizontalOverflow } from './fixtures';
import { InsightsMockOptions, insightsResponse } from './insights-data';

/** Tab „Insights“ (#537) mit Konto: Premium sieht die drei Bereiche (gemockte API-Antwort), Free die gesperrte Karte. */

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
async function mockInsights(page: Page, opts: InsightsMockOptions = {}): Promise<string[]> {
  const calls: string[] = [];
  await page.route('http://localhost:5100/api/reports/insights/**', async (route: Route) => {
    if (route.request().method() === 'OPTIONS') return route.fulfill({ status: 204, headers: CORS });
    const url = new URL(route.request().url());
    calls.push(`${url.pathname}?${url.searchParams.toString()}`);
    const [y, m] = url.pathname.split('/').slice(-3).map(Number);
    return route.fulfill({
      status: 200,
      headers: { ...CORS, 'content-type': 'application/json' },
      body: JSON.stringify(insightsResponse(y, m, url.searchParams.get('tz') ?? '', opts)),
    });
  });
  return calls;
}

async function openInsights(page: Page): Promise<void> {
  await page.getByRole('tab', { name: 'Insights' }).click();
}

/** Heutiger Kalendertag im Browser (Playwright-Zone Europe/Berlin, nicht die des Testprozesses). */
async function browserToday(page: Page): Promise<string> {
  return page.evaluate(() => {
    const d = new Date();
    return `${d.getFullYear()}/${d.getMonth() + 1}/${d.getDate()}`;
  });
}

test('Premium: Tab zeigt Wochentage, Serie und Heatmap; Aufruf mit heutigem Tag und Zone', async ({ page, account }) => {
  const calls = await mockInsights(page, { warning: true });
  await account.setPremium(true);
  await account.signIn({ path: '/reports' });
  await openInsights(page);

  const view = page.locator('app-insights-view');
  await expect(view.getByRole('heading', { name: 'Wochentags-Analyse' })).toBeVisible();
  await expect(view.getByRole('heading', { name: 'Überstunden-Serie' })).toBeVisible();
  await expect(view.getByRole('heading', { name: 'Startzeit-Heatmap' })).toBeVisible();
  await expect(view.locator('.ins-weekday')).toHaveCount(6);
  await expect(view.locator('.ins-weekday').first()).toContainText('Montag');
  await expect(view.locator('.ins-weekday').first()).toContainText('+00:32');
  await expect(view.locator('.ins-heat')).toHaveCount(5);
  await expect(view.locator('.ins-heat').first()).toContainText('Start 06:00 Uhr');
  await expect(view.locator('.ins-warning')).toContainText('Du liegst seit 7 aufeinanderfolgenden Arbeitstagen über deinem Soll.');
  await expect(view.locator('.ins-period')).toContainText('Zeitraum:');

  const today = await browserToday(page);
  expect(calls.at(-1)).toBe(`/api/reports/insights/${today}?tz=Europe%2FBerlin`);
});

test('Premium: axe ohne ernste Verstöße in der Insights-Ansicht', async ({ page, account }) => {
  await mockInsights(page, { warning: true });
  await account.setPremium(true);
  await account.signIn({ path: '/reports' });
  await openInsights(page);
  await expect(page.locator('app-insights-view .ins-heat')).toHaveCount(5);
  const result = await new AxeBuilder({ page }).include('app-insights-view').withTags(['wcag2a', 'wcag2aa']).analyze();
  const serious = result.violations
    .filter(v => v.impact === 'serious' || v.impact === 'critical')
    .map(v => `${v.id}: ${v.nodes.slice(0, 3).map(n => n.target.join(' ')).join(' | ')}`);
  expect(serious).toEqual([]);
});

test('Premium: bei 320 px kein horizontales Überlaufen', async ({ page, account }) => {
  await mockInsights(page, { warning: true });
  await account.setPremium(true);
  await page.setViewportSize({ width: 320, height: 800 });
  await account.signIn({ path: '/reports' });
  await openInsights(page);
  const view = page.locator('app-insights-view');
  await expect(view.locator('.ins-heat')).toHaveCount(5);
  // Der Tab-Inhalt gleitet beim Wechsel herein: erst messen, wenn die Ansicht ihre Endlage erreicht hat.
  await expect.poll(async () => {
    const box = await view.boundingBox();
    return box ? box.x >= 0 && box.x + box.width <= 320 : false;
  }, { timeout: 5000 }).toBe(true);
  expect(await horizontalOverflow(page)).toBe(0);
  for (const sel of ['.ins-weekdays', '.ins-streak', '.ins-heatmap', '.ins-warning']) {
    expect(await view.locator(sel).evaluate(e => e.scrollWidth <= e.clientWidth), sel).toBe(true);
  }
});

test('Premium: Leerzustand ohne Daten', async ({ page, account }) => {
  await mockInsights(page, { empty: true });
  await account.setPremium(true);
  await account.signIn({ path: '/reports' });
  await openInsights(page);
  await expect(page.locator('app-insights-view .ins-empty')).toContainText('Noch nicht genug Daten für Insights');
  await expect(page.locator('app-insights-view .ins-weekdays')).toHaveCount(0);
});

test('Free: gesperrte Karte, kein Aufruf des Insights-Endpunkts', async ({ page, account }) => {
  const calls = await mockInsights(page);
  await account.signIn({ path: '/reports' });
  await openInsights(page);
  await expect(page.locator('.mat-mdc-tab-body-active .premium-overlay')).toContainText('Insights — Premium');
  await expect(page.locator('app-insights-view')).toHaveCount(0);
  expect(calls).toEqual([]);
});
