import { TestBed } from '@angular/core/testing';
import { Firestore } from '@angular/fire/firestore';
import { of } from 'rxjs';
import { OpenEntryCloseService, OpenEntryCandidate } from './open-entry-close';
import { WorkEntryService } from '../../core/services/work-entry';
import { OvertimeService } from '../../core/services/overtime';
import { SettingsService } from '../../core/services/settings';
import { AuthService } from '../../core/auth/auth';
import { ApiClient } from '../../core/services/api-client';
import { WorkProfileService } from '../../core/services/work-profile';
import { createFakeWorkProfile } from '../../shared/testing/work-profile-fake';
import { calculateAndApplyBreaks } from '../../domain/services/break-calculator';
import { Break, DEFAULT_SETTINGS, UserSettings, WorkEntry, WorkEntryType } from '../../shared/models';

const MIN = 60_000;
const HOUR = 60 * MIN;

function at(y: number, m: number, d: number, h = 0, min = 0, s = 0): Date {
  return new Date(y, m - 1, d, h, min, s);
}

function brk(start: Date, end?: Date, auto = false): Break {
  return { id: `b${start.getTime()}`, name: 'Pause', start, end, isAutomatic: auto };
}

/** Offener Eintrag am Freitag 2026-10-02 (`date` wie vom Web geschrieben: UTC-Mitternacht). */
function openEntry(partial: Partial<WorkEntry> = {}): WorkEntry {
  return {
    id: '2026-10-02',
    date: new Date(Date.UTC(2026, 9, 2)),
    workStart: at(2026, 10, 2, 8, 0),
    breaks: [],
    isManuallyEntered: false,
    type: WorkEntryType.Work,
    ...partial,
  };
}

interface Call { op: string; pid: string | undefined; arg?: unknown; opts?: unknown }

/** Fake-Umgebung ohne `vi`-Abhängigkeit im Dienst: ein gemeinsames Schreib-/Lese-Log mit aufgelöstem Profil. */
function makeEnv(init: { uid: string | null }) {
  const log: Call[] = [];
  let activeProfile = 'B';
  const entries = new Map<string, WorkEntry[]>(); // `${pid}|${y}-${m}`
  const overtime = new Map<string, number>();
  const settings = new Map<string, UserSettings>();
  const failures: Record<string, Error | undefined> = {};
  let gate: Promise<void> | null = null;

  const resolve = (pid: string | undefined) => pid ?? activeProfile;
  const maybeFail = (op: string) => { if (failures[op]) throw failures[op]; };

  const workEntries = {
    getEntriesForMonthOnce: async (y: number, m: number, pid?: string) => {
      log.push({ op: 'readMonth', pid: resolve(pid), arg: `${y}-${m}` });
      if (gate) await gate;
      maybeFail('readMonth');
      return structuredClone(entries.get(`${resolve(pid)}|${y}-${m}`) ?? []).map(e => ({
        ...e,
        date: new Date(e.date), workStart: e.workStart && new Date(e.workStart), workEnd: e.workEnd && new Date(e.workEnd),
        breaks: e.breaks.map(b => ({ ...b, start: new Date(b.start), end: b.end && new Date(b.end) })),
      }));
    },
    saveEntry: async (e: WorkEntry, pid?: string) => {
      log.push({ op: 'saveEntry', pid: resolve(pid), arg: e });
      maybeFail('saveEntry');
      const key = `${resolve(pid)}|${e.id.slice(0, 4)}-${Number(e.id.slice(5, 7))}`;
      entries.set(key, (entries.get(key) ?? []).filter(x => x.id !== e.id).concat(e));
    },
  };
  const overtimeSvc = {
    getOvertime: async (pid?: string) => {
      log.push({ op: 'getOvertime', pid: resolve(pid) });
      maybeFail('getOvertime');
      return overtime.get(resolve(pid)) ?? 0;
    },
    saveOvertime: async (ms: number, pid?: string, opts?: unknown) => {
      log.push({ op: 'saveOvertime', pid: resolve(pid), arg: ms, opts });
      // Der Rollback ist der zweite saveOvertime-Aufruf
      if (failures['saveOvertime']) throw failures['saveOvertime'];
      if (failures['saveOvertimeRollback'] && log.filter(c => c.op === 'saveOvertime').length > 1) {
        throw failures['saveOvertimeRollback'];
      }
      overtime.set(resolve(pid), ms);
    },
    getLastUpdateDate: async (pid?: string) => { log.push({ op: 'getLastUpdateDate', pid: resolve(pid) }); return null; },
    saveLastUpdateDate: async (d: Date) => { log.push({ op: 'saveLastUpdateDate', pid: undefined, arg: d }); },
  };
  const settingsSvc = {
    getSettingsOnce: async (pid?: string) => {
      log.push({ op: 'getSettings', pid: resolve(pid) });
      maybeFail('getSettings');
      return settings.get(resolve(pid)) ?? { ...DEFAULT_SETTINGS };
    },
  };

  TestBed.resetTestingModule();
  TestBed.configureTestingModule({
    providers: [
      { provide: WorkEntryService, useValue: workEntries },
      { provide: OvertimeService, useValue: overtimeSvc },
      { provide: SettingsService, useValue: settingsSvc },
      { provide: AuthService, useValue: { uid: init.uid } },
    ],
  });

  return {
    svc: TestBed.inject(OpenEntryCloseService),
    log,
    failures,
    setActive: (p: string) => { activeProfile = p; },
    putEntry: (pid: string, e: WorkEntry) => {
      const key = `${pid}|${e.id.slice(0, 4)}-${Number(e.id.slice(5, 7))}`;
      entries.set(key, (entries.get(key) ?? []).concat(e));
    },
    setOvertime: (pid: string, ms: number) => overtime.set(pid, ms),
    getOvertimeValue: (pid: string) => overtime.get(pid),
    setSettings: (pid: string, s: Partial<UserSettings>) => settings.set(pid, { ...DEFAULT_SETTINGS, ...s }),
    stored: (pid: string, y: number, m: number) => entries.get(`${pid}|${y}-${m}`) ?? [],
    hold: () => { let release!: () => void; gate = new Promise<void>(r => (release = r)); return () => { gate = null; release(); }; },
    ops: (op: string) => log.filter(c => c.op === op),
    opNames: () => log.map(c => c.op),
  };
}

