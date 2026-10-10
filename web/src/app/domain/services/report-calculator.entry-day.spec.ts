import { calculateDailyStat, calculateMonthlyReport, calculateWeeklyReport, toDateKey } from './report-calculator';
import { DEFAULT_SETTINGS, WorkEntry, WorkEntryType } from '../../shared/models/index';

/**
 * Zonenunabhängig (#407, Block B): die Rechner bilden den Kalendertag eines Eintrags über `entryDay`/`entryDayKey`,
 * nicht aus `date`. Fixture: `id` meint Montag 05.10.2026 (KW 41), `date` liegt auf dem Sonntag davor (KW 40) wie nach einer
 * Lesegrenze, die den Vortag geliefert hat.
 */
describe('report-calculator: Tag aus der id (#407)', () => {
  const H = 3_600_000;
  const day = (y: number, m: number, d: number) => new Date(y, m - 1, d);

  function inconsistent(id: string, date: Date, extra: Partial<WorkEntry> = {}): WorkEntry {
    const [y, m, d] = id.split('-').map(Number);
    return {
      id, date, breaks: [], isManuallyEntered: false, type: WorkEntryType.Work,
      workStart: new Date(y, m - 1, d, 8, 0), workEnd: new Date(y, m - 1, d, 16, 0), ...extra,
    };
  }
  const monday = () => inconsistent('2026-10-05', day(2026, 10, 4));

  describe('calculateDailyStat', () => {
    it('zählt den Eintrag am Montag 05.10. mit Soll 8 h', () => {
      const stat = calculateDailyStat([monday()], day(2026, 10, 5), DEFAULT_SETTINGS);
      expect(stat.worked).toBe(8 * H);
      expect(stat.target).toBe(8 * H);
    });

    it('zählt den Eintrag am Sonntag 04.10. nicht', () => {
      const stat = calculateDailyStat([monday()], day(2026, 10, 4), DEFAULT_SETTINGS);
      expect(stat.worked).toBe(0);
    });
  });

  describe('calculateWeeklyReport', () => {
    it('der Eintrag liegt in KW 41 (Mo 05.-So 11.10.), nicht in der Vorwoche', () => {
      const kw41 = calculateWeeklyReport([monday()], day(2026, 10, 5), DEFAULT_SETTINGS);
      expect(kw41.weekNumber).toBe(41);
      expect(kw41.workDays).toBe(1);
      const kw40 = calculateWeeklyReport([monday()], day(2026, 10, 4), DEFAULT_SETTINGS);
      expect(kw40.workDays).toBe(0);
    });

    it('der Berichtstag ist der Montag 05.10. (Schlüssel aus der id)', () => {
      const kw41 = calculateWeeklyReport([monday()], day(2026, 10, 5), DEFAULT_SETTINGS);
      expect(kw41.days.map(d => toDateKey(d.date))).toEqual(['2026-10-05']);
      expect(kw41.days[0].date.getDay()).toBe(1);
    });
  });

  describe('calculateMonthlyReport', () => {
    it('Schlüssel des Berichtstags kommt aus der id', () => {
      const report = calculateMonthlyReport([monday()], day(2026, 10, 1), DEFAULT_SETTINGS, 0);
      expect(report.days.map(d => toDateKey(d.date))).toEqual(['2026-10-05']);
    });

    it('Wochennummer kommt aus der id: KW 41 statt KW 40', () => {
      const report = calculateMonthlyReport([monday()], day(2026, 10, 1), DEFAULT_SETTINGS, 0);
      expect(report.weeks.map(w => w.weekNumber)).toEqual([41]);
    });

    it('Monatsgrenze: id 2026-11-01 (date 2026-10-31) gehört in den November, KW 44', () => {
      const e = inconsistent('2026-11-01', day(2026, 10, 31));
      const report = calculateMonthlyReport([e], day(2026, 11, 1), DEFAULT_SETTINGS, 0);
      expect(report.days.map(d => toDateKey(d.date))).toEqual(['2026-11-01']);
      expect(report.weeks.map(w => w.weekNumber)).toEqual([44]);
    });
  });

  it('Platzhalter-Ids fallen auf date zurück (Bestandsverhalten)', () => {
    const e: WorkEntry = { ...monday(), id: crypto.randomUUID(), date: day(2026, 10, 5) };
    expect(calculateDailyStat([e], day(2026, 10, 5), DEFAULT_SETTINGS).worked).toBe(8 * H);
    expect(calculateWeeklyReport([e], day(2026, 10, 5), DEFAULT_SETTINGS).workDays).toBe(1);
  });
});
