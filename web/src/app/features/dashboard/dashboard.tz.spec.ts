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
import { entryDto, mapWorkEntryDtos } from '../../shared/testing/mapped-entries';
import { DEFAULT_SETTINGS, UserSettings, WorkEntry, WorkEntryType } from '../../shared/models/index';

/**
 * Zonen-Regressionstests (#407), Komposition Mapper -> DashboardService: das Backend-DTO eines heutigen Eintrags läuft
 * durch den echten `ApiClient`-Mapper und danach in den Service. Heute = Montag 05.10.2026, 12:00 lokal. Westlich von
 * UTC lag `date` vorher auf dem Sonntag: der Eintrag galt nicht als „heute" (Start/Stop/Zeiten blockiert) und
 * rechnete mit dem Sonntags-Soll 0.
 */
describe('DashboardService mit gemapptem Eintrag (#407)', () => {
  const H = 3_600_000;
  let getTodayEntry: ReturnType<typeof vi.fn>;
  let saveEntry: ReturnType<typeof vi.fn>;

  async function stoppedToday(): Promise<WorkEntry> {
    const [e] = await mapWorkEntryDtos([entryDto('2026-10-05', '2026-10-05T00:00:00Z', {
      workStart: new Date(2026, 9, 5, 8, 0).toISOString(),
      workEnd: new Date(2026, 9, 5, 16, 0).toISOString(),
    })]);
    return e;
  }

  async function runningToday(): Promise<WorkEntry> {
    const [e] = await mapWorkEntryDtos([entryDto('2026-10-05', '2026-10-05T00:00:00Z', {
      workStart: new Date(2026, 9, 5, 8, 0).toISOString(),
    })]);
    return e;
  }

  function create(entry: WorkEntry): DashboardService {
    getTodayEntry = vi.fn(() => of(entry));
    saveEntry = vi.fn().mockResolvedValue(undefined);
    TestBed.resetTestingModule();
    TestBed.configureTestingModule({
      providers: [
        { provide: WorkEntryService, useValue: {
          getTodayEntry,
          emptyEntry: (d: Date) => ({ id: 'x', date: d, breaks: [], isManuallyEntered: false, type: WorkEntryType.Work }),
          saveEntry,
        } },
        { provide: OvertimeService, useValue: {
          getOvertime: vi.fn().mockResolvedValue(0),
          getLastUpdateDate: vi.fn().mockResolvedValue(null),
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

  beforeEach(() => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date(2026, 9, 5, 12, 0)); // Montag
  });
  afterEach(() => {
    TestBed.resetTestingModule();
    vi.useRealTimers();
    vi.restoreAllMocks();
  });

  it('D1: manuelle Endzeit auf einem gestoppten heutigen Eintrag wird nicht blockiert', async () => {
    const svc = create(await stoppedToday());
    await vi.advanceTimersByTimeAsync(0);
    expect(svc.isLoading()).toBe(false);

    await svc.setManualEndTime('17:00');

    expect(saveEntry).toHaveBeenCalledTimes(1);
    const saved = saveEntry.mock.calls[0][0] as WorkEntry;
    expect(saved.workEnd!.getTime()).toBe(new Date(2026, 9, 5, 17, 0).getTime());
    expect(getTodayEntry).toHaveBeenCalledTimes(1); // kein Reinit durch _ensureCurrentDay
  });

  it('D2: Soll ist das des Montags (kein Sonntags-Soll 0): 8 h netto bei 8 h Soll = 0', async () => {
    const svc = create(await stoppedToday());
    await vi.advanceTimersByTimeAsync(0);
    expect(svc.isLoading()).toBe(false);
    expect(svc.dailyOvertime()).toBe(0);
    expect(svc.dailyOvertime()).not.toBe(8 * H);
  });

  it('D3: Stop eines laufenden heutigen Eintrags löst keinen Reinit aus', async () => {
    vi.setSystemTime(new Date(2026, 9, 5, 17, 0));
    const svc = create(await runningToday());
    await vi.advanceTimersByTimeAsync(0);
    expect(svc.isTimerRunning()).toBe(true);

    await svc.startOrStopTimer();

    expect(saveEntry).toHaveBeenCalled();
    expect(svc.isTimerRunning()).toBe(false);
    expect(getTodayEntry).toHaveBeenCalledTimes(1);
  });
});
