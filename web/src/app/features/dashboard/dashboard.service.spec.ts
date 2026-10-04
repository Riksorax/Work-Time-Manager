import { TestBed } from '@angular/core/testing';
import { signal } from '@angular/core';
import { BehaviorSubject, of } from 'rxjs';
import { DashboardService } from './dashboard.service';
import { WorkEntryService } from '../../core/services/work-entry';
import { OvertimeService } from '../../core/services/overtime';
import { SettingsService } from '../../core/services/settings';
import { AuthService } from '../../core/auth/auth';
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
      ],
    });
    return TestBed.inject(DashboardService);
  }

  beforeEach(() => {
    entry = null;
    vi.useFakeTimers();
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
