import { TestBed } from '@angular/core/testing';
import { signal, WritableSignal } from '@angular/core';
import { BehaviorSubject, defer, of } from 'rxjs';
import { DashboardService } from './dashboard.service';
import { WorkEntryService } from '../../core/services/work-entry';
import { OvertimeService } from '../../core/services/overtime';
import { SettingsService } from '../../core/services/settings';
import { AuthService } from '../../core/auth/auth';
import { WorkProfileService } from '../../core/services/work-profile';
import { createFakeWorkProfile } from '../../shared/testing/work-profile-fake';
import { toDateKey } from '../../shared/utils/german-holidays.util';
import { Bundesland, DEFAULT_SETTINGS, UserSettings, WorkEntry, WorkEntryType } from '../../shared/models/index';

describe('DashboardService.holidayToday (#279)', () => {
  let settings$: BehaviorSubject<UserSettings>;
  let saveEntry: ReturnType<typeof vi.fn>;
  let entry: WorkEntry | null;

  function setSettings(bundesland: Bundesland | null): void {
    settings$.next({ ...DEFAULT_SETTINGS, bundesland });
  }

  function create(bundesland: Bundesland | null = 'nordrheinWestfalen'): DashboardService {
    settings$ = new BehaviorSubject<UserSettings>({ ...DEFAULT_SETTINGS, bundesland });
    saveEntry = vi.fn();
    TestBed.resetTestingModule();
    TestBed.configureTestingModule({
      providers: [
        { provide: WorkEntryService, useValue: {
          getTodayEntry: () => of(entry),
          emptyEntry: (d: Date) => ({ id: 'x', date: d, breaks: [], isManuallyEntered: false, type: WorkEntryType.Work }),
          saveEntry,
        } },
        { provide: OvertimeService, useValue: {
          getOvertime: vi.fn().mockResolvedValue(0),
          getLastUpdateDate: vi.fn().mockResolvedValue(null),
          saveOvertime: vi.fn(),
        } },
        { provide: SettingsService, useValue: { getSettings: () => settings$.asObservable(), saveSettings: vi.fn() } },
        { provide: AuthService, useValue: { user: signal(null), uid: null } },
        { provide: WorkProfileService, useValue: createFakeWorkProfile() },
      ],
    });
    return TestBed.inject(DashboardService);
  }

  beforeEach(() => {
    entry = null;
    vi.useFakeTimers();
    vi.setSystemTime(new Date(2026, 9, 3, 12, 0));
  });
  afterEach(() => {
    TestBed.resetTestingModule();
    vi.useRealTimers();
    vi.restoreAllMocks();
  });

  it('zeigt am 3.10. den Tag der Deutschen Einheit', () => {
    vi.setSystemTime(new Date(2026, 9, 3, 12, 0));
    expect(create().holidayToday()).toBe('germanUnityDay');
  });

  it('zeigt ohne Bundesland nie einen Feiertag', () => {
    vi.setSystemTime(new Date(2026, 9, 3, 12, 0));
    expect(create(null).holidayToday()).toBeNull();
  });

  it('liefert an einem normalen Tag null', () => {
    vi.setSystemTime(new Date(2026, 9, 5, 12, 0));
    expect(create().holidayToday()).toBeNull();
  });

  it('reagiert auf ein geändertes Bundesland', () => {
    vi.setSystemTime(new Date(2026, 9, 31, 12, 0));
    const svc = create('sachsen');
    expect(svc.holidayToday()).toBe('reformationDay');
    setSettings('bayern');
    expect(svc.holidayToday()).toBeNull();
    setSettings('sachsen');
    expect(svc.holidayToday()).toBe('reformationDay');
  });

  it('Landesfeiertag Heilige Drei Könige', () => {
    vi.setSystemTime(new Date(2026, 0, 6, 9, 0));
    const svc = create('bayern');
    expect(svc.holidayToday()).toBe('epiphany');
    setSettings('nordrheinWestfalen');
    expect(svc.holidayToday()).toBeNull();
  });

  it('wechselt zur lokalen Mitternacht', () => {
    vi.setSystemTime(new Date(2026, 9, 2, 23, 59, 30));
    const svc = create();
    expect(svc.holidayToday()).toBeNull();
    vi.advanceTimersByTime(31_000);
    expect(svc.holidayToday()).toBe('germanUnityDay');
    // Folgetag: nächster Timer ist geplant
    vi.advanceTimersByTime(24 * 60 * 60 * 1000);
    expect(svc.holidayToday()).toBeNull();
  });

  it('plant den Mitternachts-Timer mit mindestens 1 s Verzögerung (1 ms vor Mitternacht)', () => {
    const spy = vi.spyOn(globalThis, 'setTimeout');
    vi.setSystemTime(new Date(2026, 9, 2, 23, 59, 59, 999));
    create();
    const delays = spy.mock.calls.map(c => c[1] as number).filter(d => d <= 25 * 3600 * 1000);
    // tatsächlich verbleibende 1 ms wird auf 1000 ms angehoben, nie darunter
    expect(delays).toContain(1000);
    expect(delays.filter(d => d > 0 && d < 1000)).toEqual([]);
  });

  it('trifft den Tageswechsel exakt über die Zeitumstellung (Ostermontag 2024-04-01 nach 31.3.)', () => {
    // 31.3.2024 ist in Europe/Berlin ein 23-h-Tag, in UTC ein 24-h-Tag: der Test gilt für beide Zonen.
    vi.setSystemTime(new Date(2024, 2, 31, 0, 30));
    const svc = create('bayern');
    expect(svc.holidayToday()).toBeNull();
    const untilMidnight = new Date(2024, 3, 1).getTime() - Date.now();
    vi.advanceTimersByTime(untilMidnight - 1);
    expect(svc.holidayToday()).toBeNull();
    vi.advanceTimersByTime(1);
    expect(svc.holidayToday()).toBe('easterMonday');
  });

  it('trifft den Tageswechsel am 25-h-Tag der Rückumstellung (2025-10-26 -> 27.)', () => {
    vi.setSystemTime(new Date(2025, 9, 26, 0, 30));
    const svc = create('bayern');
    expect(svc.holidayToday()).toBeNull();
    const untilMidnight = new Date(2025, 9, 27).getTime() - Date.now();
    vi.advanceTimersByTime(untilMidnight - 1);
    expect(svc.holidayToday()).toBeNull();
    vi.advanceTimersByTime(1);
    expect(svc.holidayToday()).toBeNull();
    expect(new Date().getDate()).toBe(27);
  });

  it('wechselt über die Umstellung hinweg weiter (Ostermontag, Folgetag wieder ohne Feiertag)', () => {
    vi.setSystemTime(new Date(2024, 2, 31, 12, 0));
    const svc = create('bayern');
    vi.advanceTimersByTime(new Date(2024, 3, 1).getTime() - Date.now());
    expect(svc.holidayToday()).toBe('easterMonday');
    vi.advanceTimersByTime(new Date(2024, 3, 2).getTime() - Date.now());
    expect(svc.holidayToday()).toBeNull();
  });

  it('aktualisiert bei visibilitychange (visible), nicht bei hidden', () => {
    vi.setSystemTime(new Date(2026, 9, 2, 12, 0));
    const svc = create();
    expect(svc.holidayToday()).toBeNull();
    vi.setSystemTime(new Date(2026, 9, 3, 8, 0));

    Object.defineProperty(document, 'visibilityState', { value: 'hidden', configurable: true });
    document.dispatchEvent(new Event('visibilitychange'));
    expect(svc.holidayToday()).toBeNull();

    Object.defineProperty(document, 'visibilityState', { value: 'visible', configurable: true });
    document.dispatchEvent(new Event('visibilitychange'));
    expect(svc.holidayToday()).toBe('germanUnityDay');
  });

  it('räumt Timer und Listener beim Destroy auf', () => {
    vi.setSystemTime(new Date(2026, 9, 2, 12, 0));
    const remove = vi.spyOn(document, 'removeEventListener');
    const svc = create();
    const before = vi.getTimerCount();
    TestBed.resetTestingModule();
    expect(remove.mock.calls.some(c => c[0] === 'visibilitychange')).toBe(true);
    expect(vi.getTimerCount()).toBeLessThan(before);
    vi.advanceTimersByTime(48 * 60 * 60 * 1000);
    expect(svc.holidayToday()).toBeNull();
  });

  describe('rein informativ', () => {
    const types = [WorkEntryType.Work, WorkEntryType.Vacation, WorkEntryType.Sick, WorkEntryType.Holiday];

    it.each(types)('lässt Eintrag und Überstunden bei Typ %s unverändert', async type => {
      vi.setSystemTime(new Date(2026, 9, 3, 12, 0));
      const date = new Date(2026, 9, 3);
      entry = {
        id: '2026-10-03', date, type, breaks: [], isManuallyEntered: false,
        workStart: new Date(2026, 9, 3, 8, 0), workEnd: new Date(2026, 9, 3, 16, 0),
      };
      const withLand = create('nordrheinWestfalen');
      await vi.advanceTimersByTimeAsync(0);
      const snapshot = {
        e: withLand.workEntry(), t: withLand.totalOvertime(), d: withLand.dailyOvertime(), x: withLand.expectedEndTime(),
      };
      expect(withLand.holidayToday()).toBe('germanUnityDay');
      const saves = saveEntry.mock.calls.length;
      TestBed.resetTestingModule();

      const without = create(null);
      await vi.advanceTimersByTimeAsync(0);
      expect(without.holidayToday()).toBeNull();
      expect({
        e: without.workEntry(), t: without.totalOvertime(), d: without.dailyOvertime(), x: without.expectedEndTime(),
      }).toEqual(snapshot);
      expect(saves).toBe(0);
      expect(saveEntry).not.toHaveBeenCalled();
    });
  });
});

