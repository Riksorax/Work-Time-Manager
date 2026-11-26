import { TestBed } from '@angular/core/testing';
import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { ApiClient } from './api-client';
import { InsightsReport } from '../../domain/models/insights.models';

/** `GET /api/reports/insights/{y}/{m}/{d}?tz=...&profileId=...` (#537): URL, Parameter und Mapping. */
describe('ApiClient.getInsightsReport (#537)', () => {
  let api: ApiClient;
  let http: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({ providers: [provideHttpClient(), provideHttpClientTesting()] });
    api = TestBed.inject(ApiClient);
    http = TestBed.inject(HttpTestingController);
  });

  afterEach(() => http.verify());

  const body: InsightsReport = {
    from: '2026-09-01', to: '2026-11-30', timeZone: 'Europe/Berlin', dailyTargetMs: 28_800_000,
    weekdayAverages: [{ weekday: 1, averageWorkedMs: 30_600_000, deviationMs: 1_800_000, sampleCount: 12 }],
    overtimeStreak: { currentStreak: 6, longestStreak: 8, isWarning: true, warningThresholdDays: 5 },
    startTimeHeatmap: [{ startHour: 7, averageOvertimeMs: 2_700_000, sampleCount: 5 }],
  };

  it('Bezugstag als lokaler Kalendertag im Pfad, tz als Pflichtparameter, ohne profileId im Standard-Profil', () => {
    api.getInsightsReport(new Date(2026, 10, 26, 23, 30), 'America/Los_Angeles').subscribe();
    const req = http.expectOne(r => r.url.endsWith('/api/reports/insights/2026/11/26'));
    expect(req.request.method).toBe('GET');
    expect(req.request.params.get('tz')).toBe('America/Los_Angeles');
    expect(req.request.params.has('profileId')).toBe(false);
    req.flush(body);
  });

  it('Zusatzprofil: profileId und tz', () => {
    api.getInsightsReport(new Date(2026, 0, 5), 'Pacific/Auckland', 'p1').subscribe();
    const req = http.expectOne(r => r.url.endsWith('/api/reports/insights/2026/1/5'));
    expect(req.request.params.get('tz')).toBe('Pacific/Auckland');
    expect(req.request.params.get('profileId')).toBe('p1');
    req.flush(body);
  });

  it('gibt die Antwort unverändert weiter (Kalendertage bleiben Strings, keine Rechnung)', () => {
    let result: InsightsReport | undefined;
    api.getInsightsReport(new Date(2026, 10, 26), 'Europe/Berlin').subscribe(r => (result = r));
    http.expectOne(r => r.url.includes('/insights/')).flush(body);
    expect(result).toEqual(body);
  });

  it('fehlende Listen und Serie (älteres Backend): leer bzw. 0 ohne Hinweis', () => {
    let result: InsightsReport | undefined;
    api.getInsightsReport(new Date(2026, 10, 26), 'Europe/Berlin').subscribe(r => (result = r));
    http.expectOne(r => r.url.includes('/insights/'))
      .flush({ from: '2026-09-01', to: '2026-11-30', timeZone: 'Europe/Berlin', dailyTargetMs: 0 });
    expect(result?.weekdayAverages).toEqual([]);
    expect(result?.startTimeHeatmap).toEqual([]);
    expect(result?.overtimeStreak).toEqual({ currentStreak: 0, longestStreak: 0, isWarning: false, warningThresholdDays: 5 });
  });
});
