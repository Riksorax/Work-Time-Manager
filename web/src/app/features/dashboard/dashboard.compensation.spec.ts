import { TestBed } from '@angular/core/testing';
import { signal } from '@angular/core';
import { DashboardService } from './dashboard.service';
import { DashboardSaveError } from './dashboard-save-error';
import { WorkProfileService } from '../../core/services/work-profile';
import { ProfileSwitchConfirmService } from '../../shared/components/work-profile-switcher/profile-switch-confirm';
import { createFakeWorkProfile, FakeWorkProfile } from '../../shared/testing/work-profile-fake';
import {
  DashboardWorld, WORLD_A as A, WORLD_B as B, dashboardWorldProviders, worldEntry,
} from '../../shared/testing/dashboard-world-fake';
import { PromiseTimeoutError } from '../../shared/utils/promise-timeout.util';
import { WorkEntry } from '../../shared/models/index';

// ─── Eintrag-Kompensation bei Saldo-Fehler (#426 Block B, Web-Pendant zu Mobile #412) ──────────────────────────
// Aktionen mit Saldo-Block (Stop, manuelle Endzeit, Start/Pause bearbeiten auf beendetem Eintrag): scheitert der
// Eintrag- oder der Saldo-Write, wird die Anzeige auf den Vorzustand zurückgenommen, bei Saldo-Fehler zusätzlich der
// Eintrag best-effort zurückgeschrieben; die Aktion wirft dann einen `DashboardSaveError`. Feste lokale Daten
// (Montag 2026-10-05) + `vi.setSystemTime`, Steuerung nur über die Gates der Welt und `advanceTimersByTimeAsync`.

const MON = (h = 12, m = 0, s = 0): Date => new Date(2026, 9, 5, h, m, s);
const TUE = (h = 1, m = 0): Date => new Date(2026, 9, 6, h, m, 0);

const BREAK = { id: 'b1', name: 'Pause 1', start: MON(9, 0), end: MON(9, 15), isAutomatic: false };
/** A: Timer läuft seit 08:00, eine beendete Pause `b1`. */
const aRunning = (): WorkEntry => worldEntry(MON(), { workStart: MON(8, 0), breaks: [{ ...BREAK }] });
/** A: bereits beendeter Eintrag 08:00-12:00 mit Pause `b1`. */
const aDone = (): WorkEntry => worldEntry(MON(), { workStart: MON(8, 0), workEnd: MON(12, 0), breaks: [{ ...BREAK }] });
const bDone = (): WorkEntry => worldEntry(MON(), { workStart: MON(8, 0), workEnd: MON(12, 0) });

const STOP_ENTRY = 'entry:default:08:00-12:00';
const RUNNING_ENTRY = 'entry:default:08:00-';

interface Harness {
  svc: DashboardService;
  world: DashboardWorld;
  profile: FakeWorkProfile;
  confirm: { confirmStopAndSwitch: ReturnType<typeof vi.fn>; notifySaveFailed: ReturnType<typeof vi.fn> };
}

let current: Harness | undefined;

function setup(over: ConstructorParameters<typeof DashboardWorld>[0] = {}): Harness {
  const world = new DashboardWorld({ aEntry: aRunning(), bEntry: bDone(), ...over });
  const profile = createFakeWorkProfile(A);
  const user = signal<{ uid: string } | null>({ uid: 'u1' });
  const confirm = { confirmStopAndSwitch: vi.fn(() => Promise.resolve(true)), notifySaveFailed: vi.fn() };
  TestBed.resetTestingModule();
  TestBed.configureTestingModule({
    providers: [
      ...dashboardWorldProviders(world, () => profile, user),
      { provide: WorkProfileService, useValue: profile },
      { provide: ProfileSwitchConfirmService, useValue: confirm },
    ],
  });
  const svc = TestBed.inject(DashboardService);
  current = { svc, world, profile, confirm };
  return current;
}

const settle = async (): Promise<void> => { await vi.advanceTimersByTimeAsync(0); };

