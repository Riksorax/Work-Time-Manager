import { TestBed } from '@angular/core/testing';
import { signal } from '@angular/core';
import { DashboardService } from './dashboard.service';
import { WorkProfileService } from '../../core/services/work-profile';
import { ProfileSwitchConfirmService } from '../../shared/components/work-profile-switcher/profile-switch-confirm';
import { createFakeWorkProfile, FakeWorkProfile } from '../../shared/testing/work-profile-fake';
import {
  DashboardWorld, WORLD_A as A, WORLD_B as B, dashboardWorldProviders, worldEntry,
} from '../../shared/testing/dashboard-world-fake';
import { PromiseTimeoutError } from '../../shared/utils/promise-timeout.util';
import { WorkEntry } from '../../shared/models/index';

// ─── Reentranz-Sperre im Dashboard (#426, Web-Pendant zu Mobile #413) ─────────────────────────────────────
// Überlappende Schreibaktionen werden serialisiert: ein zweiter Aufruf wird still verworfen (`undefined`). Alle
// Zeiten sind feste LOKALE Daten (Montag 2026-10-05) + `vi.setSystemTime`, gesteuert wird nur über die Gates der
// Welt (Hold/Release) und `advanceTimersByTimeAsync`; kein echter Flush, keine Zeitzonen-/Datumsannahme.

const MIN = 60000;
const MON = (h = 12, m = 0, s = 0): Date => new Date(2026, 9, 5, h, m, s);
const TUE = (h = 8, m = 0): Date => new Date(2026, 9, 6, h, m, 0);

/** A: Timer läuft seit 08:00, eine beendete Pause `b1`. */
const aRunning = (): WorkEntry => worldEntry(MON(), {
  workStart: MON(8, 0),
  breaks: [{ id: 'b1', name: 'Pause 1', start: MON(9, 0), end: MON(9, 15), isAutomatic: false }],
});
/** B: abgeschlossener Eintrag 08:00-12:00 mit 30 min Pause. */
const bDone = (): WorkEntry => worldEntry(MON(), {
  workStart: MON(8, 0), workEnd: MON(12, 0),
  breaks: [{ id: 'bb', name: 'Pause', start: MON(10, 0), end: MON(10, 30), isAutomatic: false }],
});

interface Harness {
  svc: DashboardService;
  world: DashboardWorld;
  profile: FakeWorkProfile;
  user: ReturnType<typeof signal<{ uid: string } | null>>;
}

let current: Harness | undefined;

function setup(over: ConstructorParameters<typeof DashboardWorld>[0] = {}): Harness {
  const world = new DashboardWorld({ aEntry: aRunning(), bEntry: bDone(), ...over });
  const profile = createFakeWorkProfile(A);
  const user = signal<{ uid: string } | null>({ uid: 'u1' });
  TestBed.resetTestingModule();
  TestBed.configureTestingModule({
    providers: [
      ...dashboardWorldProviders(world, () => profile, user),
      { provide: WorkProfileService, useValue: profile },
      { provide: ProfileSwitchConfirmService, useValue: { confirmStopAndSwitch: vi.fn(() => Promise.resolve(true)), notifySaveFailed: vi.fn() } },
    ],
  });
  const svc = TestBed.inject(DashboardService);
  profile.activeProfileId$.subscribe(id => world.logSwitch(id));
  world.log.length = 0; // Replay des Startwerts nicht mitzählen
  current = { svc, world, profile, user };
  return current;
}

const settle = async (): Promise<void> => { await vi.advanceTimersByTimeAsync(0); };

/** Wahr, sobald das Promise ohne weiteres Zutun erfüllt ist (ohne darauf zu warten). */
function trackDone(p: Promise<unknown>): { readonly done: boolean } {
  const state = { done: false };
  p.then(() => { state.done = true; }, () => { state.done = true; });
  return state;
}