// ─── Gemeinsamer Aufbau für #372 (Tageswechsel) ────────────────────────────────
interface Harness {
  svc: DashboardService;
  user: WritableSignal<{ uid: string } | null>;
  settings$: BehaviorSubject<UserSettings>;
  store: Map<string, WorkEntry>;
  saveEntry: ReturnType<typeof vi.fn>;
  saveOvertime: ReturnType<typeof vi.fn>;
  saveLastUpdateDate: ReturnType<typeof vi.fn>;
  getOvertime: ReturnType<typeof vi.fn>;
  getLastUpdateDate: ReturnType<typeof vi.fn>;
}

interface SetupOptions {
  entries?: WorkEntry[];
  loggedIn?: boolean;
  storedOvertimeMs?: number;
  lastUpdate?: Date | null;
  getOvertime?: () => Promise<number>;
}

function mkEntry(y: number, m: number, d: number, extra: Partial<WorkEntry> = {}): WorkEntry {
  const date = new Date(y, m, d);
  return { id: toDateKey(date), date, breaks: [], isManuallyEntered: false, type: WorkEntryType.Work, ...extra };
}

function setup(opts: SetupOptions = {}): Harness {
  const store = new Map<string, WorkEntry>((opts.entries ?? []).map(e => [toDateKey(e.date), e]));
  const settings$ = new BehaviorSubject<UserSettings>({ ...DEFAULT_SETTINGS, bundesland: null });
  const user = signal<{ uid: string } | null>(opts.loggedIn === false ? null : { uid: 'u1' });
  const saveEntry = vi.fn(async (e: WorkEntry) => { store.set(toDateKey(e.date), e); });
  const saveOvertime = vi.fn().mockResolvedValue(undefined);
  const saveLastUpdateDate = vi.fn().mockResolvedValue(undefined);
  const getOvertime = vi.fn(opts.getOvertime ?? (() => Promise.resolve(opts.storedOvertimeMs ?? 0)));
  const getLastUpdateDate = vi.fn().mockResolvedValue(opts.lastUpdate ?? null);
  TestBed.resetTestingModule();
  TestBed.configureTestingModule({
    providers: [
      { provide: WorkEntryService, useValue: {
        getTodayEntry: () => defer(() => of(store.get(toDateKey(new Date())) ?? null)),
        emptyEntry: (d: Date) => mkEntry(d.getFullYear(), d.getMonth(), d.getDate()),
        saveEntry,
      } },
      { provide: OvertimeService, useValue: { getOvertime, getLastUpdateDate, saveOvertime, saveLastUpdateDate } },
      { provide: SettingsService, useValue: { getSettings: () => settings$.asObservable(), saveSettings: vi.fn() } },
      { provide: AuthService, useValue: { user, get uid() { return user()?.uid ?? null; } } },
      { provide: WorkProfileService, useValue: createFakeWorkProfile() },
    ],
  });
  const svc = TestBed.inject(DashboardService);
  return { svc, user, settings$, store, saveEntry, saveOvertime, saveLastUpdateDate, getOvertime, getLastUpdateDate };
}

