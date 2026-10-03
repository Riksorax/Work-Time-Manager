import { TestBed } from '@angular/core/testing';
import { BehaviorSubject, Subject, of, throwError } from 'rxjs';
import { LEAVE_NOW, LeaveBalanceService } from './leave-balance';
import { AuthService } from '../auth/auth';
import { ApiClient } from './api-client';
import { SettingsService } from './settings';
import { WorkEntryService } from './work-entry';
import { WorkProfileService } from './work-profile';
import { YearlyLeaveReport } from '../../domain/models/leave.models';
import { DEFAULT_SETTINGS, WorkEntryType } from '../../shared/models/index';

function report(year: number, taken = 3): YearlyLeaveReport {
  return { year, vacationDaysPerYear: 30, vacationDaysTaken: taken, vacationDaysRemaining: 30 - taken, sickDays: 1 };
}

describe('LeaveBalanceService', () => {
  let user$: BehaviorSubject<{ uid: string } | null>;
  let profile$: BehaviorSubject<string>;
  let getYearlyLeave: ReturnType<typeof vi.fn>;
  let getAllLocalEntries: ReturnType<typeof vi.fn>;
  let nowDate: Date;

  function create(): LeaveBalanceService {
    TestBed.configureTestingModule({
      providers: [
        { provide: AuthService, useValue: { user$ } },
        {
          provide: WorkProfileService,
          useValue: {
            activeProfileId$: profile$,
            get activeProfileIdForApi() { return profile$.value === 'default' ? undefined : profile$.value; },
          },
        },
        { provide: ApiClient, useValue: { getYearlyLeave } },
        { provide: WorkEntryService, useValue: { getAllLocalEntries } },
        { provide: SettingsService, useValue: { getSettings: () => of({ ...DEFAULT_SETTINGS, vacationDaysPerYear: 20 }) } },
        { provide: LEAVE_NOW, useValue: () => nowDate },
      ],
    });
    const svc = TestBed.inject(LeaveBalanceService);
    TestBed.tick();
    return svc;
  }

  beforeEach(() => {
    user$ = new BehaviorSubject<{ uid: string } | null>({ uid: 'u1' });
    profile$ = new BehaviorSubject('default');
    getYearlyLeave = vi.fn((year: number) => of(report(year)));
    getAllLocalEntries = vi.fn(() => []);
    nowDate = new Date(2026, 5, 15);
  });

  it('lädt eingeloggt vom Backend für das Standard-Profil', () => {
    const svc = create();
    expect(getYearlyLeave).toHaveBeenCalledWith(2026, undefined);
    expect(svc.currentYearState()).toBe('data');
    expect(svc.currentYearReport()).toEqual(report(2026));
  });

  it('zeigt loading, solange die Antwort aussteht', () => {
    const pending = new Subject<YearlyLeaveReport>();
    getYearlyLeave.mockReturnValue(pending);
    const svc = create();
    expect(svc.currentYearState()).toBe('loading');
    pending.next(report(2026));
    expect(svc.currentYearState()).toBe('data');
  });

  it('lädt nach Profilwechsel mit profileId neu', () => {
    create();
    profile$.next('p1');
    TestBed.tick();
    expect(getYearlyLeave).toHaveBeenLastCalledWith(2026, 'p1');
  });

  it('rechnet anonym lokal ohne API-Aufruf', () => {
    user$.next(null);
    getAllLocalEntries.mockReturnValue([
      { id: 'a', date: new Date(2026, 1, 2), breaks: [], isManuallyEntered: true, type: WorkEntryType.Vacation },
    ]);
    const svc = create();
    expect(getYearlyLeave).not.toHaveBeenCalled();
    expect(svc.currentYearReport()).toEqual({
      year: 2026, vacationDaysPerYear: 20, vacationDaysTaken: 1, vacationDaysRemaining: 19, sickDays: 0,
    });
  });

  it('meldet Fehler und erholt sich per refresh()', () => {
    getYearlyLeave.mockReturnValueOnce(throwError(() => new Error('boom')));
    const svc = create();
    expect(svc.currentYearState()).toBe('error');
    expect(svc.currentYearReport()).toBeNull();

    const pending = new Subject<YearlyLeaveReport>();
    getYearlyLeave.mockReturnValueOnce(pending);
    svc.refresh();
    expect(svc.currentYearState()).toBe('loading');
    pending.next(report(2026));
    expect(svc.currentYearState()).toBe('data');
  });

  it('behält bei refresh() vorhandene Daten und verwirft ältere Antworten', () => {
    const svc = create();
    const first = new Subject<YearlyLeaveReport>();
    const second = new Subject<YearlyLeaveReport>();
    getYearlyLeave.mockReturnValueOnce(first).mockReturnValueOnce(second);
    svc.refresh();
    expect(svc.currentYearState()).toBe('data');
    svc.refresh();
    second.next(report(2026, 7));
    first.next(report(2026, 1));
    expect(svc.currentYearReport()?.vacationDaysTaken).toBe(7);
  });

  it('lädt bei Login/Logout-Wechsel neu', () => {
    const svc = create();
    user$.next(null);
    TestBed.tick();
    expect(getYearlyLeave).toHaveBeenCalledTimes(1);
    expect(svc.currentYearReport()?.vacationDaysPerYear).toBe(20);
    user$.next({ uid: 'u1' });
    TestBed.tick();
    expect(getYearlyLeave).toHaveBeenCalledTimes(2);
  });

  it('navigiert zwischen Jahren', () => {
    const svc = create();
    expect(svc.year()).toBe(2026);
    expect(svc.canGoNextYear()).toBe(false);
    svc.navigateYear(-1);
    TestBed.tick();
    expect(svc.year()).toBe(2025);
    expect(svc.isCurrentYear()).toBe(false);
    expect(svc.canGoNextYear()).toBe(true);
    expect(getYearlyLeave).toHaveBeenLastCalledWith(2025, undefined);
    expect(svc.report()?.year).toBe(2025);

    svc.navigateYear(1);
    TestBed.tick();
    expect(svc.year()).toBe(2026);
    expect(getYearlyLeave).toHaveBeenCalledTimes(2);
    svc.navigateYear(1);
    expect(svc.year()).toBe(2026);
  });

  it('begrenzt die Navigation nach unten auf 2000', () => {
    const svc = create();
    svc.navigateYear(-100);
    expect(svc.year()).toBe(2000);
    expect(svc.canGoPrevYear()).toBe(false);
  });

  it('übernimmt beim Jahreswechsel das neue aktuelle Jahr', () => {
    nowDate = new Date(2026, 11, 31);
    const svc = create();
    nowDate = new Date(2027, 0, 1);
    svc.refresh();
    TestBed.tick();
    expect(svc.year()).toBe(2027);
    expect(getYearlyLeave).toHaveBeenLastCalledWith(2027, undefined);
    expect(svc.currentYearReport()?.year).toBe(2027);
  });
});
