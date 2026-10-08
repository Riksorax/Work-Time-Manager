import { Page } from '@playwright/test';
import { expect, gotoReady, seedPreferences, test } from './fixtures';
import { freezeTime, openDay, seedEntries, workDay } from './seed';

/** Manuelle Prüfungen aus #385: Banner „Offene Einträge" im Dashboard (Beenden / Später / Fortsetzen). */

const banner = (page: Page) => page.locator('app-open-entry-banner');

async function openDashboard(page: Page, entries: Parameters<typeof seedEntries>[1]): Promise<void> {
  await seedPreferences(page, 'de', 'light');
  await freezeTime(page);
  await seedEntries(page, entries);
  await gotoReady(page, '/dashboard');
}

test.describe('Banner „Offene Einträge" (#385)', () => {
  test('kein Banner ohne offenen Eintrag', async ({ page }) => {
    await openDashboard(page, [workDay('2026-03-16')]);
    await expect(page.getByRole('button', { name: 'Zeiterfassung starten' })).toBeVisible();
    await expect(banner(page)).toHaveCount(0);
  });

  test('zeigt einen älteren offenen Eintrag mit Beenden und Später, ohne Fortsetzen', async ({ page }) => {
    await openDashboard(page, [openDay('2026-03-16')]);
    await expect(banner(page)).toContainText('läuft noch seit 08:00');
    await expect(banner(page).getByRole('button', { name: 'Beenden' })).toBeVisible();
    await expect(banner(page).getByRole('button', { name: 'Später' })).toBeVisible();
    await expect(banner(page).getByRole('button', { name: /fortsetzen/i })).toHaveCount(0);
  });

  test('„Später" blendet das Banner aus, nach Neuladen kommt es wieder', async ({ page }) => {
    await openDashboard(page, [openDay('2026-03-16')]);
    await banner(page).getByRole('button', { name: 'Später' }).click();
    await expect(banner(page)).toHaveCount(0);
    await page.reload();
    await expect(banner(page)).toBeVisible();
  });

  test('„Beenden" öffnet den Dialog und schließt den Eintrag', async ({ page }) => {
    await openDashboard(page, [openDay('2026-03-16')]);
    await banner(page).getByRole('button', { name: 'Beenden' }).click();

    const dialog = page.getByRole('dialog');
    await expect(dialog).toContainText('Ende des Eintrags festlegen');
    await dialog.getByRole('button', { name: 'Eintrag beenden' }).click();

    await expect(dialog).toBeHidden();
    await expect(banner(page)).toHaveCount(0);
    const stored = await page.evaluate(() => JSON.parse(localStorage.getItem('local_work_entries_2026_03')!).days['16']);
    expect(stored.workEnd).not.toBeNull();
  });

  test('„Fortsetzen" setzt einen Eintrag der letzten 24 Stunden fort', async ({ page }) => {
    await openDashboard(page, [openDay('2026-03-17', '12:00')]);
    await banner(page).getByRole('button', { name: /fortsetzen/i }).click();
    await expect(banner(page)).toHaveCount(0);
    await expect(page.getByRole('button', { name: 'Zeiterfassung beenden' })).toBeVisible();
  });

  test('mehrere offene Einträge: Hinweis auf weitere', async ({ page }) => {
    await openDashboard(page, [openDay('2026-03-13'), openDay('2026-03-16')]);
    await expect(banner(page)).toContainText('Noch 1 weiterer offener Eintrag');
  });
});