function fakeClockSuite(name: string, body: () => void): void {
  describe(name, () => {
    beforeEach(() => {
      vi.useFakeTimers();
      vi.setSystemTime(new Date(2026, 9, 3, 12, 0));
    });
    afterEach(() => {
      TestBed.resetTestingModule();
      vi.useRealTimers();
      vi.restoreAllMocks();
      Object.defineProperty(document, 'visibilityState', { value: 'visible', configurable: true });
    });
    body();
  });
}

fakeClockSuite('DashboardService Listener (#372)', () => {
  it('Refokus: aktualisiert Daily/Total/ExpectedEnd nach visible + 1-s-Tick', async () => {
    vi.setSystemTime(new Date(2026, 9, 5, 12, 0)); // Montag
    const h = setup({ entries: [mkEntry(2026, 9, 5, { workStart: new Date(2026, 9, 5, 8, 0) })] });
    await vi.advanceTimersByTimeAsync(1000);
    expect(h.svc.isTimerRunning()).toBe(true);

    Object.defineProperty(document, 'visibilityState', { value: 'hidden', configurable: true });
    document.dispatchEvent(new Event('visibilitychange'));
    vi.setSystemTime(new Date(2026, 9, 5, 12, 5));
    Object.defineProperty(document, 'visibilityState', { value: 'visible', configurable: true });
    document.dispatchEvent(new Event('visibilitychange'));
    vi.advanceTimersByTime(1000);

    const elapsed = Date.now() - new Date(2026, 9, 5, 8, 0).getTime();
    const target = 8 * 3600000;
    expect(h.svc.dailyOvertime()).toBe(elapsed - target);
    expect(h.svc.totalOvertime()).toBe(elapsed - target);
    expect(h.svc.expectedEndTime()?.getTime()).toBe(new Date(2026, 9, 5, 8, 0).getTime() + target + 30 * 60000); // + Pflichtpause
  });

  it('Leck: jeder visibilitychange-Listener wird beim Destroy mit derselben Referenz entfernt', () => {
    const add = vi.spyOn(document, 'addEventListener');
    const remove = vi.spyOn(document, 'removeEventListener');
    setup();
    TestBed.resetTestingModule();
    const added = add.mock.calls.filter(c => c[0] === 'visibilitychange').map(c => c[1]);
    const removed = remove.mock.calls.filter(c => c[0] === 'visibilitychange').map(c => c[1]);
    expect(added.length).toBeGreaterThan(0);
    for (const fn of added) expect(removed).toContain(fn);
  });
});

const H = 3600000;

/** Setzt die Uhr, lässt `_init` laufen und den ersten Tick. */
async function startRunning(
  h: Harness,
  tickAt: Date,
): Promise<void> {
  await vi.advanceTimersByTimeAsync(0);
  expect(h.svc.isTimerRunning()).toBe(true);
  vi.setSystemTime(tickAt);
  await vi.advanceTimersByTimeAsync(1000);
}

fakeClockSuite('DashboardService Eintragsdatum-Kopplung (#372)', () => {
  it('Fr -> Sa: Soll bleibt das Freitags-Soll, Endzeit unverändert', async () => {
    vi.setSystemTime(new Date(2026, 9, 2, 12, 0)); // Freitag
    const start = new Date(2026, 9, 2, 8, 0);
    const h = setup({ entries: [mkEntry(2026, 9, 2, { workStart: start })] });
    await vi.advanceTimersByTimeAsync(1000);
    const endBefore = h.svc.expectedEndTime()?.getTime();
    expect(endBefore).toBe(start.getTime() + 8 * H + 30 * 60000);

    vi.setSystemTime(new Date(2026, 9, 3, 1, 0)); // Samstag
    await vi.advanceTimersByTimeAsync(1000);
    const elapsed = Date.now() - start.getTime();
    // Pause: laufende Pflichtpause wird nicht angesetzt (keine Pause erfasst)
    expect(h.svc.dailyOvertime()).toBe(elapsed - 8 * H);
    expect(h.svc.expectedEndTime()?.getTime()).toBe(endBefore);
  });

  it('So -> Mo: Soll bleibt 0 (Sonntagseintrag); Gegenprobe Montag mit 8 h Soll', async () => {
    vi.setSystemTime(new Date(2026, 9, 4, 12, 0)); // Sonntag
    const start = new Date(2026, 9, 4, 8, 0);
    const h = setup({ entries: [mkEntry(2026, 9, 4, { workStart: start })] });
    await vi.advanceTimersByTimeAsync(1000);
    vi.setSystemTime(new Date(2026, 9, 5, 1, 0)); // Montag
    await vi.advanceTimersByTimeAsync(1000);
    expect(h.svc.dailyOvertime()).toBe(Date.now() - start.getTime());
    expect(h.svc.expectedEndTime()?.getTime()).toBe(start.getTime());
    TestBed.resetTestingModule();

    vi.setSystemTime(new Date(2026, 9, 5, 12, 0));
    const startMo = new Date(2026, 9, 5, 8, 0);
    const mo = setup({ entries: [mkEntry(2026, 9, 5, { workStart: startMo })] });
    await vi.advanceTimersByTimeAsync(1000);
    expect(mo.svc.dailyOvertime()).toBe(Date.now() - startMo.getTime() - 8 * H);
  });

  it('Stop nach Mitternacht rechnet mit dem Soll des Eintragstags (Freitag)', async () => {
    vi.setSystemTime(new Date(2026, 9, 2, 12, 0));
    const start = new Date(2026, 9, 2, 20, 0);
    const h = setup({ entries: [mkEntry(2026, 9, 2, { workStart: start })] });
    await startRunning(h, new Date(2026, 9, 3, 1, 0));
    await h.svc.startOrStopTimer();
    const saved = h.saveEntry.mock.calls.at(-1)![0] as WorkEntry;
    expect(toDateKey(saved.date)).toBe('2026-10-02');
    const breakMs = saved.breaks.reduce((sum, b) => sum + (b.end!.getTime() - b.start.getTime()), 0);
    const net = saved.workEnd!.getTime() - start.getTime() - breakMs;
    expect(h.saveOvertime).toHaveBeenCalledWith(net - 8 * H, 'default');
  });

  // Samstage vor Zeitumstellungen (Berlin 28.3./24.10., LA 7.3./31.10., Auckland 4.4./26.9.)
  it.each([
    [2026, 2, 28], [2026, 9, 24], [2026, 2, 7], [2026, 9, 31], [2026, 3, 4], [2026, 8, 26],
  ])('laufender Timer über Zeitumstellung %i-%i-%i: absolute Differenz, Soll am Starttag', async (y, m, d) => {
    const start = new Date(y, m, d, 22, 0);
    vi.setSystemTime(new Date(y, m, d, 23, 0));
    const h = setup({ entries: [mkEntry(y, m, d, { workStart: start })] });
    await vi.advanceTimersByTimeAsync(1000);
    vi.setSystemTime(new Date(y, m, d + 1, 3, 0));
    await vi.advanceTimersByTimeAsync(1000);
    expect(h.svc.isTimerRunning()).toBe(true);
    // Samstag/Sonntag: Soll 0 -> Daily = absolute Differenz
    expect(h.svc.dailyOvertime()).toBe(Date.now() - start.getTime());
  });
});

