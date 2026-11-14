import { AxeBuilder } from '@axe-core/playwright';
import { expect, gotoReady, seedPreferences, test, Theme } from './fixtures';
import { freezeTime, seedEntries, seedSettings, workDay } from './seed';

/** Arbeitsorte (#526): Einstellung, Dashboard-Button, Dialog mit Vorschlägen, Home-Office-Schalter. Ohne Konto (localStorage). */

const HISTORY = [
  workDay('2026-03-16', { workLocations: ['Büro Nord'] }),
  workDay('2026-03-17', { workLocations: ['Kunde', 'Home Base'] }),
];

test.describe('Arbeitsorte im Dashboard', () => {
  test.beforeEach(async ({ page }) => {
    await seedPreferences(page, 'de', 'light');
    await freezeTime(page);
    await seedEntries(page, HISTORY);
  });

  test('Standard: kein Button, Home-Office-Schalter sichtbar (heutiger Zustand)', async ({ page }) => {
    await gotoReady(page, '/dashboard');
    await expect(page.getByRole('switch', { name: 'Von zu Hause gearbeitet' })).toBeVisible();
    await expect(page.getByRole('button', { name: 'Arbeitsort hinzufügen' })).toHaveCount(0);
  });

  test('Einstellung einschalten, Orte hinzufügen, Vorschlag wählen, entfernen, speichern', async ({ page }) => {
    await gotoReady(page, '/settings');
    const toggle = page.getByRole('switch', { name: 'Arbeitsort im Dashboard anzeigen' });
    await expect(toggle).not.toBeChecked();
    await toggle.click();
    await expect(toggle).toBeChecked();

    await page.reload();
    await expect(page.getByRole('switch', { name: 'Arbeitsort im Dashboard anzeigen' })).toBeChecked();

    await gotoReady(page, '/dashboard');
    await page.getByRole('button', { name: 'Arbeitsort hinzufügen' }).click();
    const dialog = page.getByRole('dialog');
    const field = dialog.getByLabel('Arbeitsort', { exact: true });
    await expect(field).toBeFocused();

    // Hinzufügen mit Enter, Leerzeichen werden getrimmt
    await field.fill('  Büro Süd ');
    await field.press('Enter');
    await expect(dialog.locator('mat-chip').filter({ hasText: 'Büro Süd' })).toHaveCount(1);

    // Duplikat wird nicht übernommen und erklärt
    await field.fill('büro süd');
    await field.press('Enter');
    await expect(dialog.getByText('Dieser Ort ist schon eingetragen.')).toBeVisible();
    await expect(dialog.locator('mat-chip').filter({ hasText: 'Büro Süd' })).toHaveCount(1);

    // Vorschläge: zuletzt verwendete zuerst, ohne den schon gewählten Ort
    await field.fill('');
    await field.click();
    const options = page.getByRole('option');
    await expect(options).toHaveText(['Kunde', 'Home Base', 'Büro Nord']);
    await page.getByRole('option', { name: 'Home Base' }).click();
    await expect(dialog.locator('mat-chip').filter({ hasText: 'Home Base' })).toHaveCount(1);

    // Entfernen
    await dialog.getByRole('button', { name: 'Büro Süd entfernen' }).click();
    await expect(dialog.locator('mat-chip').filter({ hasText: 'Büro Süd' })).toHaveCount(0);

    await dialog.getByRole('button', { name: 'Speichern' }).click();
    await expect(dialog).toHaveCount(0);

    const summary = page.getByRole('button', { name: 'Arbeitsorte bearbeiten: Home Base' });
    await expect(summary).toBeVisible();
    await expect(page.getByRole('button', { name: 'Arbeitsort hinzufügen' })).toHaveCount(0);

    // Klick auf die Zeile öffnet denselben Dialog mit dem Stand
    await summary.click();
    await expect(page.getByRole('dialog').locator('mat-chip').filter({ hasText: 'Home Base' })).toHaveCount(1);
    // Escape bricht ab (auch bei offener Vorschlagsliste, die beim Fokussieren aufgeht): der Stand bleibt
    await page.keyboard.press('Escape');
    await expect(page.getByRole('dialog')).toHaveCount(0);
    await expect(summary).toBeVisible();
  });

  test('bei 5 Orten ist das Hinzufügen gesperrt und erklärt', async ({ page }) => {
    await seedSettings(page, { showWorkLocationOnDashboard: true });
    await gotoReady(page, '/dashboard');
    await page.getByRole('button', { name: 'Arbeitsort hinzufügen' }).click();
    const dialog = page.getByRole('dialog');
    const field = dialog.getByLabel('Arbeitsort', { exact: true });
    for (const name of ['A', 'B', 'C', 'D', 'E']) {
      await field.fill(name);
      await field.press('Enter');
    }
    await expect(field).toBeDisabled();
    await expect(dialog.getByText(/Höchstens 5 Orte pro Tag/)).toBeVisible();
  });

  test('Einstellung aus: kein Button, auch wenn Orte gespeichert sind', async ({ page }) => {
    await seedSettings(page, { showWorkLocationOnDashboard: false });
    await gotoReady(page, '/dashboard');
    await expect(page.getByRole('button', { name: 'Arbeitsort hinzufügen' })).toHaveCount(0);
    await expect(page.locator('.work-locations-summary')).toHaveCount(0);
  });

  test('Home-Office im Dashboard ausblenden entfernt nur den Schalter', async ({ page }) => {
    await seedSettings(page, { showWorkLocationOnDashboard: true, showHomeOfficeOnDashboard: false });
    await gotoReady(page, '/dashboard');
    await expect(page.getByRole('switch', { name: 'Von zu Hause gearbeitet' })).toHaveCount(0);
    await expect(page.getByRole('button', { name: 'Arbeitsort hinzufügen' })).toBeVisible();
  });

  test('Berichte zeigen die Orte unabhängig von den Dashboard-Einstellungen', async ({ page }) => {
    await seedSettings(page, { showWorkLocationOnDashboard: false, showHomeOfficeOnDashboard: false });
    await gotoReady(page, '/reports');
    await page.locator('[role="gridcell"][data-date="2026-03-17"]').click();
    await expect(page.locator('.work-location-chip')).toHaveCount(1);
    await expect(page.locator('.work-location-chip')).toContainText('Kunde, Home Base');
  });
});

