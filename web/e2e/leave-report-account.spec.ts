import { AxeBuilder } from '@axe-core/playwright';
import { Locator, Page, Route } from '@playwright/test';
import { EMULATORS_ENABLED, expect, test } from './account';
import { horizontalOverflow } from './fixtures';
import { yearlyLeaveResponse } from './leave-report-data';

/**
 * Urlaubs- und Krankheitsauswertung als Druckansicht (#284) mit Konto: Premium lädt und druckt (gemockter Endpunkt),
 * Fehler ohne Druckdialog, getrennter Druck von Auswertung und Jahres-Tab; Free bekommt die Paywall.
 */

test.skip(!EMULATORS_ENABLED, 'Firebase-Emulatoren aus (E2E_EMULATORS=1 setzen)');
test.beforeEach(({}, testInfo) => {
  test.skip(testInfo.project.name !== 'chromium', 'Tests mit Konto laufen nur in Chromium');
});

const CORS = {
  'access-control-allow-origin': '*',
  'access-control-allow-headers': '*',
  'access-control-allow-methods': 'GET,OPTIONS',
};

interface LeaveMock {
  calls: string[];
  /** Nächste Antworten schlagen fehl (500). */
  fail: boolean;
  /** Solange gesetzt, wartet jede Antwort auf dieses Versprechen. */
  hold: Promise<void> | null;
}

/** Ersetzt den Jahres-Endpunkt des Fake-Backends (später registrierte Routen haben Vorrang) und zählt die Aufrufe. */
async function mockYearly(page: Page): Promise<LeaveMock> {
  const mock: LeaveMock = { calls: [], fail: false, hold: null };
  await page.route('http://localhost:5100/api/reports/yearly/*', async (route: Route) => {
    if (route.request().method() === 'OPTIONS') return route.fulfill({ status: 204, headers: CORS });
    const url = new URL(route.request().url());
    mock.calls.push(`${url.pathname}?${url.searchParams.toString()}`);
    if (mock.hold) await mock.hold;
    if (mock.fail) return route.fulfill({ status: 500, headers: CORS, body: '' });
    const year = Number(url.pathname.split('/').at(-1));
    return route.fulfill({
      status: 200,
      headers: { ...CORS, 'content-type': 'application/json' },
      body: JSON.stringify(yearlyLeaveResponse(year)),
    });
  });
  // Der Jahresvergleich (#530) gehört nicht zum Test: leer und schnell beantworten.
  await page.route('http://localhost:5100/api/reports/yearly-comparison/**', route =>
    route.request().method() === 'OPTIONS'
      ? route.fulfill({ status: 204, headers: CORS })
      : route.fulfill({ status: 500, headers: CORS, body: '' }));
  return mock;
}

/** Ersetzt `window.print` (Headless hat keinen Druckdialog) und zählt die Aufrufe. */
async function stubPrint(page: Page): Promise<void> {
  await page.addInitScript(() => {
    (window as unknown as { __prints: number }).__prints = 0;
    window.print = () => { (window as unknown as { __prints: number }).__prints++; };
  });
}

const prints = (page: Page) => page.evaluate(() => (window as unknown as { __prints: number }).__prints);

const leaveButton = (page: Page) => page.getByRole('button', { name: /Urlaub\/Krank|Wird geladen/ });

/** Öffnet den Jahres-Tab und wartet, bis das Premium-Flag aus Firestore angekommen ist (vorher zeigt der Button Free). */
async function openYear(page: Page, premium = true): Promise<void> {
  await page.getByRole('tab', { name: 'Jahr' }).click();
  await expect(page.locator('app-leave-balance-card .leave-header')).toBeVisible();
  await expect(leaveButton(page)).toHaveText(premium ? /Urlaub\/Krank drucken/ : /Urlaub\/Krank mit Premium/);
}

const yearButton = (page: Page) => page.getByRole('button', { name: 'Als PDF speichern / Drucken' });

/** Im Druckmedium trefferbar (nicht abgeschnitten, nicht unsichtbar); wiederholt, weil das Layout nachlaufen kann. */
async function expectHittable(target: Locator, host: string): Promise<void> {
  await expect.poll(() => target.evaluate((node, sel) => {
    const r = node.getBoundingClientRect();
    if (r.width === 0 || r.height === 0) return false;
    node.scrollIntoView();
    const s = node.getBoundingClientRect();
    return !!document.elementFromPoint(s.left + s.width / 2, s.top + s.height / 2)?.closest(sel);
  }, host)).toBe(true);
}