fakeClockSuite('DashboardService Generationszähler (#372)', () => {
  function deferred(): { promise: Promise<number>; resolve: (v: number) => void } {
    let resolve!: (v: number) => void;
    const promise = new Promise<number>(r => { resolve = r; });
    return { promise, resolve };
  }

  it('ein überholter _init-Lauf überschreibt den Zustand des neueren nicht und startet keinen Timer', async () => {
    vi.setSystemTime(new Date(2026, 9, 5, 12, 0));
    const gate = deferred();
    let call = 0;
    const h = setup({
      loggedIn: false,
      entries: [mkEntry(2026, 9, 5, { workStart: new Date(2026, 9, 5, 8, 0) })],
      getOvertime: () => (++call === 1 ? gate.promise : Promise.resolve(100 * 60000)),
    });
    await vi.advanceTimersByTimeAsync(0); // Lauf 1 hängt in getOvertime (Eintrag schon gelesen)
    h.store.clear();
    h.user.set({ uid: 'u1' });            // Login -> Lauf 2
    TestBed.tick();
    await vi.advanceTimersByTimeAsync(0);
    expect(h.svc.isLoading()).toBe(false);
    expect(h.svc.totalOvertime()).toBe(100 * 60000);

    gate.resolve(999 * 60000);            // alter Lauf wird nachträglich fertig
    await vi.advanceTimersByTimeAsync(0);
    expect(h.svc.totalOvertime()).toBe(100 * 60000);
    expect(h.svc.isTimerRunning()).toBe(false);
    expect(h.svc.workEntry().workStart).toBeUndefined();
    expect(vi.getTimerCount()).toBe(1); // nur der Mitternachts-Timer
  });

  it('ein fehlgeschlagener alter Lauf setzt den Status des neueren nicht zurück', async () => {
    vi.setSystemTime(new Date(2026, 9, 5, 12, 0));
    let rejectFirst!: (e: Error) => void;
    const first = new Promise<number>((_, rej) => { rejectFirst = rej; });
    let call = 0;
    const h = setup({ loggedIn: false, getOvertime: () => (++call === 1 ? first : Promise.resolve(60000)) });
    await vi.advanceTimersByTimeAsync(0);
    h.user.set({ uid: 'u1' });
    TestBed.tick();
    await vi.advanceTimersByTimeAsync(0);
    expect(h.svc.totalOvertime()).toBe(60000);
    rejectFirst(new Error('boom'));
    await vi.advanceTimersByTimeAsync(0);
    expect(h.svc.totalOvertime()).toBe(60000);
    expect(h.svc.isLoading()).toBe(false);
  });
});

