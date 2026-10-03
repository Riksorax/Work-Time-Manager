import { TestBed } from '@angular/core/testing';
import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { ApiClient } from './api-client';
import { YearlyLeaveReport } from '../../domain/models/leave.models';

describe('ApiClient.getYearlyLeave', () => {
  let api: ApiClient;
  let http: HttpTestingController;
  const dto: YearlyLeaveReport = {
    year: 2026, vacationDaysPerYear: 30, vacationDaysTaken: 5, vacationDaysRemaining: 25, sickDays: 2,
  };

  beforeEach(() => {
    TestBed.configureTestingModule({ providers: [provideHttpClient(), provideHttpClientTesting()] });
    api = TestBed.inject(ApiClient);
    http = TestBed.inject(HttpTestingController);
  });

  afterEach(() => http.verify());

  it('ruft den Endpunkt ohne profileId-Parameter auf und reicht die Antwort unverändert durch', () => {
    let result: YearlyLeaveReport | undefined;
    api.getYearlyLeave(2026).subscribe(r => (result = r));
    const req = http.expectOne(r => r.url.endsWith('/api/reports/yearly/2026'));
    expect(req.request.method).toBe('GET');
    expect(req.request.params.has('profileId')).toBe(false);
    req.flush(dto);
    expect(result).toEqual(dto);
  });

  it('setzt profileId, falls angegeben', () => {
    api.getYearlyLeave(2025, 'p1').subscribe();
    const req = http.expectOne(r => r.url.endsWith('/api/reports/yearly/2025'));
    expect(req.request.params.get('profileId')).toBe('p1');
    req.flush(dto);
  });
});
