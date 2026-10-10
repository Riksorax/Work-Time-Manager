import { TestBed } from '@angular/core/testing';
import { WritableSignal, inject, signal } from '@angular/core';
import { Observable, defer, from, map, of, switchMap } from 'rxjs';
import { DashboardService } from './dashboard.service';
import { WorkEntryService } from '../../core/services/work-entry';
import { OvertimeService } from '../../core/services/overtime';
import { SettingsService } from '../../core/services/settings';
import { AuthService } from '../../core/auth/auth';
import { ApiClient } from '../../core/services/api-client';
import { ProfileService } from '../../core/services/profile';
import { WorkProfileService } from '../../core/services/work-profile';
import { ProfileSwitchConfirmService } from '../../shared/components/work-profile-switcher/profile-switch-confirm';
import { createFakeWorkProfile, FakeWorkProfile } from '../../shared/testing/work-profile-fake';
import { toDateKey } from '../../shared/utils/german-holidays.util';
import { DEFAULT_SETTINGS, UserSettings, WorkEntry, WorkEntryType } from '../../shared/models/index';

// ─── Profilwechsel mit laufendem Timer (#380, Stufe 2: Bestätigungsdialog) ───────────────────────────────
// A = Standard-Profil, B = zusätzliches Profil. Feste lokale Daten (Montag 2026-10-05) + `vi.setSystemTime`,
// keine Zeitzonen-/Datumsannahme. Der Dialog selbst ist durch einen Fake ersetzt (`ProfileSwitchConfirmService`).

const H = 3600000;
const MIN = 60000;
const A = 'default';
const B = 'B';

const MON = (h = 12, m = 0, s = 0): Date => new Date(2026, 9, 5, h, m, s);
const TUE = (h = 0, m = 30): Date => new Date(2026, 9, 6, h, m, 0);

interface ProfData { entries: Map<string, WorkEntry>; overtimeMs: number; lastUpdate: Date | null; settings: UserSettings }
interface World {
  data: Record<string, ProfData>;
  /** Alle Writes mit festgehaltenem Profil. */
  writes: { kind: 'entry' | 'overtime'; pid: string | undefined; entry?: WorkEntry; ms?: number }[];
  reads: { kind: 'entry' | 'overtime' | 'lastUpdate'; resolved: string }[];
  /** Gemeinsames Protokoll aus Writes und Profilwechseln (Reihenfolge-Tests). */
  log: string[];
  failEntry: boolean;
  failOvertime: boolean;
  entryReadGate: Promise<void> | null;
}

function deferred<T = void>(): { promise: Promise<T>; resolve: (v: T) => void } {
  let resolve!: (v: T) => void;
  const promise = new Promise<T>(r => { resolve = r; });
  return { promise, resolve };
}

function mkEntry(date: Date, extra: Partial<WorkEntry> = {}): WorkEntry {
  const d = new Date(date.getFullYear(), date.getMonth(), date.getDate());
  return { id: toDateKey(d), date: d, breaks: [], isManuallyEntered: false, type: WorkEntryType.Work, ...extra };
}

/** A: Timer läuft seit 08:00, eine beendete Pause. */
function aRunning(): WorkEntry {
  return mkEntry(MON(), {
    workStart: MON(8, 0),
    breaks: [{ id: 'b1', name: 'Pause 1', start: MON(9, 0), end: MON(9, 15), isAutomatic: false }],
  });
}
/** B: abgeschlossener Eintrag 08:00-12:00. */
function bDone(): WorkEntry {
  return mkEntry(MON(), { workStart: MON(8, 0), workEnd: MON(12, 0) });
}

function makeWorld(over: { aEntry?: WorkEntry | null; bEntry?: WorkEntry | null } = {}): World {
  const aE = over.aEntry === undefined ? aRunning() : over.aEntry;
  const bE = over.bEntry === undefined ? bDone() : over.bEntry;
  return {
    data: {
      [A]: { entries: new Map(aE ? [[toDateKey(aE.date), aE]] : []), overtimeMs: 120 * MIN, lastUpdate: null, settings: { ...DEFAULT_SETTINGS } },
      [B]: { entries: new Map(bE ? [[toDateKey(bE.date), bE]] : []), overtimeMs: 30 * MIN, lastUpdate: null,
             settings: { ...DEFAULT_SETTINGS, weeklyTargetHours: 18, workdays: [1, 2, 3] } },
    },
    writes: [], reads: [], log: [],
    failEntry: false, failOvertime: false, entryReadGate: null,
  };
}

