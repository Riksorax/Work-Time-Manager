import { ComponentFixture, TestBed } from '@angular/core/testing';
import { signal } from '@angular/core';
import { MatDialog } from '@angular/material/dialog';
import { NoopAnimationsModule } from '@angular/platform-browser/animations';
import { MatSnackBar } from '@angular/material/snack-bar';
import { TranslateService, provideTranslateService } from '@ngx-translate/core';
import { Router } from '@angular/router';
import { ReportsComponent } from './reports';
import { ReportsService } from './reports.service';
import { LeaveBalanceService } from '../../core/services/leave-balance';
import { WebPremiumService } from '../../core/services/web-premium';
import { TrendViewService, TrendState } from './components/trend-view/trend-view.service';
import { DailyStat } from '../../domain/models/reports.models';
import { WorkEntry } from '../../shared/models/index';
import { WorkEntryService } from '../../core/services/work-entry';
import { WorkProfileService } from '../../core/services/work-profile';
import { createFakeWorkProfile } from '../../shared/testing/work-profile-fake';
import de from '../../../../public/i18n/de.json';

/** Tab „Trend“ (#531): Gate wie Wochen-/Monatsbericht, die Ansicht (und damit der API-Aufruf) nur für Premium. */
describe('ReportsComponent: Tab Trend (#531)', () => {
  let fixture: ComponentFixture<ReportsComponent>;
  let attach: ReturnType<typeof vi.fn>;
  let presentPaywall: ReturnType<typeof vi.fn>;

  function mount(loggedIn: boolean, premium: boolean): void {
    attach = vi.fn(() => () => undefined);
    presentPaywall = vi.fn().mockResolvedValue(false);
    const trend = {
      attach,
      granularity: signal('week'),
      state: signal<TrendState>({ status: 'loading' }),
      report: signal(null),
      isEmpty: signal(false),
      setGranularity: vi.fn(),
      retry: vi.fn(),
    };
    TestBed.overrideComponent(ReportsComponent, { set: { providers: [{ provide: TrendViewService, useValue: trend }] } });
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
          year: signal(2026), canGoPrevYear: signal(false), canGoNextYear: signal(false), isCurrentYear: signal(true),
          report: signal(null), state: signal('loading'), navigateYear: vi.fn(), refresh: vi.fn() } },
        // Jahres-Tab (Premium): Home-Office-Karte wird eager angelegt.
        { provide: WorkEntryService, useValue: { getEntriesForMonthOnce: async () => [] } },
        { provide: WorkProfileService, useValue: createFakeWorkProfile() },
        { provide: Router, useValue: { navigate: vi.fn() } },
        { provide: MatDialog, useValue: {} },
        { provide: MatSnackBar, useValue: { open: vi.fn() } },
        { provide: WebPremiumService, useValue: {
          isRestoring: signal(false), isPurchasing: signal(false), isConfigured: true, presentPaywall } },
      ],
    });
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('de', de);
    translate.use('de');
    fixture = TestBed.createComponent(ReportsComponent);
    fixture.detectChanges();
  }

  async function openTrendTab(): Promise<void> {
    const tab = [...(fixture.nativeElement as HTMLElement).querySelectorAll<HTMLElement>('[role="tab"]')]
      .find(t => t.textContent?.trim() === 'Trend');
    expect(tab).toBeTruthy();
    (fixture.componentInstance as unknown as { onTabChange(i: number): void }).onTabChange(4);
    for (let i = 0; i < 3; i++) {
      fixture.detectChanges();
      TestBed.tick();
      await Promise.resolve();
    }
    fixture.detectChanges();
  }

  const el = (): HTMLElement => fixture.nativeElement as HTMLElement;

  afterEach(() => TestBed.resetTestingModule());

  it('fünfter Tab „Trend“; die Ansicht entsteht erst beim Öffnen des Tabs', async () => {
    mount(true, true);
    const tabs = [...el().querySelectorAll('[role="tab"]')].map(t => t.textContent?.trim());
    expect(tabs).toEqual(['Täglich', 'Wöchentlich', 'Monatlich', 'Jahr', 'Trend']);
    expect(attach).not.toHaveBeenCalled();
    await openTrendTab();
    expect(el().querySelector('app-trend-view')).not.toBeNull();
    expect(attach).toHaveBeenCalledTimes(1);
  });

  it('nicht angemeldet: Hinweis mit Anmelden, keine Ansicht, kein Laden', async () => {
    mount(false, false);
    await openTrendTab();
    expect(el().textContent).toContain('Melde dich an, um den Trend deiner Arbeitszeit zu sehen.');
    expect(el().querySelector('app-trend-view')).toBeNull();
    expect(attach).not.toHaveBeenCalled();
  });

  it('Free: gesperrte Karte mit Paywall, keine Ansicht, kein Laden', async () => {
    mount(true, false);
    await openTrendTab();
    expect(el().textContent).toContain('Trend — Premium');
    expect(el().querySelector('app-trend-view')).toBeNull();
    expect(attach).not.toHaveBeenCalled();
    const unlock = [...el().querySelectorAll<HTMLButtonElement>('.premium-overlay button')]
      .find(b => b.textContent?.includes('Premium freischalten'));
    unlock!.click();
    expect(presentPaywall).toHaveBeenCalled();
  });
});
