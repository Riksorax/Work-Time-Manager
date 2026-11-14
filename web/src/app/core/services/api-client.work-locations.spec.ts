import { TestBed } from '@angular/core/testing';
import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { ApiClient } from './api-client';
import { DEFAULT_SETTINGS, WorkEntry, WorkEntryType } from '../../shared/models';

/** Arbeitsorte und Dashboard-Einstellungen im ApiClient (#526). */
describe('ApiClient: workLocations (#526)', () => {
  let api: ApiClient;
  let http: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({ providers: [provideHttpClient(), provideHttpClientTesting()] });
    api = TestBed.inject(ApiClient);
    http = TestBed.inject(HttpTestingController);
  });

  afterEach(() => http.verify());

  const entry = (workLocations?: string[]): WorkEntry => ({
    id: '2026-06-05', date: new Date(2026, 5, 5), breaks: [], isManuallyEntered: false,
    type: WorkEntryType.Work, workLocations,
  });

  function putBody(e: WorkEntry): Record<string, unknown> {
    void api.saveWorkEntry(e);
    const req = http.expectOne(r => r.url.endsWith('/work-entries'));
    req.flush({});
    return req.request.body as Record<string, unknown>;
  }

  it('toDto: undefined wird null (Backend lässt Orte unangetastet)', () => {
    expect(putBody(entry(undefined))['workLocations']).toBeNull();
  });

  it('toDto: [] wird als [] gesendet (Backend entfernt das Feld)', () => {
    expect(putBody(entry([]))['workLocations']).toEqual([]);
  });

  it('toDto: Liste wird bereinigt gesendet (trimmen, Duplikate ohne Groß-/Kleinschreibung, leere weg)', () => {
    expect(putBody(entry([' Büro ', 'büro', '', 'Zuhause']))['workLocations']).toEqual(['Büro', 'Zuhause']);
  });

  it('toDto: mehr als 5 Orte werden auf 5 begrenzt', () => {
    expect(putBody(entry(['1', '2', '3', '4', '5', '6']))['workLocations']).toEqual(['1', '2', '3', '4', '5']);
  });

  it.each([
    [{ workLocations: ['Büro', 'Kunde'] }, ['Büro', 'Kunde']],
    [{ workLocations: [] }, []],
    [{ workLocations: null }, []],
    [{}, []],
  ])('fromDto %j -> %j', async (extra, expected) => {
    const p = api.getWorkEntriesForMonth(2026, 6);
    http.expectOne(r => r.url.endsWith('/api/work-entries/2026/6')).flush([{
      id: '2026-06-05', date: '2026-06-05T00:00:00Z', workStart: null, workEnd: null, type: 'work',
      isManuallyEntered: false, manualOvertimeMinutes: null, description: null, breaks: [], ...extra,
    }]);
    const [e] = await p;
    expect(e.workLocations).toEqual(expected);
  });

  it('Einstellungen: beide Dashboard-Felder gehen im PUT mit', () => {
    void api.saveSettings({ ...DEFAULT_SETTINGS, showWorkLocationOnDashboard: true, showHomeOfficeOnDashboard: false });
    const req = http.expectOne(r => r.url.endsWith('/settings'));
    req.flush({});
    expect(req.request.body).toEqual(expect.objectContaining({
      showWorkLocationOnDashboard: true, showHomeOfficeOnDashboard: false,
    }));
  });
});
