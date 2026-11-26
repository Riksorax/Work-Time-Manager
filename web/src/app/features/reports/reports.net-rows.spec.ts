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

/**
 * Berichtszeilen zeigen Netto (#551): Tage im Wochen-/Monatsbericht und Wochen im Monatsbericht zeigen
 * `netWorked` (ohne Pausen), nicht den Brutto-Wert; das `aria-label` der Tageszeile ebenso.
 */
describe('ReportsComponent: Zeilen der Berichte zeigen Netto (#551)', () => {
  let fixture: ComponentFixture<ReportsComponent>;
  const H = 3600000;

  async function mount(tab: number): Promise<void> {
    TestBed.configureTestingModule({
      imports: [ReportsComponent, NoopAnimationsModule],
      providers: [
        provideTranslateService({ fallbackLang: 'de' }),
        { provide: ReportsService, useValue: {
          isLoading: signal(false), selectedDate: signal(new Date(2026, 9, 15)), isMultiSelectActive: signal(false),
          selectedDates: signal(new Set<string>()), daysWithEntries: signal<number[]>([]), homeOfficeDays: signal<number[]>([]),
          bundesland: signal(null), dailyStat: signal<DailyStat>({ target: 0, worked: 0, overtime: 0 }),
          selectedDayEntries: signal<WorkEntry[]>([]), isPremium: signal(true), isLoggedIn: signal(true),
          navigateToLogin: vi.fn(), navigateWeek: vi.fn(), navigateMonth: vi.fn(), selectDate: vi.fn(),
          weeklyReport: signal({ weekNumber: 46, start: new Date(2026, 10, 9), end: new Date(2026, 10, 15),
            totalWorked: 9 * H, totalBreaks: H / 2, workDays: 1, avgPerDay: 8.5 * H, overtime: 0,
            days: [
              { date: new Date(2026, 10, 9), worked: 9 * H, netWorked: 8.5 * H },
              { date: new Date(2026, 10, 10), worked: 0, netWorked: 0 },
            ] }),
          monthlyReport: signal({ month: new Date(2026, 10, 1), totalWorked: 9 * H, totalBreaks: H / 2, workDays: 1,
            avgPerDay: 8.5 * H, avgPerWeek: 8.5 * H, monthlyOvertime: 0, totalOvertime: 0,
            weeks: [{ weekNumber: 46, totalWorked: 9 * H, netWorked: 8.5 * H }],
            days: [{ date: new Date(2026, 10, 9), worked: 9 * H, netWorked: 8.5 * H }] }),
        } },
        { provide: LeaveBalanceService, useValue: {
          year: signal(2025), canGoPrevYear: signal(true), canGoNextYear: signal(true), isCurrentYear: signal(false),
          report: signal(null), state: signal('loading'), navigateYear: vi.fn(), refresh: vi.fn() } },
        { provide: LEAVE_NOW, useValue: () => new Date(2026, 10, 14) },
        { provide: WorkEntryService, useValue: { getEntriesForMonthOnce: async () => [] } },
        { provide: WorkProfileService, useValue: createFakeWorkProfile() },
        { provide: AuthService, useValue: { user$: of({ uid: 'u1' }) } },
        { provide: ProfileService, useValue: { isPremium: signal(true) } },
        { provide: ApiClient, useValue: { getYearlyComparison: () => NEVER, getHomeOfficeReport: () => NEVER } },
        { provide: Router, useValue: { navigate: vi.fn() } },
        { provide: MatDialog, useValue: {} },
        { provide: MatSnackBar, useValue: { open: vi.fn() } },
        { provide: WebPremiumService, useValue: {
          isRestoring: signal(false), isPurchasing: signal(false), isConfigured: true } },
      ],
    });
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('de', de);
    translate.use('de');
    fixture = TestBed.createComponent(ReportsComponent);
    fixture.detectChanges();
    (fixture.componentInstance as unknown as { onTabChange(i: number): void }).onTabChange(tab);
    for (let i = 0; i < 3; i++) {
      fixture.detectChanges();
      TestBed.tick();
      await Promise.resolve();
    }
    fixture.detectChanges();
  }

  const root = (): HTMLElement => fixture.nativeElement as HTMLElement;
  const texts = (selector: string): string[] =>
    [...root().querySelectorAll(selector)].map(e => e.textContent!.trim());

  afterEach(() => TestBed.resetTestingModule());

  it('Wochenbericht: Tageszeile netto (08:30, nicht 09:00), freier Tag „—“', async () => {
    await mount(1);
    const rows = texts('.day-duration');
    expect(rows).toContain('08:30');
    expect(rows).not.toContain('09:00');
    expect(rows).toContain('—');
  });

  it('Wochenbericht: aria-label der Tageszeile nennt den Netto-Wert', async () => {
    await mount(1);
    const label = root().querySelector('.day-row')!.getAttribute('aria-label')!;
    expect(label).toContain('08:30');
    expect(label).not.toContain('09:00');
  });

  it('Monatsbericht: Wochenzeile und Tageszeile netto', async () => {
    await mount(2);
    expect(texts('.week-overview-duration')).toEqual(['08:30']);
    expect(texts('.day-duration')).toEqual(['08:30']);
    expect(root().querySelector('.day-row')!.getAttribute('aria-label')).toContain('08:30');
  });

  it('Wochenbericht: Gesamtarbeitszeit netto (brutto − Pausen), Gesamtpausen separat, passt zur Zeilensumme', async () => {
    await mount(1);
    const rows = [...root().querySelectorAll('.summary-card')].find(c => c.textContent!.includes('Gesamtarbeitszeit'))!;
    const values = [...rows.querySelectorAll('.summary-value')].map(e => e.textContent!.trim());
    expect(values[0]).toBe('08:30');
    expect(values[1]).toBe('00:30');
    expect(texts('.day-duration').filter(t => t !== '—')).toEqual([values[0]]);
  });

  it('Monatsbericht: Gesamtarbeitszeit netto, gleich der Wochenzeile', async () => {
    await mount(2);
    const card = [...root().querySelectorAll('.summary-card')].find(c => c.textContent!.includes('Gesamtarbeitszeit'))!;
    const values = [...card.querySelectorAll('.summary-value')].map(e => e.textContent!.trim());
    expect(values[0]).toBe('08:30');
    expect(values[1]).toBe('00:30');
    expect(texts('.week-overview-duration')).toEqual([values[0]]);
  });

  it('Wochentage der Zeilen folgen der App-Sprache (de „Mo. 9.“, en „Mon 9.“), auch im aria-label', async () => {
    await mount(1);
    expect(texts('.day-name')[0]).toBe('Mo. 9.');
    expect(root().querySelector('.day-row')!.getAttribute('aria-label')).toContain('Montag');
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('en', {});
    translate.use('en');
    for (let i = 0; i < 3; i++) {
      fixture.detectChanges();
      TestBed.tick();
      await Promise.resolve();
    }
    fixture.detectChanges();
    expect(texts('.day-name')[0]).toBe('Mon 9.');
    expect(root().querySelector('.day-row')!.getAttribute('aria-label')).toContain('Monday');
  });
});
