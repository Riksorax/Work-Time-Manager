import { expect, gotoReady, seedPreferences, test } from './fixtures';
import { freezeTime, seedEntries, workDay } from './seed';

/** Dauer je Pause im Dashboard (#504): feste Pause 12:00–12:30, Dauer unabhängig von der Zeitzone. */
for (const [lang, expected] of [['de', '· 30 Min'], ['en', '· 30 min']] as const) {
  test(`Pausenliste zeigt die Dauer (${lang})`, async ({ page }) => {
    await seedPreferences(page, lang, 'light');
    await freezeTime(page);
    await seedEntries(page, [workDay('2026-03-18')]);
    await gotoReady(page, '/dashboard');
    await expect(page.locator('.break-item .break-duration').first()).toHaveText(expected);
  });
}
