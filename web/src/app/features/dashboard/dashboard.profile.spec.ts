import { TestBed } from '@angular/core/testing';
import { Signal, WritableSignal, inject, signal } from '@angular/core';
import { Observable, defer, from, map, of, switchMap } from 'rxjs';
import { DashboardService } from './dashboard.service';
import { WorkEntryService } from '../../core/services/work-entry';
import { OvertimeService } from '../../core/services/overtime';
import { SettingsService } from '../../core/services/settings';
import { AuthService } from '../../core/auth/auth';
import { ApiClient } from '../../core/services/api-client';
import { ProfileService } from '../../core/services/profile';
import { WorkProfileService } from '../../core/services/work-profile';
import { createFakeWorkProfile, FakeWorkProfile } from '../../shared/testing/work-profile-fake';
import { toDateKey } from '../../shared/utils/german-holidays.util';
import { DEFAULT_SETTINGS, UserSettings, WorkEntry, WorkEntryType } from '../../shared/models/index';

// ─── Profilwechsel im Dashboard (#380, Stufe 1: Datenintegrität) ──────────────────────────────────────────
// Zwei Profile: `A` = Standard-Profil (`'default'`), `B` = zusätzliches Profil. Alle Daten, Reads und Writes liegen
// in einer „Welt", die jeden Zugriff mit Profil-Argument protokolliert. Kein Test hängt an Datum/Zeitzone: feste
// lokale Daten (Montag 2026-10-05) + `vi.setSystemTime`.

const H = 3600000;
const MIN = 60000;
const A = 'default';
const B = 'B';

interface ProfData {
  entries: Map<string, WorkEntry>;
  overtimeMs: number;
  lastUpdate: Date | null;
  settings: UserSettings;
}
interface WriteRec {
  kind: 'entry' | 'overtime';
  /** Roh-Argument: `undefined` = der Aufrufer hat KEIN Profil festgehalten. */
  profileId: string | undefined;
  /** Profil, in dem der Write gelandet wäre. */
  resolved: string;
  entry?: WorkEntry;
  ms?: number;
}
interface ReadRec { kind: 'entry' | 'overtime' | 'lastUpdate'; resolved: string }

interface World {
  data: Record<string, ProfData>;
  writes: WriteRec[];
  reads: ReadRec[];
  gates: { saveEntry: Promise<void> | null; overtime: Record<string, Promise<void>>; entryRead: Promise<void> | null };
}

interface ProfileSource { activeProfileId: Signal<string>; activeProfileId$: Observable<string> }

function deferred<T = void>(): { promise: Promise<T>; resolve: (v: T) => void } {
  let resolve!: (v: T) => void;
  const promise = new Promise<T>(r => { resolve = r; });
  return { promise, resolve };
}

function mkEntry(y: number, m: number, d: number, extra: Partial<WorkEntry> = {}): WorkEntry {
  const date = new Date(y, m, d);
  return { id: toDateKey(date), date, breaks: [], isManuallyEntered: false, type: WorkEntryType.Work, ...extra };
}

const MON = (h = 12, m = 0, s = 0): Date => new Date(2026, 9, 5, h, m, s);
const MON_KEY = '2026-10-05';
const B_SETTINGS: UserSettings = { ...DEFAULT_SETTINGS, weeklyTargetHours: 18, workdays: [1, 2, 3] }; // 6 h Soll
const B_DAILY = 3.5 * H - 6 * H; // 08:00-12:00 abzüglich 30 min Pause, Soll 6 h

/** Profil B: abgeschlossener Montagseintrag 08:00-12:00 mit 30 min Pause, Saldo 30 min. */
function bEntry(): WorkEntry {
  return mkEntry(2026, 9, 5, {
    workStart: MON(8, 0), workEnd: MON(12, 0),
    breaks: [{ id: 'bb', name: 'Pause', start: MON(10, 0), end: MON(10, 30), isAutomatic: false }],
  });
}
/** Profil A: Timer läuft seit 08:00, eine beendete Pause `b1`. */
function aRunning(): WorkEntry {
  return mkEntry(2026, 9, 5, {
    workStart: MON(8, 0),
    breaks: [{ id: 'b1', name: 'Pause 1', start: MON(9, 0), end: MON(9, 15), isAutomatic: false }],
  });
}

function makeWorld(over: { a?: Partial<ProfData>; b?: Partial<ProfData>; aEntry?: WorkEntry | null; bEntry?: WorkEntry | null } = {}): World {
  const aEntry = over.aEntry === undefined ? null : over.aEntry;
  const bE = over.bEntry === undefined ? bEntry() : over.bEntry;
  return {
    data: {
      [A]: {
        entries: new Map(aEntry ? [[toDateKey(aEntry.date), aEntry]] : []),
        overtimeMs: 120 * MIN, lastUpdate: null, settings: { ...DEFAULT_SETTINGS }, ...over.a,
      },
      [B]: {
        entries: new Map(bE ? [[toDateKey(bE.date), bE]] : []),
        overtimeMs: 30 * MIN, lastUpdate: null, settings: { ...B_SETTINGS }, ...over.b,
      },
    },
    writes: [], reads: [],
    gates: { saveEntry: null, overtime: {}, entryRead: null },
  };
}

