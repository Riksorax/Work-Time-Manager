import { getEffectiveWorkDays, getWeekEntriesForDate } from './overtime.utils';
import { WorkEntry, WorkEntryType } from '../../shared/models/index';

/**
 * Zonenunabhängig (#407, Block B): Arbeitstage und Wocheneinträge richten sich nach dem Kalendertag aus der `id`.
 * Fixture: `id` Montag 05.10.2026, `date` Sonntag 04.10. (wie nach einer Lesegrenze, die den Vortag geliefert hat).
 */
describe('overtime.utils: Tag aus der id (#407)', () => {
  const entry = (id: string, date: Date, extra: Partial<WorkEntry> = {}): WorkEntry => ({
    id, date, breaks: [], isManuallyEntered: false, type: WorkEntryType.Work,
    workStart: new Date(2026, 9, 5, 8, 0), ...extra,
  });
  const monday = () => entry('2026-10-05', new Date(2026, 9, 4));

  describe('getEffectiveWorkDays', () => {
    it('der Montag zählt (Wochentag aus der id, nicht der Sonntag aus date)', () => {
      expect(getEffectiveWorkDays([monday()], [1, 2, 3, 4, 5])).toBe(1);
    });

    it('ein Sonntags-only-Vertrag zählt ihn nicht', () => {
      expect(getEffectiveWorkDays([monday()], [7])).toBe(0);
    });

    it('zwei Einträge desselben Tages (gleiche id) zählen einmal', () => {
      const other = entry('2026-10-05', new Date(2026, 9, 5));
      expect(getEffectiveWorkDays([monday(), other], [1, 2, 3, 4, 5])).toBe(1);
    });
  });

  describe('getWeekEntriesForDate', () => {
    it('Woche von Mo 05.10.: enthält den Eintrag trotz date auf dem Sonntag davor', () => {
      expect(getWeekEntriesForDate(new Date(2026, 9, 5), [monday()]).map(e => e.id)).toEqual(['2026-10-05']);
    });

    it('Vorwoche (Sonntag 04.10.): enthält ihn nicht', () => {
      expect(getWeekEntriesForDate(new Date(2026, 9, 4), [monday()])).toEqual([]);
    });
  });
});
