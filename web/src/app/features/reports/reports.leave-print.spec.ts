import { ComponentFixture, TestBed } from '@angular/core/testing';
import { signal } from '@angular/core';
import { MatDialog } from '@angular/material/dialog';
import { NoopAnimationsModule } from '@angular/platform-browser/animations';
import { MatSnackBar } from '@angular/material/snack-bar';
import { TranslateService, provideTranslateService } from '@ngx-translate/core';
import { Router } from '@angular/router';
import { NEVER, Observable, Subject, of, throwError } from 'rxjs';
import { ReportsComponent } from './reports';
import { ReportsService } from './reports.service';
import { AuthService } from '../../core/auth/auth';
import { ApiClient } from '../../core/services/api-client';
import { LEAVE_NOW, LeaveBalanceService } from '../../core/services/leave-balance';
import { ProfileService } from '../../core/services/profile';
import { WebPremiumService } from '../../core/services/web-premium';
import { WorkEntryService } from '../../core/services/work-entry';
import { WorkProfileService } from '../../core/services/work-profile';
import { DailyStat } from '../../domain/models/reports.models';
import { YearlyLeaveReport } from '../../domain/models/leave.models';
import { DEFAULT_WORK_PROFILE_ID, WorkEntry } from '../../shared/models/index';
import { createFakeWorkProfile } from '../../shared/testing/work-profile-fake';
import { LEAVE_PRINT_CLASS } from './components/leave-report-print/leave-report-print.service';
import de from '../../../../public/i18n/de.json';