interface ProfileSource { activeProfileId: () => string; activeProfileId$: Observable<string> }

function fakeProviders(world: World, profile: () => ProfileSource, user: WritableSignal<{ uid: string } | null>) {
  return [
    { provide: WorkEntryService, useFactory: () => {
      const p = profile();
      const read = (id: string): Observable<WorkEntry | null> => defer(() => {
        world.reads.push({ kind: 'entry', resolved: id });
        const value = (): WorkEntry | null => world.data[id].entries.get(toDateKey(new Date())) ?? null;
        return world.entryReadGate ? from(world.entryReadGate).pipe(map(value)) : of(value());
      });
      return {
        getTodayEntry: (pid?: string) => (pid !== undefined ? read(pid) : p.activeProfileId$.pipe(switchMap(read))),
        emptyEntry: (d: Date) => mkEntry(d),
        saveEntry: async (entry: WorkEntry, pid?: string) => {
          world.writes.push({ kind: 'entry', pid, entry });
          world.log.push(`saveEntry:${pid}`);
          if (world.failEntry) throw new Error('save failed');
          world.data[pid ?? p.activeProfileId()].entries.set(toDateKey(entry.date), entry);
        },
      };
    } },
    { provide: OvertimeService, useFactory: () => {
      const p = profile();
      const read = async (kind: 'overtime' | 'lastUpdate', pid: string | undefined) => {
        const id = pid ?? p.activeProfileId();
        world.reads.push({ kind, resolved: id });
        return id;
      };
      return {
        getOvertime: async (pid?: string) => world.data[await read('overtime', pid)].overtimeMs,
        getLastUpdateDate: async (pid?: string) => world.data[await read('lastUpdate', pid)].lastUpdate,
        saveOvertime: async (ms: number, pid?: string) => {
          world.writes.push({ kind: 'overtime', pid, ms });
          world.log.push(`saveOvertime:${pid}`);
          if (world.failOvertime) throw new Error('overtime failed');
          world.data[pid ?? p.activeProfileId()].overtimeMs = ms;
        },
        saveLastUpdateDate: async () => undefined,
      };
    } },
    { provide: SettingsService, useFactory: () => {
      const p = profile();
      return { getSettings: () => p.activeProfileId$.pipe(map(id => world.data[id].settings)), saveSettings: () => undefined };
    } },
    { provide: AuthService, useValue: { user, get uid() { return user()?.uid ?? null; } } },
  ];
}

interface ConfirmFake { confirmStopAndSwitch: ReturnType<typeof vi.fn>; notifySaveFailed: ReturnType<typeof vi.fn> }
const newConfirm = (answer: boolean | Promise<boolean> = true): ConfirmFake => ({
  confirmStopAndSwitch: vi.fn(() => Promise.resolve(answer)),
  notifySaveFailed: vi.fn(),
});

interface Harness {
  svc: DashboardService;
  world: World;
  profile: FakeWorkProfile;
  confirm: ConfirmFake;
}

function setup(over: Parameters<typeof makeWorld>[0] = {}, confirm: ConfirmFake = newConfirm()): Harness {
  const world = makeWorld(over);
  const profile = createFakeWorkProfile(A);
  const user = signal<{ uid: string } | null>({ uid: 'u1' });
  TestBed.resetTestingModule();
  TestBed.configureTestingModule({
    providers: [
      ...fakeProviders(world, () => profile, user),
      { provide: WorkProfileService, useValue: profile },
      { provide: ProfileSwitchConfirmService, useValue: confirm },
    ],
  });
  const svc = TestBed.inject(DashboardService);
  profile.activeProfileId$.subscribe(id => { world.log.push(`switch:${id}`); });
  world.log.length = 0; // Replay des Startwerts nicht mitzählen
  return { svc, world, profile, confirm };
}

const settle = async (): Promise<void> => { await vi.advanceTimersByTimeAsync(0); };
const writes = (w: World, kind: 'entry' | 'overtime') => w.writes.filter(x => x.kind === kind);

