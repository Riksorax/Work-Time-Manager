import { ComponentFixture, TestBed } from '@angular/core/testing';
import { signal } from '@angular/core';
import { MatDialog } from '@angular/material/dialog';
import { NoopAnimationsModule } from '@angular/platform-browser/animations';
import { MatSnackBar } from '@angular/material/snack-bar';
import { TranslateService, provideTranslateService } from '@ngx-translate/core';
import { Router } from '@angular/router';
import { NEVER, of } from 'rxjs';
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
import { WorkEntry } from '../../shared/models/index';
import { createFakeWorkProfile } from '../../shared/testing/work-profile-fake';
import de from '../../../../public/i18n/de.json';

/** Jahres-Tab (#530): Jahresvergleich nur für Premium, sonst kompakte gesperrte Karte; API nur mit Premium. */
describe('ReportsComponent: Jahresvergleich im Jahres-Tab (#530)', () => {
  let fixture: ComponentFixture<ReportsComponent>;
  let presentPaywall: ReturnType<typeof vi.fn>;
  let navigateToLogin: ReturnType<typeof vi.fn>;
  let getYearlyComparison: ReturnType<typeof vi.fn>;

  async function mount(loggedIn: boolean, premium: boolean): Promise<void> {
    presentPaywall = vi.fn().mockResolvedValue(false);
    navigateToLogin = vi.fn();
    getYearlyComparison = vi.fn(() => NEVER);
    TestBed.configureTestingModule({
      imports: [ReportsComponent, NoopAnimationsModule],
      providers: [
        provideTranslateService({ fallbackLang: 'de' }),
        { provide: ReportsService, useValue: {
          isLoading: signal(false), selectedDate: signal(new Date(2026, 9, 15)), isMultiSelectActive: signal(false),
          selectedDates: signal(new Set<string>()), daysWithEntries: signal<number[]>([]), homeOfficeDays: signal<number[]>([]),
          bundesland: signal(null), dailyStat: signal<DailyStat>({ target: 0, worked: 0, overtime: 0 }),
          selectedDayEntries: signal<WorkEntry[]>([]), isPremium: signal(premium), isLoggedIn: signal(loggedIn),
          navigateToLogin, navigateWeek: vi.fn(), navigateMonth: vi.fn(),
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
        { provide: WorkProfileService, useValue: createFakeWorkProfile() },
        { provide: AuthService, useValue: { user$: of(loggedIn ? { uid: 'u1' } : null) } },
        { provide: ProfileService, useValue: { isPremium: signal(premium) } },
        { provide: ApiClient, useValue: { getYearlyComparison, getHomeOfficeReport: () => NEVER } },
        { provide: Router, useValue: { navigate: vi.fn() } },
        { provide: MatDialog, useValue: {} },
        { provide: MatSnackBar, useValue: { open: vi.fn() } },
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
    for (let i = 0; i < 3; i++) {
      fixture.detectChanges();
      TestBed.tick();
      await Promise.resolve();
    }
    fixture.detectChanges();
  }

  const el = (): HTMLElement => fixture.nativeElement as HTMLElement;
  const button = (text: string): HTMLButtonElement | undefined =>
    [...el().querySelectorAll<HTMLButtonElement>('app-yearly-comparison-locked button')].find(b => b.textContent?.includes(text));

  afterEach(() => TestBed.resetTestingModule());

  it('Premium: Karte im Druckbereich, lädt das gewählte Jahr', async () => {
    await mount(true, true);
    const card = el().querySelector('app-yearly-comparison-card');
    expect(card).not.toBeNull();
    expect(card!.closest('.print-area')).not.toBeNull();
    expect(el().querySelector('app-yearly-comparison-locked')).toBeNull();
    expect(getYearlyComparison).toHaveBeenCalledWith(2025, undefined, undefined);
  });

  it('Free: gesperrte Karte mit Paywall, keine Vergleichskarte, kein API-Aufruf', async () => {
    await mount(true, false);
    expect(el().querySelector('app-yearly-comparison-card')).toBeNull();
    const locked = el().querySelector('app-yearly-comparison-locked');
    expect(locked?.textContent).toContain('Vergleich mit dem Vorjahr — Premium');
    expect(locked?.classList).toContain('no-print');
    button('Premium freischalten')!.click();
    expect(presentPaywall).toHaveBeenCalled();
    expect(button('Kauf wiederherstellen')).toBeTruthy();
    expect(getYearlyComparison).not.toHaveBeenCalled();
  });

  it('nicht angemeldet: Hinweis mit Anmelden, kein API-Aufruf', async () => {
    await mount(false, false);
    expect(el().querySelector('app-yearly-comparison-card')).toBeNull();
    expect(el().querySelector('app-yearly-comparison-locked')?.textContent)
      .toContain('Melde dich an, um dein Jahr mit dem Vorjahr zu vergleichen (Premium).');
    button('Anmelden')!.click();
    expect(navigateToLogin).toHaveBeenCalled();
    expect(button('Premium freischalten')).toBeUndefined();
    expect(getYearlyComparison).not.toHaveBeenCalled();
  });
});