/** Fake-Services, die je Profil unterschiedliche Daten liefern und jeden Zugriff protokollieren. */
function fakeProviders(world: World, profile: () => ProfileSource, user: WritableSignal<{ uid: string } | null>) {
  return [
    { provide: WorkEntryService, useFactory: () => {
      const p = profile();
      const read = (id: string): Observable<WorkEntry | null> => defer(() => {
        world.reads.push({ kind: 'entry', resolved: id });
        const value = (): WorkEntry | null => world.data[id].entries.get(toDateKey(new Date())) ?? null;
        return world.gates.entryRead ? from(world.gates.entryRead).pipe(map(value)) : of(value());
      });
      return {
        getTodayEntry: (pid?: string) => (pid !== undefined ? read(pid) : p.activeProfileId$.pipe(switchMap(read))),
        emptyEntry: (d: Date) => mkEntry(d.getFullYear(), d.getMonth(), d.getDate()),
        saveEntry: async (entry: WorkEntry, pid?: string) => {
          const resolved = pid ?? p.activeProfileId();
          world.writes.push({ kind: 'entry', profileId: pid, resolved, entry });
          if (world.gates.saveEntry) await world.gates.saveEntry;
          world.data[resolved].entries.set(toDateKey(entry.date), entry);
        },
      };
    } },
    { provide: OvertimeService, useFactory: () => {
      const p = profile();
      const read = async (kind: 'overtime' | 'lastUpdate', pid: string | undefined) => {
        const id = pid ?? p.activeProfileId();
        world.reads.push({ kind, resolved: id });
        const g = world.gates.overtime[id];
        if (g) await g;
        return id;
      };
      return {
        getOvertime: async (pid?: string) => world.data[await read('overtime', pid)].overtimeMs,
        getLastUpdateDate: async (pid?: string) => world.data[await read('lastUpdate', pid)].lastUpdate,
        saveOvertime: async (ms: number, pid?: string) => {
          const resolved = pid ?? p.activeProfileId();
          world.writes.push({ kind: 'overtime', profileId: pid, resolved, ms });
          world.data[resolved].overtimeMs = ms;
        },
        saveLastUpdateDate: async () => undefined,
      };
    } },
    { provide: SettingsService, useFactory: () => {
      const p = profile();
      // Wie der echte SettingsService: folgt dem Observable (hinkt dem Signal hinterher).
      return { getSettings: () => p.activeProfileId$.pipe(map(id => world.data[id].settings)), saveSettings: () => undefined };
    } },
    { provide: AuthService, useValue: { user, get uid() { return user()?.uid ?? null; } } },
  ];
}

interface FakeHarness {
  svc: DashboardService;
  world: World;
  profile: FakeProfile;
  user: WritableSignal<{ uid: string } | null>;
}
type FakeProfile = FakeWorkProfile;

function setup(over: Parameters<typeof makeWorld>[0] = {}, loggedIn = true): FakeHarness {
  const world = makeWorld(over);
  const profile = createFakeWorkProfile(A);
  const user = signal<{ uid: string } | null>(loggedIn ? { uid: 'u1' } : null);
  TestBed.resetTestingModule();
  TestBed.configureTestingModule({
    providers: [
      ...fakeProviders(world, () => profile, user),
      { provide: WorkProfileService, useValue: profile },
    ],
  });
  const svc = TestBed.inject(DashboardService);
  return { svc, world, profile, user };
}

const settle = async (): Promise<void> => { await vi.advanceTimersByTimeAsync(0); };
const entryWrites = (w: World): WriteRec[] => w.writes.filter(x => x.kind === 'entry');
const overtimeWrites = (w: World): WriteRec[] => w.writes.filter(x => x.kind === 'overtime');

function suite(name: string, body: () => void): void {
  describe(name, () => {
    beforeEach(() => {
      localStorage.clear();
      vi.useFakeTimers();
      vi.setSystemTime(MON());
    });
    afterEach(() => {
      TestBed.resetTestingModule();
      const timers = vi.getTimerCount();
      vi.useRealTimers(); // auch bei fehlgeschlagener Prüfung zurücksetzen (kein Leck in andere Specs)
      vi.restoreAllMocks();
      localStorage.clear();
      expect(timers).toBe(0);
    });
    body();
  });
}