interface Outcome { done: boolean; value?: unknown; error?: unknown }
/** Ergebnis abfangen, damit eine Rejection nie unbehandelt bleibt. */
function outcome(p: Promise<unknown>): Outcome {
  const r: Outcome = { done: false };
  p.then(v => { r.value = v; r.done = true; }, e => { r.error = e; r.done = true; });
  return r;
}
async function rejection(p: Promise<unknown>): Promise<unknown> {
  return p.then(() => undefined, (e: unknown) => e);
}

const entryLog = (w: DashboardWorld): string[] => w.log.filter(l => l.startsWith('entry:'));

describe('DashboardService Kompensation bei Speicherfehlern (#426 B)', () => {
  beforeEach(() => {
    localStorage.clear();
    vi.useFakeTimers();
    vi.setSystemTime(MON());
    vi.spyOn(console, 'error').mockImplementation(() => undefined);
  });
  afterEach(async () => {
    if (current) {
      current.world.releaseAll();
      await settle();
    }
    current = undefined;
    TestBed.resetTestingModule();
    const timers = vi.getTimerCount();
    vi.useRealTimers();
    vi.restoreAllMocks();
    localStorage.clear();
    expect(timers).toBe(0);
  });

  it('C1 Saldo-Fehler beim Stop: Eintrag wird auf den Vorzustand zurückgeschrieben, Anzeige = Vorzustand, DashboardSaveError', async () => {
    const h = setup();
    await settle();
    const before = h.svc.workEntry();
    const totalBefore = h.svc.totalOvertime();
    const readsBefore = h.world.calls.getTodayEntry;
    const boom = new Error('overtime failed');
    h.world.fail('saveOvertime', boom);

    const err = await rejection(h.svc.startOrStopTimer());

    expect(err).toBeInstanceOf(DashboardSaveError);
    expect((err as DashboardSaveError).cause).toBe(boom);
    expect(entryLog(h.world)).toEqual([STOP_ENTRY, RUNNING_ENTRY]); // Stop-Eintrag, danach der Vorzustand
    expect(h.world.stored(A, MON())!.workEnd).toBeUndefined();
    expect(h.world.lastUpdateWrites().length).toBe(0);
    expect(h.svc.workEntry()).toBe(before);
    expect(h.svc.isTimerRunning()).toBe(true);
    expect(h.svc.totalOvertime()).toBe(totalBefore);
    expect(h.svc.isSaving()).toBe(false);
    expect(h.world.calls.getTodayEntry).toBe(readsBefore); // kein Reinit-Read
    expect(vi.getTimerCount()).toBe(2); // Mitternachts-Timer + genau ein Sekundentakt
  });

  it('C2 Eintrag-Fehler bei einer Aktion mit Saldo-Block: nichts geschrieben, kein Saldo, keine Kompensation, Anzeige = Vorzustand', async () => {
    const h = setup();
    await settle();
    const before = h.svc.workEntry();
    h.world.failSaveEntryCalls = new Set([1]);

    const err = await rejection(h.svc.startOrStopTimer());

    expect(err).toBeInstanceOf(DashboardSaveError);
    expect(((err as DashboardSaveError).cause as Error).message).toContain('saveEntry #1');
    expect(h.world.calls.saveEntry).toBe(1); // keine Kompensation
    expect(h.world.overtimeWrites().length).toBe(0);
    expect(h.world.lastUpdateWrites().length).toBe(0);
    expect(h.world.stored(A, MON())!.workEnd).toBeUndefined();
    expect(h.svc.workEntry()).toBe(before);
    expect(h.svc.isTimerRunning()).toBe(true);
    expect(h.svc.isSaving()).toBe(false);
    expect(vi.getTimerCount()).toBe(2);
  });

  describe('C3 Saldo-Timeout', () => {
    it('bei 30 s ist die Anzeige sofort zurückgenommen und die Kompensation läuft (gesperrt); nach deren Ende frei', async () => {
      const h = setup();
      await settle();
      const before = h.svc.workEntry();
      h.world.hold('saveOvertime');
      const stop = outcome(h.svc.startOrStopTimer());
      await settle();
      h.world.hold('saveEntry'); // die Kompensation soll hängen
      expect(h.world.pending('saveOvertime')).toBe(1);

      await vi.advanceTimersByTimeAsync(30_000);
      expect(h.svc.workEntry()).toBe(before); // Rollback schon sichtbar
      expect(h.world.pending('saveEntry')).toBe(1); // Kompensation beginnt
      expect(stop.done).toBe(false);
      expect(h.svc.isSaving()).toBe(true);
      const tap = outcome(h.svc.startOrStopTimer());
      await settle();
      expect(tap.done).toBe(true);
      expect(tap.value).toBeUndefined(); // verworfen

      h.world.release('saveEntry');
      await settle();
      expect(stop.done).toBe(true);
      expect(stop.error).toBeInstanceOf(DashboardSaveError);
      expect(((stop.error as DashboardSaveError).cause)).toBeInstanceOf(PromiseTimeoutError);
      expect(h.svc.isSaving()).toBe(false);
    });

    it('hängt auch die Kompensation, ist nach weiteren 30 s frei; geworfen wird der Saldo-Fehler, Timer sauber', async () => {
      const h = setup();
      await settle();
      h.world.hold('saveOvertime');
      const stop = outcome(h.svc.startOrStopTimer());
      await settle();
      h.world.hold('saveEntry');

      await vi.advanceTimersByTimeAsync(30_000);
      expect(stop.done).toBe(false);
      await vi.advanceTimersByTimeAsync(29_999);
      expect(stop.done).toBe(false);
      await vi.advanceTimersByTimeAsync(1);
      expect(stop.done).toBe(true);
      expect(stop.error).toBeInstanceOf(DashboardSaveError);
      expect((stop.error as DashboardSaveError).cause).toBeInstanceOf(PromiseTimeoutError);
      expect(h.svc.isSaving()).toBe(false);
      expect(vi.getTimerCount()).toBe(2); // Mitternachts-Timer + Sekundentakt, kein Timeout-Timer übrig
    });
  });

  it('C4 Doppelfehler: geworfen wird der Saldo-Fehler, die Anzeige bleibt Vorzustand, der Autosave heilt den laufenden Eintrag', async () => {
    const h = setup();
    await settle();
    const before = h.svc.workEntry();
    const boom = new Error('overtime failed');
    h.world.fail('saveOvertime', boom);
    h.world.failSaveEntryCalls = new Set([2]); // die Kompensation scheitert ebenfalls

    const err = await rejection(h.svc.startOrStopTimer());

    expect(err).toBeInstanceOf(DashboardSaveError);
    expect((err as DashboardSaveError).cause).toBe(boom); // nicht der Kompensationsfehler
    expect(h.svc.workEntry()).toBe(before);
    expect(h.world.stored(A, MON())!.workEnd).toEqual(MON(12, 0)); // Daten und Anzeige laufen (vorerst) auseinander

    await vi.advanceTimersByTimeAsync(31_000);
    expect(h.world.calls.saveEntry).toBe(3); // Stop, Kompensation, Autosave
    expect(h.world.log[h.world.log.length - 1]).toBe(RUNNING_ENTRY);
    expect(h.world.stored(A, MON())!.workEnd).toBeUndefined(); // geheilt
  });

  it('C5 Wiederholen nach einem Saldo-Fehler schreibt Eintrag und Saldo vollständig, Saldo gleich dem direkt gelungenen Stop', async () => {
    const ref = setup();
    await settle();
    await ref.svc.startOrStopTimer();
    const expectedSaldo = ref.world.data[A].overtimeMs;
    expect(expectedSaldo).not.toBe(120 * 60000);

    const h = setup();
    await settle();
    h.world.fail('saveOvertime', new Error('overtime failed'));
    expect(await rejection(h.svc.startOrStopTimer())).toBeInstanceOf(DashboardSaveError);
    h.world.fail('saveOvertime', null);

    await h.svc.startOrStopTimer();
    expect(h.world.data[A].overtimeMs).toBe(expectedSaldo);
    expect(h.world.stored(A, MON())!.workEnd).toEqual(MON(12, 0));
    expect(h.svc.isTimerRunning()).toBe(false);
    expect(h.world.lastUpdateWrites().length).toBe(1);
  });

  describe('C6 Aktionen mit Saldo-Block: Saldo-Fehler kompensiert den Eintrag', () => {
    const rows: Array<[string, () => WorkEntry, (s: DashboardService) => Promise<unknown>]> = [
      ['setManualEndTime (laufender Eintrag)', aRunning, s => s.setManualEndTime('11:00')],
      ['setManualStartTime (beendeter Eintrag)', aDone, s => s.setManualStartTime('07:30')],
      ['updateBreak (beendeter Eintrag)', aDone, s => s.updateBreak({ ...BREAK, end: MON(9, 30) })],
      ['deleteBreak (beendeter Eintrag)', aDone, s => s.deleteBreak('b1')],
    ];

    it.each(rows)('%s', async (_n, entry, run) => {
      const h = setup({ aEntry: entry() });
      await settle();
      const before = h.svc.workEntry();
      const beforeLine = h.world.entryLogLine(A, before);
      h.world.fail('saveOvertime', new Error('overtime failed'));

      const err = await rejection(run(h.svc));

      expect(err).toBeInstanceOf(DashboardSaveError);
      const lines = entryLog(h.world);
      expect(lines.length).toBe(2);
      expect(lines[1]).toBe(beforeLine); // zuletzt geschrieben: der Vorzustand
      expect(h.world.stored(A, MON())).toBe(before);
      expect(h.svc.workEntry()).toBe(before);
      expect(h.world.lastUpdateWrites().length).toBe(0);
      expect(h.svc.isSaving()).toBe(false);
    });

    describe('Wächter: Aktionen ohne Saldo-Block bleiben unverändert (optimistisch, kein DashboardSaveError, keine Kompensation)', () => {
      const guards: Array<[string, () => WorkEntry | null, (s: DashboardService) => Promise<unknown>, (s: DashboardService) => boolean]> = [
        ['Start', () => null, s => s.startOrStopTimer(), s => s.isTimerRunning()],
        ['Pause auf laufendem Eintrag', aRunning, s => s.startOrStopBreak(), s => s.breaks().length === 2],
        ['clearEndTime', aDone, s => s.clearEndTime(), s => s.isTimerRunning()],
        ['startNewSession', aDone, s => s.startNewSession(true), s => s.isTimerRunning()],
      ];

      it.each(guards)('%s', async (_n, entry, run, optimistic) => {
        const h = setup({ aEntry: entry() });
        await settle();
        h.world.failSaveEntryCalls = new Set([1]);

        const err = await rejection(run(h.svc));

        expect(err).toBeInstanceOf(Error);
        expect(err).not.toBeInstanceOf(DashboardSaveError);
        expect((err as Error).message).toContain('saveEntry #1'); // der Rohfehler, unverändert
        expect(optimistic(h.svc)).toBe(true); // Zustand bleibt optimistisch
        expect(h.world.calls.saveEntry).toBe(1); // keine Kompensation
        expect(h.svc.isSaving()).toBe(false);
      });
    });
  });

  describe('C7 stopRunningTimerForSwitch', () => {
    it('Saldo-Fehler: false (nicht geworfen), Eintrag kompensiert, Timer läuft, Profil unverändert, Folgeversuch gelingt', async () => {
      const h = setup();
      await settle();
      const before = h.svc.workEntry();
      h.world.fail('saveOvertime', new Error('overtime failed'));

      expect(await h.svc.stopRunningTimerForSwitch(A)).toBe(false);

      expect(entryLog(h.world)).toEqual([STOP_ENTRY, RUNNING_ENTRY]);
      expect(h.world.stored(A, MON())!.workEnd).toBeUndefined(); // Server-Eintrag laufend
      expect(h.svc.workEntry()).toBe(before);
      expect(h.svc.isTimerRunning()).toBe(true);
      expect(h.profile.activeProfileId()).toBe(A);
      expect(h.svc.isSaving()).toBe(false);
      expect(vi.getTimerCount()).toBe(2);

      h.world.fail('saveOvertime', null);
      expect(await h.svc.stopRunningTimerForSwitch(A)).toBe(true);
      expect(h.world.stored(A, MON())!.workEnd).toEqual(MON(12, 0));
    });

    it('über den Guard (_confirmSwitch): die Meldung bleibt die des Wechsel-Dialogs, nicht die der Komponente', async () => {
      const h = setup();
      await settle();
      h.world.fail('saveOvertime', new Error('overtime failed'));

      expect(await h.profile.requestSwitch(B)).toBe(false);
      expect(h.confirm.notifySaveFailed).toHaveBeenCalledTimes(1);
      expect(h.profile.activeProfileId()).toBe(A);
    });
  });

  it('C8 Überholte Aktion: nach einem Profilwechsel kompensiert der Saldo-Fehler im alten Profil, State und Timer des neuen bleiben unberührt', async () => {
    const h = setup();
    await settle();
    h.world.hold('saveOvertime');
    const stop = outcome(h.svc.startOrStopTimer());
    await settle();
    h.profile.set(B);
    await settle();
    const bState = h.svc.workEntry();
    expect(bState.workEnd).toEqual(MON(12, 0));

    h.world.rejectPending('saveOvertime', new Error('overtime failed'));
    await settle();

    expect(stop.done).toBe(true);
    expect(stop.error).toBeInstanceOf(DashboardSaveError);
    expect(entryLog(h.world)).toEqual([STOP_ENTRY, RUNNING_ENTRY]); // Kompensation im alten Profil
    expect(h.world.entryWrites().every(w => w.pid === A)).toBe(true);
    expect(h.world.stored(A, MON())!.workEnd).toBeUndefined();
    expect(h.world.writes.filter(w => w.pid === B && w.kind !== 'lastUpdate')).toEqual([]);
    expect(h.svc.workEntry()).toBe(bState);
    expect(h.svc.isTimerRunning()).toBe(false);
    expect(vi.getTimerCount()).toBe(1); // nur der Mitternachts-Timer: kein Timer für B, kein Timeout-Rest
  });

  it('C9 Der Stop schreibt den Saldo genau einmal (kein Duplikat-Write)', async () => {
    const h = setup();
    await settle();
    await h.svc.startOrStopTimer();
    expect(h.world.overtimeWrites().length).toBe(1);
    expect(h.world.lastUpdateWrites().length).toBe(1);
  });

  describe('C10 Mitternachts-Reinit', () => {
    it('Wächter: ohne Fehler wechselt der Stop über Mitternacht auf den neuen Tag (zusätzlicher Read)', async () => {
      const h = setup();
      await settle();
      vi.setSystemTime(TUE(1, 0));
      const readsBefore = h.world.calls.getTodayEntry;
      await h.svc.startOrStopTimer();
      expect(h.world.calls.getTodayEntry).toBeGreaterThan(readsBefore);
    });

    it('nach einem Saldo-Fehler gibt es keinen Reinit (keine zusätzlichen Reads)', async () => {
      const h = setup();
      await settle();
      vi.setSystemTime(TUE(1, 0));
      const readsBefore = h.world.calls.getTodayEntry;
      h.world.fail('saveOvertime', new Error('overtime failed'));

      expect(await rejection(h.svc.startOrStopTimer())).toBeInstanceOf(DashboardSaveError);
      await settle();
      expect(h.world.calls.getTodayEntry).toBe(readsBefore);
      expect(h.svc.isTimerRunning()).toBe(true);
    });
  });

  it('C11 Die Kompensation fasst lastUpdated nie an (im Log nach dem Fehler nur Eintrag-Writes)', async () => {
    const h = setup();
    await settle();
    h.world.fail('saveOvertime', new Error('overtime failed'));
    await rejection(h.svc.startOrStopTimer());

    const afterFailure = h.world.log.slice(h.world.log.findIndex(l => l.startsWith('overtime:')) + 1);
    expect(afterFailure).toEqual([RUNNING_ENTRY]);
    expect(h.world.log.some(l => l.startsWith('lastUpdate:'))).toBe(false);
  });

  describe('C12 DashboardSaveError', () => {
    it('ist ein Error mit Namen, reicht cause durch und nennt keine Eintragswerte', () => {
      const cause = new Error('underlying 08:00-12:00');
      const e = new DashboardSaveError(cause);
      expect(e).toBeInstanceOf(Error);
      expect(e).toBeInstanceOf(DashboardSaveError);
      expect(e.name).toBe('DashboardSaveError');
      expect(e.cause).toBe(cause);
      expect(e.message).not.toMatch(/\d/);
      expect(e.message).not.toContain('08:00');
    });
  });
});