const CAND: OpenEntryCandidate = { id: '2026-10-02', profileId: 'A' };

async function flush(): Promise<void> {
  for (let i = 0; i < 30; i++) await Promise.resolve();
}

describe('OpenEntryCloseService.endEntry (#385)', () => {
  beforeEach(() => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date(2026, 9, 3, 9, 0)); // Sa 2026-10-03 09:00
  });
  afterEach(() => {
    TestBed.resetTestingModule();
    vi.useRealTimers();
    vi.restoreAllMocks();
  });

  it('schließt den Eintrag, schneidet das Ende auf die Minute ab', async () => {
    const env = makeEnv({ uid: 'u1' });
    env.putEntry('A', openEntry());
    const result = await env.svc.endEntry(CAND, at(2026, 10, 2, 16, 0, 42));
    expect(result).toBe('closed');
    const saved = env.ops('saveEntry')[0].arg as WorkEntry;
    expect(saved.workEnd).toEqual(at(2026, 10, 2, 16, 0));
  });

  it('offene Pause erhält das gewählte Ende, geschlossene Pausen bleiben unverändert', async () => {
    const env = makeEnv({ uid: 'u1' });
    const closedBreak = brk(at(2026, 10, 2, 10, 0), at(2026, 10, 2, 10, 15));
    env.putEntry('A', openEntry({ breaks: [closedBreak, brk(at(2026, 10, 2, 15, 0))] }));
    await env.svc.endEntry(CAND, at(2026, 10, 2, 15, 30));
    const saved = env.ops('saveEntry')[0].arg as WorkEntry;
    expect(saved.breaks.find(b => b.id === closedBreak.id)).toEqual(closedBreak);
    const formerlyOpen = saved.breaks.find(b => b.start.getTime() === at(2026, 10, 2, 15, 0).getTime())!;
    expect(formerlyOpen.end).toEqual(at(2026, 10, 2, 15, 30));
  });

  it('Auto-Pausen wie calculateAndApplyBreaks (10 h brutto ohne Pause)', async () => {
    const env = makeEnv({ uid: 'u1' });
    env.putEntry('A', openEntry());
    await env.svc.endEntry(CAND, at(2026, 10, 2, 18, 0));
    const saved = env.ops('saveEntry')[0].arg as WorkEntry;
    const expected = calculateAndApplyBreaks({ ...openEntry(), workEnd: at(2026, 10, 2, 18, 0) });
    expect(expected.breaks.length).toBeGreaterThan(0);
    expect(saved.breaks.map(b => [b.name, b.start, b.end])).toEqual(expected.breaks.map(b => [b.name, b.start, b.end]));
  });

  it('kurzer Eintrag bekommt keine Auto-Pause', async () => {
    const env = makeEnv({ uid: 'u1' });
    env.putEntry('A', openEntry());
    await env.svc.endEntry(CAND, at(2026, 10, 2, 12, 0));
    expect((env.ops('saveEntry')[0].arg as WorkEntry).breaks).toEqual([]);
  });

  it('Typ != work: invalidEntry ohne Writes; ohne Start ebenso', async () => {
    for (const partial of [{ type: WorkEntryType.Vacation }, { workStart: undefined }] as Partial<WorkEntry>[]) {
      const env = makeEnv({ uid: 'u1' });
      const e = openEntry(partial);
      if ('workStart' in partial) e.workStart = undefined;
      env.putEntry('A', e);
      expect(await env.svc.endEntry(CAND, at(2026, 10, 2, 16, 0))).toBe('invalidEntry');
      expect(env.ops('saveEntry')).toEqual([]);
      expect(env.ops('saveOvertime')).toEqual([]);
    }
  });

  describe('Saldo', () => {
    it('neu = alt + (Netto nach Auto-Pausen - Soll am Eintragstag) an einem Arbeitstag', async () => {
      const env = makeEnv({ uid: 'u1' });
      env.putEntry('A', openEntry());
      env.setOvertime('A', 2 * HOUR);
      await env.svc.endEntry(CAND, at(2026, 10, 2, 18, 0)); // Fr, 10 h brutto, 45 min Auto-Pause
      const saved = env.ops('saveEntry')[0].arg as WorkEntry;
      const brkMs = saved.breaks.reduce((s, b) => s + (b.end!.getTime() - b.start.getTime()), 0);
      expect(brkMs).toBe(45 * MIN);
      expect(env.getOvertimeValue('A')).toBe(2 * HOUR + (10 * HOUR - 45 * MIN - 8 * HOUR));
    });

    it('Samstag (Soll 0): gesamtes Netto kommt dazu', async () => {
      const env = makeEnv({ uid: 'u1' });
      env.putEntry('A', openEntry({ id: '2026-09-26', date: new Date(Date.UTC(2026, 8, 26)), workStart: at(2026, 9, 26, 9, 0) }));
      env.setOvertime('A', 0);
      await env.svc.endEntry({ id: '2026-09-26', profileId: 'A' }, at(2026, 9, 26, 12, 0));
      expect(env.getOvertimeValue('A')).toBe(3 * HOUR);
    });

    it('manualOvertimeMinutes wird eingerechnet', async () => {
      const env = makeEnv({ uid: 'u1' });
      env.putEntry('A', openEntry({ manualOvertimeMinutes: 30 }));
      await env.svc.endEntry(CAND, at(2026, 10, 2, 16, 30)); // 8,5 h brutto - 30 min Auto-Pause = 8 h
      expect(env.getOvertimeValue('A')).toBe(30 * MIN);
    });

    it('Soll kommt aus den Einstellungen des Profils des Eintrags, nicht aus dem aktiven', async () => {
      const env = makeEnv({ uid: 'u1' });
      env.setActive('B');
      env.setSettings('A', { weeklyTargetHours: 40 }); // 8 h
      env.setSettings('B', { weeklyTargetHours: 20 }); // 4 h
      env.putEntry('A', openEntry());
      await env.svc.endEntry(CAND, at(2026, 10, 2, 16, 30)); // 8 h netto
      expect(env.getOvertimeValue('A')).toBe(0);
      expect(env.ops('getSettings').map(c => c.pid)).toEqual(['A']);
    });

    it('Soll gehört zum Eintragstag, nicht zu heute (Fr 8 h, heute ist Sa mit Soll 0)', async () => {
      const env = makeEnv({ uid: 'u1' });
      env.putEntry('A', openEntry());
      await env.svc.endEntry(CAND, at(2026, 10, 2, 16, 30));
      expect(env.getOvertimeValue('A')).toBe(0); // 8 h Netto - 8 h Soll
    });

    it('Saldo wird in Millisekunden aus dem gespeicherten Wert fortgeschrieben (negativ möglich)', async () => {
      const env = makeEnv({ uid: 'u1' });
      env.putEntry('A', openEntry());
      env.setOvertime('A', -3 * HOUR);
      await env.svc.endEntry(CAND, at(2026, 10, 2, 13, 0)); // 5 h netto, keine Pflichtpause
      expect(env.getOvertimeValue('A')).toBe(-3 * HOUR - 3 * HOUR);
    });
  });

  describe('lastUpdated', () => {
    it('eingeloggt: saveOvertime mit { keepLastUpdated: true }', async () => {
      const env = makeEnv({ uid: 'u1' });
      env.putEntry('A', openEntry());
      await env.svc.endEntry(CAND, at(2026, 10, 2, 16, 0));
      expect(env.ops('saveOvertime')[0].opts).toEqual({ keepLastUpdated: true });
    });

    it('saveLastUpdateDate wird nie aufgerufen, getLastUpdateDate nie gelesen', async () => {
      const env = makeEnv({ uid: null });
      env.putEntry('A', openEntry());
      await env.svc.endEntry(CAND, at(2026, 10, 2, 16, 0));
      expect(env.ops('saveLastUpdateDate')).toEqual([]);
      expect(env.ops('getLastUpdateDate')).toEqual([]);
    });
  });

  describe('Reihenfolge, Profil, Datum', () => {
    it('Saldo vor Eintrag, beide mit explizitem Profil des Eintrags', async () => {
      const env = makeEnv({ uid: 'u1' });
      env.setActive('B');
      env.putEntry('A', openEntry());
      await env.svc.endEntry(CAND, at(2026, 10, 2, 16, 0));
      const writes = env.log.filter(c => c.op === 'saveOvertime' || c.op === 'saveEntry');
      expect(writes.map(c => c.op)).toEqual(['saveOvertime', 'saveEntry']);
      expect(env.log.every(c => c.pid === 'A')).toBe(true);
    });

    it('Profilwechsel mitten in der Aktion: alle Zugriffe bleiben im Profil des Beginns', async () => {
      const env = makeEnv({ uid: 'u1' });
      env.putEntry('A', openEntry());
      const release = env.hold();
      const p = env.svc.endEntry(CAND, at(2026, 10, 2, 16, 0));
      await flush();
      env.setActive('C');
      release();
      expect(await p).toBe('closed');
      expect(env.log.map(c => c.pid)).toEqual(env.log.map(() => 'A'));
    });

    it('Eintrag wird mit date = lokaler Tag aus der id geschrieben (nie der Vortag)', async () => {
      const env = makeEnv({ uid: 'u1' });
      env.putEntry('A', openEntry()); // date = UTC-Mitternacht: in LA lokal der 1.10.
      await env.svc.endEntry(CAND, at(2026, 10, 2, 16, 0));
      const saved = env.ops('saveEntry')[0].arg as WorkEntry;
      expect([saved.date.getFullYear(), saved.date.getMonth() + 1, saved.date.getDate()]).toEqual([2026, 10, 2]);
      expect(saved.id).toBe('2026-10-02');
    });

    it('der Tag kommt aus der id: Lesepfad nutzt Jahr und Monat der id', async () => {
      const env = makeEnv({ uid: 'u1' });
      env.putEntry('A', openEntry({ id: '2026-09-30', date: new Date(Date.UTC(2026, 8, 30)), workStart: at(2026, 9, 30, 8, 0) }));
      expect(await env.svc.endEntry({ id: '2026-09-30', profileId: 'A' }, at(2026, 9, 30, 16, 0))).toBe('closed');
      expect(env.ops('readMonth')[0].arg).toBe('2026-9');
    });
  });

  describe('Validierung', () => {
    it.each([
      ['Ende gleich Start', () => at(2026, 10, 2, 8, 0)],
      ['Ende vor Start', () => at(2026, 10, 2, 7, 0)],
      ['Ende nach jetzt', () => at(2026, 10, 3, 9, 1)],
    ])('%s: invalidEnd ohne Writes', async (_label, endFn) => {
      const env = makeEnv({ uid: 'u1' });
      env.putEntry('A', openEntry());
      expect(await env.svc.endEntry(CAND, endFn())).toBe('invalidEnd');
      expect(env.ops('saveEntry')).toEqual([]);
      expect(env.ops('saveOvertime')).toEqual([]);
    });

    it('Ende vor dem Ende einer geschlossenen Pause: invalidEnd', async () => {
      const env = makeEnv({ uid: 'u1' });
      env.putEntry('A', openEntry({ breaks: [brk(at(2026, 10, 2, 12, 0), at(2026, 10, 2, 12, 30))] }));
      expect(await env.svc.endEntry(CAND, at(2026, 10, 2, 12, 10))).toBe('invalidEnd');
      expect(env.ops('saveOvertime')).toEqual([]);
    });

    it('prüft mit frischer Uhr: Ende war beim Öffnen des Dialogs gültig, beim Bestätigen nicht mehr', async () => {
      const env = makeEnv({ uid: 'u1' });
      env.putEntry('A', openEntry());
      const end = at(2026, 10, 3, 8, 59); // gültig bei 09:00
      vi.setSystemTime(new Date(2026, 9, 3, 8, 58)); // Uhr läuft rückwärts (Zeitumstellung/Korrektur)
      expect(await env.svc.endEntry(CAND, end)).toBe('invalidEnd');
      expect(env.ops('saveEntry')).toEqual([]);
    });
  });

  describe('frisch lesen', () => {
    it('bereits beendet: alreadyClosed ohne Writes', async () => {
      const env = makeEnv({ uid: 'u1' });
      env.putEntry('A', openEntry({ workEnd: at(2026, 10, 2, 17, 0) }));
      expect(await env.svc.endEntry(CAND, at(2026, 10, 2, 16, 0))).toBe('alreadyClosed');
      expect(env.ops('saveEntry')).toEqual([]);
      expect(env.ops('saveOvertime')).toEqual([]);
    });

    it('nicht mehr vorhanden: alreadyClosed', async () => {
      const env = makeEnv({ uid: 'u1' });
      expect(await env.svc.endEntry(CAND, at(2026, 10, 2, 16, 0))).toBe('alreadyClosed');
      expect(env.ops('saveOvertime')).toEqual([]);
    });

    it('zweiter Aufruf nach Erfolg zählt den Saldo nicht doppelt', async () => {
      const env = makeEnv({ uid: 'u1' });
      env.putEntry('A', openEntry());
      env.setOvertime('A', 0);
      expect(await env.svc.endEntry(CAND, at(2026, 10, 2, 17, 0))).toBe('closed');
      const after = env.getOvertimeValue('A');
      expect(await env.svc.endEntry(CAND, at(2026, 10, 2, 17, 0))).toBe('alreadyClosed');
      expect(env.getOvertimeValue('A')).toBe(after);
      expect(env.ops('saveOvertime').length).toBe(1);
    });
  });

  describe('Fehler', () => {
    it('Lesefehler (Monat): failed ohne Writes', async () => {
      const env = makeEnv({ uid: 'u1' });
      env.failures['readMonth'] = new Error('offline');
      expect(await env.svc.endEntry(CAND, at(2026, 10, 2, 16, 0))).toBe('failed');
      expect(env.ops('saveOvertime')).toEqual([]);
      expect(env.ops('saveEntry')).toEqual([]);
    });

    it('Lesefehler (Einstellungen): failed ohne Writes', async () => {
      const env = makeEnv({ uid: 'u1' });
      env.putEntry('A', openEntry());
      env.failures['getSettings'] = new Error('offline');
      expect(await env.svc.endEntry(CAND, at(2026, 10, 2, 16, 0))).toBe('failed');
      expect(env.ops('saveOvertime')).toEqual([]);
      expect(env.ops('saveEntry')).toEqual([]);
    });

    it('Saldo-Write schlägt fehl: kein Eintrag-Write, failed', async () => {
      const env = makeEnv({ uid: 'u1' });
      env.putEntry('A', openEntry());
      env.failures['saveOvertime'] = new Error('500');
      expect(await env.svc.endEntry(CAND, at(2026, 10, 2, 17, 0))).toBe('failed');
      expect(env.ops('saveEntry')).toEqual([]);
    });

    it('Eintrag-Write schlägt fehl: Rollback des alten Saldos (mit keepLastUpdated), failed', async () => {
      const env = makeEnv({ uid: 'u1' });
      env.putEntry('A', openEntry());
      env.setOvertime('A', 90 * MIN);
      env.failures['saveEntry'] = new Error('500');
      expect(await env.svc.endEntry(CAND, at(2026, 10, 2, 17, 0))).toBe('failed');
      const saves = env.ops('saveOvertime');
      expect(saves.length).toBe(2);
      expect(saves[0].arg).toBe(90 * MIN + 15 * MIN); // 9 h brutto - 45 min Auto-Pause - 8 h Soll
      expect(saves[1].arg).toBe(90 * MIN);
      expect(saves[1].opts).toEqual({ keepLastUpdated: true });
      expect(saves[1].pid).toBe('A');
      expect(env.getOvertimeValue('A')).toBe(90 * MIN);
      // Reihenfolge: Saldo, Eintrag (fehlgeschlagen), Rollback
      expect(env.log.filter(c => c.op === 'saveOvertime' || c.op === 'saveEntry').map(c => c.op))
        .toEqual(['saveOvertime', 'saveEntry', 'saveOvertime']);
    });

    it('Rollback schlägt ebenfalls fehl: failed, kein Wurf', async () => {
      const env = makeEnv({ uid: 'u1' });
      env.putEntry('A', openEntry());
      env.failures['saveEntry'] = new Error('500');
      env.failures['saveOvertimeRollback'] = new Error('500');
      await expect(env.svc.endEntry(CAND, at(2026, 10, 2, 17, 0))).resolves.toBe('failed');
    });
  });

  it('Doppelaufruf während einer laufenden Aktion wird ignoriert (genau ein Write-Satz)', async () => {
    const env = makeEnv({ uid: 'u1' });
    env.putEntry('A', openEntry());
    const release = env.hold();
    const first = env.svc.endEntry(CAND, at(2026, 10, 2, 17, 0));
    const second = env.svc.endEntry(CAND, at(2026, 10, 2, 17, 0));
    await flush();
    release();
    expect(await second).toBe('busy');
    expect(await first).toBe('closed');
    expect(env.ops('saveOvertime').length).toBe(1);
    expect(env.ops('saveEntry').length).toBe(1);
    // danach wieder bedienbar
    expect(await env.svc.endEntry(CAND, at(2026, 10, 2, 17, 0))).toBe('alreadyClosed');
  });

  it('Soft-Warnung > 16 h blockiert den Service nicht', async () => {
    const env = makeEnv({ uid: 'u1' });
    env.putEntry('A', openEntry({ workStart: at(2026, 10, 2, 8, 0) }));
    expect(await env.svc.endEntry(CAND, at(2026, 10, 3, 8, 30))).toBe('closed'); // 24,5 h brutto
  });
});

