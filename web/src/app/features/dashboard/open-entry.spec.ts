import { TestBed } from '@angular/core/testing';
import { signal } from '@angular/core';
import { OpenEntryService } from './open-entry';
import { CloseResult, OpenEntryCandidate, OpenEntryCloseService } from './open-entry-close';
import { DashboardService } from './dashboard.service';
import { WorkEntryService } from '../../core/services/work-entry';
import { AuthService } from '../../core/auth/auth';
import { WorkProfileService } from '../../core/services/work-profile';
import { TodayService } from '../../core/services/today';
import { createFakeWorkProfile, FakeWorkProfile } from '../../shared/testing/work-profile-fake';
import { WorkEntry, WorkEntryType } from '../../shared/models';
import { localDateFromEntryId } from '../../domain/utils/open-entry.utils';

type TestUser = { uid: string } | null | undefined;

function open(id: string, extra: Partial<WorkEntry> = {}): WorkEntry {
  const day = localDateFromEntryId(id);
  return {
    id,
    date: day,
    workStart: new Date(day.getFullYear(), day.getMonth(), day.getDate(), 22, 0),
    breaks: [],
    isManuallyEntered: false,
    type: WorkEntryType.Work,
    ...extra,
  };
}

async function flush(): Promise<void> {
  for (let i = 0; i < 40; i++) {
    TestBed.tick();
    await Promise.resolve();
  }
}

interface Env {
  svc: OpenEntryService;
  user: ReturnType<typeof signal<TestUser>>;
  profile: FakeWorkProfile;
  dashLoading: ReturnType<typeof signal<boolean>>;
  dashEntry: ReturnType<typeof signal<WorkEntry>>;
  reload: ReturnType<typeof vi.fn>;
  closeFn: ReturnType<typeof vi.fn>;
  reads: { year: number; month: number; pid: string | undefined }[];
  months: Map<string, WorkEntry[] | Error>;
  gates: Map<string, Promise<void>>;
  today: TodayService;
}

function setup(init: { user?: TestUser; pid?: string } = {}): Env {
  const user = signal<TestUser>('user' in init ? init.user : { uid: 'u1' });
  const profile = createFakeWorkProfile(init.pid ?? 'A');
  const dashLoading = signal(false);
  const dashEntry = signal<WorkEntry>({
    id: '2026-10-03', date: new Date(2026, 9, 3), breaks: [], isManuallyEntered: false, type: WorkEntryType.Work,
  });
  const reload = vi.fn().mockResolvedValue(undefined);
  const closeFn = vi.fn().mockResolvedValue('closed' as CloseResult);
  const reads: Env['reads'] = [];
  const months = new Map<string, WorkEntry[] | Error>();
  const gates = new Map<string, Promise<void>>();

  TestBed.resetTestingModule();
  TestBed.configureTestingModule({
    providers: [
      { provide: AuthService, useValue: { user: user.asReadonly(), get uid() { return user()?.uid ?? null; } } },
      { provide: WorkProfileService, useValue: profile },
      { provide: DashboardService, useValue: {
        isLoading: dashLoading.asReadonly(), workEntry: dashEntry.asReadonly(), reloadAfterRetroClose: reload,
      } },
      { provide: OpenEntryCloseService, useValue: { endEntry: closeFn } },
      { provide: WorkEntryService, useValue: {
        getEntriesForMonthOnce: async (year: number, month: number, pid?: string) => {
          reads.push({ year, month, pid });
          const key = `${pid}|${year}-${month}`;
          const gate = gates.get(key);
          if (gate) await gate;
          const v = months.get(key);
          if (v instanceof Error) throw v;
          return v ?? [];
        },
      } },
    ],
  });
  const svc = TestBed.inject(OpenEntryService);
  return { svc, user, profile, dashLoading, dashEntry, reload, closeFn, reads, months, gates, today: TestBed.inject(TodayService) };
}

const ids = (svc: OpenEntryService): string[] => svc.entries().map(e => e.id);

