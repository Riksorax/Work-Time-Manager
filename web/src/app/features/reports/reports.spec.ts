import { LiveAnnouncer } from '@angular/cdk/a11y';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { signal } from '@angular/core';
import { By } from '@angular/platform-browser';
import { MatDialog } from '@angular/material/dialog';
import { MatSnackBar } from '@angular/material/snack-bar';
import { TranslateService, provideTranslateService } from '@ngx-translate/core';
import { Router } from '@angular/router';
import { ReportsComponent } from './reports';
import { ReportsService } from './reports.service';
import { LeaveBalanceService } from '../../core/services/leave-balance';
import { WebPremiumService } from '../../core/services/web-premium';
import { CalendarComponent } from '../../shared/components/calendar/calendar';
import { DailyStat } from '../../domain/models/reports.models';
import { WorkEntry } from '../../shared/models/index';

describe('ReportsComponent.goToSettings', () => {
  it('navigiert zu /settings', () => {
    const navigate = vi.fn();
    TestBed.overrideComponent(ReportsComponent, { set: { template: '', imports: [] } });
    TestBed.configureTestingModule({
      providers: [
        { provide: ReportsService, useValue: {} },
        { provide: LeaveBalanceService, useValue: {} },
        { provide: Router, useValue: { navigate } },
        { provide: MatDialog, useValue: {} },
        { provide: MatSnackBar, useValue: {} },
        { provide: TranslateService, useValue: {} },
        { provide: WebPremiumService, useValue: {
          isRestoring: signal(false), isPurchasing: signal(false), isConfigured: signal(false) } },
      ],
    });
    TestBed.createComponent(ReportsComponent).componentInstance.goToSettings();
    expect(navigate).toHaveBeenCalledWith(['/settings']);
  });
});

describe('ReportsComponent - Mehrfachauswahl-Toggle (#377)', () => {
  let fixture: ComponentFixture<ReportsComponent>;
  let el: HTMLElement;
  let isMultiSelectActive: ReturnType<typeof signal<boolean>>;
  let svc: {
    toggleMultiSelect: ReturnType<typeof vi.fn>;
    endMultiSelect: ReturnType<typeof vi.fn>;
    removeDatesFromSelection: ReturnType<typeof vi.fn>;
    addDateRangeSelection: ReturnType<typeof vi.fn>;
  };

  const toggle = (): HTMLButtonElement => el.querySelector('.multi-select-toggle') as HTMLButtonElement;
  const calendar = (): CalendarComponent =>
    fixture.debugElement.query(By.directive(CalendarComponent)).componentInstance as CalendarComponent;
  const render = (): void => {
    fixture.detectChanges();
    TestBed.tick();
  };

  beforeEach(async () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date(2026, 9, 15, 12));
    isMultiSelectActive = signal(false);
    svc = {
      toggleMultiSelect: vi.fn(),
      endMultiSelect: vi.fn(() => isMultiSelectActive.set(false)),
      removeDatesFromSelection: vi.fn(),
      addDateRangeSelection: vi.fn(),
    };
    const fake = {
      ...svc,
      isLoading: signal(false),
      selectedDate: signal(new Date(2026, 9, 15)),
      isMultiSelectActive,
      selectedDates: signal(new Set<string>()),
      daysWithEntries: signal<number[]>([]),
      bundesland: signal(null),
      dailyStat: signal<DailyStat>({ target: 0, worked: 0, overtime: 0 }),
      selectedDayEntries: signal<WorkEntry[]>([]),
      isPremium: signal(false),
      isLoggedIn: signal(false),
      selectDate: vi.fn(),
      onMonthChanged: vi.fn(),
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
      common: { cancel: 'Abbrechen', weekdaysShort: ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'] },
      reports: {
        multiSelectButton: 'Mehrfachauswahl',
        multiSelectTooltip: 'Mehrere Tage auswählen. Tastenkürzel: Umschalt + Pfeiltasten',
        cancelMultiSelectAria: 'Mehrfachauswahl beenden',
      },
    });
    translate.use('de');
    fixture = TestBed.createComponent(ReportsComponent);
    el = fixture.nativeElement as HTMLElement;
    render();
  });

  afterEach(() => vi.useRealTimers());

  it('zeigt den Toggle im Kalender-Panel vor dem Kalender', () => {
    const panel = el.querySelector('.calendar-panel') as HTMLElement;
    expect(panel.contains(toggle())).toBe(true);
    const cal = panel.querySelector('app-calendar') as HTMLElement;
    expect(toggle().compareDocumentPosition(cal) & Node.DOCUMENT_POSITION_FOLLOWING).toBeTruthy();
    expect(toggle().textContent).toContain('Mehrfachauswahl');
  });

  it('aria-pressed folgt isMultiSelectActive, Klick ruft toggleMultiSelect', () => {
    expect(toggle().getAttribute('aria-pressed')).toBe('false');
    toggle().click();
    expect(svc.toggleMultiSelect).toHaveBeenCalledTimes(1);
    isMultiSelectActive.set(true);
    render();
    expect(toggle().getAttribute('aria-pressed')).toBe('true');
    expect(toggle().classList.contains('is-active')).toBe(true);
  });

  it('Icon wechselt, kein Zusatz-aria-label, Kürzel per Tooltip-aria-describedby', () => {
    const icon = (): string => toggle().querySelector('mat-icon')!.textContent!.trim();
    expect(icon()).toBe('checklist');
    isMultiSelectActive.set(true);
    render();
    expect(icon()).toBe('done_all');
    expect(toggle().hasAttribute('aria-label')).toBe(false);
    // matTooltip hängt den Text per AriaDescriber als aria-describedby an (auch ohne Hover/Fokus)
    const ids = (toggle().getAttribute('aria-describedby') ?? '').split(' ').filter(Boolean);
    const texts = ids.map(id => document.getElementById(id)?.textContent?.trim());
    expect(texts).toContain('Mehrere Tage auswählen. Tastenkürzel: Umschalt + Pfeiltasten');
  });

  it('verdrahtet Kalender-Input und -Outputs mit dem Service', () => {
    expect(calendar().multiSelectActive()).toBe(false);
    isMultiSelectActive.set(true);
    render();
    expect(calendar().multiSelectActive()).toBe(true);
    const days = [new Date(2026, 9, 16)];
    calendar().daysDeselected.emit(days);
    expect(svc.removeDatesFromSelection).toHaveBeenCalledWith(days);
    calendar().multiSelectEnded.emit();
    expect(svc.endMultiSelect).toHaveBeenCalledTimes(1);
  });

  it('Abbrechen im Day-Panel beendet den Modus und gibt dem Toggle den Fokus', () => {
    isMultiSelectActive.set(true);
    render();
    const cancel = el.querySelector('.day-header-actions button') as HTMLButtonElement;
    cancel.focus();
    cancel.click();
    expect(svc.endMultiSelect).toHaveBeenCalledTimes(1);
    expect(svc.toggleMultiSelect).not.toHaveBeenCalled();
    render();
    expect(el.querySelector('.day-header-actions')).toBeNull();
    expect(document.activeElement).toBe(toggle());
  });
});
