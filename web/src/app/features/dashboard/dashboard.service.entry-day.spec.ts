import { TestBed } from '@angular/core/testing';
import { signal } from '@angular/core';
import { BehaviorSubject, of } from 'rxjs';
import { DashboardService } from './dashboard.service';
import { WorkEntryService } from '../../core/services/work-entry';
import { OvertimeService } from '../../core/services/overtime';
import { SettingsService } from '../../core/services/settings';
import { AuthService } from '../../core/auth/auth';
import { WorkProfileService } from '../../core/services/work-profile';
import { createFakeWorkProfile } from '../../shared/testing/work-profile-fake';
import { DEFAULT_SETTINGS, UserSettings, WorkEntry, WorkEntryType } from '../../shared/models/index';

/**
 * Zonenunabhängig (#407, Block B): der `DashboardService` bildet den Kalendertag des Eintrags über `entryDay`/`entryDayKey`.
 * Fixture: `id` Montag 05.10.2026 (Soll 8 h), `date` Sonntag 04.10. (Soll 0), wie nach einer Lesegrenze, die den Vortag
 * geliefert hat. Uhr: Montag 05.10.2026, 12:00 lokal. Schreibpfade bleiben auf `date` (nicht Teil dieser Tests).
 */
describe('DashboardService: Tag des Eintrags aus der id (#407)', () => {
  const H = 3_600_000;
  let getTodayEntry: ReturnType<typeof vi.fn>;
  let saveEntry: ReturnType<typeof vi.fn>;

  function entry(id: string, date: Date, extra: Partial<WorkEntry> = {}): WorkEntry {
    return { id, date, breaks: [], isManuallyEntered: false, type: WorkEntryType.Work, ...extra };
  }

  /** Montag laut id, Sonntag laut date. */
  const monday = (extra: Partial<WorkEntry> = {}) => entry('2026-10-05', new Date(2026, 9, 4), extra);
  const stopped = () => monday({ workStart: new Date(2026, 9, 5, 8, 0), workEnd: new Date(2026, 9, 5, 16, 0) });
  const running = () => monday({ workStart: new Date(2026, 9, 5, 8, 0) });

  function create(loaded: WorkEntry, opts: { storedMs?: number; lastUpdate?: Date | null } = {}): DashboardService {
    getTodayEntry = vi.fn(() => of(loaded));
    saveEntry = vi.fn().mockResolvedValue(undefined);
    TestBed.resetTestingModule();
    TestBed.configureTestingModule({
      providers: [
        { provide: WorkEntryService, useValue: {
          getTodayEntry,
          emptyEntry: (d: Date) => entry('x', d),
          saveEntry,
        } },
        { provide: OvertimeService, useValue: {
          getOvertime: vi.fn().mockResolvedValue(opts.storedMs ?? 0),
          getLastUpdateDate: vi.fn().mockResolvedValue(opts.lastUpdate ?? null),
          saveOvertime: vi.fn().mockResolvedValue(undefined),
          saveLastUpdateDate: vi.fn().mockResolvedValue(undefined),
        } },
        { provide: SettingsService, useValue: {
          getSettings: () => new BehaviorSubject<UserSettings>({ ...DEFAULT_SETTINGS, bundesland: null }).asObservable(),
          saveSettings: vi.fn(),
        } },
        { provide: AuthService, useValue: { user: signal({ uid: 'u1' }), get uid() { return 'u1'; } } },
        { provide: WorkProfileService, useValue: createFakeWorkProfile() },
      ],
    });
    return TestBed.inject(DashboardService);
  }

  /** `isExtraDay` hat kein öffentliches Signal; der interne Zustand wird direkt gelesen. */
  const isExtraDay = (svc: DashboardService): boolean =>
    (svc as unknown as { _s: () => { isExtraDay: boolean } })['_s']().isExtraDay;

  beforeEach(() => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date(2026, 9, 5, 12, 0)); // Montag
  });
  afterEach(() => {
    TestBed.resetTestingModule();
    vi.useRealTimers();
    vi.restoreAllMocks();
  });

  it('B5-1 _isCurrentDay: gestoppter Eintrag von heute (id) wird nicht blockiert', async () => {
    const svc = create(stopped());
    await vi.advanceTimersByTimeAsync(0);

    await svc.setManualEndTime('16:30');

    expect(saveEntry).toHaveBeenCalledTimes(1);
    expect(getTodayEntry).toHaveBeenCalledTimes(1); // kein Reinit durch _ensureCurrentDay
  });

  it('B5-2 _onDayChange: Eintrag mit id = neuer Tag löst um Mitternacht keinen Reinit aus', async () => {
    vi.setSystemTime(new Date(2026, 9, 5, 23, 59, 30));
    create(entry('2026-10-06', new Date(2026, 9, 5), {
      workStart: new Date(2026, 9, 5, 8, 0), workEnd: new Date(2026, 9, 5, 16, 0),
    }));
    await vi.advanceTimersByTimeAsync(0);
    expect(getTodayEntry).toHaveBeenCalledTimes(1);

    await vi.advanceTimersByTimeAsync(31_000); // Mitternacht -> 06.10.

    expect(new Date().getDate()).toBe(6);
    expect(getTodayEntry).toHaveBeenCalledTimes(1);
  });

  describe('B5-3 Soll des Eintragstags (Montag 8 h, nicht Sonntag 0)', () => {
    it('beim Laden eines laufenden Eintrags (Schritt 4 von _initInner): isExtraDay und Saldo-Basis', async () => {
      // Gespeichert heute um 11:00: die Basis ist Saldo minus das beim Laden berechnete Daily (4 h netto - 8 h Soll).
      const svc = create(running(), { storedMs: 60 * 60_000, lastUpdate: new Date(2026, 9, 5, 11, 0) });
      await vi.advanceTimersByTimeAsync(0);
      expect(isExtraDay(svc)).toBe(false);
      await vi.advanceTimersByTimeAsync(1000); // erster Tick: Daily = 4 h + 1 s - 8 h
      expect(svc.totalOvertime()).toBe(60 * 60_000 + 1000);
    });

    it('beim Laden eines gestoppten Eintrags (_recalculateState)', async () => {
      const svc = create(stopped());
      await vi.advanceTimersByTimeAsync(0);
      expect(svc.dailyOvertime()).toBe(0); // 8 h netto bei 8 h Soll
    });

    it('isExtraDay im gestoppten Zustand (_recalculateState)', async () => {
      const svc = create(stopped());
      await vi.advanceTimersByTimeAsync(0);
      expect(isExtraDay(svc)).toBe(false);
    });

    it('nach setManualEndTime (_recalculateState)', async () => {
      const svc = create(stopped());
      await vi.advanceTimersByTimeAsync(0);
      await svc.setManualEndTime('16:30'); // 8,5 h brutto, 30 min Pflichtpause -> 8 h netto
      expect(svc.dailyOvertime()).toBe(0);
      expect(isExtraDay(svc)).toBe(false);
    });

    it('im laufenden Tick (_recalculateOvertime)', async () => {
      const svc = create(running());
      await vi.advanceTimersByTimeAsync(1000);
      expect(svc.dailyOvertime()).toBe(Date.now() - new Date(2026, 9, 5, 8, 0).getTime() - 8 * H);
      expect(isExtraDay(svc)).toBe(false);
    });
  });

  describe('B5-4 Reinit nach Mitternacht beim Stop', () => {
    it('laufender Eintrag von heute (id), Stop um 17:00: kein Reinit', async () => {
      vi.setSystemTime(new Date(2026, 9, 5, 17, 0));
      const svc = create(running());
      await vi.advanceTimersByTimeAsync(0);
      expect(svc.isTimerRunning()).toBe(true);

      await svc.startOrStopTimer();

      expect(saveEntry).toHaveBeenCalled();
      expect(svc.isTimerRunning()).toBe(false);
      expect(getTodayEntry).toHaveBeenCalledTimes(1);
    });

    it('Gegenprobe: laufender Eintrag von gestern (id), Stop nach Mitternacht: Reinit auf den neuen Tag', async () => {
      vi.setSystemTime(new Date(2026, 9, 5, 1, 0));
      const svc = create(entry('2026-10-04', new Date(2026, 9, 4), { workStart: new Date(2026, 9, 4, 20, 0) }));
      await vi.advanceTimersByTimeAsync(0);
      expect(svc.isTimerRunning()).toBe(true);

      await svc.startOrStopTimer();

      expect(getTodayEntry).toHaveBeenCalledTimes(2);
    });
  });

  describe('B5-5 manuelle Zeiten landen am Tag der id', () => {
    it('setManualStartTime: 08:30 am 05.10. (nicht am 04.10.)', async () => {
      const svc = create(monday());
      await vi.advanceTimersByTimeAsync(0);

      await svc.setManualStartTime('08:30');

      const saved = saveEntry.mock.calls[0][0] as WorkEntry;
      expect(saved.workStart!.getTime()).toBe(new Date(2026, 9, 5, 8, 30).getTime());
    });

    it('setManualEndTime: 16:30 am 05.10. (nicht am 04.10.)', async () => {
      const svc = create(stopped());
      await vi.advanceTimersByTimeAsync(0);

      await svc.setManualEndTime('16:30');

      const saved = saveEntry.mock.calls[0][0] as WorkEntry;
      expect(saved.workEnd!.getTime()).toBe(new Date(2026, 9, 5, 16, 30).getTime());
    });
  });
});