describe('DashboardService Profilwechsel mit laufendem Timer (#380, Stufe 2)', () => {
  beforeEach(() => {
    localStorage.clear();
    vi.useFakeTimers();
    vi.setSystemTime(MON());
    vi.spyOn(console, 'error').mockImplementation(() => undefined);
  });
  afterEach(() => {
    TestBed.resetTestingModule();
    const timers = vi.getTimerCount();
    vi.useRealTimers();
    vi.restoreAllMocks();
    localStorage.clear();
    expect(timers).toBe(0);
  });

  it('der Constructor meldet genau einen Guard an; beim Destroy ist er abgemeldet', async () => {
    const h = setup();
    await settle();
    expect(h.profile.guardCount).toBe(1);
    TestBed.resetTestingModule();
    expect(h.profile.guardCount).toBe(0);
  });

  it('ohne laufenden Timer: kein Dialog, Wechsel und Reinit auf B', async () => {
    const h = setup({ aEntry: null });
    await settle();
    expect(await h.profile.requestSwitch(B)).toBe(true);
    await settle();
    expect(h.confirm.confirmStopAndSwitch).not.toHaveBeenCalled();
    expect(h.profile.activeProfileId()).toBe(B);
    expect(h.svc.workEntry().workEnd).toEqual(MON(12, 0));
    expect(h.world.writes).toEqual([]);
  });

  it('Abbrechen: kein Wechsel, keine Writes, kein Reinit, der Timer läuft ungestört weiter', async () => {
    const h = setup({}, newConfirm(false));
    await settle();
    expect(h.svc.isTimerRunning()).toBe(true);
    const readsBefore = h.world.reads.length;

    expect(await h.profile.requestSwitch(B)).toBe(false);
    await settle();
    expect(h.profile.activeProfileId()).toBe(A);
    expect(h.world.writes).toEqual([]);
    expect(h.world.reads.length).toBe(readsBefore);
    expect(h.confirm.notifySaveFailed).not.toHaveBeenCalled();
    expect(h.svc.isTimerRunning()).toBe(true);
    expect(vi.getTimerCount()).toBe(2); // Sekundentakt + Mitternachts-Timer

    await vi.advanceTimersByTimeAsync(31_000);
    expect(writes(h.world, 'entry').length).toBe(1); // Autosave
    expect(h.world.writes.every(w => w.pid === A)).toBe(true);
    expect(writes(h.world, 'entry')[0].entry!.workEnd).toBeUndefined();
  });

  it('Beenden und wechseln: Eintrag und Saldo werden in A gespeichert, erst danach wird B aktiv und geladen', async () => {
    const h = setup();
    await settle();

    expect(await h.profile.requestSwitch(B)).toBe(true);
    await settle();

    expect(h.confirm.confirmStopAndSwitch).toHaveBeenCalledWith({ from: A, to: B });
    const i = (s: string): number => h.world.log.indexOf(s);
    expect(i(`saveEntry:${A}`)).toBeGreaterThanOrEqual(0);
    expect(i(`saveOvertime:${A}`)).toBeGreaterThan(i(`saveEntry:${A}`));
    expect(i(`switch:${B}`)).toBeGreaterThan(h.world.log.lastIndexOf(`saveOvertime:${A}`));
    expect(h.world.writes.every(w => w.pid === A)).toBe(true);

    const saved = h.world.data[A].entries.get(toDateKey(MON()))!;
    expect(saved.workEnd).toEqual(MON(12, 0));
    expect(h.world.data[A].overtimeMs).not.toBe(120 * MIN);

    expect(h.profile.activeProfileId()).toBe(B);
    expect(h.svc.workEntry().workEnd).toEqual(MON(12, 0)); // B-Eintrag
    expect(h.svc.isLoading()).toBe(false);
    expect(h.svc.isTimerRunning()).toBe(false);
    expect(vi.getTimerCount()).toBe(1); // nur der Mitternachts-Timer von TodayService

    // A ist nicht mehr laufend: Rückwechsel setzt keinen Timer fort
    expect(await h.profile.requestSwitch(A)).toBe(true);
    await settle();
    expect(h.svc.workEntry().workEnd).toEqual(MON(12, 0));
    expect(h.svc.isTimerRunning()).toBe(false);
  });

  it('Pflichtpausen und Saldo sind identisch zum Stop-Button', async () => {
    vi.setSystemTime(MON(17, 0)); // 08:00-17:00 = 9 h brutto, davon 15 min Pause: Pflichtpause greift
    const viaButton = setup();
    await settle();
    await viaButton.svc.startOrStopTimer();
    const buttonEntry = writes(viaButton.world, 'entry').at(-1)!.entry!;
    const buttonMs = writes(viaButton.world, 'overtime').at(-1)!.ms;

    const viaSwitch = setup();
    await settle();
    expect(await viaSwitch.profile.requestSwitch(B)).toBe(true);
    const switchEntry = writes(viaSwitch.world, 'entry').at(-1)!.entry!;
    const switchMs = writes(viaSwitch.world, 'overtime').at(-1)!.ms;

    expect(buttonEntry.breaks.length).toBeGreaterThan(1); // automatische Pause ergänzt
    const stripIds = (e: WorkEntry) => e.breaks.map(({ id: _id, ...rest }) => rest); // automatische Pausen: zufällige ID
    expect(stripIds(switchEntry)).toEqual(stripIds(buttonEntry));
    expect(switchEntry.workEnd).toEqual(buttonEntry.workEnd);
    expect(switchMs).toBe(buttonMs);
  });

  it('Speichern des Eintrags schlägt fehl: kein Wechsel, Meldung, Rollback; ein Folgeversuch gelingt', async () => {
    const h = setup();
    await settle();
    const readsBefore = h.world.reads.length;
    h.world.failEntry = true;

    expect(await h.profile.requestSwitch(B)).toBe(false);
    await settle();
    expect(h.profile.activeProfileId()).toBe(A);
    expect(h.confirm.notifySaveFailed).toHaveBeenCalledTimes(1);
    expect(writes(h.world, 'overtime')).toEqual([]);
    expect(h.world.reads.length).toBe(readsBefore); // kein Reinit
    expect(h.svc.isTimerRunning()).toBe(true);
    expect(h.svc.workEntry().workEnd).toBeUndefined();
    expect(vi.getTimerCount()).toBe(2); // Timer läuft wieder (+ Mitternachts-Timer)

    h.world.failEntry = false;
    expect(await h.profile.requestSwitch(B)).toBe(true);
    expect(h.profile.activeProfileId()).toBe(B);
  });

  it('Speichern des Saldos schlägt fehl: kein Wechsel, Rollback; der Eintrag wird auf den laufenden Vorzustand kompensiert (#426)', async () => {
    const h = setup();
    await settle();
    h.world.failOvertime = true;

    expect(await h.profile.requestSwitch(B)).toBe(false);
    expect(h.profile.activeProfileId()).toBe(A);
    expect(h.confirm.notifySaveFailed).toHaveBeenCalledTimes(1);
    expect(h.svc.isTimerRunning()).toBe(true);
    // Stop-Eintrag, danach der Vorzustand (laufend): der Server-Eintrag ist nach der Kompensation nicht beendet
    const entryWrites = writes(h.world, 'entry');
    expect(entryWrites.length).toBe(2);
    expect(entryWrites[0].entry!.workEnd).toBeDefined();
    expect(entryWrites[1].entry!.workEnd).toBeUndefined();
    expect(h.world.data[A].entries.get(toDateKey(MON()))!.workEnd).toBeUndefined();

    // der laufende Eintrag bleibt auch nach dem nächsten Autosave laufend
    await vi.advanceTimersByTimeAsync(31_000);
    expect(h.world.data[A].entries.get(toDateKey(MON()))!.workEnd).toBeUndefined();
  });

  it('Timer wurde während des Dialogs manuell gestoppt: kein zweiter Stop, der Wechsel erfolgt', async () => {
    const gate = deferred<boolean>();
    const h = setup({}, newConfirm(gate.promise));
    await settle();

    const p = h.profile.requestSwitch(B);
    await h.svc.startOrStopTimer(); // Stop-Button während der Dialog offen ist
    const entryWritesBefore = writes(h.world, 'entry').length;
    gate.resolve(true);

    expect(await p).toBe(true);
    expect(writes(h.world, 'entry').length).toBe(entryWritesBefore);
    expect(h.profile.activeProfileId()).toBe(B);
  });

  it('Profil wechselte während des Dialogs: kein Stop, Wechsel abgelehnt', async () => {
    const gate = deferred<boolean>();
    const h = setup({}, newConfirm(gate.promise));
    await settle();

    const p = h.profile.requestSwitch(B);
    h.profile.set(B); // nicht-interaktiver Wechsel (z. B. Reload-Pfad) dazwischen
    await settle();
    gate.resolve(true);

    expect(await p).toBe(false);
    expect(h.world.writes).toEqual([]);
  });

  it('Lade-Zustand: Wechsel ohne Dialog, der überholte Lauf schreibt nichts', async () => {
    const gate = deferred();
    const world = makeWorld();
    world.entryReadGate = gate.promise;
    const profile = createFakeWorkProfile(A);
    const user = signal<{ uid: string } | null>({ uid: 'u1' });
    const confirm = newConfirm();
    TestBed.resetTestingModule();
    TestBed.configureTestingModule({
      providers: [
        ...fakeProviders(world, () => profile, user),
        { provide: WorkProfileService, useValue: profile },
        { provide: ProfileSwitchConfirmService, useValue: confirm },
      ],
    });
    const svc = TestBed.inject(DashboardService);
    await settle();
    expect(svc.isLoading()).toBe(true);

    expect(await profile.requestSwitch(B)).toBe(true);
    gate.resolve();
    await settle();
    expect(confirm.confirmStopAndSwitch).not.toHaveBeenCalled();
    expect(world.writes).toEqual([]);
    expect(svc.isLoading()).toBe(false);
    expect(svc.workEntry().workEnd).toEqual(MON(12, 0));
  });

  it('Tageswechsel im Stop: im alten Profil gestoppt, kein zusätzlicher dayChange-Reinit', async () => {
    const h = setup();
    await settle();
    vi.setSystemTime(TUE());

    expect(await h.profile.requestSwitch(B)).toBe(true);
    await settle();
    expect(h.world.data[A].entries.get(toDateKey(MON()))!.workEnd).toEqual(TUE());
    const entryReads = h.world.reads.filter(r => r.kind === 'entry');
    expect(entryReads.map(r => r.resolved)).toEqual([A, B]); // Initiallauf A + der Reinit des Profilwechsels, sonst nichts
  });

  it('doppelte Anfrage bei offenem Dialog: Dialog und Stop genau einmal, die zweite Anfrage wird abgelehnt', async () => {
    const gate = deferred<boolean>();
    const h = setup({}, newConfirm(gate.promise));
    await settle();

    const first = h.profile.requestSwitch(B);
    const second = h.profile.requestSwitch(B);
    // Fake-Profil kennt keine Sperre: die zweite Anfrage fragt den Guard erneut, der Stop darf trotzdem nur einmal laufen.
    gate.resolve(true);
    await Promise.all([first, second]);

    expect(writes(h.world, 'entry').filter(w => w.entry!.workEnd).length).toBe(1);
    expect(h.profile.activeProfileId()).toBe(B);
  });

  it('fehlkonfigurierter Dialog-Service (wirft): Wechsel abgelehnt, keine Writes', async () => {
    const world = makeWorld();
    const profile = createFakeWorkProfile(A);
    const user = signal<{ uid: string } | null>({ uid: 'u1' });
    TestBed.resetTestingModule();
    TestBed.configureTestingModule({
      providers: [
        ...fakeProviders(world, () => profile, user),
        { provide: WorkProfileService, useValue: profile },
        { provide: ProfileSwitchConfirmService, useFactory: () => { throw new Error('nicht konfiguriert'); } },
      ],
    });
    const svc = TestBed.inject(DashboardService);
    await settle();
    expect(svc.isTimerRunning()).toBe(true);

    expect(await profile.requestSwitch(B)).toBe(false);
    expect(world.writes).toEqual([]);
    expect(profile.activeProfileId()).toBe(A);
  });
});

