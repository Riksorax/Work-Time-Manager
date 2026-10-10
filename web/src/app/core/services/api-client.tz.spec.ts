import { TestBed } from '@angular/core/testing';
import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { ApiClient } from './api-client';
import { toDateKey } from '../../shared/utils/german-holidays.util';
import { getIsoWeekNumber } from '../../shared/utils/iso-week.util';
import { entryDto, EntryDtoFixture } from '../../shared/testing/mapped-entries';
import { WorkEntry } from '../../shared/models';

/**
 * Zonen-Regressionstests (#407). Das Backend liefert `date` als UTC-Mitternacht des Kalendertags; westlich von UTC
 * ergibt `new Date(iso)` lokal den Vortag. Die Tests schicken DTOs durch den echten Mapper (`fromDto`) und laufen
 * in CI zusätzlich unter America/Los_Angeles und Pacific/Auckland.
 */
describe('ApiClient: Kalendertag eines Eintrags (#407)', () => {
  let api: ApiClient;
  let http: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({ providers: [provideHttpClient(), provideHttpClientTesting()] });
    api = TestBed.inject(ApiClient);
    http = TestBed.inject(HttpTestingController);
  });

  afterEach(() => {
    http.verify();
    TestBed.resetTestingModule();
  });

  async function load(dtos: EntryDtoFixture[], year = 2026, month = 10, profileId?: string): Promise<WorkEntry[]> {
    const p = api.getWorkEntriesForMonth(year, month, profileId);
    http.expectOne(r => r.url.endsWith(`/api/work-entries/${year}/${month}`)).flush(dtos);
    return p;
  }

  const localMidnight = (y: number, m: number, d: number): number => new Date(y, m - 1, d).getTime();

  describe('R1: UTC-Mitternacht ergibt den Kalendertag der id', () => {
    it.each([
      ['Z', '2026-10-05T00:00:00Z'],
      ['+00:00', '2026-10-05T00:00:00+00:00'],
      ['.000Z', '2026-10-05T00:00:00.000Z'],
    ])('date mit Suffix %s: 05.10.2026, Montag, id unverändert', async (_label, iso) => {
      const [e] = await load([entryDto('2026-10-05', iso)]);
      expect(toDateKey(e.date)).toBe('2026-10-05');
      expect(e.date.getDay()).toBe(1);
      expect(e.id).toBe('2026-10-05');
    });

    it('mit profileId: gleiche Abbildung (Mapper sind profilunabhängig)', async () => {
      const [e] = await load([entryDto('2026-10-05')], 2026, 10, 'p1');
      expect(toDateKey(e.date)).toBe('2026-10-05');
      expect(e.date.getDay()).toBe(1);
    });
  });

  describe('R2: Randfälle', () => {
    it('Monatserster 2026-11-01 (Sonntag) liegt im November', async () => {
      const [e] = await load([entryDto('2026-11-01')], 2026, 11);
      expect(e.date.getMonth()).toBe(10);
      expect(e.date.getDate()).toBe(1);
      expect(e.date.getDay()).toBe(0);
    });

    it('Jahresgrenze 2026-01-01 (Donnerstag) liegt in 2026', async () => {
      const [e] = await load([entryDto('2026-01-01')], 2026, 1);
      expect(e.date.getFullYear()).toBe(2026);
      expect(e.date.getDay()).toBe(4);
    });

    it('Sonntag 04.10. (KW 40) und Montag 05.10. (KW 41) bleiben getrennt', async () => {
      const [so, mo] = await load([entryDto('2026-10-04'), entryDto('2026-10-05')]);
      expect(getIsoWeekNumber(so.date)).toBe(40);
      expect(getIsoWeekNumber(mo.date)).toBe(41);
    });
  });

  describe('R3: die id gewinnt über date (Altdaten)', () => {
    it('date auf dem Vortag: Tag bleibt 05.10.', async () => {
      const [e] = await load([entryDto('2026-10-05', '2026-10-04T00:00:00Z')]);
      expect(toDateKey(e.date)).toBe('2026-10-05');
    });

    it('Altdaten date = lokale Mitternacht Berlin als UTC (22:00Z am Vortag): Tag bleibt 05.10.', async () => {
      const [e] = await load([entryDto('2026-10-05', '2026-10-04T22:00:00Z')]);
      expect(toDateKey(e.date)).toBe('2026-10-05');
    });
  });

  describe('R4: ungültige id fällt auf die UTC-Felder von date zurück', () => {
    it.each(['1', 'x', '2026-3-2', '2026-13-45', '2026-02-30', '2026-10-05T00:00:00Z', ''])(
      'id %j: Kalendertag aus date (UTC-Felder) 05.10.',
      async id => {
        const [e] = await load([entryDto(id, '2026-10-05T00:00:00Z')]);
        expect(toDateKey(e.date)).toBe('2026-10-05');
      },
    );
  });

  describe('R5: Zeitpunkte bleiben echte Instants', () => {
    it('workStart, workEnd und Pausen werden minutengenau, aber nicht verschoben', async () => {
      const [e] = await load([entryDto('2026-10-05', undefined, {
        workStart: '2026-10-05T06:00:30Z',
        workEnd: '2026-10-05T14:00:00Z',
        breaks: [{ id: 'b1', name: 'Pause', isAutomatic: false, start: '2026-10-05T09:00:00Z', end: '2026-10-05T09:30:00Z' }],
      })]);
      expect(e.workStart!.getTime()).toBe(new Date('2026-10-05T06:00:00Z').getTime());
      expect(e.workEnd!.getTime()).toBe(new Date('2026-10-05T14:00:00Z').getTime());
      expect(e.breaks[0].start.getTime()).toBe(new Date('2026-10-05T09:00:00Z').getTime());
      expect(e.breaks[0].end!.getTime()).toBe(new Date('2026-10-05T09:30:00Z').getTime());
    });
  });

  describe('R6: Schreibpfad ohne Slot-Wechsel', () => {
    it.each(['2026-10-05', '2026-11-01', '2026-01-01'])(
      'geladener Eintrag %s unverändert gespeichert: PUT-Body date = UTC-Mitternacht, id unverändert',
      async id => {
        const [e] = await load([entryDto(id)], 2026, Number(id.slice(5, 7)));
        const p = api.saveWorkEntry(e);
        const req = http.expectOne(r => r.method === 'PUT' && r.url.endsWith('/api/work-entries'));
        req.flush({});
        await p;
        expect(req.request.body.date).toBe(`${id}T00:00:00.000Z`);
        expect(req.request.body.id).toBe(id);
      },
    );
  });

  describe('E1: Mitternacht statt Zeitpunkt (Europa, Sommer/Winter)', () => {
    it.each([
      ['Sommer', '2026-07-15', 2026, 7, 15],
      ['Winter', '2026-01-15', 2026, 1, 15],
    ])('%s %s: date ist die lokale Mitternacht des Tages', async (_label, id, y, m, d) => {
      const [e] = await load([entryDto(id)], y, m);
      expect(e.date.getTime()).toBe(localMidnight(y, m, d));
      expect(e.date.getHours()).toBe(0);
    });
  });

  describe('E2: Zeitumstellungstage', () => {
    // Berlin 29.03./25.10., Los Angeles 08.03./01.11., Auckland 27.09./05.04.: jeweils Vor-, Umstell- und Folgetag
    const triples: [number, number, number][] = [
      [2026, 3, 28], [2026, 10, 24], [2026, 3, 7], [2026, 10, 31], [2026, 9, 26], [2026, 4, 4],
    ];
    const iso = (y: number, m: number, d: number): string =>
      `${y}-${String(m).padStart(2, '0')}-${String(d).padStart(2, '0')}`;

    it.each(triples)('Tage ab %i-%i-%i: jedes date ist lokale Mitternacht, Folgetag lückenlos', async (y, m, d) => {
      const ids = [0, 1, 2].map(i => {
        const day = new Date(y, m - 1, d + i);
        return iso(day.getFullYear(), day.getMonth() + 1, day.getDate());
      });
      const entries = await load(ids.map(id => entryDto(id)), y, m);
      entries.forEach((e, i) => {
        expect(e.date.getTime()).toBe(localMidnight(y, m, d + i));
        expect(e.date.getHours()).toBe(0);
      });
      // Invariante statt Stundenzahl: der Folgetag beginnt genau dort, wo der Vortag laut Kalender endet
      expect(new Date(y, m - 1, d + 1).getTime()).toBe(entries[1].date.getTime());
      expect(new Date(y, m - 1, d + 2).getTime()).toBe(entries[2].date.getTime());
    });
  });

  describe('E3: Reihenfolge', () => {
    it('Sortierung nach date.getTime() entspricht der id-Reihenfolge, auch über Zeitumstellungspaare', async () => {
      const ids = ['2026-03-29', '2026-03-28', '2026-03-30', '2026-03-08', '2026-03-07', '2026-03-09', '2026-04-05', '2026-04-04'];
      const entries = await load(ids.map(id => entryDto(id)), 2026, 3);
      const byTime = [...entries].sort((a, b) => a.date.getTime() - b.date.getTime()).map(e => e.id);
      expect(byTime).toEqual([...ids].sort());
    });
  });

  describe('E4: Round-Trip fromDto -> toDto', () => {
    const ids = [
      '2026-07-15', '2026-01-15', '2026-03-28', '2026-03-29', '2026-03-30', '2026-10-24', '2026-10-25', '2026-10-26',
      '2026-03-07', '2026-03-08', '2026-03-09', '2026-10-31', '2026-11-01', '2026-11-02',
      '2026-09-26', '2026-09-27', '2026-09-28', '2026-04-04', '2026-04-05', '2026-04-06',
    ];
    it.each(ids)('%s: dieselbe UTC-Mitternacht wie das Eingabe-DTO', async id => {
      const [e] = await load([entryDto(id)], Number(id.slice(0, 4)), Number(id.slice(5, 7)));
      const p = api.saveWorkEntry(e);
      const req = http.expectOne(r => r.method === 'PUT' && r.url.endsWith('/api/work-entries'));
      req.flush({});
      await p;
      expect(req.request.body.date).toBe(`${id}T00:00:00.000Z`);
    });
  });
});
