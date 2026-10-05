import { TestBed } from '@angular/core/testing';
import { WritableSignal, signal } from '@angular/core';
import { Observable, defer, from, map, of } from 'rxjs';
import { DashboardService } from './dashboard.service';
import { WorkEntryService } from '../../core/services/work-entry';
import { OvertimeService } from '../../core/services/overtime';
import { SettingsService } from '../../core/services/settings';
import { AuthService } from '../../core/auth/auth';
import { TodayService } from '../../core/services/today';
import { WorkProfileService } from '../../core/services/work-profile';
import { createFakeWorkProfile, FakeWorkProfile } from '../../shared/testing/work-profile-fake';
import { toDateKey } from '../../shared/utils/german-holidays.util';
import { DEFAULT_SETTINGS, WorkEntry, WorkEntryType } from '../../shared/models/index';

// ─── „Fortsetzen" eines offenen Vortags im Dashboard (#385, Pinning) ───────────────────────────────────────
// Feste lokale Daten: Sa 2026-10-03 09:00 lokal, offener Eintrag Fr 2026-10-02 22:00 lokal. Keine Zonenannahme.
// Flush nur über `advanceTimersByTimeAsync(0)` (kein setTimeout-Flush, #392/#393).

const H = 3600000;
const MIN = 60000;
const A = 'default';
const B = 'B';
const FRI_ID = '2026-10-02';
const SAT_ID = '2026-10-03';

const at = (d: number, h = 0, m = 0, s = 0): Date => new Date(2026, 9, d, h, m, s);
/** Der Web-/API-Eintrag trägt `date` als UTC-Mitternacht des Tages (westlich von UTC der Vortag lokal). */
const utcMidnight = (d: number): Date => new Date(Date.UTC(2026, 9, d));

function mk(id: string, d: number, extra: Partial<WorkEntry> = {}): WorkEntry {
  return { id, date: utcMidnight(d), breaks: [], isManuallyEntered: false, type: WorkEntryType.Work, ...extra };
}
const openFri = (extra: Partial<WorkEntry> = {}): WorkEntry => mk(FRI_ID, 2, { workStart: at(2, 22, 0), ...extra });

interface ProfData { entries: Map<string, WorkEntry>; overtimeMs: number; lastUpdate: Date | null }
interface Write { kind: 'entry' | 'overtime'; pid: string | undefined; entry?: WorkEntry; ms?: number }
interface World {
  data: Record<string, ProfData>;
  writes: Write[];
  todayReads: number;
  monthReads: number;
  overtimeReads: number;
  failToday: boolean;
  failMonth: boolean;
  gateToday: Promise<void> | null;
  gateMonth: Promise<void> | null;
}

function deferred<T = void>(): { promise: Promise<T>; resolve: (v: T) => void } {
  let resolve!: (v: T) => void;
  const promise = new Promise<T>(r => { resolve = r; });
  return { promise, resolve };
}

function makeWorld(entries: WorkEntry[] = [], stored = 120 * MIN, lastUpdate: Date | null = null): World {
  return {
    data: {
      [A]: { entries: new Map(entries.map(e => [e.id, e])), overtimeMs: stored, lastUpdate },
      [B]: { entries: new Map(), overtimeMs: 30 * MIN, lastUpdate: null },
    },
    writes: [], todayReads: 0, monthReads: 0, overtimeReads: 0,
    failToday: false, failMonth: false, gateToday: null, gateMonth: null,
  };
}

interface Harness {
  svc: DashboardService;
  world: World;
  profile: FakeWorkProfile;
  user: WritableSignal<{ uid: string } | null>;
}