test.describe('Arbeitsorte: axe', () => {
  test.skip(({ browserName }) => browserName !== 'chromium', 'axe läuft nur in Chromium');

  for (const theme of ['light', 'dark'] as Theme[]) {
    test(`Dialog mit Orten und aufgeklappten Vorschlägen (${theme})`, async ({ page }) => {
      await seedPreferences(page, 'de', theme);
      await freezeTime(page);
      await seedEntries(page, HISTORY);
      await seedSettings(page, { showWorkLocationOnDashboard: true });
      await gotoReady(page, '/dashboard');
      await page.getByRole('button', { name: 'Arbeitsort hinzufügen' }).click();
      const field = page.getByRole('dialog').getByLabel('Arbeitsort', { exact: true });
      await field.fill('Büro Süd');
      await field.press('Enter');
      await field.click();
      await expect(page.getByRole('option').first()).toBeVisible();
      const result = await new AxeBuilder({ page }).withTags(['wcag2a', 'wcag2aa']).analyze();
      const serious = result.violations
        .filter(v => v.impact === 'serious' || v.impact === 'critical')
        .map(v => `${v.id}: ${v.nodes.length}× (${v.nodes.slice(0, 3).map(n => n.target.join(' ')).join(' | ')})`);
      expect(serious).toEqual([]);
    });

    test(`Dashboard mit Orten und Einstellungen (${theme})`, async ({ page }) => {
      await seedPreferences(page, 'de', theme);
      await freezeTime(page);
      await seedEntries(page, [workDay('2026-03-18', { workLocations: ['Büro', 'Kunde'] })]);
      await seedSettings(page, { showWorkLocationOnDashboard: true });
      for (const path of ['/dashboard', '/settings', '/reports']) {
        await gotoReady(page, path);
        const result = await new AxeBuilder({ page }).withTags(['wcag2a', 'wcag2aa']).analyze();
        const serious = result.violations
          .filter(v => v.impact === 'serious' || v.impact === 'critical')
          .map(v => `${path} ${v.id}: ${v.nodes.length}× (${v.nodes.slice(0, 3).map(n => n.target.join(' ')).join(' | ')})`);
        expect(serious).toEqual([]);
      }
    });
  }
});
