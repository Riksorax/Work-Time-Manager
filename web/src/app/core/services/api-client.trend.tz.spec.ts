import { TestBed } from '@angular/core/testing';
import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { ApiClient } from './api-client';
import { TrendReport } from '../../domain/models/trend.models';
import { toDateKey } from '../../shared/utils/german-holidays.util';

/**
 * Zonen-Regressionstest (#407/#531): `start`/`end` der Trend-Buckets kommen als UTC-Mitternacht
 * (`…T00:00:00+00:00`) und müssen in jeder Zone der lokale Kalendertag sein (westlich von UTC sonst der Vortag).
 */
describe('ApiClient.getTrendReport: Bucket-Grenzen als lokaler Kalendertag (#531)', () => {
  let api: ApiClient;
  let http: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({ providers: [provideHttpClient(), provideHttpClientTesting()] });
    api = TestBed.inject(ApiClient);
    http = TestBed.inject(HttpTestingController);
  });

  afterEach(() => http.verify());

  function load(): TrendReport {
    let result!: TrendReport;
    // Pfad aus den lokalen Feldern des Bezugstags, in jeder Zone 2026/1/1.
    api.getTrendReport(new Date(2026, 0, 1), 'week').subscribe(r => (result = r));
    http.expectOne(r => r.url.endsWith('/api/reports/trend/2026/1/1')).flush({
      granularity: 'week',
      buckets: [
        { key: '2026-W01', start: '2025-12-29T00:00:00+00:00', end: '2026-01-04T00:00:00+00:00',
          workedMs: 0, targetMs: 0, overtimeMs: 0, cumulativeOvertimeMs: 0, hasData: false },
        { key: '2026-03', start: '2026-03-01T00:00:00Z', end: '2026-03-31T00:00:00Z',
          workedMs: 0, targetMs: 0, overtimeMs: 0, cumulativeOvertimeMs: 0, hasData: false },
      ],
      weeklyTrend: null,
      forecast: {
        targetDate: '2026-12-31', currentBalanceMs: 0, averageWeeklyOvertimeMs: 0, weeksUsed: 4,
        remainingWeeks: 0, projectedBalanceMs: 0,
      },
    });
    return result;
  }

  it('Wochen-Bucket über den Jahreswechsel: Mo 29.12.2025 bis So 04.01.2026', () => {
    const b = load().buckets[0];
    expect(toDateKey(b.start)).toBe('2025-12-29');
    expect(toDateKey(b.end)).toBe('2026-01-04');
    expect(b.start.getTime()).toBe(new Date(2025, 11, 29).getTime());
  });

  it('Monats-Bucket über die Zeitumstellung: 01.03. bis 31.03. als lokale Mitternacht', () => {
    const b = load().buckets[1];
    expect(b.start.getTime()).toBe(new Date(2026, 2, 1).getTime());
    expect(b.end.getTime()).toBe(new Date(2026, 2, 31).getTime());
  });

  it('Prognose-Zieldatum 31.12.2026 ist in jeder Zone der lokale Kalendertag (#532)', () => {
    const f = load().forecast!;
    expect(toDateKey(f.targetDate)).toBe('2026-12-31');
    expect(f.targetDate.getTime()).toBe(new Date(2026, 11, 31).getTime());
  });
});