describe('OpenEntryService (#385)', () => {
  beforeEach(() => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date(2026, 9, 3, 9, 0)); // Sa 2026-10-03 09:00
  });
  afterEach(() => {
    TestBed.resetTestingModule();
    vi.useRealTimers();
    vi.restoreAllMocks();
  });

  describe('Suche und Filter', () => {
    it('Fr 22:00 offen, jetzt Sa 09:00 ⇒ ein Treffer mit Profil des Aufrufs', async () => {
      const env = setup();
      env.months.set('A|2026-10', [open('2026-10-02')]);
      await flush();
      expect(env.svc.entries()).toEqual([{ id: '2026-10-02', profileId: 'A' }]);
      expect(env.svc.current()).toEqual({ id: '2026-10-02', profileId: 'A' });
    });

    it('re-triggern: Treffer erscheinen erst, wenn die Daten da sind (initial leer)', async () => {
      const env = setup();
      expect(env.svc.entries()).toEqual([]);
      await flush();
      expect(env.svc.entries()).toEqual([]);
    });

    it('heute offen, Zukunft, abgeschlossen, ohne Start, Typ vacation/sick/holiday ⇒ keine Treffer', async () => {
      const env = setup();
      env.months.set('A|2026-10', [
        open('2026-10-03'),
        open('2026-10-04'),
        open('2026-10-01', { workEnd: new Date(2026, 9, 1, 23, 0) }),
        open('2026-09-30', { workStart: undefined }),
        open('2026-10-02', { type: WorkEntryType.Vacation }),
        open('2026-10-02', { type: WorkEntryType.Sick }),
        open('2026-10-02', { type: WorkEntryType.Holiday }),
      ]);
      await flush();
      expect(env.svc.entries()).toEqual([]);
    });

    it('Monatsgrenze: heute 2026-11-01 liest 2026-11 und 2026-10, sonst nichts', async () => {
      vi.setSystemTime(new Date(2026, 10, 1, 9, 0));
      const env = setup();
      env.months.set('A|2026-10', [open('2026-10-31')]);
      await flush();
      const read = env.reads.map(r => `${r.year}-${r.month}`).sort();
      expect(read).toEqual(['2026-10', '2026-11']);
      expect(ids(env.svc)).toEqual(['2026-10-31']);
    });

    it('Jahreswechsel: im Januar wird der Dezember des Vorjahres gelesen', async () => {
      vi.setSystemTime(new Date(2026, 0, 5, 9, 0));
      const env = setup();
      env.months.set('A|2025-12', [open('2025-12-31')]);
      await flush();
      expect(env.reads.map(r => `${r.year}-${r.month}`).sort()).toEqual(['2025-12', '2026-1']);
      expect(ids(env.svc)).toEqual(['2025-12-31']);
    });

    it('der Vor-Vormonat wird nie gelesen', async () => {
      const env = setup();
      await flush();
      expect(env.reads.some(r => r.year === 2026 && r.month === 8)).toBe(false);
      expect(env.reads.length).toBe(2);
    });

    it('mehrere Treffer: neuester zuerst, auch bei unsortierter Antwort; moreCount', async () => {
      const env = setup();
      env.months.set('A|2026-10', [open('2026-10-01'), open('2026-10-02')]);
      env.months.set('A|2026-9', [open('2026-09-29')]);
      await flush();
      expect(ids(env.svc)).toEqual(['2026-10-02', '2026-10-01', '2026-09-29']);
      expect(env.svc.moreCount()).toBe(2);
    });

    it('moreCount ist 0 bei einem Treffer und ohne Treffer', async () => {
      const env = setup();
      expect(env.svc.moreCount()).toBe(0);
      env.months.set('A|2026-10', [open('2026-10-02')]);
      await flush();
      env.svc.later();
      expect(env.svc.moreCount()).toBe(0);
    });

    it('Tag nur aus der id: ein date, das in LA auf den Vortag fiele, ändert den Tag nicht', async () => {
      const env = setup();
      env.months.set('A|2026-10', [open('2026-10-02', { date: new Date(Date.UTC(2026, 9, 2)) })]);
      await flush();
      expect(ids(env.svc)).toEqual(['2026-10-02']);
    });

    it('Tag nur aus der id: id von heute/Zukunft bleibt draußen, id vor heute bleibt drin, egal welches date', async () => {
      const env = setup();
      env.dashEntry.set(open('2026-10-05', { workStart: undefined })); // Dashboard zeigt keinen der Kandidaten
      env.months.set('A|2026-10', [
        open('2026-10-03', { date: new Date(2026, 9, 1) }),
        open('2026-10-04', { date: new Date(2026, 9, 1) }),
        open('2026-10-02', { date: new Date(2026, 9, 20) }),
      ]);
      await flush();
      expect(ids(env.svc)).toEqual(['2026-10-02']);
    });

    it('der heutige offene Eintrag (id = heute) ist kein Kandidat, auch ohne Dashboard-Ausschluss', async () => {
      const env = setup();
      env.dashEntry.set(open('2026-10-05', { workStart: undefined }));
      env.months.set('A|2026-10', [open('2026-10-03')]);
      await flush();
      expect(ids(env.svc)).toEqual([]);
    });

    it('Lesefehler eines Monats: der andere liefert weiter', async () => {
      const env = setup();
      env.months.set('A|2026-10', new Error('offline'));
      env.months.set('A|2026-9', [open('2026-09-30')]);
      await flush();
      expect(ids(env.svc)).toEqual(['2026-09-30']);
    });

    it('beide Monate fehlerhaft: leer, kein Wurf', async () => {
      const env = setup();
      env.months.set('A|2026-10', new Error('offline'));
      env.months.set('A|2026-9', new Error('offline'));
      await flush();
      expect(ids(env.svc)).toEqual([]);
    });

    it('liest immer mit explizitem Profil', async () => {
      const env = setup({ pid: 'default' });
      await flush();
      expect(env.reads.map(r => r.pid)).toEqual(['default', 'default']);
    });
  });

  describe('Sichtbarkeit', () => {
    it('im Dashboard laufender Vortag ist kein Kandidat; nach dessen Stop kommt er nicht zurück', async () => {
      const env = setup();
      env.months.set('A|2026-10', [open('2026-10-02')]);
      env.dashEntry.set(open('2026-10-02')); // läuft im Dashboard
      await flush();
      expect(ids(env.svc)).toEqual([]);
      // Stop: Eintrag im Dashboard hat ein Ende, gespeichert
      env.dashEntry.set(open('2026-10-02', { workEnd: new Date(2026, 9, 3, 1, 0) }));
      env.months.set('A|2026-10', [open('2026-10-02', { workEnd: new Date(2026, 9, 3, 1, 0) })]);
      await flush();
      expect(ids(env.svc)).toEqual([]);
      // Dashboard schaltet auf heute um
      env.dashEntry.set(open('2026-10-03', { workStart: undefined }));
      await flush();
      expect(ids(env.svc)).toEqual([]);
    });

    it('ein anderer offener Vortag bleibt sichtbar, auch wenn ein Vortag im Dashboard läuft', async () => {
      const env = setup();
      env.months.set('A|2026-10', [open('2026-10-02'), open('2026-10-01')]);
      env.dashEntry.set(open('2026-10-02'));
      await flush();
      expect(ids(env.svc)).toEqual(['2026-10-01']);
    });

    it('im Lag-Fenster eines Profilwechsels (Signal neu, Effect noch nicht gelaufen) zeigt entries nie das alte Profil', async () => {
      const env = setup({ pid: 'A' });
      env.months.set('A|2026-10', [open('2026-10-02')]);
      await flush();
      expect(ids(env.svc)).toEqual(['2026-10-02']);
      env.profile.setSignalOnly('B');
      expect(env.svc.entries()).toEqual([]);
    });

    it('keine Anzeige, solange das Dashboard lädt', async () => {
      const env = setup();
      env.dashLoading.set(true);
      env.months.set('A|2026-10', [open('2026-10-02')]);
      await flush();
      expect(env.svc.entries()).toEqual([]);
      env.dashLoading.set(false);
      expect(ids(env.svc)).toEqual(['2026-10-02']);
    });

    it('Auth undefined: keine Suche; nach der ersten Emission wird gesucht', async () => {
      const env = setup({ user: undefined });
      env.months.set('A|2026-10', [open('2026-10-02')]);
      await flush();
      expect(env.reads).toEqual([]);
      expect(env.svc.entries()).toEqual([]);
      env.user.set(null);
      await flush();
      expect(env.reads.length).toBe(2);
      expect(ids(env.svc)).toEqual(['2026-10-02']);
    });

    it('Login/Logout: neue Suche, Altergebnis wird verworfen', async () => {
      const env = setup({ user: null });
      env.months.set('A|2026-10', [open('2026-10-02')]);
      await flush();
      const gate = new Promise<void>(() => { /* nie erfüllt: hält die Suche des Alt-Zustands fest */ });
      env.gates.set('A|2026-10', gate);
      env.user.set({ uid: 'u9' });
      await flush();
      // Altergebnis (anonym) wurde beim Wechsel sofort geleert
      expect(env.svc.entries()).toEqual([]);
    });

    it('ein überholtes Suchergebnis wird verworfen (Nutzerwechsel mit gehaltenem Read)', async () => {
      const env = setup({ user: null });
      let release!: () => void;
      env.gates.set('A|2026-10', new Promise<void>(r => (release = r)));
      env.months.set('A|2026-10', [open('2026-10-02')]);
      await flush(); // Suche 1 hängt am Gate
      env.gates.delete('A|2026-10');
      env.months.set('A|2026-10', [open('2026-10-01')]);
      env.user.set({ uid: 'u1' }); // Suche 2 läuft sofort durch
      await flush();
      expect(ids(env.svc)).toEqual(['2026-10-01']);
      release(); // Suche 1 endet nachträglich mit 10-02
      await flush();
      expect(ids(env.svc)).toEqual(['2026-10-01']);
    });
  });

  describe('Später', () => {
    it('blendet alle Kandidaten des Profils aus', async () => {
      const env = setup();
      env.months.set('A|2026-10', [open('2026-10-02'), open('2026-10-01')]);
      await flush();
      env.svc.later();
      expect(env.svc.entries()).toEqual([]);
      expect(env.svc.current()).toBeNull();
    });

    it('A -> B -> A: A bleibt ausgeblendet, B unabhängig', async () => {
      const env = setup({ pid: 'A' });
      env.months.set('A|2026-10', [open('2026-10-02')]);
      env.months.set('B|2026-10', [open('2026-10-02')]);
      await flush();
      env.svc.later();
      env.profile.set('B');
      await flush();
      expect(ids(env.svc)).toEqual(['2026-10-02']); // B ist nicht ausgeblendet
      env.profile.set('A');
      await flush();
      expect(env.svc.entries()).toEqual([]); // A weiterhin ausgeblendet
    });

    it('anderer Nutzer (uid) sieht den Eintrag wieder', async () => {
      const env = setup();
      env.months.set('A|2026-10', [open('2026-10-02')]);
      await flush();
      env.svc.later();
      expect(env.svc.entries()).toEqual([]);
      env.user.set({ uid: 'u2' });
      await flush();
      expect(ids(env.svc)).toEqual(['2026-10-02']);
    });

    it('ausgeloggt (anon) hat einen eigenen Schlüssel', async () => {
      const env = setup({ user: null });
      env.months.set('A|2026-10', [open('2026-10-02')]);
      await flush();
      env.svc.later();
      expect(env.svc.entries()).toEqual([]);
      env.user.set({ uid: 'u1' });
      await flush();
      expect(ids(env.svc)).toEqual(['2026-10-02']);
    });

    it('eine neue Sitzung (neuer TestBed) zeigt den Eintrag wieder', async () => {
      const env = setup();
      env.months.set('A|2026-10', [open('2026-10-02')]);
      await flush();
      env.svc.later();
      const env2 = setup();
      env2.months.set('A|2026-10', [open('2026-10-02')]);
      await flush();
      expect(ids(env2.svc)).toEqual(['2026-10-02']);
    });

    it('ein später gefundener neuer Kandidat erscheint trotzdem', async () => {
      const env = setup();
      env.months.set('A|2026-10', [open('2026-10-01')]);
      await flush();
      env.svc.later();
      vi.setSystemTime(new Date(2026, 9, 4, 9, 0));
      env.months.set('A|2026-10', [open('2026-10-01'), open('2026-10-03')]);
      env.dashEntry.set(open('2026-10-04', { workStart: undefined })); // Dashboard ist auf den neuen Tag umgeschaltet
      env.today.refresh();
      await flush();
      expect(ids(env.svc)).toEqual(['2026-10-03']);
    });
  });

  describe('Trigger', () => {
    it('Profilwechsel mit gehaltenem Read: überholtes Ergebnis wird verworfen', async () => {
      const env = setup({ pid: 'A' });
      let release!: () => void;
      env.gates.set('A|2026-10', new Promise<void>(r => (release = r)));
      env.months.set('A|2026-10', [open('2026-10-02')]);
      env.months.set('B|2026-10', [open('2026-10-01')]);
      await flush();
      env.profile.set('B');
      await flush();
      expect(ids(env.svc)).toEqual(['2026-10-01']);
      release();
      await flush();
      expect(env.svc.entries()).toEqual([{ id: '2026-10-01', profileId: 'B' }]);
    });

    it('Profilwechsel leert die Kandidaten sofort (nie ein Banner des alten Profils)', async () => {
      const env = setup({ pid: 'A' });
      env.months.set('A|2026-10', [open('2026-10-02')]);
      await flush();
      env.gates.set('B|2026-10', new Promise<void>(() => { /* hängt */ }));
      env.profile.set('B');
      TestBed.tick();
      expect(env.svc.entries()).toEqual([]);
    });

    it('Tageswechsel: sucht neu, Später bleibt erhalten', async () => {
      const env = setup();
      env.months.set('A|2026-10', [open('2026-10-02')]);
      await flush();
      env.svc.later();
      const readsBefore = env.reads.length;
      vi.setSystemTime(new Date(2026, 9, 4, 9, 0));
      env.today.refresh();
      await flush();
      expect(env.reads.length).toBeGreaterThan(readsBefore);
      expect(env.svc.entries()).toEqual([]);
    });

    it('Tageswechsel ohne Später: ein neu verwaister Eintrag erscheint', async () => {
      const env = setup();
      await flush();
      vi.setSystemTime(new Date(2026, 9, 4, 9, 0));
      env.months.set('A|2026-10', [open('2026-10-03')]);
      env.dashEntry.set(open('2026-10-04', { workStart: undefined }));
      env.today.refresh();
      await flush();
      expect(ids(env.svc)).toEqual(['2026-10-03']);
    });
  });

  describe('endEntry', () => {
    async function ready(): Promise<Env> {
      const env = setup();
      env.months.set('A|2026-10', [open('2026-10-02'), open('2026-10-01')]);
      await flush();
      return env;
    }

    it('closed: Close mit dem Profil des Beginns, danach Reload mit pid und Re-Check (nächster wird current)', async () => {
      const env = await ready();
      const end = new Date(2026, 9, 2, 17, 0);
      env.closeFn.mockImplementation(async () => {
        env.months.set('A|2026-10', [open('2026-10-01')]);
        return 'closed';
      });
      const result = await env.svc.endEntry({ id: '2026-10-02', profileId: 'A' }, end);
      await flush();
      expect(result).toBe('closed');
      expect(env.closeFn).toHaveBeenCalledWith({ id: '2026-10-02', profileId: 'A' }, end);
      expect(env.reload).toHaveBeenCalledWith('A');
      expect(ids(env.svc)).toEqual(['2026-10-01']);
      expect(env.svc.current()).toEqual({ id: '2026-10-01', profileId: 'A' });
      expect(env.svc.saveError()).toBeNull();
      expect(env.svc.busy()).toBe(false);
    });

    it('Reload kommt vor dem Re-Check', async () => {
      const env = await ready();
      const order: string[] = [];
      env.reload.mockImplementation(async () => { order.push('reload'); });
      env.closeFn.mockImplementation(async () => { env.months.set('A|2026-10', []); return 'closed'; });
      const readsBefore = env.reads.length;
      await env.svc.endEntry({ id: '2026-10-02', profileId: 'A' }, new Date());
      expect(order).toEqual(['reload']);
      await flush();
      expect(env.reads.length).toBeGreaterThan(readsBefore);
    });

    it('alreadyClosed: ebenfalls Reload + Re-Check', async () => {
      const env = await ready();
      env.closeFn.mockImplementation(async () => { env.months.set('A|2026-10', []); return 'alreadyClosed'; });
      expect(await env.svc.endEntry({ id: '2026-10-02', profileId: 'A' }, new Date())).toBe('alreadyClosed');
      await flush();
      expect(env.reload).toHaveBeenCalledWith('A');
      expect(env.svc.entries()).toEqual([]);
    });

    it.each(['failed', 'invalidEnd'] as const)('%s: kein Reload, saveError gesetzt, Banner bleibt', async result => {
      const env = await ready();
      env.closeFn.mockResolvedValue(result);
      expect(await env.svc.endEntry({ id: '2026-10-02', profileId: 'A' }, new Date())).toBe(result);
      await flush();
      expect(env.reload).not.toHaveBeenCalled();
      expect(env.svc.saveError()).toEqual({ result });
      expect(ids(env.svc)).toEqual(['2026-10-02', '2026-10-01']);
      expect(env.svc.busy()).toBe(false);
    });

    it('derselbe Fehler zweimal hintereinander erzeugt zwei verschiedene saveError-Werte', async () => {
      const env = await ready();
      env.closeFn.mockResolvedValue('failed');
      await env.svc.endEntry({ id: '2026-10-02', profileId: 'A' }, new Date());
      const first = env.svc.saveError();
      await env.svc.endEntry({ id: '2026-10-02', profileId: 'A' }, new Date());
      expect(env.svc.saveError()).not.toBe(first);
    });

    it('ein neuer Versuch setzt saveError zurück', async () => {
      const env = await ready();
      env.closeFn.mockResolvedValueOnce('failed');
      await env.svc.endEntry({ id: '2026-10-02', profileId: 'A' }, new Date());
      expect(env.svc.saveError()).not.toBeNull();
      env.closeFn.mockImplementation(async () => { env.months.set('A|2026-10', [open('2026-10-01')]); return 'closed'; });
      await env.svc.endEntry({ id: '2026-10-02', profileId: 'A' }, new Date());
      expect(env.svc.saveError()).toBeNull();
    });

    it('Profilwechsel mitten in endEntry: kein Reload, kein Zustand im neuen Profil', async () => {
      const env = await ready();
      let finish!: (r: CloseResult) => void;
      env.closeFn.mockImplementation(() => new Promise<CloseResult>(r => (finish = r)));
      env.months.set('B|2026-10', [open('2026-10-01')]);
      const p = env.svc.endEntry({ id: '2026-10-02', profileId: 'A' }, new Date());
      env.profile.set('B');
      await flush();
      finish('closed');
      await p;
      await flush();
      expect(env.reload).not.toHaveBeenCalled();
      expect(env.svc.entries()).toEqual([{ id: '2026-10-01', profileId: 'B' }]);
      expect(env.svc.saveError()).toBeNull();
      expect(env.svc.busy()).toBe(false);
    });

    it('Doppelklick: busy, zweiter Aufruf ignoriert', async () => {
      const env = await ready();
      let finish!: (r: CloseResult) => void;
      env.closeFn.mockImplementation(() => new Promise<CloseResult>(r => (finish = r)));
      const first = env.svc.endEntry({ id: '2026-10-02', profileId: 'A' }, new Date());
      expect(env.svc.busy()).toBe(true);
      expect(await env.svc.endEntry({ id: '2026-10-02', profileId: 'A' }, new Date())).toBe('busy');
      expect(env.closeFn).toHaveBeenCalledTimes(1);
      finish('failed');
      await first;
      expect(env.svc.busy()).toBe(false);
    });

    it('closedCount zählt erfolgreiche Abschlüsse (Fokus/Ansage im UI)', async () => {
      const env = await ready();
      expect(env.svc.closedCount()).toBe(0);
      env.closeFn.mockImplementation(async () => { env.months.set('A|2026-10', [open('2026-10-01')]); return 'closed'; });
      await env.svc.endEntry({ id: '2026-10-02', profileId: 'A' }, new Date());
      expect(env.svc.closedCount()).toBe(1);
      env.closeFn.mockResolvedValue('failed');
      await env.svc.endEntry({ id: '2026-10-01', profileId: 'A' }, new Date());
      expect(env.svc.closedCount()).toBe(1);
    });
  });
});

describe('OpenEntryCandidate', () => {
  it('ist ein reiner Wert {id, profileId}', () => {
    const c: OpenEntryCandidate = { id: '2026-10-02', profileId: 'A' };
    expect(Object.keys(c).sort()).toEqual(['id', 'profileId']);
  });
});