fakeClockSuite('DashboardService Tageswechsel (#372)', () => {
  const key = (h: Harness): string => toDateKey(h.svc.workEntry().date);

  it('Fr -> Sa: leerer Eintrag schaltet still auf den neuen Tag, ohne Speichern', async () => {
    vi.setSystemTime(new Date(2026, 9, 2, 23, 59, 30));
    const h = setup({ storedOvertimeMs: 60 * 60000 });
    await vi.advanceTimersByTimeAsync(0);
    expect(key(h)).toBe('2026-10-02');
    await vi.advanceTimersByTimeAsync(31_000);
    expect(key(h)).toBe('2026-10-03');
    expect(h.svc.workEntry().id).toBe('2026-10-03');
    expect(h.svc.isLoading()).toBe(false);
    expect(h.svc.totalOvertime()).toBe(60 * 60000);
    expect(h.svc.dailyOvertime()).toBeNull(); // leerer Tag: kein Daily (wie beim normalen _init)
    expect(h.saveEntry).not.toHaveBeenCalled();
    expect(h.saveOvertime).not.toHaveBeenCalled();
  });

  it('So -> Mo: neuer Tag hat 8 h Soll', async () => {
    vi.setSystemTime(new Date(2026, 9, 4, 23, 59, 30));
    const h = setup();
    await vi.advanceTimersByTimeAsync(31_000);
    expect(key(h)).toBe('2026-10-05');
    await h.svc.startOrStopTimer();
    await vi.advanceTimersByTimeAsync(1000);
    const start = h.svc.workEntry().workStart!;
    expect(h.svc.dailyOvertime()).toBe(Date.now() - start.getTime() - 8 * H);
    expect(toDateKey(h.saveEntry.mock.calls.at(-1)![0].date)).toBe('2026-10-05');
  });

  it('vollständiger gestoppter Vortagseintrag: neuer Tag leer, nichts gespeichert', async () => {
    vi.setSystemTime(new Date(2026, 9, 2, 23, 59, 30));
    const h = setup({ entries: [mkEntry(2026, 9, 2, { workStart: new Date(2026, 9, 2, 8, 0), workEnd: new Date(2026, 9, 2, 16, 0) })] });
    await vi.advanceTimersByTimeAsync(0);
    expect(h.svc.workEntry().workEnd).toBeDefined();
    await vi.advanceTimersByTimeAsync(31_000);
    expect(key(h)).toBe('2026-10-03');
    expect(h.svc.workEntry().workStart).toBeUndefined();
    expect(h.saveEntry).not.toHaveBeenCalled();
    expect(h.saveOvertime).not.toHaveBeenCalled();
  });

  it.each(['focus', 'pageshow'])('Standby: Zeitsprung ohne Timerablauf + window-%s schaltet um', async evt => {
    vi.setSystemTime(new Date(2026, 9, 2, 12, 0));
    const h = setup();
    await vi.advanceTimersByTimeAsync(0);
    vi.setSystemTime(new Date(2026, 9, 3, 9, 0));
    window.dispatchEvent(new Event(evt));
    await vi.advanceTimersByTimeAsync(0);
    expect(key(h)).toBe('2026-10-03');
  });

  it('Tick-Abgleich bei laufendem Timer: Holiday-Chip zieht nach, Eintrag bleibt', async () => {
    vi.setSystemTime(new Date(2026, 9, 2, 12, 0));
    const h = setup({ entries: [mkEntry(2026, 9, 2, { workStart: new Date(2026, 9, 2, 8, 0) })] });
    h.settings$.next({ ...DEFAULT_SETTINGS, bundesland: 'nordrheinWestfalen' });
    await vi.advanceTimersByTimeAsync(1000);
    expect(h.svc.holidayToday()).toBeNull();
    vi.setSystemTime(new Date(2026, 9, 3, 9, 0));
    await vi.advanceTimersByTimeAsync(1000);
    expect(h.svc.holidayToday()).toBe('germanUnityDay');
    expect(key(h)).toBe('2026-10-02');
    expect(h.svc.isTimerRunning()).toBe(true);
  });

  it('laufender Timer über Mitternacht: kein Reinit, kein Save auf neuen Tag, Autosave am Starttag', async () => {
    vi.setSystemTime(new Date(2026, 9, 2, 23, 59, 0));
    const h = setup({ entries: [mkEntry(2026, 9, 2, { workStart: new Date(2026, 9, 2, 20, 0) })] });
    await vi.advanceTimersByTimeAsync(1000);
    const reads = h.getOvertime.mock.calls.length;
    await vi.advanceTimersByTimeAsync(65_000);
    expect(Date.now()).toBeGreaterThan(new Date(2026, 9, 3).getTime());
    expect(h.getOvertime.mock.calls.length).toBe(reads);
    expect(h.svc.isTimerRunning()).toBe(true);
    expect(key(h)).toBe('2026-10-02');
    expect(h.saveEntry.mock.calls.length).toBeGreaterThan(0);
    for (const [e] of h.saveEntry.mock.calls) {
      expect(toDateKey((e as WorkEntry).date)).toBe('2026-10-02');
      expect((e as WorkEntry).id).toBe('2026-10-02');
    }
  });

  it('Basis-Überstunden beim Tageswechsel = gespeicherter Wert (nicht minus Daily)', async () => {
    vi.setSystemTime(new Date(2026, 9, 2, 23, 59, 30));
    const sat = mkEntry(2026, 9, 3, { workStart: new Date(2026, 9, 3, 0, 0), workEnd: new Date(2026, 9, 3, 0, 10) });
    const h = setup({ entries: [sat], storedOvertimeMs: 120 * 60000, lastUpdate: new Date(2026, 9, 3, 0, 0, 5) });
    await vi.advanceTimersByTimeAsync(31_000);
    expect(key(h)).toBe('2026-10-03');
    expect(h.svc.dailyOvertime()).toBe(10 * 60000);
    expect(h.svc.totalOvertime()).toBe(130 * 60000);
  });

  it('Gegenprobe: normaler _init mit lastUpdate = heute zieht den Daily ab', async () => {
    vi.setSystemTime(new Date(2026, 9, 3, 12, 0));
    const sat = mkEntry(2026, 9, 3, { workStart: new Date(2026, 9, 3, 8, 0), workEnd: new Date(2026, 9, 3, 8, 10) });
    const h = setup({ entries: [sat], storedOvertimeMs: 120 * 60000, lastUpdate: new Date(2026, 9, 3, 9, 0) });
    await vi.advanceTimersByTimeAsync(0);
    expect(h.svc.totalOvertime()).toBe(120 * 60000);
  });

  // Berlin 28.3./24.10., LA 7.3./31.10., Auckland 4.4./26.9. (jeweils Samstag vor der Umstellung)
  it.each([
    [2026, 2, 28], [2026, 9, 24], [2026, 2, 7], [2026, 9, 31], [2026, 3, 4], [2026, 8, 26],
  ])('stiller Wechsel über Zeitumstellung %i-%i-%i', async (y, m, d) => {
    vi.setSystemTime(new Date(y, m, d, 23, 59, 30));
    const h = setup();
    await vi.advanceTimersByTimeAsync(0);
    expect(key(h)).toBe(toDateKey(new Date(y, m, d)));
    await vi.advanceTimersByTimeAsync(new Date(y, m, d + 1).getTime() - Date.now() + 1);
    expect(key(h)).toBe(toDateKey(new Date(y, m, d + 1)));
    await vi.advanceTimersByTimeAsync(new Date(y, m, d + 2).getTime() - Date.now() + 1);
    expect(key(h)).toBe(toDateKey(new Date(y, m, d + 2)));
    expect(h.saveEntry).not.toHaveBeenCalled();
  });

  it('anonym: gleicher Wechsel, Zustand anonym', async () => {
    vi.setSystemTime(new Date(2026, 9, 2, 23, 59, 30));
    const h = setup({ loggedIn: false });
    await vi.advanceTimersByTimeAsync(31_000);
    expect(h.svc.isLoggedIn()).toBe(false);
    expect(key(h)).toBe('2026-10-03');
  });

  it('Login um 23:59 + Mitternacht: genau ein gültiger Endzustand', async () => {
    vi.setSystemTime(new Date(2026, 9, 2, 23, 59, 0));
    const h = setup({ loggedIn: false, storedOvertimeMs: 30 * 60000 });
    await vi.advanceTimersByTimeAsync(0);
    h.user.set({ uid: 'u1' });
    TestBed.tick();
    await vi.advanceTimersByTimeAsync(61_000);
    expect(key(h)).toBe('2026-10-03');
    expect(h.svc.isLoading()).toBe(false);
    expect(h.svc.totalOvertime()).toBe(30 * 60000);
    expect(vi.getTimerCount()).toBe(1);
  });
});

