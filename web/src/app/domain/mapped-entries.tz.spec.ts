import {
  calculateDailyStat,
  calculateMonthlyReport,
  calculateWeeklyReport,
} from './services/report-calculator';
import { calculateYearlyLeave } from './services/leave-calculator';
import { getEffectiveWorkDays, getWeekEntriesForDate } from './utils/overtime.utils';
import { entryDto, mapWorkEntryDtos } from '../shared/testing/mapped-entries';
import { toDateKey } from '../shared/utils/german-holidays.util';
import { DEFAULT_SETTINGS } from '../shared/models/index';

/**
 * Zonen-Regressionstests (#407): Einträge laufen als Backend-DTO (`date` = UTC-Mitternacht) durch den echten
 * `ApiClient`-Mapper und dann in die reinen Rechner. Westlich von UTC lag `date` vorher auf dem Vortag und
 * verschob Tages-, Wochen-, Monatsbericht, Arbeitstage und die Jahresgrenze beim Urlaub.
 */
describe('Rechner mit gemappten Einträgen (#407)', () => {
  const H = 3_600_000;
  const day = (y: number, m: number, d: number) => new Date(y, m - 1, d);
  const worked = (id: string, extra = {}) => {
    const [y, m, d] = id.split('-').map(Number);
    return entryDto(id, `${id}T00:00:00Z`, {
      workStart: new Date(y, m - 1, d, 8, 0).toISOString(),
      workEnd: new Date(y, m - 1, d, 16, 0).toISOString(),
      ...extra,
    });
  };

  it('Tagesbericht: Eintrag 05.10. zählt am Montag mit Soll 8 h, am Sonntag 04.10. nicht', async () => {
    const entries = await mapWorkEntryDtos([worked('2026-10-05')]);
    const mo = calculateDailyStat(entries, day(2026, 10, 5), DEFAULT_SETTINGS);
    expect(mo.target).toBe(8 * H);
    expect(mo.worked).toBe(8 * H);
    expect(calculateDailyStat(entries, day(2026, 10, 4), DEFAULT_SETTINGS).worked).toBe(0);
  });

  it('Wochenbericht KW 41: Eintrag liegt am Montag, nicht in KW 40', async () => {
    const entries = await mapWorkEntryDtos([worked('2026-10-05')]);
    const kw41 = calculateWeeklyReport(entries, day(2026, 10, 5), DEFAULT_SETTINGS);
    expect(kw41.weekNumber).toBe(41);
    expect(kw41.workDays).toBe(1);
    expect(kw41.days.map(d => toDateKey(d.date))).toEqual(['2026-10-05']);
    expect(kw41.days[0].date.getDay()).toBe(1);
    const kw40 = calculateWeeklyReport(entries, day(2026, 10, 4), DEFAULT_SETTINGS);
    expect(kw40.workDays).toBe(0);
  });

  it('Monatsbericht: Sonntag 2026-11-01 liegt im November in KW 44', async () => {
    const entries = await mapWorkEntryDtos([worked('2026-11-01')]);
    const report = calculateMonthlyReport(entries, day(2026, 11, 1), DEFAULT_SETTINGS, 0);
    expect(report.days.map(d => toDateKey(d.date))).toEqual(['2026-11-01']);
    expect(report.weeks.map(w => w.weekNumber)).toEqual([44]);
  });

  it('Arbeitstage: der Montag zählt, ein Sonntagseintrag nicht', async () => {
    const entries = await mapWorkEntryDtos([worked('2026-10-05'), worked('2026-10-04')]);
    expect(getEffectiveWorkDays(entries, [1, 2, 3, 4, 5])).toBe(1);
  });

  it('Wocheneinträge für Mo 05.10.: nur 05.10., nicht der Sonntag 04.10.', async () => {
    const entries = await mapWorkEntryDtos([worked('2026-10-04'), worked('2026-10-05'), worked('2026-10-11')]);
    expect(getWeekEntriesForDate(day(2026, 10, 5), entries).map(e => e.id)).toEqual(['2026-10-05', '2026-10-11']);
  });

  it('Urlaub: 2026-01-01 zählt für 2026 (nicht 2025), 2025-12-31 für 2025', async () => {
    const entries = await mapWorkEntryDtos([
      entryDto('2026-01-01', undefined, { type: 'vacation' }),
      entryDto('2025-12-31', undefined, { type: 'vacation' }),
    ]);
    expect(calculateYearlyLeave(entries, 2026, 30).vacationDaysTaken).toBe(1);
    expect(calculateYearlyLeave(entries, 2025, 30).vacationDaysTaken).toBe(1);
    const only2026 = await mapWorkEntryDtos([entryDto('2026-01-01', undefined, { type: 'vacation' })]);
    expect(calculateYearlyLeave(only2026, 2025, 30).vacationDaysTaken).toBe(0);
    expect(calculateYearlyLeave(only2026, 2026, 30).vacationDaysTaken).toBe(1);
  });
});
