import { Page, Route } from '@playwright/test';
import { EMULATORS_ENABLED, expect, test } from './account';

/** Home-Office-Karte im Jahres-Tab (#537) mit Konto: Werte kommen vom Backend (Endpunkt per `page.route` gemockt). */

test.skip(!EMULATORS_ENABLED, 'Firebase-Emulatoren aus (E2E_EMULATORS=1 setzen)');
test.beforeEach(({}, testInfo) => {
  test.skip(testInfo.project.name !== 'chromium', 'Tests mit Konto laufen nur in Chromium');
});

const CORS = {
  'access-control-allow-origin': '*',
  'access-control-allow-headers': '*',
  'access-control-allow-methods': 'GET,OPTIONS',
};

async function mockHomeOffice(page: Page, status = 200): Promise<string[]> {
  const calls: string[] = [];
  await page.route('http://localhost:5100/api/reports/home-office/**', async (route: Route) => {
    if (route.request().method() === 'OPTIONS') return route.fulfill({ status: 204, headers: CORS });
    const url = new URL(route.request().url());
    calls.push(`${url.pathname}?${url.searchParams.toString()}`);
    const year = Number(url.pathname.split('/').at(-1));
    return route.fulfill({
      status,
      headers: { ...CORS, 'content-type': 'application/json' },
      body: JSON.stringify(status !== 200 ? {} : {
        year, homeOfficeDays: 7, officeDays: 5, totalDays: 12, homeOfficeRatio: 7 / 12,
        months: Array.from({ length: 12 }, (_, i) => ({ month: i + 1, homeOfficeDays: 0, officeDays: 0, totalDays: 0, homeOfficeRatio: null })),
        homeOfficeDates: [],
      }),
    });
  });
  return calls;
}

test('Premium: Home-Office-Karte zeigt die Werte des Backends', async ({ page, account }) => {
  const calls = await mockHomeOffice(page);
  await account.setPremium(true);
  await account.signIn({ path: '/reports' });
  await page.getByRole('tab', { name: 'Jahr' }).click();

  const card = page.locator('app-home-office-card');
  await expect(card.locator('.ho-value')).toHaveText('7');
  await expect(card).toContainText('von 12 Arbeitstagen');
  await expect(card).toContainText('58,3 %');
  expect(calls.length).toBeGreaterThan(0);
  expect(calls.every(c => /\/api\/reports\/home-office\/\d{4}\?$/.test(c))).toBe(true);
});

test('Premium: Fehler des Backends zeigt „Erneut versuchen“', async ({ page, account }) => {
  await mockHomeOffice(page, 500);
  await account.setPremium(true);
  await account.signIn({ path: '/reports' });
  await page.getByRole('tab', { name: 'Jahr' }).click();
  await expect(page.locator('app-home-office-card .ho-error')).toContainText('Erneut versuchen');
});
