import { TestBed } from '@angular/core/testing';
import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { ApiClient } from './api-client';
import { DEFAULT_SETTINGS } from '../../shared/models';
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

describe('ApiClient.saveSettings (bundesland)', () => {
  let api: ApiClient;
  let http: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({ providers: [provideHttpClient(), provideHttpClientTesting()] });
    api = TestBed.inject(ApiClient);
    http = TestBed.inject(HttpTestingController);
  });

  afterEach(() => http.verify());

  function put(settings = DEFAULT_SETTINGS, profileId?: string, opts?: { clearBundesland?: boolean }) {
    void api.saveSettings(settings, profileId, opts);
    const req = http.expectOne(r => r.url.endsWith('/settings'));
    expect(req.request.method).toBe('PUT');
    req.flush({});
    return req.request;
  }

  it('sendet einen gesetzten Wert', () => {
    expect(put({ ...DEFAULT_SETTINGS, bundesland: 'bayern' }).body.bundesland).toBe('bayern');
  });

  it('sendet null ohne Opt als null, nie als ""', () => {
    const body = put({ ...DEFAULT_SETTINGS, bundesland: null }).body;
    expect(body.bundesland).toBeNull();
    expect(body.bundesland).not.toBe('');
  });

  it('sendet "" bei null + clearBundesland', () => {
    expect(put({ ...DEFAULT_SETTINGS, bundesland: null }, undefined, { clearBundesland: true }).body.bundesland).toBe('');
  });

  it('behält einen gesetzten Wert trotz clearBundesland', () => {
    expect(put({ ...DEFAULT_SETTINGS, bundesland: 'hessen' }, undefined, { clearBundesland: true }).body.bundesland).toBe('hessen');
  });

  it('lässt übrige Felder unverändert und setzt profileId', () => {
    const s = { ...DEFAULT_SETTINGS, weeklyTargetHours: 35, workdays: [1, 2, 3], vacationDaysPerYear: 28 };
    const req = put(s, 'p1');
    expect(req.body).toEqual({ ...s, bundesland: null });
    expect(req.params.get('profileId')).toBe('p1');
  });

  it('setzt ohne profileId keinen Parameter', () => {
    expect(put().params.has('profileId')).toBe(false);
  });
});