describe('OpenEntryCloseService, ausgeloggt mit echten Core-Services (localStorage, #385)', () => {
  beforeEach(() => {
    localStorage.clear();
    vi.useFakeTimers();
    vi.setSystemTime(new Date(2026, 9, 3, 9, 0));
  });
  afterEach(() => {
    TestBed.resetTestingModule();
    vi.useRealTimers();
    localStorage.clear();
  });

  it('schließt den Eintrag lokal, schreibt den Saldo und lässt overtime_last_update unberührt', async () => {
    localStorage.setItem('overtime_value', '60');
    localStorage.setItem('overtime_last_update', '2026-10-01T10:00:00.000Z');
    localStorage.setItem('local_work_entries_2026_10', JSON.stringify({
      days: { '2': { workStart: at(2026, 10, 2, 8, 0).toISOString(), workEnd: null, type: 'work', breaks: [] } },
    }));
    TestBed.resetTestingModule();
    TestBed.configureTestingModule({
      providers: [
        { provide: Firestore, useValue: {} },
        { provide: AuthService, useValue: { uid: null, user$: of(null) } },
        { provide: ApiClient, useValue: {} },
        { provide: WorkProfileService, useValue: createFakeWorkProfile('default') },
      ],
    });
    const svc = TestBed.inject(OpenEntryCloseService);
    expect(await svc.endEntry({ id: '2026-10-02', profileId: 'default' }, at(2026, 10, 2, 17, 0))).toBe('closed');
    // 9 h brutto - 45 min Auto-Pause = 8 h 15 min Netto, Soll 8 h -> +15 min
    expect(localStorage.getItem('overtime_value')).toBe(String(60 + 15));
    expect(localStorage.getItem('overtime_last_update')).toBe('2026-10-01T10:00:00.000Z');
    const month = JSON.parse(localStorage.getItem('local_work_entries_2026_10')!);
    expect(month.days['2'].workEnd).toBe(at(2026, 10, 2, 17, 0).toISOString());
  });
});
