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

describe('ApiClient.getWorkEntriesForMonth (#385)', () => {
  let api: ApiClient;
  let http: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({ providers: [provideHttpClient(), provideHttpClientTesting()] });
    api = TestBed.inject(ApiClient);
    http = TestBed.inject(HttpTestingController);
  });

  afterEach(() => http.verify());

  const dto = {
    id: '2026-10-02',
    date: '2026-10-02T00:00:00Z',
    workStart: '2026-10-02T20:00:30Z',
    workEnd: null,
    type: 'work',
    isManuallyEntered: false,
    manualOvertimeMinutes: null,
    description: null,
    breaks: [{ id: 'b1', name: 'Pause', isAutomatic: false, start: '2026-10-02T21:00:00Z', end: null }],
  };

  it('GET /work-entries/{y}/{m} ohne profileId-Parameter, mappt das DTO inkl. id', async () => {
    const p = api.getWorkEntriesForMonth(2026, 10);
    const req = http.expectOne(r => r.url.endsWith('/api/work-entries/2026/10'));
    expect(req.request.method).toBe('GET');
    expect(req.request.params.has('profileId')).toBe(false);
    req.flush([dto]);
    const [e] = await p;
    expect(e.id).toBe('2026-10-02');
    expect(e.workStart).toEqual(new Date('2026-10-02T20:00:00Z')); // auf Minute abgeschnitten
    expect(e.workEnd).toBeUndefined();
    expect(e.breaks[0].end).toBeUndefined();
    expect(e.type).toBe('work');
  });

  it('setzt profileId, falls angegeben', async () => {
    const p = api.getWorkEntriesForMonth(2026, 11, 'p1');
    const req = http.expectOne(r => r.url.endsWith('/api/work-entries/2026/11'));
    expect(req.request.params.get('profileId')).toBe('p1');
    req.flush([]);
    expect(await p).toEqual([]);
  });

  it('der Tag eines Eintrags bleibt die id, auch wenn date in der Zone auf den Vortag fällt', async () => {
    const p = api.getWorkEntriesForMonth(2026, 10);
    http.expectOne(r => r.url.endsWith('/api/work-entries/2026/10')).flush([dto]);
    const [e] = await p;
    // `date` ist UTC-Mitternacht; lokal kann das der Vortag sein. Maßgeblich ist die id.
    expect(e.id).toBe('2026-10-02');
    expect(e.date.getTime()).toBe(Date.UTC(2026, 9, 2));
  });
});

describe('ApiClient.saveOvertimeMs (#385, keepLastUpdated)', () => {
  let api: ApiClient;
  let http: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({ providers: [provideHttpClient(), provideHttpClientTesting()] });
    api = TestBed.inject(ApiClient);
    http = TestBed.inject(HttpTestingController);
  });

  afterEach(() => http.verify());

  function put(ms: number, profileId?: string, opts?: { keepLastUpdated?: boolean }) {
    void api.saveOvertimeMs(ms, profileId, opts);
    const req = http.expectOne(r => r.url.endsWith('/api/overtime'));
    expect(req.request.method).toBe('PUT');
    req.flush({ minutes: 0, lastUpdated: null });
    return req.request;
  }

  it('sendet mit keepLastUpdated: true { minutes, keepLastUpdated: true }', () => {
    const req = put(90 * 60_000, 'p1', { keepLastUpdated: true });
    expect(req.body).toEqual({ minutes: 90, keepLastUpdated: true });
    expect(req.params.get('profileId')).toBe('p1');
  });

  it('ohne Option bleibt der Body unverändert { minutes } ohne keepLastUpdated-Schlüssel', () => {
    const req = put(90 * 60_000);
    expect(req.body).toEqual({ minutes: 90 });
    expect('keepLastUpdated' in req.body).toBe(false);
    expect(req.params.has('profileId')).toBe(false);
  });

  it('keepLastUpdated: false / leere Option sendet das Feld nicht', () => {
    expect('keepLastUpdated' in put(60_000, undefined, { keepLastUpdated: false }).body).toBe(false);
    expect('keepLastUpdated' in put(60_000, undefined, {}).body).toBe(false);
  });
});