// ─── Schritt 2: Reinit bei Profilwechsel ───────────────────────────────────────────────────────────────────
suite('DashboardService Profilwechsel: Laden (#380)', () => {
  it('Wechsel ohne Timer lädt Eintrag, Saldo und Soll des neuen Profils (Fall 9)', async () => {
    const h = setup();
    await settle();
    expect(h.svc.totalOvertime()).toBe(120 * MIN);
    expect(h.svc.workEntry().workStart).toBeUndefined();

    h.profile.set(B);
    expect(h.svc.isLoading()).toBe(true); // Ladezustand, kein A-Zustand unter B sichtbar
    await settle();

    expect(h.svc.isLoading()).toBe(false);
    expect(h.svc.workEntry().workStart).toEqual(MON(8, 0));
    expect(h.svc.breaks().length).toBe(1);
    expect(h.svc.dailyOvertime()).toBe(B_DAILY); // Soll 6 h aus den B-Einstellungen (A wäre 8 h)
    expect(h.svc.totalOvertime()).toBe(30 * MIN + B_DAILY); // Basis 30 min aus B (A: 120 min)
  });

  it('Reads des Reinits tragen ein explizites Profil (Entry, Saldo, lastUpdate)', async () => {
    const h = setup();
    await settle();
    h.world.reads.length = 0;
    h.profile.set(B);
    await settle();
    expect(h.world.reads.map(r => r.kind).sort()).toEqual(['entry', 'lastUpdate', 'overtime']);
    expect(h.world.reads.every(r => r.resolved === B)).toBe(true);
  });

  it('Idempotenz: die erste Replay-Emission löst keinen zweiten Lauf aus', async () => {
    const h = setup();
    await settle();
    expect(h.world.reads.filter(r => r.kind === 'entry').length).toBe(1);
    h.profile.emitObservable(A); // distinctUntilChanged + gleiches Profil
    await settle();
    expect(h.world.reads.filter(r => r.kind === 'entry').length).toBe(1);
  });

  it('Lag (Fall 7): Signal wechselt vor dem Observable, ein _init dazwischen lädt nie „Eintrag A + Saldo B"', async () => {
    const h = setup({ aEntry: aRunning() });
    await settle();
    h.world.reads.length = 0;

    h.profile.setSignalOnly(B);
    h.user.set({ uid: 'u2' }); // anderer Auslöser (Auth) läuft im Lag-Fenster
    TestBed.tick();
    await settle();
    expect(h.world.reads.length).toBeGreaterThan(0);
    expect(h.world.reads.every(r => r.resolved === B)).toBe(true);

    h.profile.emitObservable(B); // Observable zieht nach
    await settle();
    expect(h.world.reads.every(r => r.resolved === B)).toBe(true);
    // Endzustand = reiner B-Stand, inkl. B-Soll (die Einstellungen kamen im Lag-Fenster noch von A)
    expect(h.svc.isLoading()).toBe(false);
    expect(h.svc.workEntry().workEnd).toEqual(MON(12, 0));
    expect(h.svc.dailyOvertime()).toBe(B_DAILY);
    expect(h.svc.totalOvertime()).toBe(30 * MIN + B_DAILY);
    expect(vi.getTimerCount()).toBe(1);
  });

  it('Lag (Fall 7, Variante): die Einstellungen des Lag-Fensters stammen noch von A, der Endzustand nutzt trotzdem das B-Soll', async () => {
    // B-Eintrag endet vor „jetzt": ein nur aus „jetzt" neu gerechneter Daily (Settings-Emission) wäre erkennbar falsch.
    const bShort = mkEntry(2026, 9, 5, { workStart: MON(8, 0), workEnd: MON(11, 0) });
    const h = setup({ bEntry: bShort });
    await settle();
    h.profile.setSignalOnly(B);
    h.user.set({ uid: 'u2' });
    TestBed.tick();
    await settle();
    h.profile.emitObservable(B);
    await settle();
    expect(h.svc.dailyOvertime()).toBe(3 * H - 6 * H);
    expect(h.svc.totalOvertime()).toBe(30 * MIN + 3 * H - 6 * H);
  });

  it('Signal wechselt MITTEN im Lauf (Observable stumm): alle Reads des Laufs bleiben bei A, nie „Eintrag A + Saldo B"', async () => {
    const gate = deferred();
    const h = setup({ aEntry: aRunning() });
    await settle();
    // zweiter Lauf (Login-Wechsel) mit hängendem Entry-Read
    h.world.gates.entryRead = gate.promise;
    h.user.set({ uid: 'u2' });
    TestBed.tick(); // Lauf 2 für A, hängt im Entry-Read
    await settle();
    h.world.reads.length = 0;
    h.profile.setSignalOnly(B); // das aktive Profil wechselt, bevor der Lauf Saldo/lastUpdate liest
    gate.resolve();
    await settle();
    expect(h.world.reads.map(r => r.kind).sort()).toEqual(['lastUpdate', 'overtime']);
    expect(h.world.reads.every(r => r.resolved === A)).toBe(true);
  });

  it('Ein überholter Lauf, der fehlschlägt, setzt den Ladezustand des neuen Laufs nicht auf „bereit"', async () => {
    const h = setup({ aEntry: aRunning() });
    await settle();
    const failGate = deferred();
    h.world.gates.overtime[A] = failGate.promise.then(() => { throw new Error('boom'); });
    h.world.gates.overtime[A].catch(() => undefined);
    h.user.set({ uid: 'u2' });
    TestBed.tick(); // Lauf für A hängt (wird später fehlschlagen)
    await settle();
    const slow = deferred();
    h.world.gates.overtime[B] = slow.promise;
    h.profile.set(B); // überholt ihn: Lauf für B hängt
    await settle();
    expect(h.svc.isLoading()).toBe(true);
    failGate.resolve(); // der überholte A-Lauf scheitert jetzt
    await settle();
    expect(h.svc.isLoading()).toBe(true); // B lädt weiter
    slow.resolve();
    await settle();
    expect(h.svc.isLoading()).toBe(false);
    expect(h.svc.workEntry().workEnd).toEqual(MON(12, 0)); // B-Eintrag
  });

  it('Überholter Lauf (Fall 6): A -> B -> A, B-Antwort kommt zuletzt, Endzustand A, kein B-Timer', async () => {
    const h = setup({ aEntry: aRunning() });
    await settle();
    const gate = deferred();
    h.world.gates.overtime[B] = gate.promise;

    h.profile.set(B);
    await settle(); // B-Lauf hängt in getOvertime(B)
    h.profile.set(A);
    await settle();
    expect(h.svc.isLoading()).toBe(false);
    expect(h.svc.isTimerRunning()).toBe(true);

    gate.resolve();
    await settle();
    expect(h.svc.isLoading()).toBe(false);
    expect(h.svc.isTimerRunning()).toBe(true);
    expect(h.svc.workEntry().workEnd).toBeUndefined();
    expect(h.svc.workEntry().breaks[0].id).toBe('b1');
    expect(vi.getTimerCount()).toBe(2); // Tick-Timer von A + Mitternachts-Timer, nie ein B-Timer
    expect(h.world.writes).toEqual([]);
  });

  it('Rückwechsel setzt den laufenden Timer fort, ohne dass beim Wechsel gespeichert wurde (Fall 3)', async () => {
    const h = setup({ aEntry: aRunning() });
    await vi.advanceTimersByTimeAsync(1000);
    expect(h.svc.isTimerRunning()).toBe(true);

    h.profile.set(B);
    await settle();
    expect(h.svc.isTimerRunning()).toBe(false);
    expect(h.svc.workEntry().workEnd).toEqual(MON(12, 0));
    expect(vi.getTimerCount()).toBe(1); // eingefroren: nur der Mitternachts-Timer

    h.profile.set(A);
    await vi.advanceTimersByTimeAsync(5000);
    expect(h.svc.isTimerRunning()).toBe(true);
    expect(vi.getTimerCount()).toBe(2);
    const start = MON(8, 0).getTime();
    const breaks = 15 * MIN;
    expect(h.svc.dailyOvertime()).toBe(Date.now() - start - breaks - 8 * H);
    expect(h.svc.totalOvertime()).toBe(120 * MIN + (Date.now() - start - breaks - 8 * H));
    // kein Save beim Wechsel: A-Eintrag unverändert laufend
    expect(h.world.writes).toEqual([]);
    expect(h.world.data[A].entries.get(MON_KEY)!.workEnd).toBeUndefined();
  });

  it('nach dem Wechsel entspricht der Zustand B, auch wenn A lief (Fall 2)', async () => {
    const h = setup({ aEntry: aRunning(), bEntry: null });
    await vi.advanceTimersByTimeAsync(1000);
    h.profile.set(B);
    await settle();
    expect(h.svc.workEntry().workStart).toBeUndefined();
    expect(h.svc.isTimerRunning()).toBe(false);
    expect(vi.getTimerCount()).toBe(1);
    expect(h.svc.totalOvertime()).toBe(30 * MIN);
  });

  it('Tageswechsel-Interaktion (Fall 10): Profilwechsel um 23:59:50 nutzt die lastUpdated-Heuristik, Mitternacht danach den Tageswechsel', async () => {
    vi.setSystemTime(MON(23, 59, 50));
    // lastUpdated = heute 11:00 (vor workEnd): Heuristik -> Basis = gespeichert - Daily, Total = gespeichert
    const h = setup({ b: { lastUpdate: MON(11, 0) } });
    await settle();
    h.profile.set(B);
    await settle();
    expect(h.svc.workEntry().id).toBe(MON_KEY);
    expect(h.svc.totalOvertime()).toBe(30 * MIN); // ein dayChange-Pfad (Basis = gespeichert) ergäbe 30 min + Daily
    expect(h.svc.dailyOvertime()).toBe(B_DAILY);

    await vi.advanceTimersByTimeAsync(20_000); // Mitternacht -> Dienstag
    expect(h.svc.workEntry().id).toBe('2026-10-06');
    expect(h.svc.workEntry().workStart).toBeUndefined();
    expect(h.svc.isLoading()).toBe(false);
    expect(h.svc.totalOvertime()).toBe(30 * MIN); // Basis = gespeichert (dayChange)
    expect(vi.getTimerCount()).toBe(1);
    expect(h.world.writes).toEqual([]);
  });

  it('Profilwechsel im Lag-Fenster + verpasste Mitternacht: der Aktions-Guard lädt B als Profilwechsel (Heuristik), nicht als stiller Tageswechsel', async () => {
    const aMon = mkEntry(2026, 9, 5, { workStart: MON(8, 0), workEnd: MON(10, 0) });
    const bTue = mkEntry(2026, 9, 6, { workStart: new Date(2026, 9, 6, 8, 0), workEnd: new Date(2026, 9, 6, 11, 0) });
    const h = setup({ aEntry: aMon, bEntry: bTue, b: { lastUpdate: new Date(2026, 9, 6, 9, 0) } });
    await settle();
    expect(h.svc.workEntry().id).toBe(MON_KEY);
    vi.setSystemTime(new Date(2026, 9, 6, 12, 0)); // Dienstag, Mitternachts-Timer verpasst
    h.profile.setSignalOnly(B);

    expect(await h.svc.startOrStopTimer()).toBe('restart-dialog'); // Guard lädt B (Dienstag, abgeschlossen)
    expect(h.svc.workEntry().id).toBe('2026-10-06');
    // Heuristik: lastUpdated = heute -> Basis = gespeichert - Daily, Total = gespeichert (dayChange-Pfad ergäbe -150 min)
    expect(h.svc.totalOvertime()).toBe(30 * MIN);
    expect(h.world.writes).toEqual([]);
  });

  it('Nach Destroy löst ein Observable-Wechsel keinen Reinit mehr aus', async () => {
    const h = setup();
    await settle();
    TestBed.resetTestingModule();
    h.world.reads.length = 0;
    h.profile.set(B);
    await settle();
    expect(h.world.reads).toEqual([]);
  });
});

