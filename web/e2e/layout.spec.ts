import { expect, gotoReady, seedPreferences, test } from './fixtures';
import { freezeTime, seedEntries, workDay } from './seed';

/** Layout-Regressionen (#429), gefunden beim Durchsehen der Screenshots bei 320/768 px. Laufen ohne Konto. */

test.beforeEach(async ({ page }) => {
  await seedPreferences(page, 'de', 'light');
  await freezeTime(page);
  await seedEntries(page, [workDay('2026-03-10'), workDay('2026-03-17'), workDay('2026-03-18')]);
});

test('Dashboard: Label und Wert der Überstunden stoßen bei 320 px nicht aneinander', async ({ page }) => {
  await page.setViewportSize({ width: 320, height: 700 });
  await gotoReady(page, '/dashboard');
  const rows = page.locator('.stat-row');
  await expect(rows.first()).toBeVisible();
  for (let i = 0; i < await rows.count(); i++) {
    const label = await rows.nth(i).locator('.stat-label').boundingBox();
    const value = await rows.nth(i).locator('.stat-value').boundingBox();
    expect(value!.x - (label!.x + label!.width), `Zeile ${i}`).toBeGreaterThanOrEqual(8);
  }
});

test('Dashboard: Überstunden-Werte stehen bündig am rechten Rand, der Anpassen-Button neben dem Label', async ({ page }) => {
  for (const width of [320, 768]) {
    await page.setViewportSize({ width, height: 800 });
    await gotoReady(page, '/dashboard');
    const section = await page.locator('.overtime-stats').boundingBox();
    const values = page.locator('.overtime-stats .stat-value');
    for (let i = 0; i < await values.count(); i++) {
      const box = await values.nth(i).boundingBox();
      expect(section!.x + section!.width - (box!.x + box!.width), `${width}px, Wert ${i}`).toBeLessThanOrEqual(1);
    }
    const label = await page.locator('.stat-label-group .stat-label').boundingBox();
    const button = await page.locator('.stat-label-group .adjust-btn').boundingBox();
    expect(button!.x, `${width}px`).toBeGreaterThanOrEqual(label!.x + label!.width);
  }
});

test('Kalender: Eintrags-Punkt berührt die Ziffer bei 320 px nicht', async ({ page }) => {
  await page.setViewportSize({ width: 320, height: 700 });
  await gotoReady(page, '/reports');
  const cell = page.locator('[role="gridcell"][data-date="2026-03-10"]');
  const digit = await cell.locator('.day-number').boundingBox();
  const dot = await cell.locator('.entry-dot').boundingBox();
  expect(dot!.y).toBeGreaterThanOrEqual(digit!.y + digit!.height);
});

test('Kalender: auf 768 px nicht über die volle Breite gezogen (quadratische Zellen)', async ({ page }) => {
  await page.setViewportSize({ width: 768, height: 1000 });
  await gotoReady(page, '/reports');
  const card = await page.locator('.calendar-card').boundingBox();
  expect(card!.width).toBeLessThanOrEqual(440);
  const row = await page.locator('.calendar-week:not(.weekday-row)').first().boundingBox();
  expect(row!.height).toBeLessThanOrEqual(70);
});

test.describe('Einstellungen bei 320 px', () => {
  test('Titel werden nicht abgeschnitten', async ({ page }) => {
    await page.setViewportSize({ width: 320, height: 700 });
    await gotoReady(page, '/settings');
    const titles = page.locator('.mdc-list-item__primary-text');
    expect(await titles.count()).toBeGreaterThan(0);
    for (let i = 0; i < await titles.count(); i++) {
      // Der Titel selbst ist ein `inline`-Element (clientWidth immer 0, scrollWidth = Textbreite): geprüft wird der
      // umgebende Block, der den Text per `overflow: hidden` abschneiden würde.
      const clipped = await titles.nth(i).evaluate(e => {
        const box = (e.closest('.mdc-list-item__content') ?? e) as HTMLElement;
        return box.scrollWidth > box.clientWidth + 1;
      });
      expect(clipped, `Titel ${i}: ${await titles.nth(i).innerText()}`).toBe(false);
      // Ein auf (fast) 0 px zusammengedrückter Titel ist nicht „abgeschnitten", aber ebenso unlesbar (Chromium).
      const width = (await titles.nth(i).boundingBox())!.width;
      expect(width, `Titel ${i} sichtbar breit: ${await titles.nth(i).innerText()}`).toBeGreaterThanOrEqual(40);
    }
  });

  test('Sprachumschalter liegt innerhalb der Zeile', async ({ page }) => {
    await page.setViewportSize({ width: 320, height: 700 });
    await gotoReady(page, '/settings');
    const item = await page.locator('.language-section .mdc-list-item').boundingBox();
    const group = await page.locator('.language-section mat-button-toggle-group').boundingBox();
    expect(group!.x).toBeGreaterThanOrEqual(item!.x);
    expect(group!.x + group!.width).toBeLessThanOrEqual(item!.x + item!.width + 1);
  });

  test('Chevron der Listenzeilen ist eine 24-px-Icon-Schrift und damit sichtbar', async ({ page }) => {
    await gotoReady(page, '/settings');
    const chevron = page.locator('button[mat-list-item] mat-icon.mdc-list-item__end').first();
    const style = await chevron.evaluate(e => ({ ff: getComputedStyle(e).fontFamily, fs: getComputedStyle(e).fontSize }));
    expect(style.ff).toContain('Material Icons');
    expect(style.fs).toBe('24px');
  });
});

