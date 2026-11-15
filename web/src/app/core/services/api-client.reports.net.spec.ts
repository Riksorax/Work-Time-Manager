import { TestBed } from '@angular/core/testing';
import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { ApiClient } from './api-client';
import { MonthlyReport, WeeklyReport } from '../../domain/models/reports.models';

/** Lesegrenze für `netWorkedMs` (#551): übernommen, bei fehlendem Feld (älteres Backend) Rückfall auf brutto. */
describe('ApiClient: netWorkedMs der Berichtszeilen (#551)', () => {
  let api: ApiClient;
  let http: HttpTestingController;
  const H = 3600000;

  beforeEach(() => {
    TestBed.configureTestingModule({ providers: [provideHttpClient(), provideHttpClientTesting()] });
    api = TestBed.inject(ApiClient);
    http = TestBed.inject(HttpTestingController);
  });

  afterEach(() => {
    http.verify();
    TestBed.resetTestingModule();
  });

  function weekly(days: object[]): WeeklyReport {
    let result!: WeeklyReport;
    api.getWeeklyReport(2026, 10, 5).subscribe(r => (result = r));
    http.expectOne(r => r.url.endsWith('/api/reports/weekly/2026/10/5')).flush({
      weekNumber: 41, start: '2026-10-05T00:00:00Z', end: '2026-10-11T00:00:00Z', totalWorkedMs: 0,
      totalBreaksMs: 0, workDays: 0, avgPerDayMs: 0, overtimeMs: 0, days,
    });
    return result;
  }

  function monthly(weeks: object[], days: object[]): MonthlyReport {
    let result!: MonthlyReport;
    api.getMonthlyReport(2026, 10).subscribe(r => (result = r));
    http.expectOne(r => r.url.endsWith('/api/reports/monthly/2026/10')).flush({
      month: '2026-10-01T00:00:00Z', totalWorkedMs: 0, totalBreaksMs: 0, workDays: 0, avgPerDayMs: 0,
      avgPerWeekMs: 0, monthlyOvertimeMs: 0, totalOvertimeMs: 0, weeks, days,
    });
    return result;
  }

  it('Woche: netWorkedMs je Tag wird übernommen (auch 0 und negativ)', () => {
    const r = weekly([
      { date: '2026-10-05T00:00:00Z', workedMs: 9 * H, netWorkedMs: 8.5 * H },
      { date: '2026-10-06T00:00:00Z', workedMs: 0, netWorkedMs: 0 },
      { date: '2026-10-07T00:00:00Z', workedMs: H, netWorkedMs: -H },
    ]);
    expect(r.days.map(d => [d.worked, d.netWorked])).toEqual([[9 * H, 8.5 * H], [0, 0], [H, -H]]);
  });

  it('Woche: fehlt netWorkedMs (älteres Backend), gilt brutto, kein 0, kein Absturz', () => {
    const r = weekly([
      { date: '2026-10-05T00:00:00Z', workedMs: 9 * H },
      { date: '2026-10-06T00:00:00Z', workedMs: 7 * H, netWorkedMs: null },
    ]);
    expect(r.days.map(d => d.netWorked)).toEqual([9 * H, 7 * H]);
  });

  it('Monat: netWorkedMs je Woche und Tag wird übernommen', () => {
    const r = monthly(
      [{ weekNumber: 41, totalWorkedMs: 18 * H, netWorkedMs: 17 * H }],
      [{ date: '2026-10-05T00:00:00Z', workedMs: 9 * H, netWorkedMs: 8.5 * H }],
    );
    expect(r.weeks).toEqual([{ weekNumber: 41, totalWorked: 18 * H, netWorked: 17 * H }]);
    expect(r.days[0].netWorked).toBe(8.5 * H);
  });

  it('Monat: fehlt netWorkedMs bei Woche und Tag, gilt brutto', () => {
    const r = monthly(
      [{ weekNumber: 41, totalWorkedMs: 18 * H }],
      [{ date: '2026-10-05T00:00:00Z', workedMs: 9 * H }],
    );
    expect(r.weeks[0].netWorked).toBe(18 * H);
    expect(r.days[0].netWorked).toBe(9 * H);
  });
});