function setup(world: World = makeWorld()): Harness {
  const profile = createFakeWorkProfile(A);
  const user = signal<{ uid: string } | null>({ uid: 'u1' });
  TestBed.resetTestingModule();
  TestBed.configureTestingModule({
    providers: [
      { provide: WorkEntryService, useValue: {
        getTodayEntry: (pid: string): Observable<WorkEntry | null> => defer(() => {
          world.todayReads++;
          if (world.failToday) throw new Error('read failed');
          const value = (): WorkEntry | null => world.data[pid].entries.get(toDateKey(new Date())) ?? null;
          return world.gateToday ? from(world.gateToday).pipe(map(value)) : of(value());
        }),
        getEntriesForMonthOnce: async (y: number, m: number, pid: string): Promise<WorkEntry[]> => {
          world.monthReads++;
          if (world.gateMonth) await world.gateMonth;
          if (world.failMonth) throw new Error('month failed');
          const prefix = `${y}-${String(m).padStart(2, '0')}-`;
          return [...world.data[pid].entries.values()].filter(e => e.id.startsWith(prefix));
        },
        emptyEntry: (d: Date): WorkEntry => mk(toDateKey(d), d.getDate(), { date: d }),
        saveEntry: async (entry: WorkEntry, pid?: string) => {
          world.writes.push({ kind: 'entry', pid, entry });
          world.data[pid ?? A].entries.set(entry.id, entry);
        },
      } },
      { provide: OvertimeService, useValue: {
        getOvertime: async (pid: string) => { world.overtimeReads++; return world.data[pid].overtimeMs; },
        getLastUpdateDate: async (pid: string) => world.data[pid].lastUpdate,
        saveOvertime: async (ms: number, pid?: string) => {
          world.writes.push({ kind: 'overtime', pid, ms });
          world.data[pid ?? A].overtimeMs = ms;
        },
        saveLastUpdateDate: async () => undefined,
      } },
      { provide: SettingsService, useValue: { getSettings: () => of({ ...DEFAULT_SETTINGS }), saveSettings: () => undefined } },
      { provide: AuthService, useValue: { user, get uid() { return user()?.uid ?? null; } } },
      { provide: WorkProfileService, useValue: profile },
    ],
  });
  const svc = TestBed.inject(DashboardService);
  return { svc, world, profile, user };
}

const settle = async (): Promise<void> => { await vi.advanceTimersByTimeAsync(0); };
const entryWrites = (w: World): Write[] => w.writes.filter(x => x.kind === 'entry');

function suite(name: string, body: () => void): void {
  describe(name, () => {
    beforeEach(() => {
      localStorage.clear();
      vi.useFakeTimers();
      vi.setSystemTime(at(3, 9, 0));
    });
    afterEach(() => {
      TestBed.resetTestingModule();
      const timers = vi.getTimerCount();
      vi.useRealTimers();
      vi.restoreAllMocks();
      localStorage.clear();
      expect(timers).toBe(0);
    });
    body();
  });
}

suite('DashboardService.todayIsEmpty (#385)', () => {
  it('false beim Laden, true nach erfolgreichem Laden mit leerem heutigem Eintrag', async () => {
    const world = makeWorld();
    const gate = deferred();
    world.gateToday = gate.promise;
    const h = setup(world);
    await settle();
    expect(h.svc.isLoading()).toBe(true);
    expect(h.svc.todayIsEmpty()).toBe(false);
    gate.resolve();
    await settle();
    expect(h.svc.isLoading()).toBe(false);
    expect(h.svc.todayIsEmpty()).toBe(true);
  });

  it('false mit heutigem Start, auch ohne Ende', async () => {
    const h = setup(makeWorld([mk(SAT_ID, 3, { workStart: at(3, 8, 0) })]));
    await settle();
    expect(h.svc.todayIsEmpty()).toBe(false);
  });

  it('false bei heutigem Urlaub/Krank/Feiertag (Typ ungleich work)', async () => {
    for (const type of [WorkEntryType.Vacation, WorkEntryType.Sick, WorkEntryType.Holiday]) {
      const h = setup(makeWorld([mk(SAT_ID, 3, { type })]));
      await settle();
      expect(h.svc.isLoading()).toBe(false);
      expect(h.svc.todayIsEmpty()).toBe(false);
    }
  });

  it('false nach Lesefehler in _initInner (Status ready, aber nicht sicher geladen)', async () => {
    const world = makeWorld();
    world.failToday = true;
    const h = setup(world);
    await settle();
    expect(h.svc.isLoading()).toBe(false);
    expect(h.svc.todayIsEmpty()).toBe(false);
  });

  it('wechselt auf false, sobald heute gestartet wird', async () => {
    const h = setup();
    await settle();
    expect(h.svc.todayIsEmpty()).toBe(true);
    await h.svc.startOrStopTimer();
    expect(h.svc.todayIsEmpty()).toBe(false);
  });

  it('wird nach dem Tageswechsel gegen den neuen Tag bewertet', async () => {
    const h = setup();
    await settle();
    expect(h.svc.todayIsEmpty()).toBe(true);
    vi.setSystemTime(at(4, 0, 0, 5));
    TestBed.inject(TodayService).refresh();
    expect(h.svc.todayIsEmpty()).toBe(false); // Anzeige noch am Vortag, kein „heute leer"
    TestBed.tick();
    await settle();
    expect(h.svc.workEntry().id).toBe('2026-10-04');
    expect(h.svc.todayIsEmpty()).toBe(true);
  });
});