// ─── Schritt 3: Schreib-Isolation ─────────────────────────────────────────────────────────────────────────
suite('DashboardService Profilwechsel: Schreib-Isolation (#380)', () => {
  it('Autosave nach dem Wechsel schreibt nie ins neue Profil, überhaupt nichts (Fall 1)', async () => {
    const h = setup({ aEntry: aRunning() });
    await vi.advanceTimersByTimeAsync(1000);
    h.profile.set(B);
    await vi.advanceTimersByTimeAsync(31_000);
    expect(h.world.writes).toEqual([]);
  });

  it('Autosave im Lag-Fenster (Signal gewechselt, Observable noch nicht) schreibt explizit ins alte Profil (Fall 1)', async () => {
    const h = setup({ aEntry: aRunning() });
    await vi.advanceTimersByTimeAsync(1000);
    h.profile.setSignalOnly(B);
    await vi.advanceTimersByTimeAsync(31_000);
    const w = entryWrites(h.world);
    expect(w.length).toBeGreaterThan(0);
    expect(w.every(x => x.profileId === A)).toBe(true); // nie B, auch nicht „implizit aktiv"
  });

  it('Stop im Lag-Fenster: Eintrag und Saldo landen im alten Profil, B-Saldo bleibt unverändert (Fall 4)', async () => {
    const h = setup({ aEntry: aRunning() });
    await vi.advanceTimersByTimeAsync(1000);
    h.profile.setSignalOnly(B);
    await h.svc.startOrStopTimer();

    const e = entryWrites(h.world);
    const o = overtimeWrites(h.world);
    expect(e.length).toBeGreaterThan(0);
    expect(o.length).toBeGreaterThan(0);
    expect([...e, ...o].every(x => x.profileId === A)).toBe(true);
    const saved = e[0].entry!;
    const net = saved.workEnd!.getTime() - saved.workStart!.getTime() - 15 * MIN;
    expect(o.every(x => x.ms === 120 * MIN + (net - 8 * H))).toBe(true);

    h.profile.emitObservable(B);
    await settle();
    expect(h.world.data[B].overtimeMs).toBe(30 * MIN);
    expect(h.svc.workEntry().workEnd).toEqual(MON(12, 0));
    expect(h.svc.totalOvertime()).toBe(30 * MIN + B_DAILY);
    expect(h.world.writes.filter(x => x.resolved === B)).toEqual([]);
  });

  it('In-flight (Fall 5): Wechsel während saveEntry, danach Saldo mit eingefrorenem A-Wert ins Profil A, kein Folgeschritt in B', async () => {
    const h = setup({ aEntry: aRunning() });
    await vi.advanceTimersByTimeAsync(1000);
    const gate = deferred();
    h.world.gates.saveEntry = gate.promise;

    const p = h.svc.startOrStopTimer();
    await settle(); // Eintrag-Save hängt
    h.profile.set(B);
    await settle(); // B ist geladen
    expect(h.svc.workEntry().workEnd).toEqual(MON(12, 0));

    h.world.gates.saveEntry = null;
    gate.resolve();
    await p;
    await settle();

    const saved = entryWrites(h.world)[0].entry!;
    const net = saved.workEnd!.getTime() - saved.workStart!.getTime() - 15 * MIN;
    const expectedA = 120 * MIN + (net - 8 * H);
    const o = overtimeWrites(h.world);
    expect(o.length).toBeGreaterThan(0);
    expect(o.every(x => x.profileId === A && x.ms === expectedA)).toBe(true);
    expect(h.world.writes.filter(x => x.resolved === B)).toEqual([]);
    // B-Zustand unangetastet, kein Timer, kein Reinit nach dem Stop
    expect(h.svc.workEntry().workEnd).toEqual(MON(12, 0));
    expect(h.svc.totalOvertime()).toBe(30 * MIN + B_DAILY);
    expect(h.svc.isTimerRunning()).toBe(false);
    expect(vi.getTimerCount()).toBe(1);
    expect(h.world.data[B].overtimeMs).toBe(30 * MIN);
  });

  it('In-flight: „Neue Session" startet nach der Überholung keinen Timer im neuen Profil', async () => {
    const aDone = mkEntry(2026, 9, 5, { workStart: MON(8, 0), workEnd: MON(10, 0) });
    const h = setup({ aEntry: aDone });
    await settle();
    const gate = deferred();
    h.world.gates.saveEntry = gate.promise;
    const p = h.svc.startNewSession(false);
    await settle();
    h.profile.set(B);
    await settle();
    h.world.gates.saveEntry = null;
    gate.resolve();
    await p;
    await settle();
    expect(h.svc.isTimerRunning()).toBe(false);
    expect(h.svc.workEntry().workEnd).toEqual(MON(12, 0));
    expect(vi.getTimerCount()).toBe(1);
    expect(entryWrites(h.world).every(x => x.profileId === A)).toBe(true);
  });

  it('In-flight: nach der Überholung wird der Timer des neuen Profils nicht neu gestartet (Autosave-Takt bleibt)', async () => {
    const aDone = mkEntry(2026, 9, 5, { workStart: MON(8, 0), workEnd: MON(10, 0) });
    const bRunning = mkEntry(2026, 9, 5, { workStart: MON(9, 0) });
    const h = setup({ aEntry: aDone, bEntry: bRunning });
    await settle();
    const gate = deferred();
    h.world.gates.saveEntry = gate.promise;
    const p = h.svc.startNewSession(false);
    await settle();
    h.profile.set(B);
    await settle(); // B-Timer läuft ab jetzt, Autosave-Takt bei 0
    await vi.advanceTimersByTimeAsync(29_000);
    h.world.gates.saveEntry = null;
    gate.resolve();
    await p;
    expect(entryWrites(h.world).filter(x => x.profileId === B)).toEqual([]);
    await vi.advanceTimersByTimeAsync(1000); // 30. Tick des B-Timers: ein neu gestarteter Takt hätte noch nicht gespeichert
    expect(entryWrites(h.world).filter(x => x.profileId === B).length).toBe(1);
    expect(h.svc.isTimerRunning()).toBe(true);
    expect(vi.getTimerCount()).toBe(2);
  });

  it('Aktion während des Ladens wartet auf den Reinit und wirkt auf das neue Profil (kein Write mit A-Eintrag unter B)', async () => {
    const h = setup({ aEntry: aRunning() });
    await vi.advanceTimersByTimeAsync(1000);
    const gate = deferred();
    h.world.gates.overtime[B] = gate.promise;
    h.profile.set(B); // Reinit hängt in getOvertime(B), Zustand = Ladeplatzhalter

    const p = h.svc.startOrStopTimer();
    await settle();
    expect(h.world.writes).toEqual([]); // wartet
    gate.resolve();
    expect(await p).toBe('restart-dialog'); // B-Eintrag ist abgeschlossen
    expect(h.world.writes).toEqual([]);
  });

  describe('alle Aktionen tragen das festgehaltene Profil', () => {
    const actions: Array<[string, (s: DashboardService) => Promise<unknown>]> = [
      ['startOrStopTimer', s => s.startOrStopTimer()],
      ['startNewSession(true)', s => s.startNewSession(true)],
      ['startOrStopBreak', s => s.startOrStopBreak()],
      ['setManualStartTime', s => s.setManualStartTime('07:30')],
      ['setManualEndTime', s => s.setManualEndTime('11:00')],
      ['clearEndTime', s => s.clearEndTime()],
      ['updateBreak', s => s.updateBreak({ id: 'b1', name: 'x', start: MON(9, 0), end: MON(9, 20), isAutomatic: false })],
      ['deleteBreak', s => s.deleteBreak('b1')],
    ];

    it.each(actions)('%s im Lag-Fenster: alle Writes explizit Profil A', async (_n, run) => {
      const h = setup({ aEntry: aRunning() });
      await vi.advanceTimersByTimeAsync(1000);
      h.profile.setSignalOnly(B);
      await run(h.svc);
      expect(h.world.writes.length).toBeGreaterThan(0);
      expect(h.world.writes.every(x => x.profileId === A)).toBe(true);
      h.profile.emitObservable(B);
      await settle();
      expect(h.world.data[B].entries.get(MON_KEY)).toBeDefined();
      expect(h.world.writes.filter(x => x.resolved === B)).toEqual([]);
    });

    it.each(actions)('%s mit Wechsel während der Aktion: Writes im Profil A, B-Zustand unberührt', async (_n, run) => {
      const h = setup({ aEntry: aRunning() });
      await vi.advanceTimersByTimeAsync(1000);
      const bBefore = h.world.data[B].entries.get(MON_KEY);
      const gate = deferred();
      h.world.gates.saveEntry = gate.promise;
      const p = run(h.svc);
      await settle();
      h.profile.set(B);
      await settle();
      h.world.gates.saveEntry = null;
      gate.resolve();
      await p;
      await settle();
      expect(h.world.writes.length).toBeGreaterThan(0);
      expect(h.world.writes.every(x => x.profileId === A)).toBe(true);
      expect(h.world.data[B].entries.get(MON_KEY)).toBe(bBefore);
      expect(h.world.data[B].overtimeMs).toBe(30 * MIN);
      expect(h.svc.workEntry().workEnd).toEqual(MON(12, 0));
      expect(h.svc.isTimerRunning()).toBe(false);
      expect(vi.getTimerCount()).toBe(1);
    });
  });

  describe('updateInitialOvertime (Fall 11)', () => {
    it('ohne Argument: schreibt ins geladene Profil B und aktualisiert dessen Basis', async () => {
      const h = setup();
      await settle();
      h.profile.set(B);
      await settle();
      await h.svc.updateInitialOvertime(77 * MIN);
      expect(overtimeWrites(h.world)).toEqual([{ kind: 'overtime', profileId: B, resolved: B, ms: 77 * MIN }]);
      expect(h.svc.totalOvertime()).toBe(77 * MIN + B_DAILY);
    });

    it('mit Argument A (Settings sah A): schreibt nach A, der B-Zustand bleibt unverändert', async () => {
      const h = setup();
      await settle();
      h.profile.set(B);
      await settle();
      const before = h.svc.totalOvertime();
      await h.svc.updateInitialOvertime(5 * MIN, A);
      expect(overtimeWrites(h.world)).toEqual([{ kind: 'overtime', profileId: A, resolved: A, ms: 5 * MIN }]);
      expect(h.svc.totalOvertime()).toBe(before);
      expect(h.world.data[B].overtimeMs).toBe(30 * MIN);
    });

    it('während des Wechsels (B lädt): Argument A schreibt nach A, nie unter B; Endzustand = B-Stand', async () => {
      const h = setup();
      await settle();
      const gate = deferred();
      h.world.gates.overtime[B] = gate.promise;
      h.profile.set(B);
      await settle();
      await h.svc.updateInitialOvertime(5 * MIN, A);
      expect(overtimeWrites(h.world).every(x => x.resolved === A && x.profileId === A)).toBe(true);
      gate.resolve();
      await settle();
      expect(h.svc.totalOvertime()).toBe(30 * MIN + B_DAILY);
      expect(h.world.data[B].overtimeMs).toBe(30 * MIN);
    });
  });
});

