import { Page } from '@playwright/test';
import { expect, gotoReady, seedPreferences, test } from './fixtures';
import { freezeTime, seedEntries, workDay } from './seed';

/** Manuelle Prüfungen aus #377: Kalender per Tastatur und Mehrfachauswahl. */

const cell = (page: Page, day: string) => page.locator(`[role="gridcell"][data-date="${day}"]`);

async function openReports(page: Page): Promise<void> {
  await seedPreferences(page, 'de', 'light');
  await freezeTime(page);
  await seedEntries(page, [workDay('2026-03-10'), workDay('2026-03-11')]);
  await gotoReady(page, '/reports');
  await expect(page.getByRole('grid')).toBeVisible();
}

test.describe('Kalender (#377)', () => {
  test('markiert heute und Tage mit Eintrag', async ({ page }) => {
    await openReports(page);
    await expect(cell(page, '2026-03-18')).toHaveAttribute('aria-current', 'date');
    await expect(cell(page, '2026-03-10')).toHaveClass(/has-entry/);
    await expect(cell(page, '2026-03-10')).toHaveAttribute('aria-label', /Eintrag/);
    await expect(cell(page, '2026-03-12')).not.toHaveClass(/has-entry/);
  });

  test('Pfeiltasten bewegen den Fokus, Enter wählt den Tag', async ({ page }) => {
    await openReports(page);
    await cell(page, '2026-03-10').focus();

    await page.keyboard.press('ArrowRight');
    await expect(cell(page, '2026-03-11')).toBeFocused();
    await page.keyboard.press('ArrowDown');
    await expect(cell(page, '2026-03-18')).toBeFocused();
    await page.keyboard.press('ArrowLeft');
    await expect(cell(page, '2026-03-17')).toBeFocused();
    await page.keyboard.press('Home');
    await expect(cell(page, '2026-03-16')).toBeFocused();
    await page.keyboard.press('End');
    await expect(cell(page, '2026-03-22')).toBeFocused();

    // Der Fokus folgt nicht der Auswahl: erst Enter wählt aus.
    await page.keyboard.press('Enter');
    await expect(cell(page, '2026-03-22')).toHaveClass(/selected/);
  });

  test('PageUp/PageDown wechseln den Monat', async ({ page }) => {
    await openReports(page);
    await cell(page, '2026-03-18').focus();
    await page.keyboard.press('PageDown');
    await expect(cell(page, '2026-04-18')).toBeFocused();
    // Nach jedem Tastendruck auf den Fokus im neuen Monat warten, sonst geht ein Druck während des Neuaufbaus verloren.
    await page.keyboard.press('PageUp');
    await expect(cell(page, '2026-03-18')).toBeFocused();
    await page.keyboard.press('PageUp');
    await expect(cell(page, '2026-02-18')).toBeFocused();
  });

  test('es gibt genau einen Tab-Stopp im Gitter (Roving Tabindex)', async ({ page }) => {
    await openReports(page);
    await expect(page.locator('[role="gridcell"][tabindex="0"]')).toHaveCount(1);
  });
});

test.describe('Mehrfachauswahl per Tastatur (#377)', () => {
  test('Umschalt+Pfeil wählt einen Bereich, Escape beendet den Modus', async ({ page }) => {
    await openReports(page);
    const toggle = page.getByRole('button', { name: 'Mehrfachauswahl', exact: true });
    await expect(toggle).toHaveAttribute('aria-pressed', 'false');
    await toggle.click();
    await expect(toggle).toHaveAttribute('aria-pressed', 'true');
    await expect(page.getByRole('grid')).toHaveAttribute('aria-multiselectable', 'true');

    await cell(page, '2026-03-10').focus();
    await page.keyboard.press('Enter');
    await page.keyboard.press('Shift+ArrowRight');
    await page.keyboard.press('Shift+ArrowRight');
    await expect(page.locator('.calendar-day.multi-selected')).toHaveCount(3);

    // Verkleinern nimmt den zuletzt gewählten Tag wieder heraus.
    await page.keyboard.press('Shift+ArrowLeft');
    await expect(page.locator('.calendar-day.multi-selected')).toHaveCount(2);

    await page.keyboard.press('Escape');
    await expect(toggle).toHaveAttribute('aria-pressed', 'false');
    await expect(page.getByRole('grid')).not.toHaveAttribute('aria-multiselectable', 'true');
  });
});