// ─── Mit ECHTEM WorkProfileService ───────────────────────────────────────────────────────────────────────
interface RealHarness {
  svc: DashboardService;
  world: World;
  workProfile: WorkProfileService;
  confirm: ConfirmFake;
  api: { addWorkProfile: ReturnType<typeof vi.fn> };
}

function setupReal(order: 'dashboard-first' | 'profile-first', confirm: ConfirmFake, over: Parameters<typeof makeWorld>[0] = {}): RealHarness {
  const world = makeWorld(over);
  const user = signal<{ uid: string } | null>({ uid: 'u1' });
  const api = {
    getWorkProfiles: async () => [{ id: B, name: 'Zweit' }],
    addWorkProfile: vi.fn(async (n: string) => ({ id: B, name: n })),
    deleteWorkProfile: async () => undefined,
  };
  TestBed.resetTestingModule();
  TestBed.configureTestingModule({
    providers: [
      ...fakeProviders(world, () => inject(WorkProfileService), user),
      { provide: ApiClient, useValue: api },
      { provide: ProfileService, useValue: { isPremium: signal(true) } },
      { provide: ProfileSwitchConfirmService, useValue: confirm },
    ],
  });
  let workProfile: WorkProfileService;
  let svc: DashboardService;
  if (order === 'profile-first') {
    workProfile = TestBed.inject(WorkProfileService);
    svc = TestBed.inject(DashboardService);
  } else {
    svc = TestBed.inject(DashboardService);
    workProfile = TestBed.inject(WorkProfileService);
  }
  return { svc, world, workProfile, confirm, api };
}