/** Schreib-Zähler einer Aktion, die allein (ohne Überlappung) läuft: Referenz für „genau so viele wie ein einzelner Lauf“. */
async function aloneCounts(
  action: (s: DashboardService) => Promise<unknown>,
  over: ConstructorParameters<typeof DashboardWorld>[0] = {},
): Promise<{ entry: number; overtime: number; lastUpdate: number }> {
  const h = setup(over);
  await settle();
  await action(h.svc);
  await settle();
  const c = { entry: h.world.entryWrites().length, overtime: h.world.overtimeWrites().length, lastUpdate: h.world.lastUpdateWrites().length };
  TestBed.resetTestingModule();
  return c;
}

/**
 * Ursache eines Schreibfehlers: ab Block B (#426) wirft eine Aktion mit Saldo-Block einen `DashboardSaveError` mit dem
 * ursprünglichen Fehler als `cause`; Block A reicht ihn unverändert weiter. Der Helfer macht die Timeout-Tests für
 * beide Stände gültig, ohne Block B zu importieren.
 */
const rootCause = (e: unknown): unknown => (e instanceof Error && e.cause !== undefined ? e.cause : e);

const countsOf = (w: DashboardWorld) => ({ entry: w.entryWrites().length, overtime: w.overtimeWrites().length, lastUpdate: w.lastUpdateWrites().length });

