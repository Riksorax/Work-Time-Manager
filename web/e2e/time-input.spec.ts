import { expect, gotoReady, seedPreferences, test } from './fixtures';

/**
 * Zeitfelder im Dashboard (Entprellen, Review-Fund zu #426): Chromium feuert `change` bei `<input type="time">` nach jeder
 * gültigen Teiländerung („0930“: 09:00, 09:03, 09:30). Mit `settle` entsteht daraus genau ein Write mit dem letzten Wert.
 * Ohne Konto zählt der localStorage-Write des Hybrid-Services (eingeloggt wäre es ein API-Call mit demselben Auslöser).
 */
test.describe('Dashboard Zeitfeld Start (Entprellen)', () => {
  // Das Segment-/`change`-Verhalten von `<input type="time">` ist browserspezifisch (der Fund stammt aus Chromium).
  test.beforeEach(({}, testInfo) => {
    test.skip(testInfo.project.name !== 'chromium', 'nur Chromium (Desktop)');
  });

  const WRITE_PREFIX = 'local_work_entries_';

  interface Write { key: string; startHour: number | null; startMinute: number | null }

  async function recordWrites(page: import('@playwright/test').Page): Promise<void> {
    await page.addInitScript((prefix: string) => {
      if (window.top !== window) return;
      const w = window as unknown as { __writes: Write[] };
      w.__writes = [];
      const orig = Storage.prototype.setItem;
      Storage.prototype.setItem = function (key: string, value: string): void {
        if (key.startsWith(prefix)) {
          let h: number | null = null, m: number | null = null;
          try {
            for (const day of Object.values((JSON.parse(value) as { days: Record<string, { workStart?: string | null }> }).days)) {
              if (day?.workStart) { const d = new Date(day.workStart); h = d.getHours(); m = d.getMinutes(); }
            }
          } catch { /* kein Eintrag */ }
          w.__writes.push({ key, startHour: h, startMinute: m });
        }
        return orig.call(this, key, value);
      };
    }, WRITE_PREFIX);
  }
  const writes = (page: import('@playwright/test').Page): Promise<Write[]> =>
    page.evaluate(() => (window as unknown as { __writes: Write[] }).__writes);

  /**
   * Chromium zeigt das Zeitfeld je nach Browser-Locale mit AM/PM-Segment: `change` feuert erst, wenn alle Segmente gefüllt
   * sind. Erst „0930A“ füllen, dann Stunden und Minuten neu tippen: jetzt ist der Wert vollständig und jedes Segment löst
   * ein `change` aus (der Fall aus dem Review).
   */
  async function primeFieldAndReset(page: import('@playwright/test').Page): Promise<import('@playwright/test').Locator> {
    const start = page.locator('app-time-input input[type="time"]').first();
    await start.click();
    await page.keyboard.type('0930A');
    await page.keyboard.press('Tab');
    await expect.poll(async () => (await writes(page)).length).toBeGreaterThan(0);
    await page.waitForTimeout(1000);
    await page.evaluate(() => { (window as unknown as { __writes: Write[] }).__writes.length = 0; });
    await start.click({ position: { x: 12, y: 10 } }); // Stundensegment
    return start;
  }

  test('Tastatureingabe „1045“ in ein gefülltes Feld löst genau einen Write mit 10:45 aus', async ({ page }) => {
    await seedPreferences(page, 'de', 'light');
    await recordWrites(page);
    await gotoReady(page, '/dashboard');

    await primeFieldAndReset(page);
    await page.keyboard.type('1045');
    await page.waitForTimeout(1500); // Ruhezeit (600 ms) abwarten, danach darf nichts mehr folgen

    expect((await writes(page)).map(x => [x.startHour, x.startMinute])).toEqual([[10, 45]]);
  });

  test('Verlassen des Feldes sendet sofort, ohne die Ruhezeit abzuwarten', async ({ page }) => {
    await seedPreferences(page, 'de', 'light');
    await recordWrites(page);
    await gotoReady(page, '/dashboard');

    await primeFieldAndReset(page);
    await page.keyboard.type('1045');
    expect(await writes(page)).toEqual([]);
    await page.locator('app-time-input input[type="time"]').first().blur();
    await expect.poll(async () => (await writes(page)).map(x => [x.startHour, x.startMinute]), { timeout: 400 }).toEqual([[10, 45]]);
    await page.waitForTimeout(1500);
    expect((await writes(page)).length).toBe(1);
  });
});