test.describe('Dialoge und Eingabefelder auf schmalen Viewports', () => {
  test('Dashboard: Zeit-Felder nutzen die volle Breite wie Karten und Hauptbutton', async ({ page }) => {
    for (const width of [375, 768]) {
      await page.setViewportSize({ width, height: 900 });
      await gotoReady(page, '/dashboard');
      const field = await page.locator('app-time-input .mat-mdc-form-field').first().boundingBox();
      const button = await page.locator('.main-action-btn').boundingBox();
      expect(field!.width, `${width}px`).toBeGreaterThanOrEqual(button!.width - 1);
    }
  });

  /** Öffnet einen Dialog und prüft: nichts ragt über den Rand, das erste Label ist nicht abgeschnitten. */
  async function expectDialogFits(page: import('@playwright/test').Page, width: number): Promise<void> {
    const surface = page.locator('.mat-mdc-dialog-surface');
    await expect(surface).toBeVisible();
    await page.waitForTimeout(400); // Öffnen-Animation
    const result = await page.evaluate(() => {
      const s = document.querySelector('.mat-mdc-dialog-surface')!.getBoundingClientRect();
      const clipped: string[] = [];
      for (const el of Array.from(document.querySelectorAll('.mat-mdc-dialog-content .mat-mdc-form-field, .mat-mdc-dialog-content button, .mat-mdc-dialog-actions button'))) {
        const r = el.getBoundingClientRect();
        if (r.width > 0 && r.right > s.right + 0.5) clipped.push(`${el.tagName.toLowerCase()} right=${Math.round(r.right)} > ${Math.round(s.right)}`);
      }
      const contentEl = document.querySelector('.mat-mdc-dialog-content')!;
      const content = contentEl.getBoundingClientRect();
      const label = document.querySelector('.mat-mdc-dialog-content .mdc-floating-label, .mat-mdc-dialog-content .mat-mdc-floating-label')?.getBoundingClientRect();
      return { clipped, surfaceRight: s.right, // Nur prüfen, solange der Inhalt oben steht: ein gescrollter Inhalt schneidet das Label zu Recht ab.
      labelCut: label && contentEl.scrollTop === 0 ? label.top < content.top - 0.5 : false, vw: document.documentElement.clientWidth };
    });
    expect(result.clipped, `${width}px`).toEqual([]);
    expect(result.surfaceRight).toBeLessThanOrEqual(result.vw);
    expect(result.labelCut, 'erstes Feld-Label oben abgeschnitten').toBe(false);
  }

  for (const width of [320, 375]) {
    test(`Reports-Dialoge passen auf ${width} px`, async ({ page }) => {
      await page.setViewportSize({ width, height: 760 });
      await gotoReady(page, '/reports');
      await page.getByRole('button', { name: /Eintrag bearbeiten/ }).first().click();
      await page.getByRole('button', { name: 'Pause hinzufügen' }).click();
      await expectDialogFits(page, width);
      await page.keyboard.press('Escape');
      await page.getByRole('button', { name: /Schnell-Eintrag erstellen/ }).click();
      await expectDialogFits(page, width);
    });

    test(`Einstellungs-Dialoge passen auf ${width} px`, async ({ page }) => {
      await page.setViewportSize({ width, height: 760 });
      await gotoReady(page, '/settings');
      for (const name of [/Soll-Arbeitsstunden/, /Urlaubsanspruch/, /Bundesland/, /Überstunden.*anpassen|anpassen/i]) {
        await page.getByRole('button', { name }).first().click();
        await expectDialogFits(page, width);
        await page.keyboard.press('Escape');
        await expect(page.locator('.mat-mdc-dialog-surface')).toHaveCount(0);
      }
    });
  }
});