fakeClockSuite('DashboardService Aktionen-Guard (#372)', () => {
  const FRI = '2026-10-02';
  const SAT = '2026-10-03';
  const savedKeys = (h: Harness): string[] => h.saveEntry.mock.calls.map(c => toDateKey((c[0] as WorkEntry).date));

  function friStopped(): WorkEntry {
    return mkEntry(2026, 9, 2, {
      workStart: new Date(2026, 9, 2, 8, 0),
      workEnd: new Date(2026, 9, 2, 16, 0),
      breaks: [{ id: 'b1', name: 'Pause 1', start: new Date(2026, 9, 2, 12, 0), end: new Date(2026, 9, 2, 12, 30), isAutomatic: false }],
    });
  }

  it('startOrStopTimer auf leerem Vortagseintrag (ohne Timer/Effect-Ablauf) schreibt nur auf heute', async () => {
    vi.setSystemTime(new Date(2026, 9, 2, 12, 0));
    const h = setup();
    await vi.advanceTimersByTimeAsync(0);
    vi.setSystemTime(new Date(2026, 9, 3, 0, 30)); // Mitternacht verpasst (Standby)
    await h.svc.startOrStopTimer();
    expect(savedKeys(h)).toEqual([SAT]);
    const saved = h.saveEntry.mock.calls[0][0] as WorkEntry;
    expect(saved.id).toBe(SAT);
    expect(toDateKey(saved.workStart!)).toBe(SAT);
    expect(h.store.has(FRI)).toBe(false);
    expect(h.svc.isTimerRunning()).toBe(true);
  });

  const actions: Array<[string, (s: DashboardService) => Promise<unknown>]> = [
    ['startOrStopTimer', s => s.startOrStopTimer()],
    ['startNewSession(false)', s => s.startNewSession(false)],
    ['startNewSession(true)', s => s.startNewSession(true)],
    ['startOrStopBreak', s => s.startOrStopBreak()],
    ['setManualStartTime', s => s.setManualStartTime('09:00')],
    ['setManualEndTime', s => s.setManualEndTime('17:00')],
    ['clearEndTime', s => s.clearEndTime()],
    ['updateBreak', s => s.updateBreak({ id: 'b1', name: 'x', start: new Date(2026, 9, 2, 12, 0), end: new Date(2026, 9, 2, 12, 45), isAutomatic: false })],
    ['deleteBreak', s => s.deleteBreak('b1')],
  ];

  it.each(actions)('%s auf abgeschlossenem Vortag verändert den Vortag nicht', async (_name, run) => {
    vi.setSystemTime(new Date(2026, 9, 2, 18, 0));
    const fri = friStopped();
    const h = setup({ entries: [fri] });
    await vi.advanceTimersByTimeAsync(0);
    expect(h.svc.workEntry().id).toBe(FRI);
    vi.setSystemTime(new Date(2026, 9, 3, 0, 30));
    await run(h.svc);
    expect(h.saveEntry.mock.calls.length).toBeGreaterThan(0);
    expect(new Set(savedKeys(h))).toEqual(new Set([SAT]));
    expect(h.store.get(FRI)).toBe(fri);
    expect(fri.workStart).toEqual(new Date(2026, 9, 2, 8, 0));
    expect(fri.workEnd).toEqual(new Date(2026, 9, 2, 16, 0));
  });

  it('Doppelklick „Start" nach Mitternacht (leerer Vortag): überholter Guard schreibt nie in den Vortag', async () => {
    vi.setSystemTime(new Date(2026, 9, 2, 18, 0));
    const h = setup();
    await vi.advanceTimersByTimeAsync(0);
    expect(h.svc.workEntry().id).toBe(FRI);
    vi.setSystemTime(new Date(2026, 9, 3, 0, 30));
    const a = h.svc.startOrStopTimer();
    const b = h.svc.startOrStopTimer(); // zweiter Guard überholt den ersten _init
    await vi.advanceTimersByTimeAsync(0);
    await Promise.all([a, b]);
    expect(savedKeys(h).length).toBeGreaterThan(0);
    expect(new Set(savedKeys(h))).toEqual(new Set([SAT]));
    expect(h.store.has(FRI)).toBe(false);
  });

  it('Doppelklick „Neue Session" nach Mitternacht (abgeschlossener Vortag): Vortag bleibt unverändert', async () => {
    vi.setSystemTime(new Date(2026, 9, 2, 18, 0));
    const fri = friStopped();
    const h = setup({ entries: [fri] });
    await vi.advanceTimersByTimeAsync(0);
    vi.setSystemTime(new Date(2026, 9, 3, 0, 30));
    const a = h.svc.startNewSession(false);
    const b = h.svc.startNewSession(false);
    await vi.advanceTimersByTimeAsync(0);
    await Promise.all([a, b]);
    expect(new Set(savedKeys(h))).toEqual(new Set([SAT]));
    expect(h.store.get(FRI)).toBe(fri);
    expect(fri.workEnd).toEqual(new Date(2026, 9, 2, 16, 0));
  });

  it('Login-Reinit überholt den Guard-Lauf: vorhandener heutiger Eintrag wird nie mit leerem überschrieben', async () => {
    vi.setSystemTime(new Date(2026, 9, 2, 18, 0));
    const fri = friStopped();
    const sat = mkEntry(2026, 9, 3, { workStart: new Date(2026, 9, 3, 8, 0), workEnd: new Date(2026, 9, 3, 10, 0) });
    const h = setup({ entries: [fri, sat] });
    await vi.advanceTimersByTimeAsync(0);
    expect(h.svc.workEntry().id).toBe(FRI);
    vi.setSystemTime(new Date(2026, 9, 3, 0, 30));
    const a = h.svc.startOrStopTimer();
    h.user.set({ uid: 'u2' }); // Auth-Effekt startet einen neuen _init (setzt Ladezustand), der den Guard-Lauf überholt
    TestBed.tick();
    await vi.advanceTimersByTimeAsync(0);
    expect(await a).toBe('restart-dialog'); // heutiger Eintrag ist abgeschlossen -> Dialog, keine Überschreibung
    expect(h.saveEntry).not.toHaveBeenCalled();
    expect(h.store.get(SAT)).toBe(sat);
    expect(h.store.get(FRI)).toBe(fri);
  });

  it('Guard-Reinit schlägt fehl: Aktion bricht ab statt den Vortag zu beschreiben', async () => {
    vi.setSystemTime(new Date(2026, 9, 2, 18, 0));
    const fri = friStopped();
    const h = setup({ entries: [fri] });
    await vi.advanceTimersByTimeAsync(0);
    vi.setSystemTime(new Date(2026, 9, 3, 0, 30));
    h.getOvertime.mockRejectedValue(new Error('offline'));
    await h.svc.startNewSession(false);
    expect(h.saveEntry).not.toHaveBeenCalled();
    expect(h.store.get(FRI)).toBe(fri);
  });

  it('Reinit beim Tageswechsel mit bereits abgeschlossenem heutigen Eintrag zählt den Daily nicht doppelt', async () => {
    vi.setSystemTime(new Date(2026, 9, 2, 23, 59, 30));
    // Samstag (Soll 0) auf anderem Gerät abgeschlossen: 2 h netto, gespeicherter Wert enthält sie bereits
    const sat = mkEntry(2026, 9, 3, { workStart: new Date(2026, 9, 3, 8, 0), workEnd: new Date(2026, 9, 3, 10, 0) });
    const h = setup({ entries: [sat], storedOvertimeMs: 5 * H, lastUpdate: new Date(2026, 9, 3, 10, 0) });
    await vi.advanceTimersByTimeAsync(31_000);
    expect(h.svc.workEntry().id).toBe(SAT);
    expect(h.svc.totalOvertime()).toBe(5 * H);
  });

  it('Stop eines über Mitternacht gelaufenen Timers speichert am Starttag, dann Reinit auf heute (O1)', async () => {
    vi.setSystemTime(new Date(2026, 9, 2, 20, 30));
    const start = new Date(2026, 9, 2, 12, 0);
    const h = setup({ entries: [mkEntry(2026, 9, 2, { workStart: start })] });
    await startRunning(h, new Date(2026, 9, 3, 1, 0)); // Brutto 13 h
    expect(h.svc.workEntry().id).toBe(FRI);
    await h.svc.startOrStopTimer();
    expect(savedKeys(h)).toEqual([FRI]);
    const saved = h.saveEntry.mock.calls[0][0] as WorkEntry;
    expect(saved.workEnd).toBeDefined();
    expect(saved.id).toBe(FRI);
    // Brutto > 9 h: Pflichtpause wird ohne Fehler angesetzt
    expect(saved.breaks.length).toBeGreaterThan(0);
    expect(h.svc.workEntry().id).toBe(SAT);
    expect(h.svc.workEntry().workStart).toBeUndefined();
    expect(h.svc.isTimerRunning()).toBe(false);
    expect(h.store.get(SAT)).toBeUndefined();
  });

  it('Pause starten/stoppen im laufenden Vortagseintrag bleibt am Vortag', async () => {
    vi.setSystemTime(new Date(2026, 9, 2, 20, 30));
    const h = setup({ entries: [mkEntry(2026, 9, 2, { workStart: new Date(2026, 9, 2, 20, 0) })] });
    await startRunning(h, new Date(2026, 9, 3, 1, 0));
    await h.svc.startOrStopBreak();
    expect(h.svc.isBreakRunning()).toBe(true);
    expect(h.svc.workEntry().id).toBe(FRI);
    await h.svc.startOrStopBreak();
    expect(h.svc.isBreakRunning()).toBe(false);
    expect(h.svc.workEntry().id).toBe(FRI);
    expect(new Set(savedKeys(h))).toEqual(new Set([FRI]));
  });

  it('Autosave nach Reinit speichert nur den neuen Eintrag', async () => {
    vi.setSystemTime(new Date(2026, 9, 2, 20, 30));
    const h = setup({ entries: [mkEntry(2026, 9, 2, { workStart: new Date(2026, 9, 2, 20, 0) })] });
    await startRunning(h, new Date(2026, 9, 3, 1, 0));
    await h.svc.startOrStopTimer();           // Stop + Reinit auf Samstag
    await h.svc.startOrStopTimer();           // Start am Samstag
    h.saveEntry.mockClear();
    await vi.advanceTimersByTimeAsync(31_000);
    expect(h.saveEntry.mock.calls.length).toBeGreaterThan(0);
    expect(new Set(savedKeys(h))).toEqual(new Set([SAT]));
  });
});