/** Seiten eines echten A4-PDFs (Chromium schreibt die Seitenobjekte unkomprimiert). */
async function pdfPages(page: Page): Promise<number> {
  const pdf = await page.pdf({ format: 'A4', printBackground: true });
  return (pdf.toString('latin1').match(/\/Type\s*\/Page(?![s\w])/g) ?? []).length;
}

/** Die Auswertung nimmt im Druck keinen Platz ein (unsichtbar allein ließe Leerraum oder Leerseiten zurück). */
async function expectNotPrinted(view: Locator): Promise<void> {
  await expect(view).toBeHidden();
  expect(await view.evaluate(n => getComputedStyle(n).display)).toBe('none');
}

/** Laufendes Jahr aus der Uhr des Browsers (nicht aus dem Testprozess). */
const browserYear = (page: Page) => page.evaluate(() => new Date().getFullYear());

test('Premium: lädt Jahr und Profil, druckt nur die Auswertung; der Jahresdruck zeigt sie nicht', async ({ page, account }) => {
  const mock = await mockYearly(page);
  await stubPrint(page);
  await account.setPremium(true);
  await page.setViewportSize({ width: 1280, height: 1000 });
  await account.signIn({ path: '/reports' });
  await openYear(page);
  const year = await browserYear(page);

  // Ohne Auswertung: Jahres-Druck mit neuer Überschrift.
  await expect(leaveButton(page)).toHaveText(/Urlaub\/Krank drucken/);
  const before = mock.calls.length;
  await leaveButton(page).click();
  await expect.poll(() => prints(page)).toBe(1);
  expect(mock.calls.slice(before)).toEqual([`/api/reports/yearly/${year}?`]);

  const view = page.locator('app-leave-report-print');
  await page.emulateMedia({ media: 'print' });
  await expect(view).toBeVisible();
  await expect(view.getByRole('heading', { level: 2 })).toHaveText(`Urlaubs- und Krankheitsauswertung ${year}`);
  await expect(view.locator('tbody tr')).toHaveCount(12);
  await expect(view.locator('.lr-vacation li')).toContainText(['02.01. (1 Tag)', '26.05.–29.05. (4 Tage)']);
  await expect(view.locator('.lr-sick li')).toContainText(['10.02.–12.02. (3 Tage)', '07.10. (1 Tag)']);
  await expect(page.locator('.print-area')).toBeHidden();
  await expectHittable(view.locator('table'), 'app-leave-report-print');
  await expectHittable(view.locator('.lr-footnote'), 'app-leave-report-print');
  expect(await pdfPages(page)).toBe(1);

  // Normaler Jahresdruck danach: Jahres-Tab mit „Jahresauswertung“, ohne die Auswertung.
  await page.emulateMedia({ media: 'screen' });
  await yearButton(page).click();
  await expect.poll(() => prints(page)).toBe(2);
  await page.emulateMedia({ media: 'print' });
  await expect(page.locator('.print-area h2.print-only')).toHaveText(`Jahresauswertung ${year}`);
  await expectNotPrinted(view);
  await expectHittable(page.locator('app-leave-balance-card'), '.print-area');
  expect(await pdfPages(page)).toBeGreaterThanOrEqual(1);
});

test('Premium: nach dem Druck (afterprint) zeigt ein normaler Druck wieder nur den Jahres-Tab', async ({ page, account }) => {
  await mockYearly(page);
  await stubPrint(page);
  await account.setPremium(true);
  await account.signIn({ path: '/reports' });
  await openYear(page);
  const year = await browserYear(page);
  await page.emulateMedia({ media: 'print' });
  const pagesBefore = await pdfPages(page);
  await page.emulateMedia({ media: 'screen' });
  await leaveButton(page).click();
  await expect.poll(() => prints(page)).toBe(1);
  // Der Browser meldet das Ende des Drucks; danach etwa Strg+P (ohne Button).
  await page.evaluate(() => window.dispatchEvent(new Event('afterprint')));
  await page.emulateMedia({ media: 'print' });
  await expect(page.locator('.print-area h2.print-only')).toHaveText(`Jahresauswertung ${year}`);
  await expectNotPrinted(page.locator('app-leave-report-print'));
  await expectHittable(page.locator('app-leave-balance-card'), '.print-area');
  expect(await pdfPages(page)).toBe(pagesBefore);
});