describe('Profilwechsel mit laufendem Timer und echtem WorkProfileService (#380, Stufe 2)', () => {
  beforeEach(() => {
    localStorage.clear();
    vi.useFakeTimers();
    vi.setSystemTime(MON());
    vi.spyOn(console, 'error').mockImplementation(() => undefined);
  });
  afterEach(() => {
    TestBed.resetTestingModule();
    const timers = vi.getTimerCount();
    vi.useRealTimers();
    vi.restoreAllMocks();
    localStorage.clear();
    expect(timers).toBe(0);
  });

  const run = async (): Promise<void> => {
    TestBed.tick();
    await vi.advanceTimersByTimeAsync(50);
    TestBed.tick();
    await vi.advanceTimersByTimeAsync(50);
  };

  it.each(['dashboard-first', 'profile-first'] as const)(
    'Timer läuft, bestätigen (%s): A gestoppt und gespeichert, B geladen', async order => {
      const h = setupReal(order, newConfirm(true));
      await run();
      expect(h.svc.isTimerRunning()).toBe(true);

      expect(await h.workProfile.requestSwitch(B)).toBe(true);
      await run();

      expect(h.workProfile.activeProfileId()).toBe(B);
      expect(localStorage.getItem('active_work_profile_u1')).toBe(B);
      expect(h.world.data[A].entries.get(toDateKey(MON()))!.workEnd).toEqual(MON(12, 0));
      expect(h.world.writes.every(w => w.pid === A)).toBe(true);
      expect(h.svc.workEntry().workEnd).toEqual(MON(12, 0));
      expect(h.svc.isTimerRunning()).toBe(false);
    });

  it('Timer läuft, Abbrechen: kein activeProfileId$-Event, kein Reinit, kein Write', async () => {
    const h = setupReal('dashboard-first', newConfirm(false));
    await run();
    const emitted: string[] = [];
    h.workProfile.activeProfileId$.subscribe(id => emitted.push(id));
    TestBed.tick();
    const before = [...emitted];
    const readsBefore = h.world.reads.length;

    expect(await h.workProfile.requestSwitch(B)).toBe(false);
    await run();
    expect(emitted).toEqual(before);
    expect(h.world.reads.length).toBe(readsBefore);
    expect(h.world.writes).toEqual([]);
    expect(h.svc.isTimerRunning()).toBe(true);
    expect(h.workProfile.activeProfileId()).toBe(A);
  });

  it('addProfile() mit laufendem Timer, bestätigt: A gestoppt/gespeichert, dann neues B aktiv, A-Eintrag nie unter B', async () => {
    const h = setupReal('dashboard-first', newConfirm(true), { bEntry: null });
    await run();

    const created = await h.workProfile.addProfile('Zweit');
    await run();

    expect(created).toEqual({ id: B, name: 'Zweit' });
    expect(h.confirm.confirmStopAndSwitch).toHaveBeenCalledWith({ from: A, to: null, toName: 'Zweit' });
    expect(h.workProfile.activeProfileId()).toBe(B);
    expect(h.world.writes.length).toBeGreaterThan(0);
    expect(h.world.writes.every(w => w.pid === A)).toBe(true);
    expect(h.world.data[A].entries.get(toDateKey(MON()))!.workEnd).toBeDefined();
    expect(h.svc.workEntry().workStart).toBeUndefined();
    expect(h.svc.isTimerRunning()).toBe(false);
  });

  it('addProfile() mit laufendem Timer, abgebrochen: nichts angelegt, A läuft weiter, kein Write', async () => {
    const h = setupReal('dashboard-first', newConfirm(false), { bEntry: null });
    await run();

    expect(await h.workProfile.addProfile('Zweit')).toBeNull();
    await run();

    expect(h.api.addWorkProfile).not.toHaveBeenCalled();
    expect(h.workProfile.activeProfileId()).toBe(A);
    expect(h.svc.isTimerRunning()).toBe(true);
    expect(h.world.writes).toEqual([]);
  });
});