fakeClockSuite('DashboardService Reinit (#372)', () => {
  it('Reinit (Benutzerwechsel) stoppt den laufenden Tick-Timer des alten Eintrags', async () => {
    vi.setSystemTime(new Date(2026, 9, 5, 12, 0));
    const h = setup({ entries: [mkEntry(2026, 9, 5, { workStart: new Date(2026, 9, 5, 8, 0) })] });
    await vi.advanceTimersByTimeAsync(1000);
    expect(h.svc.isTimerRunning()).toBe(true);
    expect(vi.getTimerCount()).toBe(2); // Tick-Intervall + Mitternachts-Timer
    h.store.clear(); // neuer Benutzer hat heute keinen Eintrag
    h.user.set({ uid: 'u2' });
    TestBed.tick();
    await vi.advanceTimersByTimeAsync(0);
    expect(h.svc.isTimerRunning()).toBe(false);
    expect(vi.getTimerCount()).toBe(1); // nur noch der Mitternachts-Timer
  });
});

fakeClockSuite('DashboardService Cleanup (#372)', () => {
  it('nach Destroy: keine Timer, keine Reaktion auf Events/Tageswechsel', async () => {
    vi.setSystemTime(new Date(2026, 9, 5, 12, 0));
    const docAdd = vi.spyOn(document, 'addEventListener');
    const docRemove = vi.spyOn(document, 'removeEventListener');
    const h = setup({ entries: [mkEntry(2026, 9, 5, { workStart: new Date(2026, 9, 5, 8, 0) })] });
    await vi.advanceTimersByTimeAsync(1000);
    expect(h.svc.isTimerRunning()).toBe(true);
    expect(vi.getTimerCount()).toBeGreaterThan(1); // Tick-Intervall + Mitternachts-Timer
    const reads = h.getOvertime.mock.calls.length;
    h.saveEntry.mockClear();

    TestBed.resetTestingModule();
    const added = docAdd.mock.calls.filter(c => c[0] === 'visibilitychange').map(c => c[1]);
    const removed = docRemove.mock.calls.filter(c => c[0] === 'visibilitychange').map(c => c[1]);
    for (const fn of added) expect(removed).toContain(fn);
    expect(vi.getTimerCount()).toBe(0);

    vi.setSystemTime(new Date(2026, 9, 7, 9, 0));
    document.dispatchEvent(new Event('visibilitychange'));
    window.dispatchEvent(new Event('focus'));
    window.dispatchEvent(new Event('pageshow'));
    await vi.advanceTimersByTimeAsync(3 * 24 * H);
    expect(h.getOvertime.mock.calls.length).toBe(reads);
    expect(h.saveEntry).not.toHaveBeenCalled();
  });
});

