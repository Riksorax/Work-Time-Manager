import { calculateDailyStat, calculateMonthlyReport, calculateWeeklyReport, toDateKey } from './report-calculator';
import { DEFAULT_SETTINGS, UserSettings } from '../../shared/models/index';
import { EntryDtoFixture, mapWorkEntryDtos } from '../../shared/testing/mapped-entries';
import parityFile from '../../../../../testdata/report-parity/cases.json';

/**
 * Gemeinsame Report-Testfälle (#535): dieselbe Datei prüft das Backend (`ReportParityTests.cs`).
 * Die erwarteten Werte stammen aus dem Backend (`ReportCalculator`), siehe `testdata/report-parity/README.md`.
 *
 * Zonen-Regressionstest (`*.tz.spec.ts`): Die Einträge kommen als API-DTOs (`date` = UTC-Mitternacht) und laufen durch
 * den echten Mapper (`ApiClient.fromDto`). Berichtstage werden als Kalendertag (`yyyy-MM-dd`) verglichen: Das Web liefert
 * lokale Mitternacht, das Backend UTC-Mitternacht desselben Tages. `totalOvertimeMs` ist nicht Teil der Fälle.
 */

interface ReportDayJson { date: string; workedMs: number }

interface ParityCase {
  name: string;
  description: string;
  settings: { weeklyTargetHours: number; workdays: number[] };
  storedOvertimeMs: number;
  referenceDate: string;
  entries: EntryDtoFixture[];
  expected: {
    daily: { targetMs: number; workedMs: number; overtimeMs: number };
    weekly: {
      weekNumber: number;
      start: string;
      end: string;
      totalWorkedMs: number;
      totalBreaksMs: number;
      workDays: number;
      avgPerDayMs: number;
      overtimeMs: number;
      days: ReportDayJson[];
    };
    monthly: {
      month: string;
      totalWorkedMs: number;
      totalBreaksMs: number;
      workDays: number;
      avgPerDayMs: number;
      avgPerWeekMs: number;
      monthlyOvertimeMs: number;
      weeks: { weekNumber: number; totalWorkedMs: number }[];
      days: ReportDayJson[];
    };
  };
}

const cases = (parityFile as unknown as { cases: ParityCase[] }).cases;

/** Kalendertag eines Backend-Zeitpunkts (UTC-Mitternacht) als `yyyy-MM-dd`. */
function dayOf(iso: string): string {
  return iso.slice(0, 10);
}

function localDate(key: string): Date {
  const [y, m, d] = key.split('-').map(Number);
  return new Date(y, m - 1, d);
}

function settingsOf(c: ParityCase): UserSettings {
  return { ...DEFAULT_SETTINGS, weeklyTargetHours: c.settings.weeklyTargetHours, workdays: [...c.settings.workdays] };
}

describe('Report-Parität Web ↔ Backend (#535, testdata/report-parity)', () => {
  it('lädt die gemeinsamen Fälle', () => {
    expect(cases.length).toBeGreaterThanOrEqual(15);
    expect(new Set(cases.map(c => c.name)).size).toBe(cases.length);
  });

  for (const c of cases) {
    describe(c.name, () => {
      const ref = () => localDate(c.referenceDate);
      const monthPrefix = c.referenceDate.slice(0, 7);
      const allEntries = () => mapWorkEntryDtos(c.entries);
      const monthEntries = async () => (await allEntries()).filter(e => e.id.startsWith(monthPrefix));

      it('Tagesbericht', async () => {
        const stat = calculateDailyStat(await monthEntries(), ref(), settingsOf(c));
        expect({ targetMs: stat.target, workedMs: stat.worked, overtimeMs: stat.overtime }).toEqual(c.expected.daily);
      });

      it('Wochenbericht', async () => {
        const r = calculateWeeklyReport(await allEntries(), ref(), settingsOf(c));
        const e = c.expected.weekly;
        expect({
          weekNumber: r.weekNumber,
          start: toDateKey(r.start),
          end: toDateKey(r.end),
          totalWorkedMs: r.totalWorked,
          totalBreaksMs: r.totalBreaks,
          workDays: r.workDays,
          avgPerDayMs: r.avgPerDay,
          overtimeMs: r.overtime,
          days: r.days.map(d => ({ date: toDateKey(d.date), workedMs: d.worked })),
        }).toEqual({
          ...e,
          start: dayOf(e.start),
          end: dayOf(e.end),
          days: e.days.map(d => ({ date: dayOf(d.date), workedMs: d.workedMs })),
        });
      });

      it('Monatsbericht (ohne totalOvertimeMs)', async () => {
        const r = calculateMonthlyReport(await monthEntries(), ref(), settingsOf(c), c.storedOvertimeMs);
        const e = c.expected.monthly;
        expect({
          month: toDateKey(r.month),
          totalWorkedMs: r.totalWorked,
          totalBreaksMs: r.totalBreaks,
          workDays: r.workDays,
          avgPerDayMs: r.avgPerDay,
          avgPerWeekMs: r.avgPerWeek,
          monthlyOvertimeMs: r.monthlyOvertime,
          weeks: r.weeks.map(w => ({ weekNumber: w.weekNumber, totalWorkedMs: w.totalWorked })),
          days: r.days.map(d => ({ date: toDateKey(d.date), workedMs: d.worked })),
        }).toEqual({
          ...e,
          month: dayOf(e.month),
          days: e.days.map(d => ({ date: dayOf(d.date), workedMs: d.workedMs })),
        });
      });
    });
  }
});
