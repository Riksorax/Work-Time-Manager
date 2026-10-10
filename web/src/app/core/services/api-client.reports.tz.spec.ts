import { TestBed } from '@angular/core/testing';
import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { ApiClient } from './api-client';
import { toDateKey } from '../../shared/utils/german-holidays.util';
import { MonthlyReport, WeeklyReport } from '../../domain/models/reports.models';

/**
 * Zonen-Regressionstests (#407) für die Berichts-DTO-Mapper: das Backend liefert `start`, `end`, `month` und
 * `days[].date` als UTC-Mitternacht eines Kalendertags; westlich von UTC ergab `new Date(iso)` lokal den Vortag
 * (Reports-Tab Woche/Monat zeigte den Vortag samt Wochentag, ein Klick sprang auf den falschen Tag).
 */
describe('ApiClient: Berichts-Tage als lokaler Kalendertag (#407)', () => {
  let api: ApiClient;
  let http: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({ providers: [provideHttpClient(), provideHttpClientTesting()] });
    api = TestBed.inject(ApiClient);
    http = TestBed.inject(HttpTestingController);
  });

  afterEach(() => {
    http.verify();
    TestBed.resetTestingModule();
  });

  const iso = (y: number, m: number, d: number): string =>
    `${y}-${String(m).padStart(2, '0')}-${String(d).padStart(2, '0')}T00:00:00Z`;
  const localMidnight = (y: number, m: number, d: number): number => new Date(y, m - 1, d).getTime();

  function weekly(start: string, end: string, days: string[], profileId?: string): WeeklyReport {
    let result!: WeeklyReport;
    api.getWeeklyReport(2026, 10, 5, profileId).subscribe(r => (result = r));
    http.expectOne(r => r.url.endsWith('/api/reports/weekly/2026/10/5')).flush({
      weekNumber: 41, start, end, totalWorkedMs: 0, totalBreaksMs: 0, workDays: 0, avgPerDayMs: 0, overtimeMs: 0,
      days: days.map(date => ({ date, workedMs: 0 })),
    });
    return result;
  }

  function monthly(month: string, days: string[], profileId?: string): MonthlyReport {
    let result!: MonthlyReport;
    api.getMonthlyReport(2026, 10, profileId).subscribe(r => (result = r));
    http.expectOne(r => r.url.endsWith('/api/reports/monthly/2026/10')).flush({
      month, totalWorkedMs: 0, totalBreaksMs: 0, workDays: 0, avgPerDayMs: 0, avgPerWeekMs: 0,
      monthlyOvertimeMs: 0, totalOvertimeMs: 0, weeks: [], days: days.map(date => ({ date, workedMs: 0 })),
    });
    return result;
  }

  describe('R8: Wochenbericht', () => {
    const report = () => weekly('2026-10-05T00:00:00Z', '2026-10-11T00:00:00Z', ['2026-10-05T00:00:00Z', '2026-10-11T00:00:00Z']);

    it('start ist der lokale Montag 05.10.', () => {
      expect(toDateKey(report().start)).toBe('2026-10-05');
    });

    it('end ist der lokale Sonntag 11.10.', () => {
      expect(toDateKey(report().end)).toBe('2026-10-11');
    });

    it('days[].date sind die lokalen Kalendertage 05.10. und 11.10.', () => {
      expect(report().days.map(d => toDateKey(d.date))).toEqual(['2026-10-05', '2026-10-11']);
      expect(report().days[0].date.getDay()).toBe(1);
    });

    it('mit profileId: gleiche Abbildung', () => {
      const r = weekly('2026-10-05T00:00:00Z', '2026-10-11T00:00:00Z', ['2026-10-05T00:00:00Z'], 'p1');
      expect(toDateKey(r.days[0].date)).toBe('2026-10-05');
    });
  });

  describe('R8: Monatsbericht', () => {
    it('month ist der Monat Oktober (heute in Los Angeles: September)', () => {
      const r = monthly('2026-10-01T00:00:00Z', []);
      expect(r.month.getMonth()).toBe(9);
      expect(toDateKey(r.month)).toBe('2026-10-01');
    });

    it('days[].date sind lokale Kalendertage', () => {
      const r = monthly('2026-10-01T00:00:00Z', ['2026-10-01T00:00:00Z', '2026-10-31T00:00:00Z']);
      expect(r.days.map(d => toDateKey(d.date))).toEqual(['2026-10-01', '2026-10-31']);
    });
  });

  describe('E6: Berichtstage der Zeitumstellungswochen', () => {
    // Berlin Mo 19.10.-So 25.10. und Mo 23.03.-So 29.03., Los Angeles Mo 02.03.-So 08.03., Auckland Mo 30.03.-So 05.04.
    const weeks: [string, number, number, number][] = [
      ['Berlin Herbst', 2026, 10, 19], ['Berlin Frühjahr', 2026, 3, 23],
      ['Los Angeles Frühjahr', 2026, 3, 2], ['Auckland Herbst', 2026, 3, 30],
    ];

    it.each(weeks)('%s: days[].date ist je Tag eindeutig, aufsteigend und lokale Mitternacht', (_label, y, m, d) => {
      const days = Array.from({ length: 7 }, (_, i) => {
        const day = new Date(y, m - 1, d + i);
        return [day.getFullYear(), day.getMonth() + 1, day.getDate()] as const;
      });
      const last = days[6];
      const r = weekly(iso(...days[0]), iso(...last), days.map(t => iso(...t)));
      const times = r.days.map(x => x.date.getTime());
      expect(new Set(times).size).toBe(7);
      expect([...times].sort((a, b) => a - b)).toEqual(times);
      times.forEach((t, i) => expect(t).toBe(localMidnight(...days[i])));
    });
  });
});