/** Zustand vor einem abgelehnten Fortsetzen; danach muss alles unverändert sein. */
function snapshot(h: Harness) {
  return {
    entry: h.svc.workEntry(),
    writes: h.world.writes.length,
    todayReads: h.world.todayReads,
    monthReads: h.world.monthReads,
  };
}
function expectUntouched(h: Harness, before: ReturnType<typeof snapshot>): void {
  expect(h.svc.isLoading()).toBe(false);
  expect(h.svc.workEntry()).toBe(before.entry);
  expect(h.world.writes.length).toBe(before.writes);
  expect(h.world.todayReads).toBe(before.todayReads);
  expect(h.world.monthReads).toBe(before.monthReads);
}

suite('DashboardService.resumePastEntry (#385)', () => {
  async function ready(world: World = makeWorld([openFri()])): Promise<Harness> {
    const h = setup(world);
    await settle();
    return h;
  }

  it('Happy Path: lädt den Vortag, Timer läuft, elapsedMs sofort gesetzt, Datum lokal aus der id, Soll vom Starttag', async () => {
    const h = await ready(makeWorld([openFri()], 120 * MIN, at(3, 8, 0)));
    expect(await h.svc.resumePastEntry(openFri(), A)).toBe(true);
    expect(h.svc.workEntry().id).toBe(FRI_ID);
    expect(h.svc.isTimerRunning()).toBe(true);
    expect(h.svc.isLoading()).toBe(false);
    expect(h.svc.netDuration()).toBe(11 * H); // sofortiger Tick, nicht erst nach einer Sekunde
    expect(toDateKey(h.svc.workEntry().date)).toBe(FRI_ID); // lokal, nie der Vortag (UTC-Falle)
    expect(h.svc.dailyOvertime()).toBe(11 * H - 8 * H); // Freitag ist Arbeitstag: Soll 8 h
    expect(h.world.writes).toEqual([]); // Fortsetzen schreibt selbst nichts
  });

  it('Starttag Zusatztag (Samstag): Soll 0', async () => {
    vi.setSystemTime(new Date(2026, 9, 4, 9, 0));
    const sat = mk(SAT_ID, 3, { workStart: at(3, 22, 0) });
    const h = await ready(makeWorld([sat]));
    expect(await h.svc.resumePastEntry(sat, A)).toBe(true);
    expect(h.svc.dailyOvertime()).toBe(11 * H);
  });

  it('Saldo-Basis ist der gespeicherte Wert, auch wenn lastUpdated heute ist (keine Heuristik)', async () => {
    const h = await ready(makeWorld([openFri()], 120 * MIN, at(3, 8, 30)));
    await h.svc.resumePastEntry(openFri(), A);
    expect(h.svc.totalOvertime()).toBe(120 * MIN + (11 * H - 8 * H));
    await h.svc.updateInitialOvertime(0);
    expect(h.svc.totalOvertime()).toBe(11 * H - 8 * H);
  });

  it('offene Pause bleibt offen, die Netto-Zeit wächst nicht mit', async () => {
    const e = openFri({ breaks: [{ id: 'p', name: 'Pause 1', start: at(2, 23, 0), isAutomatic: false }] });
    const h = await ready(makeWorld([e]));
    await h.svc.resumePastEntry(e, A);
    expect(h.svc.isBreakRunning()).toBe(true);
    expect(h.svc.netDuration()).toBe(1 * H);
    await vi.advanceTimersByTimeAsync(60_000);
    expect(h.svc.isBreakRunning()).toBe(true);
    expect(h.svc.netDuration()).toBe(1 * H);
    expect(h.svc.grossDuration()).toBe(11 * H + 60_000);
  });

  it('läuft über Mitternacht weiter: kein Reinit, Eintrag und Timer bleiben (#372)', async () => {
    const h = await ready();
    await h.svc.resumePastEntry(openFri(), A);
    const todayReads = h.world.todayReads;
    vi.setSystemTime(at(4, 0, 0, 10));
    TestBed.inject(TodayService).refresh();
    TestBed.tick();
    await settle();
    expect(h.world.todayReads).toBe(todayReads);
    expect(h.svc.workEntry().id).toBe(FRI_ID);
    expect(h.svc.isTimerRunning()).toBe(true);
  });

  it('Autosave schreibt den Freitagseintrag mit dem geladenen Profil', async () => {
    const h = await ready();
    await h.svc.resumePastEntry(openFri(), A);
    await vi.advanceTimersByTimeAsync(30_000);
    const w = entryWrites(h.world);
    expect(w.length).toBe(1);
    expect(w[0].entry!.id).toBe(FRI_ID);
    expect(w[0].pid).toBe(A);
  });

  it('Stop: Saldo und Eintrag am Starttag im richtigen Profil, danach Reinit auf heute', async () => {
    const h = await ready(makeWorld([openFri()], 120 * MIN));
    await h.svc.resumePastEntry(openFri(), A);
    await h.svc.startOrStopTimer();
    const w = entryWrites(h.world);
    expect(w[0].entry!.id).toBe(FRI_ID);
    expect(w[0].entry!.workEnd).toBeDefined();
    expect(w.every(x => x.pid === A)).toBe(true);
    const net = h.world.writes.filter(x => x.kind === 'overtime').pop()!;
    expect(net.pid).toBe(A);
    expect(net.ms).toBe(h.world.data[A].overtimeMs);
    const stored = h.world.data[A].overtimeMs;
    expect(stored).toBeGreaterThan(120 * MIN); // 11 h abzüglich Pflichtpause, Soll 8 h
    expect(stored).toBeLessThanOrEqual(120 * MIN + 3 * H);
    // Reinit auf heute: leerer Samstag, Basis = neuer Saldo
    expect(h.svc.workEntry().id).toBe(SAT_ID);
    expect(h.svc.workEntry().workStart).toBeUndefined();
    expect(h.svc.totalOvertime()).toBe(stored);
    expect(h.svc.todayIsEmpty()).toBe(true);
  });

  describe('Ablehnung ohne Zustandsänderung', () => {
    it('heute schon ein Eintrag mit Start', async () => {
      const h = await ready(makeWorld([openFri(), mk(SAT_ID, 3, { workStart: at(3, 8, 0) })]));
      const before = snapshot(h);
      expect(await h.svc.resumePastEntry(openFri(), A)).toBe(false);
      expectUntouched(h, before);
    });

    it('heute Urlaub', async () => {
      const h = await ready(makeWorld([openFri(), mk(SAT_ID, 3, { type: WorkEntryType.Vacation })]));
      const before = snapshot(h);
      expect(await h.svc.resumePastEntry(openFri(), A)).toBe(false);
      expectUntouched(h, before);
    });

    it('Eintrag 24 h + 1 min alt', async () => {
      vi.setSystemTime(at(3, 22, 1));
      const h = await ready();
      const before = snapshot(h);
      expect(await h.svc.resumePastEntry(openFri(), A)).toBe(false);
      expectUntouched(h, before);
    });

    it('Typ ungleich work', async () => {
      const sick = openFri({ type: WorkEntryType.Sick });
      const h = await ready(makeWorld([sick]));
      const before = snapshot(h);
      expect(await h.svc.resumePastEntry(sick, A)).toBe(false);
      expectUntouched(h, before);
    });

    it('anderes Profil als das geladene/aktive', async () => {
      const h = await ready();
      const before = snapshot(h);
      expect(await h.svc.resumePastEntry(openFri(), B)).toBe(false);
      expectUntouched(h, before);
    });

    it('vorheriger Ladefehler (nicht sicher geladen)', async () => {
      const world = makeWorld([openFri()]);
      world.failToday = true;
      const h = await ready(world);
      const before = snapshot(h);
      expect(await h.svc.resumePastEntry(openFri(), A)).toBe(false);
      expectUntouched(h, before);
    });
  });

  describe('Frisch lesen', () => {
    it('inzwischen beendet (anderes Gerät): false, Dashboard zeigt heute mit korrekter Basis', async () => {
      const h = await ready(makeWorld([openFri({ workEnd: at(2, 23, 0) })], 90 * MIN));
      expect(await h.svc.resumePastEntry(openFri(), A)).toBe(false);
      expect(h.svc.isLoading()).toBe(false);
      expect(h.svc.workEntry().id).toBe(SAT_ID);
      expect(h.svc.todayIsEmpty()).toBe(true);
      expect(h.svc.totalOvertime()).toBe(0 + 90 * MIN - 0);
      expect(h.world.writes).toEqual([]);
    });

    it('inzwischen gelöscht', async () => {
      const h = await ready(makeWorld([]));
      expect(await h.svc.resumePastEntry(openFri(), A)).toBe(false);
      expect(h.svc.workEntry().id).toBe(SAT_ID);
      expect(h.svc.todayIsEmpty()).toBe(true);
      expect(h.world.writes).toEqual([]);
    });

    it('inzwischen älter als 24 h (anderer Start)', async () => {
      const h = await ready(makeWorld([openFri({ workStart: at(2, 8, 0) })]));
      expect(await h.svc.resumePastEntry(openFri(), A)).toBe(false);
      expect(h.svc.isTimerRunning()).toBe(false);
      expect(h.svc.workEntry().id).toBe(SAT_ID);
      expect(h.world.writes).toEqual([]);
    });
  });

  it('Lesefehler beim Pin: false, Dashboard geladen (kein Dauerspinner), nichts geschrieben', async () => {
    const world = makeWorld([openFri()]);
    const h = await ready(world);
    world.failMonth = true;
    expect(await h.svc.resumePastEntry(openFri(), A)).toBe(false);
    expect(h.svc.isLoading()).toBe(false);
    expect(h.svc.workEntry().id).toBe(SAT_ID);
    expect(h.svc.todayIsEmpty()).toBe(true);
    expect(h.world.writes).toEqual([]);
  });

  it('wartet auf einen laufenden Ladelauf und bewertet danach neu (heute leer: pinnt)', async () => {
    const world = makeWorld([openFri()]);
    const gate = deferred();
    world.gateToday = gate.promise;
    const h = setup(world);
    await settle();
    const p = h.svc.resumePastEntry(openFri(), A);
    await settle();
    expect(world.monthReads).toBe(0);
    gate.resolve();
    world.gateToday = null;
    expect(await p).toBe(true);
    expect(h.svc.workEntry().id).toBe(FRI_ID);
  });

  it('wartet auf einen laufenden Ladelauf: endet er mit heutigem Start, false', async () => {
    const world = makeWorld([openFri(), mk(SAT_ID, 3, { workStart: at(3, 8, 0) })]);
    const gate = deferred();
    world.gateToday = gate.promise;
    const h = setup(world);
    await settle();
    const p = h.svc.resumePastEntry(openFri(), A);
    gate.resolve();
    expect(await p).toBe(false);
    expect(world.monthReads).toBe(0);
    expect(h.svc.workEntry().id).toBe(SAT_ID);
  });

  it('Profilwechsel mitten im Pin: Ergebnis verworfen, kein Timer aus A, nichts geschrieben', async () => {
    const world = makeWorld([openFri()]);
    const h = await ready(world);
    const gate = deferred();
    world.gateMonth = gate.promise;
    const p = h.svc.resumePastEntry(openFri(), A);
    await settle();
    h.profile.set(B);
    await settle();
    gate.resolve();
    expect(await p).toBe(false);
    expect(h.svc.isTimerRunning()).toBe(false);
    expect(h.svc.workEntry().id).toBe(SAT_ID);
    expect(h.svc.isLoading()).toBe(false);
    expect(world.writes).toEqual([]);
  });

  it('Tageswechsel mitten im Pin: überholt, kein Zustand des Pins', async () => {
    const world = makeWorld([openFri()]);
    const h = await ready(world);
    const gate = deferred();
    world.gateMonth = gate.promise;
    const p = h.svc.resumePastEntry(openFri(), A);
    await settle();
    vi.setSystemTime(at(4, 0, 0, 5));
    TestBed.inject(TodayService).refresh();
    TestBed.tick();
    await settle();
    gate.resolve();
    expect(await p).toBe(false);
    expect(h.svc.isTimerRunning()).toBe(false);
    expect(h.svc.workEntry().id).toBe('2026-10-04');
  });

  it('Login-Wechsel mitten im Pin: überholt', async () => {
    const world = makeWorld([openFri()]);
    const h = await ready(world);
    const gate = deferred();
    world.gateMonth = gate.promise;
    const p = h.svc.resumePastEntry(openFri(), A);
    await settle();
    h.user.set({ uid: 'u2' });
    TestBed.tick();
    await settle();
    gate.resolve();
    expect(await p).toBe(false);
    expect(h.svc.isTimerRunning()).toBe(false);
    expect(h.svc.workEntry().id).toBe(SAT_ID);
  });

  it('doppelter Aufruf: zweiter false, ein Pin-Read, ein Timer', async () => {
    const h = await ready();
    const [a, b] = await Promise.all([
      h.svc.resumePastEntry(openFri(), A),
      h.svc.resumePastEntry(openFri(), A),
    ]);
    expect([a, b]).toEqual([true, false]);
    expect(h.world.monthReads).toBe(1);
    expect(h.svc.isTimerRunning()).toBe(true);
  });

  it('Service-Aufruf in der Ladelücke wartet auf den Pin und stoppt dann den gepinnten Lauf (dokumentierte Grenze)', async () => {
    const world = makeWorld([openFri()]);
    const h = await ready(world);
    const gate = deferred();
    world.gateMonth = gate.promise;
    const p = h.svc.resumePastEntry(openFri(), A);
    await settle();
    expect(h.svc.isLoading()).toBe(true);
    const toggle = h.svc.startOrStopTimer();
    await settle();
    expect(world.writes).toEqual([]);
    gate.resolve();
    expect(await p).toBe(true);
    await toggle;
    const w = entryWrites(world);
    expect(w[0].entry!.id).toBe(FRI_ID);
    expect(w[0].entry!.workEnd).toBeDefined();
  });

  it('reloadAfterRetroClose mit gepinntem Vortag: nur Basis erneuert, kein Reinit, Timer läuft', async () => {
    const world = makeWorld([openFri()], 120 * MIN);
    const h = await ready(world);
    await h.svc.resumePastEntry(openFri(), A);
    const todayReads = world.todayReads;
    world.data[A].overtimeMs = 200 * MIN;
    await h.svc.reloadAfterRetroClose(A);
    expect(world.todayReads).toBe(todayReads);
    expect(h.svc.isTimerRunning()).toBe(true);
    expect(h.svc.workEntry().id).toBe(FRI_ID);
    expect(h.svc.totalOvertime()).toBe(200 * MIN + (11 * H - 8 * H));
  });

  it('stopRunningTimerForSwitch mit gepinntem Vortag: stoppt und speichert im Starttag, kein Reinit', async () => {
    const world = makeWorld([openFri()]);
    const h = await ready(world);
    await h.svc.resumePastEntry(openFri(), A);
    const todayReads = world.todayReads;
    expect(await h.svc.stopRunningTimerForSwitch(A)).toBe(true);
    expect(entryWrites(world)[0].entry!.id).toBe(FRI_ID);
    expect(world.todayReads).toBe(todayReads);
  });
});
