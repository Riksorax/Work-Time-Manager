import { TestBed } from '@angular/core/testing';
import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { ApiClient } from './api-client';
import { TrendReport } from '../../domain/models/trend.models';

/** `GET /api/reports/trend/{y}/{m}/{d}?granularity=...` (#531): URL, Parameter, Abbildung der Felder. */
describe('ApiClient.getTrendReport (#531)', () => {
  let api: ApiClient;
  let http: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({ providers: [provideHttpClient(), provideHttpClientTesting()] });
    api = TestBed.inject(ApiClient);
    http = TestBed.inject(HttpTestingController);
  });

  afterEach(() => http.verify());

  const bucket = {
    key: '2026-W45', start: '2026-11-02T00:00:00+00:00', end: '2026-11-08T00:00:00+00:00',
    workedMs: 144_000_000, targetMs: 144_000_000, overtimeMs: -1_800_000, cumulativeOvertimeMs: 5_400_000, hasData: true,
  };

  it('Bezugstag aus den lokalen Feldern im Pfad, granularity als Parameter, ohne profileId', () => {
    api.getTrendReport(new Date(2026, 10, 9), 'week').subscribe();
    const req = http.expectOne(r => r.url.endsWith('/api/reports/trend/2026/11/9'));
    expect(req.request.method).toBe('GET');
    expect(req.request.params.get('granularity')).toBe('week');
    expect(req.request.params.has('profileId')).toBe(false);
    req.flush({ granularity: 'week', buckets: [], weeklyTrend: null });
  });

  it('setzt profileId und granularity=month', () => {
    api.getTrendReport(new Date(2026, 0, 31), 'month', 'p1').subscribe();
    const req = http.expectOne(r => r.url.endsWith('/api/reports/trend/2026/1/31'));
    expect(req.request.params.get('granularity')).toBe('month');
    expect(req.request.params.get('profileId')).toBe('p1');
    req.flush({ granularity: 'month', buckets: [], weeklyTrend: null });
  });

  it('bildet Buckets und Wochen-Trend ohne Umrechnung ab (Dauern in ms)', () => {
    let result: TrendReport | undefined;
    api.getTrendReport(new Date(2026, 10, 9), 'week').subscribe(r => (result = r));
    http.expectOne(r => r.url.includes('/api/reports/trend/')).flush({
      granularity: 'week',
      buckets: [bucket, { ...bucket, key: '2026-W46', hasData: false, workedMs: 0, targetMs: 0, overtimeMs: 0 }],
      weeklyTrend: {
        lastWeekKey: '2026-W45', lastWeekWorkedMs: 150_000_000, averageWorkedMs: 141_000_000,
        deltaMs: 9_000_000, comparedWeeks: 4,
      },
    });
    expect(result!.granularity).toBe('week');
    expect(result!.buckets).toHaveLength(2);
    const b = result!.buckets[0];
    expect([b.key, b.worked, b.target, b.overtime, b.cumulativeOvertime, b.hasData])
      .toEqual(['2026-W45', 144_000_000, 144_000_000, -1_800_000, 5_400_000, true]);
    expect(result!.buckets[1].hasData).toBe(false);
    expect(result!.weeklyTrend).toEqual({
      lastWeekKey: '2026-W45', lastWeekWorked: 150_000_000, averageWorked: 141_000_000, delta: 9_000_000, comparedWeeks: 4,
    });
  });

  it('weeklyTrend = null bleibt null', () => {
    let result: TrendReport | undefined;
    api.getTrendReport(new Date(2026, 10, 9), 'month').subscribe(r => (result = r));
    http.expectOne(r => r.url.includes('/api/reports/trend/')).flush({ granularity: 'month', buckets: [], weeklyTrend: null });
    expect(result!.weeklyTrend).toBeNull();
  });

  describe('forecast (#532)', () => {
    function load(body: Record<string, unknown>): TrendReport {
      let result!: TrendReport;
      api.getTrendReport(new Date(2026, 10, 9), 'week').subscribe(r => (result = r));
      http.expectOne(r => r.url.includes('/api/reports/trend/')).flush({ granularity: 'week', buckets: [], weeklyTrend: null, ...body });
      return result;
    }

    it('bildet die Prognose ohne Umrechnung ab (ms, Restwochen ungerundet, targetDate als lokaler Kalendertag)', () => {
      const r = load({
        forecast: {
          targetDate: '2026-12-31', currentBalanceMs: 67_500_000, averageWeeklyOvertimeMs: 4_500_000,
          weeksUsed: 6, remainingWeeks: 7.142857, projectedBalanceMs: 117_000_000,
        },
      });
      expect(r.forecast).toEqual({
        targetDate: new Date(2026, 11, 31), currentBalance: 67_500_000, averageWeeklyOvertime: 4_500_000,
        weeksUsed: 6, remainingWeeks: 7.142857, projectedBalance: 117_000_000,
      });
    });

    it('forecast = null bleibt null', () => {
      expect(load({ forecast: null }).forecast).toBeNull();
    });

    it('fehlendes Feld (älteres Backend) gilt als null', () => {
      expect(load({}).forecast).toBeNull();
    });

    it('unlesbares targetDate gilt als null', () => {
      expect(load({
        forecast: { targetDate: 'x', currentBalanceMs: 0, averageWeeklyOvertimeMs: 0, weeksUsed: 4, remainingWeeks: 1, projectedBalanceMs: 0 },
      }).forecast).toBeNull();
    });
  });
});