describe('DashboardService Reentranz-Sperre (#426)', () => {
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

  // ─── Schritt A3: Kern ───────────────────────────────────────────────────────────────────────────────────
  describe('Kern (W1-W9, W17)', () => {
    it('W1 Doppel-Start: genau ein Eintrag-Write, kein Saldo-Write, Timer läuft, zweites Ergebnis sofort undefined', async () => {
      const h = setup({ aEntry: null });
      await settle();
      h.world.hold('saveEntry');

      const p1 = h.svc.startOrStopTimer();
      const p2 = h.svc.startOrStopTimer();
      const second = trackDone(p2);
      await settle();

      expect(second.done).toBe(true);
      expect(await p2).toBeUndefined();
      expect(h.world.calls.saveEntry).toBe(1);
      expect(h.world.pending('saveEntry')).toBe(1);

      h.world.release('saveEntry');
      await p1;
      await settle();
      expect(h.world.calls.saveEntry).toBe(1);
      expect(h.world.overtimeWrites().length).toBe(0);
      expect(h.svc.isTimerRunning()).toBe(true);
      expect(h.svc.workEntry().workEnd).toBeUndefined();
      expect(vi.getTimerCount()).toBe(2); // Mitternachts-Timer + genau ein Sekundentakt
    });

    it('W2a Doppel-Stop (im selben Tick, Saldo-Write gehalten): genau so viele Writes wie ein einzelner Stop, danach ist die Sperre frei', async () => {
      const alone = await aloneCounts(s => s.startOrStopTimer());
      const h = setup();
      await settle();
      h.world.hold('saveOvertime');

      const p1 = h.svc.startOrStopTimer();
      const p2 = h.svc.startOrStopTimer();
      await settle();
      expect(await p2).toBeUndefined();

      h.world.releaseAll();
      await p1;
      await settle();
      expect(countsOf(h.world)).toEqual(alone);
      expect(h.svc.isSaving()).toBe(false);
      expect(await h.svc.startOrStopTimer()).toBe('restart-dialog'); // Sperre frei, Eintrag ist gestoppt
    });

    it('W2b Zweiter Tap im Schreibfenster (nach dem Stop-State) wird verworfen statt den Restart-Dialog zu öffnen', async () => {
      const h = setup();
      await settle();
      h.world.hold('saveOvertime');
      const p1 = h.svc.startOrStopTimer();
      await settle();
      expect(h.world.pending('saveOvertime')).toBe(1);

      const p2 = h.svc.startOrStopTimer();
      await settle();
      expect(await p2).toBeUndefined();

      h.world.releaseAll();
      await p1;
    });

    it('W3 Sperre ist nach einer Rejection frei: der Fehler erreicht den Aufrufer unverändert, die nächste Aktion läuft', async () => {
      const h = setup({ aEntry: null });
      await settle();
      const boom = new Error('write failed');
      h.world.fail('saveEntry', boom);

      await expect(h.svc.startOrStopTimer()).rejects.toBe(boom);
      expect(h.svc.isSaving()).toBe(false);

      h.world.fail('saveEntry', null);
      const before = h.world.calls.saveEntry;
      await h.svc.startOrStopBreak();
      expect(h.world.calls.saveEntry).toBe(before + 1);
      expect(h.svc.isSaving()).toBe(false);
    });

    describe('W4 Kombinationen', () => {
      const pause = (s: DashboardService) => s.startOrStopBreak();
      const stop = (s: DashboardService) => s.startOrStopTimer();
      const manual = (s: DashboardService) => s.setManualStartTime('07:30');
      type Act = (s: DashboardService) => Promise<unknown>;
      const combos: Array<[string, Act, Act]> = [
        ['Pause + Pause', pause, pause],
        ['Pause + Stop', pause, stop],
        ['Stop + Pause', stop, pause],
        ['manuelle Zeit + Stop', manual, stop],
      ];

      it.each(combos)('%s: die zweite Aktion wird verworfen, die Writes entsprechen der ersten Aktion allein', async (_n, first, second) => {
        const alone = await aloneCounts(first);
        const h = setup();
        await settle();
        h.world.hold('saveEntry');

        const p1 = first(h.svc);
        await settle();
        const p2 = second(h.svc);
        const secondDone = trackDone(p2);
        await settle();
        expect(secondDone.done).toBe(true);
        expect(await p2).toBeUndefined();
        expect(h.world.calls.saveEntry).toBe(1);

        h.world.releaseAll();
        await p1;
        await settle();
        expect(countsOf(h.world)).toEqual(alone);
      });
    });

    describe('W5 alle acht Aktionen: der zweite Aufruf derselben Aktion ist wirkungslos', () => {
      const actions: Array<[string, (s: DashboardService) => Promise<unknown>]> = [
        ['startOrStopTimer', s => s.startOrStopTimer()],
        ['startNewSession(true)', s => s.startNewSession(true)],
        ['startNewSession(false)', s => s.startNewSession(false)],
        ['startOrStopBreak', s => s.startOrStopBreak()],
        ['setManualStartTime', s => s.setManualStartTime('07:30')],
        ['setManualEndTime', s => s.setManualEndTime('11:00')],
        ['clearEndTime', s => s.clearEndTime()],
        ['updateBreak', s => s.updateBreak({ id: 'b1', name: 'x', start: MON(9, 0), end: MON(9, 20), isAutomatic: false })],
        ['deleteBreak', s => s.deleteBreak('b1')],
      ];

      it.each(actions)('%s', async (_n, run) => {
        const h = setup();
        await settle();
        h.world.hold('saveEntry');

        const p1 = run(h.svc);
        await settle();
        expect(h.world.pending('saveEntry')).toBe(1);
        const p2 = run(h.svc);
        const secondDone = trackDone(p2);
        await settle();

        expect(secondDone.done).toBe(true);
        expect(await p2).toBeUndefined();
        expect(h.world.pending('saveEntry')).toBe(1);
        expect(h.world.calls.saveEntry).toBe(1);

        h.world.releaseAll();
        await p1;
      });
    });

    it('W6 Ladefenster: der erste Tap wartet auf den Ladelauf (isSaving schon true), der zweite wird sofort verworfen', async () => {
      const h = setup({ aEntry: null });
      await settle();
      h.world.hold('getTodayEntry');
      h.user.set({ uid: 'u2' });
      TestBed.tick(); // Login-Wechsel: Ladelauf hängt im Entry-Read
      await settle();
      expect(h.svc.isLoading()).toBe(true);

      const p1 = h.svc.startOrStopTimer();
      expect(h.svc.isSaving()).toBe(true);
      const p2 = h.svc.startOrStopTimer();
      const secondDone = trackDone(p2);
      await settle();
      expect(secondDone.done).toBe(true);
      expect(await p2).toBeUndefined();
      expect(h.world.calls.saveEntry).toBe(0);

      h.world.releaseAll();
      await p1;
      await settle();
      expect(h.world.calls.saveEntry).toBe(1);
      expect(h.svc.isTimerRunning()).toBe(true);
      expect(h.svc.isSaving()).toBe(false);
    });

    it('W7 Restart-Dialog-Pfad: während „Neue Session“ läuft, liefert ein Tap undefined, nie einen zweiten Dialog', async () => {
      const done = worldEntry(MON(), { workStart: MON(8, 0), workEnd: MON(10, 0) });
      const h = setup({ aEntry: done });
      await settle();
      expect(await h.svc.startOrStopTimer()).toBe('restart-dialog'); // ohne Überlappung wie bisher
      h.world.hold('saveEntry');

      const p1 = h.svc.startNewSession(false);
      await settle();
      const p2 = h.svc.startOrStopTimer();
      const secondDone = trackDone(p2);
      await settle();
      expect(secondDone.done).toBe(true);
      expect(await p2).toBeUndefined();

      h.world.releaseAll();
      await p1;
    });

    it('W8 Profilwechsel mitten in der Aktion: die Sperre der alten Aktion entsperrt nicht und sperrt nicht das neue Profil', async () => {
      const h = setup();
      await settle();
      h.world.hold('saveEntry');

      const pA = h.svc.startOrStopTimer(); // Stop in A, Eintrag-Write hängt
      await settle();
      expect(h.svc.isSaving()).toBe(true);

      h.profile.set(B);
      await settle(); // B ist geladen, die Sperre ist zurückgesetzt
      expect(h.svc.isSaving()).toBe(false);
      expect(h.svc.workEntry().workEnd).toEqual(MON(12, 0));

      const pB = h.svc.startNewSession(false); // Aktion in B wird nicht verworfen
      await settle();
      expect(h.svc.isSaving()).toBe(true);
      expect(h.world.pending('saveEntry')).toBe(2);

      // Die alte A-Aktion schreibt über ihren Kontext ins alte Profil zu Ende ...
      h.world.hold('saveEntry', false);
      h.world.release('saveEntry', 0);
      await pA;
      await settle();
      expect(h.world.overtimeWrites().every(w => w.pid === A)).toBe(true);
      expect(h.world.overtimeWrites().length).toBeGreaterThan(0);
      // ... und löscht dabei die Sperre der B-Aktion nicht.
      expect(h.svc.isSaving()).toBe(true);
      const third = h.svc.startOrStopBreak(); // zweiter B-Tap bleibt verworfen
      const thirdDone = trackDone(third);
      await settle();
      expect(thirdDone.done).toBe(true);
      expect(h.world.calls.saveEntry).toBe(2);

      h.world.releaseAll();
      await pB;
      await settle();
      expect(h.svc.isSaving()).toBe(false);
      expect(h.world.entryWrites(B).length).toBe(1);
    });

    it('W9 Tageswechsel mitten in der Aktion lässt die Sperre stehen; danach genau ein Write am neuen Tag', async () => {
      const done = worldEntry(MON(), { workStart: MON(8, 0), workEnd: MON(10, 0) });
      const h = setup({ aEntry: done });
      await settle();
      vi.setSystemTime(TUE(8, 0));
      h.world.hold('getTodayEntry');

      const p = h.svc.startOrStopTimer(); // Guard stellt auf den neuen Tag um, Lade-Gate hängt
      await settle();
      TestBed.tick(); // Tageswechsel-Effekt: zweiter Reinit
      await settle();
      expect(h.world.pending('getTodayEntry')).toBe(2); // beide Reinit-Läufe hängen
      expect(h.svc.isSaving()).toBe(true);
      expect(h.world.calls.saveEntry).toBe(0);

      h.world.releaseAll();
      await p;
      await settle();
      expect(h.world.calls.saveEntry).toBe(1);
      expect(h.world.entryWrites()[0].entry!.id).toBe('2026-10-06');
      expect(h.svc.isTimerRunning()).toBe(true);
      expect(h.svc.isSaving()).toBe(false);
    });

    it('W17 isSaving-Verlauf: false nach dem Boot, true im Fenster, false nach Erfolg, Rejection, Reinit und Profilwechsel', async () => {
      const h = setup();
      await settle();
      expect(h.svc.isSaving()).toBe(false); // nach Boot

      h.world.hold('saveEntry');
      const p = h.svc.startOrStopBreak();
      await settle();
      expect(h.svc.isSaving()).toBe(true); // im Fenster
      h.world.releaseAll();
      await p;
      expect(h.svc.isSaving()).toBe(false); // nach Erfolg

      h.world.fail('saveEntry', new Error('x'));
      await expect(h.svc.startOrStopBreak()).rejects.toThrow('x');
      expect(h.svc.isSaving()).toBe(false); // nach Rejection
      h.world.fail('saveEntry', null);

      h.world.hold('saveEntry');
      const q = h.svc.startOrStopBreak();
      await settle();
      expect(h.svc.isSaving()).toBe(true);
      h.user.set({ uid: 'u2' }); // Reinit (Login) lässt die Sperre der Aktion stehen
      TestBed.tick();
      await settle();
      expect(h.svc.isSaving()).toBe(true);
      h.world.releaseAll();
      await q;
      await settle();
      expect(h.svc.isSaving()).toBe(false); // nach Reinit

      h.world.hold('saveEntry');
      const r = h.svc.startOrStopBreak();
      await settle();
      expect(h.svc.isSaving()).toBe(true);
      h.profile.set(B);
      await settle();
      expect(h.svc.isSaving()).toBe(false); // nach Profilwechsel
      h.world.releaseAll();
      await r;
      await settle();
      expect(h.svc.isSaving()).toBe(false);
    });
  });

  // ─── Schritt A4: Autosave serialisieren, Timeouts ───────────────────────────────────────────────────────
  describe('Autosave und Timeouts (W10-W14)', () => {
    /** Ergebnis einer Aktion abfangen, damit eine Rejection nie unbehandelt bleibt. */
    const settled = (p: Promise<unknown>): { value?: unknown; error?: unknown; done: boolean } => {
      const r: { value?: unknown; error?: unknown; done: boolean } = { done: false };
      p.then(v => { r.value = v; r.done = true; }, e => { r.error = e; r.done = true; });
      return r;
    };

    it('W10 Der Autosave wird übersprungen, solange eine Aktion läuft', async () => {
      const h = setup();
      await vi.advanceTimersByTimeAsync(20_000); // Autosave-Zähler bei 20
      h.world.hold('saveEntry');

      const p = h.svc.startOrStopBreak(); // Timer läuft weiter, Eintrag-Write hängt
      await settle();
      expect(h.world.calls.saveEntry).toBe(1);
      await vi.advanceTimersByTimeAsync(11_000); // Zähler läuft über 30
      expect(h.world.calls.saveEntry).toBe(1); // kein Autosave im Fenster
      expect(h.svc.isSaving()).toBe(true);

      h.world.releaseAll();
      await p;
    });

    it('W11 Der Zähler bleibt erhalten: der Autosave läuft im nächsten Tick, nicht erst 30 s später', async () => {
      const h = setup();
      await vi.advanceTimersByTimeAsync(20_000);
      h.world.hold('saveEntry');
      const p = h.svc.startOrStopBreak();
      await vi.advanceTimersByTimeAsync(11_000);
      expect(h.world.calls.saveEntry).toBe(1);
      h.world.releaseAll();
      await p;
      await settle();
      expect(h.world.calls.saveEntry).toBe(1);

      await vi.advanceTimersByTimeAsync(1_000); // nächster Tick
      expect(h.world.calls.saveEntry).toBe(2);
      await vi.advanceTimersByTimeAsync(29_000); // danach wieder normaler 30-s-Takt
      expect(h.world.calls.saveEntry).toBe(2);
      await vi.advanceTimersByTimeAsync(1_000);
      expect(h.world.calls.saveEntry).toBe(3);
    });

    it('W12 Eine Aktion wartet auf einen laufenden Autosave: Reihenfolge Autosave-Eintrag, Stop-Eintrag, Saldo', async () => {
      const h = setup();
      await settle();
      h.world.hold('saveEntry');
      await vi.advanceTimersByTimeAsync(30_000); // Autosave hängt im Eintrag-Write
      expect(h.world.calls.saveEntry).toBe(1);

      const p = h.svc.startOrStopTimer();
      await settle();
      expect(h.svc.isSaving()).toBe(true);
      expect(h.world.calls.saveEntry).toBe(1); // der Stop wartet, schreibt noch nichts
      expect(h.world.overtimeWrites().length).toBe(0);

      h.world.hold('saveEntry', false);
      h.world.release('saveEntry', 0); // Autosave fertig
      await p;
      await settle();

      expect(h.world.log.filter(l => !l.startsWith('lastUpdate'))[0]).toBe('entry:default:08:00-'); // Autosave
      const stopEntry = h.world.log.findIndex(l => l === 'entry:default:08:00-12:00');
      const overtime = h.world.log.findIndex(l => l.startsWith('overtime:default:'));
      expect(stopEntry).toBeGreaterThan(0);
      expect(overtime).toBeGreaterThan(stopEntry);
    });

    describe('W13 Timeouts je Write-Block (30 s)', () => {
      it('(a) Saldo-Block: bei 29 s noch gesperrt, bei 30 s Rejection mit PromiseTimeoutError, danach frei', async () => {
        const h = setup();
        await settle();
        h.world.hold('saveOvertime');
        const stop = settled(h.svc.startOrStopTimer());
        await settle();
        expect(h.world.pending('saveOvertime')).toBe(1);

        await vi.advanceTimersByTimeAsync(29_000);
        expect(stop.done).toBe(false);
        expect(h.svc.isSaving()).toBe(true);
        const tap = settled(h.svc.startOrStopTimer());
        await settle();
        expect(tap.done).toBe(true); // verworfen
        expect(tap.value).toBeUndefined();

        await vi.advanceTimersByTimeAsync(1_000);
        expect(stop.done).toBe(true);
        expect(rootCause(stop.error)).toBeInstanceOf(PromiseTimeoutError);
        expect(h.svc.isSaving()).toBe(false);
        // Mitternachts-Timer (+ Sekundentakt, falls die Anzeige zurückgenommen wurde, Block B), kein Timeout-Timer übrig
        expect(vi.getTimerCount()).toBe(h.svc.isTimerRunning() ? 2 : 1);
      });

      it('(b) Eintrag-Block: bei 29 s noch gesperrt, bei 30 s Rejection mit PromiseTimeoutError, danach frei', async () => {
        const h = setup();
        await settle();
        h.world.hold('saveEntry');
        const stop = settled(h.svc.startOrStopTimer());
        await settle();
        expect(h.world.pending('saveEntry')).toBe(1);

        await vi.advanceTimersByTimeAsync(29_000);
        expect(stop.done).toBe(false);
        expect(h.svc.isSaving()).toBe(true);

        await vi.advanceTimersByTimeAsync(1_000);
        expect(stop.done).toBe(true);
        expect(rootCause(stop.error)).toBeInstanceOf(PromiseTimeoutError);
        expect(h.svc.isSaving()).toBe(false);
        expect(h.world.overtimeWrites().length).toBe(0); // nach dem Eintrag-Fehler kein Saldo
        expect(vi.getTimerCount()).toBe(h.svc.isTimerRunning() ? 2 : 1);
      });

      it('(c) Autosave-Timeout: ein wartender Stop läuft nach höchstens 30 s weiter', async () => {
        const h = setup();
        await settle();
        h.world.hold('saveEntry');
        await vi.advanceTimersByTimeAsync(30_000); // Autosave-Write hängt (Timeout bei +30 s)
        const stop = settled(h.svc.startOrStopTimer());
        await vi.advanceTimersByTimeAsync(29_999);
        expect(h.world.calls.saveEntry).toBe(1);
        expect(stop.done).toBe(false);

        await vi.advanceTimersByTimeAsync(1);
        expect(h.world.calls.saveEntry).toBe(2); // Autosave aufgegeben, der Stop schreibt jetzt
        h.world.releaseAll();
        await settle();
        expect(stop.done).toBe(true);
        expect(stop.error).toBeUndefined();
        expect(h.svc.isSaving()).toBe(false);
      });
    });

    it('W14 Ein nach dem Timeout spät landender Saldo-Write löst weder lastUpdate noch einen Folgeschritt aus', async () => {
      const h = setup();
      await settle();
      h.world.hold('saveOvertime');
      const stop = settled(h.svc.startOrStopTimer());
      await vi.advanceTimersByTimeAsync(30_000);
      expect(rootCause(stop.error)).toBeInstanceOf(PromiseTimeoutError);
      const stateBefore = h.svc.workEntry();
      const counts = countsOf(h.world);

      h.world.release('saveOvertime'); // der aufgegebene Write landet doch
      await settle();
      await vi.advanceTimersByTimeAsync(5_000);

      expect(h.world.lastUpdateWrites().length).toBe(0);
      expect(countsOf(h.world)).toEqual(counts);
      expect(h.svc.workEntry()).toBe(stateBefore);
      expect(h.svc.isSaving()).toBe(false);
    });
  });

  // ─── Schritt A5: Profilwechsel-Guard und „Fortsetzen“ ──────────────────────────────────────────────────
  describe('stopRunningTimerForSwitch und resumePastEntry (W15, W16)', () => {
    const settled = (p: Promise<unknown>): { value?: unknown; error?: unknown; done: boolean } => {
      const r: { value?: unknown; error?: unknown; done: boolean } = { done: false };
      p.then(v => { r.value = v; r.done = true; }, e => { r.error = e; r.done = true; });
      return r;
    };

    it('W15a Läuft ein Stop, wartet der Guard-Stop darauf: danach true und genau ein Stop (kein doppelter Saldo)', async () => {
      const alone = await aloneCounts(s => s.startOrStopTimer());
      const h = setup();
      await settle();
      h.world.hold('saveEntry');

      const stop = h.svc.startOrStopTimer();
      await settle();
      const sw = settled(h.svc.stopRunningTimerForSwitch(A));
      await settle();
      expect(sw.done).toBe(false); // wartet auf die laufende Aktion
      expect(h.world.calls.saveEntry).toBe(1);

      h.world.releaseAll();
      await stop;
      await settle();
      expect(sw.done).toBe(true);
      expect(sw.value).toBe(true);
      expect(countsOf(h.world)).toEqual(alone);
      expect(h.svc.isSaving()).toBe(false);
    });

    it('W15b Läuft eine Pause-Aktion (Timer läuft weiter), wartet der Guard-Stop und stoppt danach genau einmal', async () => {
      const h = setup();
      await settle();
      h.world.hold('saveEntry');

      const pause = h.svc.startOrStopBreak();
      await settle();
      const sw = settled(h.svc.stopRunningTimerForSwitch(A));
      await settle();
      expect(sw.done).toBe(false);
      expect(h.world.calls.saveEntry).toBe(1);

      h.world.releaseAll();
      await pause;
      await settle();
      expect(sw.value).toBe(true);
      expect(h.svc.isTimerRunning()).toBe(false);
      // Reihenfolge: erst die Pause (Eintrag ohne Ende), dann der Stop (mit Ende)
      const entries = h.world.log.filter(l => l.startsWith('entry:'));
      expect(entries[0]).toBe('entry:default:08:00-');
      expect(entries[1]).toBe('entry:default:08:00-12:00');
      expect(h.world.entryWrites().length).toBe(2);
    });

    it('W15d Eine Folgeaktion direkt nach dem Ende der laufenden Aktion drängt sich nicht vor den wartenden Guard-Stop', async () => {
      const h = setup();
      await settle();
      h.world.hold('saveEntry');

      const stop = h.svc.startOrStopTimer();
      await settle();
      const sw = settled(h.svc.stopRunningTimerForSwitch(A));
      await settle();
      let follow: Promise<unknown> | undefined;
      // Im selben Microtask-Schub wie das Ende der Aktion: kein `await` zwischen Warteschleife und Sperre im Guard-Stop.
      void stop.then(() => { follow = h.svc.startOrStopBreak(); });

      h.world.releaseAll();
      await settle();
      expect(follow).toBeDefined();
      expect(await follow).toBeUndefined(); // verworfen: der Guard-Stop hält die Sperre
      expect(sw.value).toBe(true);
      expect(h.svc.isTimerRunning()).toBe(false);
    });

    it('W15c Profilwechsel während des Wartens: false, kein Hängen, keine Writes in B', async () => {
      const h = setup();
      await settle();
      h.world.hold('saveEntry');

      const stop = h.svc.startOrStopTimer();
      await settle();
      const sw = settled(h.svc.stopRunningTimerForSwitch(A));
      await settle();
      expect(sw.done).toBe(false);

      h.profile.set(B);
      await settle();
      expect(sw.done).toBe(true);
      expect(sw.value).toBe(false);
      const bData = (): unknown[] => h.world.writes.filter(w => w.pid === B && w.kind !== 'lastUpdate');
      expect(bData()).toEqual([]);

      h.world.releaseAll();
      await stop;
      await settle();
      // Eintrag und Saldo der überholten A-Aktion landen in A. (`saveLastUpdateDate` kennt kein Profil-Argument und
      // schreibt immer ins aktive Profil — Bestandsverhalten aus #380, nicht Teil von #426.)
      expect(bData()).toEqual([]);
      expect(h.svc.isSaving()).toBe(false);
    });

    describe('resumePastEntry', () => {
      const SUN_START = new Date(2026, 9, 4, 20, 0, 0);
      const sunday = (): WorkEntry => worldEntry(new Date(2026, 9, 4), { workStart: SUN_START });

      /** Ladefenster: der Login-Wechsel startet einen Ladelauf, dessen Entry-Read hängt. */
      async function loadingWindow(h: Harness): Promise<void> {
        h.world.hold('getTodayEntry');
        h.user.set({ uid: 'u2' });
        TestBed.tick();
        await settle();
        expect(h.svc.isLoading()).toBe(true);
      }

      it('W16c Wächter: ohne laufende Aktion wird der Vortag wie bisher fortgesetzt', async () => {
        const h = setup({ aEntry: sunday() });
        await settle();
        expect(await h.svc.resumePastEntry(sunday(), A)).toBe(true);
        expect(h.world.calls.getMonth).toBe(1);
      });

      it('W16a Läuft eine Aktion, liefert resumePastEntry sofort false (auch während eines Ladelaufs), ohne Pin-Read', async () => {
        const h = setup({ aEntry: sunday() });
        await settle();
        await loadingWindow(h);
        const action = settled(h.svc.deleteBreak('x')); // Sperre gesetzt, wartet auf den Ladelauf

        const resume = settled(h.svc.resumePastEntry(sunday(), A));
        await settle();
        expect(resume.done).toBe(true); // wartet nicht auf den Ladelauf
        expect(resume.value).toBe(false);
        expect(h.world.calls.getMonth).toBe(0);

        h.world.releaseAll();
        await settle();
        expect(action.done).toBe(true);
        expect(h.world.calls.getMonth).toBe(0);
      });

      it('W16b Wird eine Aktion während der Ladelücke gestartet, liefert resumePastEntry danach false, ohne Pin-Read', async () => {
        const h = setup({ aEntry: sunday() });
        await settle();
        await loadingWindow(h);

        const resume = settled(h.svc.resumePastEntry(sunday(), A)); // wartet auf den Ladelauf
        await settle();
        expect(resume.done).toBe(false);
        const action = settled(h.svc.deleteBreak('x')); // setzt die Sperre in der Ladelücke

        h.world.releaseAll();
        await settle();
        expect(resume.done).toBe(true);
        expect(resume.value).toBe(false);
        expect(h.world.calls.getMonth).toBe(0);
        await settle();
        expect(action.done).toBe(true);
      });
    });
  });
});
