import { TestBed } from '@angular/core/testing';
import { signal } from '@angular/core';
import { Observable, Subject, of, throwError } from 'rxjs';
import { ApiClient } from '../../../../core/services/api-client';
import { LEAVE_NOW } from '../../../../core/services/leave-balance';
import { WorkProfileService } from '../../../../core/services/work-profile';
import { YearlyLeaveReport } from '../../../../domain/models/leave.models';
import { DEFAULT_WORK_PROFILE_ID, WorkProfile } from '../../../../shared/models';
import { FakeWorkProfile, createFakeWorkProfile } from '../../../../shared/testing/work-profile-fake';
import { LEAVE_PRINT_CLASS, LeaveReportPrintService } from './leave-report-print.service';

/** Ablauf der Urlaubs-/Krankheitsauswertung (#284): frisch laden, rendern, erst dann drucken; Fehler ohne Druck. */
describe('LeaveReportPrintService', () => {
  let svc: LeaveReportPrintService;
  let getYearlyLeave: ReturnType<typeof vi.fn>;
  let print: ReturnType<typeof vi.spyOn>;
  let profile: FakeWorkProfile & { profiles: ReturnType<typeof signal<WorkProfile[]>> };

  const report = (year: number): YearlyLeaveReport => ({
    year, vacationDaysPerYear: 30, vacationDaysTaken: 12, vacationDaysRemaining: 18, sickDays: 3,
    months: [], vacationPeriods: [], sickPeriods: [],
  });

  function setup(response: (year: number) => Observable<YearlyLeaveReport>, activeProfile = DEFAULT_WORK_PROFILE_ID): void {
    getYearlyLeave = vi.fn((year: number) => response(year));
    print = vi.spyOn(window, 'print').mockImplementation(() => undefined);
    // Nicht per Spread/`Object.assign` (würde den Getter `activeProfileIdForApi` einfrieren): den Fake selbst erweitern.
    profile = createFakeWorkProfile(activeProfile) as typeof profile;
    Object.defineProperty(profile, 'profiles', {
      value: signal<WorkProfile[]>([{ id: DEFAULT_WORK_PROFILE_ID, name: 'Standard' }, { id: 'p2', name: 'Nebenjob' }]),
    });
    TestBed.configureTestingModule({
      providers: [
        LeaveReportPrintService,
        { provide: ApiClient, useValue: { getYearlyLeave } },
        { provide: WorkProfileService, useValue: profile },
        { provide: LEAVE_NOW, useValue: () => new Date(2026, 10, 15, 10, 0) },
      ],
    });
    svc = TestBed.inject(LeaveReportPrintService);
  }

  /** Lässt Promise-Ketten und den Render-Hook (`afterNextRender`) laufen. */
  async function settle<T>(p: Promise<T>): Promise<T> {
    for (let i = 0; i < 5; i++) {
      await Promise.resolve();
      TestBed.tick();
    }
    return p;
  }

  afterEach(() => {
    document.documentElement.classList.remove(LEAVE_PRINT_CLASS);
    vi.restoreAllMocks();
  });

  it('lädt Jahr und Standard-Profil, setzt die Daten und druckt danach im Druckmodus', async () => {
    setup(year => of(report(year)));
    let classAtPrint = false;
    print.mockImplementation(() => { classAtPrint = document.documentElement.classList.contains(LEAVE_PRINT_CLASS); });

    expect(await settle(svc.print(2026))).toBe('printed');

    expect(getYearlyLeave).toHaveBeenCalledWith(2026, undefined);
    expect(print).toHaveBeenCalledTimes(1);
    expect(classAtPrint).toBe(true);
    expect(svc.data()).toEqual({
      report: report(2026), isCurrentYear: true, profileName: null, createdAt: new Date(2026, 10, 15, 10, 0),
    });
    expect(svc.loading()).toBe(false);
  });

  it('vergangenes Jahr: isCurrentYear = false', async () => {
    setup(year => of(report(year)));
    await settle(svc.print(2024));
    expect(svc.data()?.isCurrentYear).toBe(false);
    expect(getYearlyLeave).toHaveBeenCalledWith(2024, undefined);
  });

  it('Zusatzprofil: profileId an die API, Profilname in der Auswertung', async () => {
    setup(year => of(report(year)), 'p2');
    await settle(svc.print(2026));
    expect(getYearlyLeave).toHaveBeenCalledWith(2026, 'p2');
    expect(svc.data()?.profileName).toBe('Nebenjob');
  });

  it('während des Ladens gesperrt; ein zweiter Aufruf wird verworfen', async () => {
    const pending = new Subject<YearlyLeaveReport>();
    setup(() => pending);
    const first = svc.print(2026);
    expect(svc.loading()).toBe(true);
    expect(await svc.print(2026)).toBe('busy');
    expect(getYearlyLeave).toHaveBeenCalledTimes(1);
    expect(print).not.toHaveBeenCalled();

    pending.next(report(2026));
    pending.complete();
    expect(await settle(first)).toBe('printed');
    expect(svc.loading()).toBe(false);
    expect(print).toHaveBeenCalledTimes(1);
  });

  it('Fehler beim Laden: kein Druckdialog, kein Druckmodus, Sperre wieder frei', async () => {
    setup(() => throwError(() => new Error('500')));
    expect(await settle(svc.print(2026))).toBe('error');
    expect(print).not.toHaveBeenCalled();
    expect(document.documentElement.classList.contains(LEAVE_PRINT_CLASS)).toBe(false);
    expect(svc.loading()).toBe(false);
    expect(svc.data()).toBeNull();
  });

  it('Profilwechsel während des Ladens: Daten und Name bleiben beim Profil des Klicks', async () => {
    const pending = new Subject<YearlyLeaveReport>();
    setup(() => pending, 'p2');
    const run = svc.print(2026);
    profile.set(DEFAULT_WORK_PROFILE_ID);
    pending.next(report(2026));
    pending.complete();
    await settle(run);
    expect(getYearlyLeave).toHaveBeenCalledWith(2026, 'p2');
    expect(svc.data()?.profileName).toBe('Nebenjob');
  });

  it('afterprint und endPrintMode beenden den Druckmodus', async () => {
    setup(year => of(report(year)));
    await settle(svc.print(2026));
    expect(document.documentElement.classList.contains(LEAVE_PRINT_CLASS)).toBe(true);
    window.dispatchEvent(new Event('afterprint'));
    expect(document.documentElement.classList.contains(LEAVE_PRINT_CLASS)).toBe(false);

    await settle(svc.print(2026));
    expect(document.documentElement.classList.contains(LEAVE_PRINT_CLASS)).toBe(true);
    svc.endPrintMode();
    expect(document.documentElement.classList.contains(LEAVE_PRINT_CLASS)).toBe(false);
  });
});