fakeClockSuite('DashboardService Neuberechnung gestoppter Eintrag (#390)', () => {
  const MONDAY = (h: number, min = 0): Date => new Date(2026, 9, 5, h, min);

  it('A: gestoppter Eintrag behält Daily/Total nach Settings-Emission, egal wie spät es ist', async () => {
    vi.setSystemTime(MONDAY(12));
    const h = setup({ entries: [mkEntry(2026, 9, 5, { workStart: MONDAY(8), workEnd: MONDAY(11) })] });
    h.settings$.next({ ...DEFAULT_SETTINGS, bundesland: null, weeklyTargetHours: 30 }); // 6 h Soll
    await vi.advanceTimersByTimeAsync(0);
    expect(h.svc.isTimerRunning()).toBe(false);
    expect(h.svc.dailyOvertime()).toBe(-3 * H);

    h.settings$.next({ ...DEFAULT_SETTINGS, bundesland: null, weeklyTargetHours: 30 });
    await vi.advanceTimersByTimeAsync(0);
    expect(h.svc.dailyOvertime()).toBe(-3 * H);
    expect(h.svc.totalOvertime()).toBe(-3 * H);

    vi.setSystemTime(MONDAY(15));
    h.settings$.next({ ...DEFAULT_SETTINGS, bundesland: null, weeklyTargetHours: 30 });
    await vi.advanceTimersByTimeAsync(0);
    expect(h.svc.dailyOvertime()).toBe(-3 * H);
    expect(h.svc.totalOvertime()).toBe(-3 * H);
  });

  it('B: laufender Eintrag rechnet weiter mit der Uhr (Gegenprobe)', async () => {
    vi.setSystemTime(MONDAY(12));
    const h = setup({ entries: [mkEntry(2026, 9, 5, { workStart: MONDAY(8) })] });
    h.settings$.next({ ...DEFAULT_SETTINGS, bundesland: null, weeklyTargetHours: 30 });
    await vi.advanceTimersByTimeAsync(0);
    expect(h.svc.isTimerRunning()).toBe(true);
    h.settings$.next({ ...DEFAULT_SETTINGS, bundesland: null, weeklyTargetHours: 30 });
    await vi.advanceTimersByTimeAsync(0);
    expect(h.svc.dailyOvertime()).toBe(4 * H - 6 * H);

    vi.setSystemTime(MONDAY(13));
    h.settings$.next({ ...DEFAULT_SETTINGS, bundesland: null, weeklyTargetHours: 30 });
    await vi.advanceTimersByTimeAsync(0);
    expect(h.svc.dailyOvertime()).toBe(5 * H - 6 * H);
  });

  it('D: nach Stop um 11:00 bleibt der Wert bei späterer Settings-Emission', async () => {
    vi.setSystemTime(MONDAY(11));
    const h = setup({ entries: [mkEntry(2026, 9, 5, { workStart: MONDAY(8) })] });
    h.settings$.next({ ...DEFAULT_SETTINGS, bundesland: null, weeklyTargetHours: 30 });
    await vi.advanceTimersByTimeAsync(1000);
    expect(h.svc.isTimerRunning()).toBe(true);
    await h.svc.startOrStopTimer();
    expect(h.svc.isTimerRunning()).toBe(false);
    const stopped = h.svc.dailyOvertime();
    expect(stopped).toBe(-3 * H);

    vi.setSystemTime(MONDAY(12));
    h.settings$.next({ ...DEFAULT_SETTINGS, bundesland: null, weeklyTargetHours: 30 });
    await vi.advanceTimersByTimeAsync(0);
    expect(h.svc.dailyOvertime()).toBe(stopped);
  });

  it('C: offene Pause zählt bis workEnd (nicht bis „jetzt“), Netto und erwartetes Ende bleiben stabil', async () => {
    vi.setSystemTime(MONDAY(12));
    const h = setup({
      entries: [mkEntry(2026, 9, 5, {
        workStart: MONDAY(8), workEnd: MONDAY(11),
        breaks: [{ id: 'b1', name: 'Pause', start: MONDAY(10), isAutomatic: false }],
      })],
    });
    h.settings$.next({ ...DEFAULT_SETTINGS, bundesland: null, weeklyTargetHours: 30 });
    await vi.advanceTimersByTimeAsync(0);
    h.settings$.next({ ...DEFAULT_SETTINGS, bundesland: null, weeklyTargetHours: 30 });
    await vi.advanceTimersByTimeAsync(0);
    expect(h.svc.isTimerRunning()).toBe(false);
    // 3 h brutto − 1 h Pause (10:00-11:00) − 6 h Soll
    expect(h.svc.dailyOvertime()).toBe(-4 * H);
    // 08:00 + 6 h Soll + 1 h Pause
    expect(h.svc.expectedEndTime()?.getTime()).toBe(MONDAY(15).getTime());
  });
});