/** Jahres-Tab (#284): Button „Urlaub/Krank drucken“ neben dem Jahresdruck, Premium-Gate, Laden vor dem Druck. */
describe('ReportsComponent: Urlaubs- und Krankheitsauswertung drucken (#284)', () => {
  let fixture: ComponentFixture<ReportsComponent>;
  let presentPaywall: ReturnType<typeof vi.fn>;
  let snackOpen: ReturnType<typeof vi.fn>;
  let getYearlyLeave: ReturnType<typeof vi.fn>;
  let print: ReturnType<typeof vi.spyOn>;

  const report: YearlyLeaveReport = {
    year: 2025, vacationDaysPerYear: 30, vacationDaysTaken: 3, vacationDaysRemaining: 27, sickDays: 0,
    months: Array.from({ length: 12 }, (_, i) => ({ month: i + 1, vacationDays: i === 4 ? 3 : 0, sickDays: 0 })),
    vacationPeriods: [{ start: '2025-05-05', end: '2025-05-07', days: 3 }], sickPeriods: [],
  };

  async function mount(loggedIn: boolean, premium: boolean,
    leave$: () => Observable<YearlyLeaveReport> = () => of(report)): Promise<void> {
    presentPaywall = vi.fn().mockResolvedValue(false);
    snackOpen = vi.fn();
    getYearlyLeave = vi.fn(leave$);
    print = vi.spyOn(window, 'print').mockImplementation(() => undefined);
    const profile = createFakeWorkProfile();
    Object.defineProperty(profile, 'profiles', { value: signal([{ id: DEFAULT_WORK_PROFILE_ID, name: 'Standard' }]) });
    TestBed.configureTestingModule({
      imports: [ReportsComponent, NoopAnimationsModule],
      providers: [
        provideTranslateService({ fallbackLang: 'de' }),
        { provide: ReportsService, useValue: {
          isLoading: signal(false), selectedDate: signal(new Date(2026, 9, 15)), isMultiSelectActive: signal(false),
          selectedDates: signal(new Set<string>()), daysWithEntries: signal<number[]>([]), homeOfficeDays: signal<number[]>([]),
          bundesland: signal(null), dailyStat: signal<DailyStat>({ target: 0, worked: 0, overtime: 0 }),
          selectedDayEntries: signal<WorkEntry[]>([]), isPremium: signal(premium), isLoggedIn: signal(loggedIn),
          navigateToLogin: vi.fn(), navigateWeek: vi.fn(), navigateMonth: vi.fn(),
          weeklyReport: signal({ weekNumber: 46, start: new Date(2026, 10, 9), end: new Date(2026, 10, 15),
            totalWorked: 0, totalBreaks: 0, workDays: 0, avgPerDay: 0, overtime: 0, days: [] }),
          monthlyReport: signal({ month: new Date(2026, 10, 1), totalWorked: 0, totalBreaks: 0, workDays: 0,
            avgPerDay: 0, avgPerWeek: 0, monthlyOvertime: 0, totalOvertime: 0, weeks: [], days: [] }),
        } },
        { provide: LeaveBalanceService, useValue: {
          year: signal(2025), canGoPrevYear: signal(true), canGoNextYear: signal(true), isCurrentYear: signal(false),
          report: signal(null), state: signal('loading'), navigateYear: vi.fn(), refresh: vi.fn() } },
        { provide: LEAVE_NOW, useValue: () => new Date(2026, 10, 14) },
        { provide: WorkEntryService, useValue: { getEntriesForMonthOnce: async () => [] } },
        { provide: WorkProfileService, useValue: profile },
        { provide: AuthService, useValue: { user$: of(loggedIn ? { uid: 'u1' } : null) } },
        { provide: ProfileService, useValue: { isPremium: signal(premium) } },
        { provide: ApiClient, useValue: { getYearlyComparison: () => NEVER, getYearlyLeave } },
        { provide: Router, useValue: { navigate: vi.fn() } },
        { provide: MatDialog, useValue: {} },
        { provide: MatSnackBar, useValue: { open: snackOpen } },
        { provide: WebPremiumService, useValue: {
          isRestoring: signal(false), isPurchasing: signal(false), isConfigured: true, presentPaywall,
          restorePurchases: vi.fn().mockResolvedValue(false) } },
      ],
    });
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('de', de);
    translate.use('de');
    fixture = TestBed.createComponent(ReportsComponent);
    fixture.detectChanges();
    (fixture.componentInstance as unknown as { onTabChange(i: number): void }).onTabChange(3);
    await settle();
  }

  async function settle(): Promise<void> {
    for (let i = 0; i < 4; i++) {
      fixture.detectChanges();
      TestBed.tick();
      await Promise.resolve();
    }
    fixture.detectChanges();
  }

  const el = (): HTMLElement => fixture.nativeElement as HTMLElement;
  const actions = (): HTMLButtonElement[] => [...el().querySelectorAll<HTMLButtonElement>('.print-actions button')];
  const leaveButton = (): HTMLButtonElement | null => el().querySelector('.leave-print-button');

  afterEach(() => {
    document.documentElement.classList.remove(LEAVE_PRINT_CLASS);
    vi.restoreAllMocks();
    TestBed.resetTestingModule();
  });

  it('Premium: beide Druck-Buttons nebeneinander, außerhalb des Drucks', async () => {
    await mount(true, true);
    expect(actions().map(b => b.textContent?.replace(/\s+/g, ' ').trim())).toEqual([
      'picture_as_pdf Als PDF speichern / Drucken', 'print Urlaub/Krank drucken',
    ]);
    expect(el().querySelector('.print-actions')?.classList).toContain('no-print');
    expect(el().querySelector('app-leave-report-print')).toBeNull();
  });

  it('Premium: lädt das gewählte Jahr, rendert die Auswertung außerhalb des Jahres-Druckbereichs und druckt danach', async () => {
    await mount(true, true);
    leaveButton()!.click();
    await settle();
    expect(getYearlyLeave).toHaveBeenCalledWith(2025, undefined);
    expect(print).toHaveBeenCalledTimes(1);
    const view = el().querySelector('app-leave-report-print');
    expect(view?.textContent).toContain('Urlaubs- und Krankheitsauswertung 2025');
    expect(view?.closest('.print-area')).toBeNull();
    expect(document.documentElement.classList).toContain(LEAVE_PRINT_CLASS);
    expect(presentPaywall).not.toHaveBeenCalled();
  });

  it('Ladezustand: Button gesperrt mit Ladetext, Druck erst nach der Antwort', async () => {
    const pending = new Subject<YearlyLeaveReport>();
    await mount(true, true, () => pending);
    leaveButton()!.click();
    await settle();
    expect(leaveButton()!.disabled).toBe(true);
    expect(leaveButton()!.textContent).toContain('Wird geladen');
    expect(leaveButton()!.querySelector('mat-spinner')).not.toBeNull();
    expect(print).not.toHaveBeenCalled();

    pending.next(report);
    pending.complete();
    await settle();
    expect(print).toHaveBeenCalledTimes(1);
    expect(leaveButton()!.disabled).toBe(false);
  });

  it('Fehler beim Laden: Snackbar, kein Druckdialog, Button wieder frei', async () => {
    await mount(true, true, () => throwError(() => new Error('500')));
    leaveButton()!.click();
    await settle();
    expect(print).not.toHaveBeenCalled();
    expect(snackOpen).toHaveBeenCalledWith(
      'Die Urlaubs- und Krankheitsauswertung konnte nicht geladen werden.', 'OK', { duration: 4000 });
    expect(leaveButton()!.disabled).toBe(false);
    expect(document.documentElement.classList).not.toContain(LEAVE_PRINT_CLASS);
  });

  it('Jahresdruck nach der Auswertung beendet deren Druckmodus (Überschrift „Jahresauswertung“)', async () => {
    await mount(true, true);
    leaveButton()!.click();
    await settle();
    expect(document.documentElement.classList).toContain(LEAVE_PRINT_CLASS);
    actions()[0].click();
    await settle();
    expect(document.documentElement.classList).not.toContain(LEAVE_PRINT_CLASS);
    expect(print).toHaveBeenCalledTimes(2);
    expect(el().querySelector('.print-area h2.print-only')?.textContent?.trim()).toBe('Jahresauswertung 2025');
  });

  it('Free: gesperrter Button öffnet die Paywall, kein Laden, kein Druck', async () => {
    await mount(true, false);
    expect(leaveButton()!.textContent?.replace(/\s+/g, ' ').trim()).toBe('lock Urlaub/Krank mit Premium');
    leaveButton()!.click();
    await settle();
    expect(presentPaywall).toHaveBeenCalledTimes(1);
    expect(getYearlyLeave).not.toHaveBeenCalled();
    expect(print).not.toHaveBeenCalled();
  });

  it('nicht angemeldet: kein Button für die Auswertung', async () => {
    await mount(false, false);
    expect(leaveButton()).toBeNull();
    expect(actions().length).toBe(1);
  });
});