test('Premium: Ladezustand sperrt den Button, Fehler meldet und öffnet keinen Druckdialog', async ({ page, account }) => {
  const mock = await mockYearly(page);
  await stubPrint(page);
  await account.setPremium(true);
  await account.signIn({ path: '/reports' });
  await openYear(page);

  let release!: () => void;
  mock.hold = new Promise<void>(r => (release = r));
  mock.fail = true;
  await leaveButton(page).click();
  await expect(leaveButton(page)).toBeDisabled();
  await expect(leaveButton(page)).toHaveText(/Wird geladen/);
  mock.hold = null;
  release();

  await expect(page.locator('mat-snack-bar-container'))
    .toContainText('Die Urlaubs- und Krankheitsauswertung konnte nicht geladen werden.');
  await expect(leaveButton(page)).toBeEnabled();
  await expect(leaveButton(page)).toHaveText(/Urlaub\/Krank drucken/);
  expect(await prints(page)).toBe(0);
  await expect(page.locator('app-leave-report-print')).toHaveCount(0);
});

test('Premium: Zusatzprofil mit Profilname und profileId', async ({ page, account }) => {
  const mock = await mockYearly(page);
  await stubPrint(page);
  await account.setPremium(true);
  const profileId = await account.addProfile('Nebenjob');
  await account.signIn({ path: '/reports' });
  await page.getByRole('button', { name: 'Profil wechseln' }).click();
  await page.getByRole('menuitem', { name: /Nebenjob/ }).click();
  await openYear(page);
  const year = await browserYear(page);

  await leaveButton(page).click();
  await expect.poll(() => prints(page)).toBe(1);
  expect(mock.calls.at(-1)).toBe(`/api/reports/yearly/${year}?profileId=${profileId}`);
  await page.emulateMedia({ media: 'print' });
  await expect(page.locator('app-leave-report-print .lr-meta')).toContainText('Profil: Nebenjob');
});

test('Premium: 320 px ohne Überlauf, beide Buttons sichtbar, axe', async ({ page, account }) => {
  await mockYearly(page);
  await account.setPremium(true);
  await page.setViewportSize({ width: 320, height: 800 });
  await account.signIn({ path: '/reports' });
  await openYear(page);
  await expect(yearButton(page)).toBeVisible();
  await expect(leaveButton(page)).toBeVisible();
  // Wiederholt geprüft: die Tab-Animation schiebt den Inhalt anfangs noch von der Seite herein.
  for (const b of [yearButton(page), leaveButton(page)]) {
    await expect.poll(async () => {
      const box = (await b.boundingBox())!;
      return box.x >= 0 && box.x + box.width <= 320;
    }).toBe(true);
  }
  expect(await horizontalOverflow(page)).toBeLessThanOrEqual(0);
  const result = await new AxeBuilder({ page }).include('.print-actions').withTags(['wcag2a', 'wcag2aa']).analyze();
  const serious = result.violations
    .filter(v => v.impact === 'serious' || v.impact === 'critical')
    .map(v => `${v.id}: ${v.nodes.slice(0, 3).map(n => n.target.join(' ')).join(' | ')}`);
  expect(serious).toEqual([]);
});

test('Free: gesperrter Button öffnet die Paywall, kein Laden, kein Druck', async ({ page, account }) => {
  const mock = await mockYearly(page);
  await stubPrint(page);
  await account.signIn({ path: '/reports' });
  await openYear(page, false);
  const before = mock.calls.length;
  await leaveButton(page).click();
  // Ohne konfiguriertes RC Billing (E2E) meldet die Paywall das per Snackbar.
  await expect(page.locator('mat-snack-bar-container')).toContainText('RevenueCat ist nicht konfiguriert');
  expect(mock.calls.length).toBe(before);
  expect(await prints(page)).toBe(0);
  const result = await new AxeBuilder({ page }).include('.print-actions').withTags(['wcag2a', 'wcag2aa']).analyze();
  expect(result.violations.filter(v => v.impact === 'serious' || v.impact === 'critical')).toEqual([]);
});
