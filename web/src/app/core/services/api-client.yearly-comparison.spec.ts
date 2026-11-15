import { TestBed } from '@angular/core/testing';
import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { ApiClient } from './api-client';
import { YearlyComparison } from '../../domain/models/yearly-comparison.models';

/** `GET /api/reports/yearly-comparison/{year}?until=MM-dd&profileId=...` (#530): URL und Parameter. */
describe('ApiClient.getYearlyComparison (#530)', () => {
  let api: ApiClient;
  let http: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({ providers: [provideHttpClient(), provideHttpClientTesting()] });
    api = TestBed.inject(ApiClient);
    http = TestBed.inject(HttpTestingController);
  });

  afterEach(() => http.verify());

  const summary = (year: number) => ({
    year, hasData: true, totalWorkedMs: 1, totalBreaksMs: 0, overtimeMs: 0, workDays: 1, vacationDays: 0, sickDays: 0,
    holidayDays: 0, months: [],
  });

  it('abgeschlossenes Jahr: ohne until und ohne profileId', () => {
    api.getYearlyComparison(2025).subscribe();
    const req = http.expectOne(r => r.url.endsWith('/api/reports/yearly-comparison/2025'));
    expect(req.request.method).toBe('GET');
    expect(req.request.params.keys()).toEqual([]);
    req.flush({ until: null, current: summary(2025), previous: summary(2024), delta: null });
  });

  it('laufendes Jahr: until als Parameter, mit profileId', () => {
    api.getYearlyComparison(2026, '11-14', 'p1').subscribe();
    const req = http.expectOne(r => r.url.endsWith('/api/reports/yearly-comparison/2026'));
    expect(req.request.params.get('until')).toBe('11-14');
    expect(req.request.params.get('profileId')).toBe('p1');
    req.flush({ until: '11-14', current: summary(2026), previous: summary(2025), delta: null });
  });

  it('nur profileId, kein leeres until', () => {
    api.getYearlyComparison(2024, undefined, 'p2').subscribe();
    const req = http.expectOne(r => r.url.endsWith('/api/reports/yearly-comparison/2024'));
    expect(req.request.params.has('until')).toBe(false);
    expect(req.request.params.get('profileId')).toBe('p2');
    req.flush({ until: null, current: summary(2024), previous: summary(2023), delta: null });
  });

  it('gibt die Antwort unverändert weiter (keine Rechnung im Client)', () => {
    let result: YearlyComparison | undefined;
    api.getYearlyComparison(2025).subscribe(r => (result = r));
    const body = {
      until: null, current: summary(2025), previous: summary(2024),
      delta: { workedMs: 5, workedPercent: 12.4, overtimeMs: -3, workDays: 2, vacationDays: -1, sickDays: 0, holidayDays: 1 },
    };
    http.expectOne(r => r.url.includes('/yearly-comparison/')).flush(body);
    expect(result).toEqual(body);
  });
});