// ─── Schritt 2/4: mit ECHTEM WorkProfileService ───────────────────────────────────────────────────────────
interface RealHarness {
  svc: DashboardService;
  world: World;
  workProfile: WorkProfileService;
  user: WritableSignal<{ uid: string } | null>;
  api: { getWorkProfiles: () => Promise<unknown[]>; addWorkProfile: (n: string) => Promise<{ id: string; name: string }>; deleteWorkProfile: (id: string) => Promise<void> };
}

function setupReal(
  over: Parameters<typeof makeWorld>[0] = {},
  opts: { loggedIn?: boolean; stored?: string; order?: 'dashboard-first' | 'profile-first' } = {},
): RealHarness {
  const world = makeWorld(over);
  const user = signal<{ uid: string } | null>(opts.loggedIn === false ? null : { uid: 'u1' });
  if (opts.stored) localStorage.setItem('active_work_profile_u1', opts.stored);
  const api = {
    getWorkProfiles: async () => [{ id: B, name: 'Zweit' }],
    addWorkProfile: async (n: string) => ({ id: B, name: n }),
    deleteWorkProfile: async () => undefined,
  };
  TestBed.resetTestingModule();
  TestBed.configureTestingModule({
    providers: [
      ...fakeProviders(world, () => inject(WorkProfileService), user),
      { provide: ApiClient, useValue: api },
      { provide: ProfileService, useValue: { isPremium: signal(true) } },
    ],
  });
  let workProfile: WorkProfileService;
  let svc: DashboardService;
  if (opts.order === 'profile-first') {
    workProfile = TestBed.inject(WorkProfileService);
    svc = TestBed.inject(DashboardService);
  } else {
    svc = TestBed.inject(DashboardService);
    workProfile = TestBed.inject(WorkProfileService);
  }
  return { svc, world, workProfile, user, api };
}

