import { AxeBuilder } from '@axe-core/playwright';
import { expect, gotoReady, seedPreferences, test, Theme } from './fixtures';
import { freezeTime, openDay, seedEntries, workDay } from './seed';

/** axe mit gefüllten Seiten: Leerzustände verstecken Kontrast- und Rollenfehler von Banner, Kalender und Berichten. */

test.skip(({ browserName }) => browserName !== 'chromium', 'axe läuft nur in Chromium');

const SCENARIOS = [
  { name: 'Dashboard mit Banner „Offene Einträge"', path: '/dashboard', entries: [openDay('2026-03-16')] },
  { name: 'Dashboard mit laufender Fortsetzen-Option', path: '/dashboard', entries: [openDay('2026-03-17', '12:00')] },
  { name: 'Reports mit Einträgen', path: '/reports', entries: [workDay('2026-03-10'), workDay('2026-03-11'), workDay('2026-03-18')] },
  { name: 'Einstellungen mit Einträgen', path: '/settings', entries: [workDay('2026-03-10')] },
];

for (const theme of ['light', 'dark'] as Theme[]) {
  for (const s of SCENARIOS) {
    test(`${s.name} (${theme})`, async ({ page }) => {
      await seedPreferences(page, 'de', theme);
      await freezeTime(page);
      await seedEntries(page, s.entries);
      await gotoReady(page, s.path);
      const result = await new AxeBuilder({ page }).withTags(['wcag2a', 'wcag2aa']).analyze();
      const serious = result.violations
        .filter(v => v.impact === 'serious' || v.impact === 'critical')
        .map(v => `${v.id}: ${v.nodes.length}× (${v.nodes.slice(0, 3).map(n => n.target.join(' ')).join(' | ')})`);
      expect(serious).toEqual([]);
    });
  }
}
