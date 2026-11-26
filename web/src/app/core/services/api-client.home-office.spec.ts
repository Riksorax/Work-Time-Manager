import { TestBed } from '@angular/core/testing';
import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { ApiClient } from './api-client';
import { HomeOfficeReport } from '../../domain/models/home-office.models';

/** `GET /api/reports/home-office/{year}?profileId=...` (#537): URL, Parameter und Mapping. */
describe('ApiClient.getHomeOfficeReport (#537)', () => {
  let api: ApiClient;
  let http: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({ providers: [provideHttpClient(), provideHttpClientTesting()] });
    api = TestBed.inject(ApiClient);
    http = TestBed.inject(HttpTestingController);
  });

  afterEach(() => http.verify());

  const months = Array.from({ length: 12 }, (_, i) => ({
    month: i + 1, homeOfficeDays: 0, officeDays: 0, totalDays: 0, homeOfficeRatio: null,
  }));

  it('Standard-Profil: Jahr im Pfad, keine Parameter', () => {
    api.getHomeOfficeReport(2026).subscribe();
    const req = http.expectOne(r => r.url.endsWith('/api/reports/home-office/2026'));
    expect(req.request.method).toBe('GET');
    expect(req.request.params.keys()).toEqual([]);
    req.flush({ year: 2026, homeOfficeDays: 0, officeDays: 0, totalDays: 0, homeOfficeRatio: null, months, homeOfficeDates: [] });
  });

  it('Zusatzprofil: profileId als Parameter', () => {
    api.getHomeOfficeReport(2025, 'p1').subscribe();
    const req = http.expectOne(r => r.url.endsWith('/api/reports/home-office/2025'));
    expect(req.request.params.get('profileId')).toBe('p1');
    req.flush({ year: 2025, homeOfficeDays: 0, officeDays: 0, totalDays: 0, homeOfficeRatio: null, months, homeOfficeDates: [] });
  });

  it('gibt die Werte unverändert weiter (keine Rechnung im Client)', () => {
    let result: HomeOfficeReport | undefined;
    api.getHomeOfficeReport(2026).subscribe(r => (result = r));
    const body = {
      year: 2026, homeOfficeDays: 7, officeDays: 5, totalDays: 12, homeOfficeRatio: 7 / 12, months,
      homeOfficeDates: ['2026-01-05', '2026-02-02'],
    };
    http.expectOne(r => r.url.includes('/home-office/')).flush(body);
    expect(result).toEqual(body);
  });

  it('älteres Backend ohne Listen und Anteil: leere Listen, Anteil null', () => {
    let result: HomeOfficeReport | undefined;
    api.getHomeOfficeReport(2026).subscribe(r => (result = r));
    http.expectOne(r => r.url.includes('/home-office/')).flush({ year: 2026, homeOfficeDays: 0, officeDays: 0, totalDays: 0 });
    expect(result).toEqual({
      year: 2026, homeOfficeDays: 0, officeDays: 0, totalDays: 0, homeOfficeRatio: null, months: [], homeOfficeDates: [],
    });
  });
});