suite('DashboardService Profilwechsel mit echtem WorkProfileService (#380)', () => {
  it.each(['dashboard-first', 'profile-first'] as const)(
    'Reload mit gemerktem Zweitprofil (Fall 8, %s): lädt B vollständig, kein gemischter Zustand', async order => {
      const h = setupReal({ aEntry: aRunning() }, { stored: B, order });
      TestBed.tick();
      await vi.advanceTimersByTimeAsync(50);
      TestBed.tick();
      await vi.advanceTimersByTimeAsync(50);

      expect(h.workProfile.activeProfileId()).toBe(B);
      expect(h.svc.isLoading()).toBe(false);
      expect(h.svc.workEntry().workEnd).toEqual(MON(12, 0));
      expect(h.svc.breaks().length).toBe(1);
      expect(h.svc.dailyOvertime()).toBe(B_DAILY);
      expect(h.svc.totalOvertime()).toBe(30 * MIN + B_DAILY);
      expect(h.svc.isTimerRunning()).toBe(false);
      // die jeweils letzten Reads gehören B
      for (const kind of ['entry', 'overtime', 'lastUpdate'] as const) {
        expect(h.world.reads.filter(r => r.kind === kind).at(-1)!.resolved).toBe(B);
      }
      expect(h.world.writes).toEqual([]);
      expect(vi.getTimerCount()).toBe(1);
    });

  it('Logout (Regression): Profil default, Timer gestoppt, nichts geschrieben', async () => {
    const h = setupReal({ bEntry: aRunning() }, { stored: B });
    TestBed.tick();
    await vi.advanceTimersByTimeAsync(1000);
    expect(h.svc.isTimerRunning()).toBe(true);
    expect(h.workProfile.activeProfileId()).toBe(B);

    h.user.set(null);
    TestBed.tick();
    await vi.advanceTimersByTimeAsync(31_000);
    expect(h.workProfile.activeProfileId()).toBe(A);
    expect(h.svc.isTimerRunning()).toBe(false);
    expect(h.world.writes).toEqual([]);
    expect(vi.getTimerCount()).toBe(1);
  });

  it('addProfile() mit laufendem Timer in A (Fall 9a): lädt B, A-Eintrag wird nie unter B geschrieben', async () => {
    const h = setupReal({ aEntry: aRunning(), bEntry: null });
    TestBed.tick();
    await vi.advanceTimersByTimeAsync(1000);
    expect(h.svc.isTimerRunning()).toBe(true);

    await h.workProfile.addProfile('Zweit');
    TestBed.tick();
    await vi.advanceTimersByTimeAsync(31_000);

    expect(h.workProfile.activeProfileId()).toBe(B);
    expect(h.svc.workEntry().workStart).toBeUndefined();
    expect(h.svc.isTimerRunning()).toBe(false);
    expect(h.world.writes).toEqual([]);
    expect(h.world.data[A].entries.get(MON_KEY)!.workEnd).toBeUndefined(); // A bleibt laufend
    expect(vi.getTimerCount()).toBe(1);
  });

  it('deleteProfile(aktiv) mit laufendem Timer (Fall 9b): Timer verworfen, B-Eintrag wird nie unter default geschrieben', async () => {
    const h = setupReal({ bEntry: aRunning() }, { stored: B });
    TestBed.tick();
    await vi.advanceTimersByTimeAsync(1000);
    expect(h.svc.isTimerRunning()).toBe(true);

    await h.workProfile.deleteProfile(B);
    TestBed.tick();
    await vi.advanceTimersByTimeAsync(31_000);

    expect(h.workProfile.activeProfileId()).toBe(A);
    expect(h.svc.isTimerRunning()).toBe(false);
    expect(h.svc.workEntry().workStart).toBeUndefined();
    expect(h.world.writes).toEqual([]);
    expect(vi.getTimerCount()).toBe(1);
  });

  it('deleteProfile(aktiv): auch während der API-Löschung (langsam) schreibt kein Autosave mehr ins gelöschte Profil', async () => {
    const h = setupReal({ bEntry: aRunning() }, { stored: B });
    TestBed.tick();
    await vi.advanceTimersByTimeAsync(1000);
    expect(h.svc.isTimerRunning()).toBe(true);

    const gate = deferred();
    h.api.deleteWorkProfile = () => gate.promise;
    const p = h.workProfile.deleteProfile(B);
    TestBed.tick();
    await vi.advanceTimersByTimeAsync(31_000); // mehr als ein Autosave-Takt, Löschung hängt noch
    expect(h.world.writes).toEqual([]);
    expect(h.svc.isTimerRunning()).toBe(false);

    gate.resolve();
    await p;
    expect(h.workProfile.activeProfileId()).toBe(A);
    expect(h.world.writes).toEqual([]);
  });

  it('deleteProfile(aktiv) schlägt fehl: das Profil bleibt/wird wieder aktiv und lädt B neu', async () => {
    const h = setupReal({ bEntry: aRunning() }, { stored: B });
    TestBed.tick();
    await vi.advanceTimersByTimeAsync(1000);
    h.api.deleteWorkProfile = async () => { throw new Error('boom'); };

    await expect(h.workProfile.deleteProfile(B)).rejects.toThrow('boom');
    TestBed.tick();
    await vi.advanceTimersByTimeAsync(1000);

    expect(h.workProfile.activeProfileId()).toBe(B);
    expect(localStorage.getItem('active_work_profile_u1')).toBe(B);
    expect(h.svc.isTimerRunning()).toBe(true); // B läuft laut Backend weiter, Dashboard lädt es neu
    expect(h.world.writes).toEqual([]);
  });

  it('deleteProfile eines NICHT aktiven Profils lässt das aktive Profil unberührt', async () => {
    const h = setupReal({ aEntry: aRunning() });
    TestBed.tick();
    await vi.advanceTimersByTimeAsync(1000);
    await h.workProfile.deleteProfile(B);
    TestBed.tick();
    await vi.advanceTimersByTimeAsync(1000);
    expect(h.workProfile.activeProfileId()).toBe(A);
    expect(h.svc.isTimerRunning()).toBe(true);
  });
});
