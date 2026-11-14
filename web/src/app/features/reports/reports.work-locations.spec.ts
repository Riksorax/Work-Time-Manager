import { LiveAnnouncer } from '@angular/cdk/a11y';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { signal } from '@angular/core';
import { MatDialog } from '@angular/material/dialog';
import { MatSnackBar } from '@angular/material/snack-bar';
import { TranslateService, provideTranslateService } from '@ngx-translate/core';
import { Router } from '@angular/router';
import { ReportsComponent } from './reports';
import { ReportsService } from './reports.service';
import { LeaveBalanceService } from '../../core/services/leave-balance';
import { WebPremiumService } from '../../core/services/web-premium';
import { DailyStat } from '../../domain/models/reports.models';
import { WorkEntry, WorkEntryType } from '../../shared/models/index';

/** Orte in der Eintragskarte der Berichte (#526): immer sichtbar, unabhängig von den Dashboard-Einstellungen. */
describe('ReportsComponent: Arbeitsorte in der Eintragskarte (#526)', () => {
  let fixture: ComponentFixture<ReportsComponent>;
  const selectedDayEntries = signal<WorkEntry[]>([]);

  const entry = (over: Partial<WorkEntry> = {}): WorkEntry => ({
    id: '2026-10-15', date: new Date(2026, 9, 15), breaks: [], isManuallyEntered: false, type: WorkEntryType.Work,
    workStart: new Date(2026, 9, 15, 8, 0), workEnd: new Date(2026, 9, 15, 16, 0), ...over,
  });

  beforeEach(async () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date(2026, 9, 15, 12));
    selectedDayEntries.set([]);
    const fake = {
      isLoading: signal(false),
      selectedDate: signal(new Date(2026, 9, 15)),
      isMultiSelectActive: signal(false),
      selectedDates: signal(new Set<string>()),
      daysWithEntries: signal<number[]>([]),
      homeOfficeDays: signal<number[]>([]),
      bundesland: signal(null),
      dailyStat: signal<DailyStat>({ target: 0, worked: 0, overtime: 0 }),
      selectedDayEntries,
      isPremium: signal(false),
      isLoggedIn: signal(false),
      entryNetDuration: () => 0,
      selectDate: vi.fn(), onMonthChanged: vi.fn(), toggleMultiSelect: vi.fn(), endMultiSelect: vi.fn(),
      removeDatesFromSelection: vi.fn(), addDateRangeSelection: vi.fn(),
    };
    await TestBed.configureTestingModule({
      imports: [ReportsComponent],
      providers: [
        provideTranslateService({ fallbackLang: 'de' }),
        { provide: ReportsService, useValue: fake },
        { provide: LeaveBalanceService, useValue: {
          year: signal(2026), canGoPrevYear: signal(false), canGoNextYear: signal(false), isCurrentYear: signal(true),
          report: signal(null), state: signal('empty'), navigateYear: vi.fn(), refresh: vi.fn() } },
        { provide: Router, useValue: { navigate: vi.fn() } },
        { provide: MatDialog, useValue: {} },
        { provide: MatSnackBar, useValue: {} },
        { provide: LiveAnnouncer, useValue: { announce: vi.fn() } },
        { provide: WebPremiumService, useValue: {
          isRestoring: signal(false), isPurchasing: signal(false), isConfigured: signal(false) } },
      ],
    }).compileComponents();
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('de', {
      common: { weekdaysShort: ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'] },
      shared: { workLocationLabel: 'Arbeitsorte: {{names}}', homeOfficeChip: 'Home-Office' },
    });
    translate.use('de');
    fixture = TestBed.createComponent(ReportsComponent);
  });

  afterEach(() => vi.useRealTimers());

  const render = (): void => { fixture.detectChanges(); TestBed.tick(); };
  const chip = (): HTMLElement | null => (fixture.nativeElement as HTMLElement).querySelector('.work-location-chip');

  it('mehrere Orte stehen durch Komma getrennt neben dem Home-Office-Chip', () => {
    selectedDayEntries.set([entry({ isHomeOffice: true, workLocations: ['Büro', 'Kunde'] })]);
    render();
    expect(chip()?.textContent).toContain('Büro, Kunde');
    expect(chip()?.querySelector('.cdk-visually-hidden')?.textContent?.trim()).toBe('Arbeitsorte: Büro, Kunde');
    const ho = (fixture.nativeElement as HTMLElement).querySelector('.home-office-chip')!;
    expect(ho.nextElementSibling).toBe(chip());
  });

  it('ohne Orte kein Chip', () => {
    selectedDayEntries.set([entry({ workLocations: [] }), entry({ id: '2026-10-16' })]);
    render();
    expect(chip()).toBeNull();
  });

  it('bei anderen Typen als Arbeit nicht angezeigt', () => {
    selectedDayEntries.set([entry({ type: WorkEntryType.Vacation, workLocations: ['Büro'] })]);
    render();
    expect(chip()).toBeNull();
  });
});
