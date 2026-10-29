import { WorkEntry, WorkEntryType } from '../../shared/models/index';
import { calculateHomeOfficeStats } from './home-office-stats';

// Feste Kalendertage, keine Abhängigkeit von Datum oder Zeitzone: der Tag kommt aus der `id`.
function entry(day: string, over: Partial<WorkEntry> = {}): WorkEntry {
  const [y, m, d] = day.split('-').map(Number);
  return {
    id: day,
    date: new Date(y, m - 1, d),
    workStart: new Date(y, m - 1, d, 8),
    workEnd: new Date(y, m - 1, d, 16),
    breaks: [],
    isManuallyEntered: false,
    type: WorkEntryType.Work,
    ...over,
  };
}

describe('calculateHomeOfficeStats (#283)', () => {
  it('leere Liste: keine Bezugstage, Anteil null', () => {
    expect(calculateHomeOfficeStats([])).toEqual({ homeOfficeDays: 0, officeDays: 0, totalDays: 0, ratio: null });
  });

  it('zählt Home-Office- und Bürotage und den Anteil', () => {
    const s = calculateHomeOfficeStats([
      entry('2026-03-02', { isHomeOffice: true }),
      entry('2026-03-03'),
      entry('2026-03-04', { isHomeOffice: false }),
    ]);
    expect(s).toEqual({ homeOfficeDays: 1, officeDays: 2, totalDays: 3, ratio: 1 / 3 });
  });

  it('offene Einträge (Start ohne Ende) zählen, Einträge ohne Start nicht', () => {
    const s = calculateHomeOfficeStats([
      entry('2026-03-02', { isHomeOffice: true, workEnd: undefined }),
      entry('2026-03-03', { isHomeOffice: true, workStart: undefined, workEnd: undefined }),
    ]);
    expect(s.totalDays).toBe(1);
    expect(s.homeOfficeDays).toBe(1);
  });

  it('Urlaub, Krankheit und Feiertag zählen nie, auch nicht mit Flag', () => {
    const s = calculateHomeOfficeStats([
      entry('2026-03-02', { type: WorkEntryType.Vacation, isHomeOffice: true }),
      entry('2026-03-03', { type: WorkEntryType.Sick, isHomeOffice: true }),
      entry('2026-03-04', { type: WorkEntryType.Holiday, isHomeOffice: true }),
    ]);
    expect(s.totalDays).toBe(0);
  });

  it('mehrere Einträge am selben Tag zählen einmal; ein Flag macht den Tag zum Home-Office-Tag', () => {
    const s = calculateHomeOfficeStats([
      entry('2026-03-02'),
      { ...entry('2026-03-02', { isHomeOffice: true }), id: '2026-03-02' },
    ]);
    expect(s).toEqual({ homeOfficeDays: 1, officeDays: 0, totalDays: 1, ratio: 1 });
  });

  it('der Tag kommt aus der id, nicht aus date (inkonsistenter Eintrag)', () => {
    const s = calculateHomeOfficeStats([
      entry('2026-10-05', { date: new Date(2026, 9, 4), isHomeOffice: true }),
      entry('2026-10-05'),
    ]);
    expect(s.totalDays).toBe(1);
  });
});
