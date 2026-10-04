import { TestBed } from '@angular/core/testing';
import { Component, input, output, signal } from '@angular/core';
import { ComponentFixture } from '@angular/core/testing';
import { MatDialog } from '@angular/material/dialog';
import { MatSnackBar } from '@angular/material/snack-bar';
import { TranslateService, provideTranslateService } from '@ngx-translate/core';
import { Router } from '@angular/router';
import { DashboardComponent } from './dashboard';
import { DashboardService } from './dashboard.service';
import { LeaveBalanceService } from '../../core/services/leave-balance';
import { GermanHoliday } from '../../shared/utils/german-holidays.util';
import { HolidayBannerComponent } from '../../shared/components/holiday-banner/holiday-banner';
import { LeaveBalanceCardComponent } from '../../shared/components/leave-balance-card/leave-balance-card';
import { TimeInputComponent } from '../../shared/components/time-input/time-input';
import { WorkEntryType } from '../../shared/models/index';

describe('DashboardComponent.goToSettings', () => {
  it('navigiert zu /settings', () => {
    const navigate = vi.fn();
    TestBed.overrideComponent(DashboardComponent, { set: { template: '', imports: [] } });
    TestBed.configureTestingModule({
      providers: [
        { provide: DashboardService, useValue: {} },
        { provide: LeaveBalanceService, useValue: {} },
        { provide: Router, useValue: { navigate } },
        { provide: MatDialog, useValue: {} },
        { provide: MatSnackBar, useValue: {} },
        { provide: TranslateService, useValue: {} },
      ],
    });
    TestBed.createComponent(DashboardComponent).componentInstance.goToSettings();
    expect(navigate).toHaveBeenCalledWith(['/settings']);
  });
});

@Component({ selector: 'app-holiday-banner', template: '<div class="stub-banner">{{ holiday() }}</div>' })
class HolidayBannerStub { readonly holiday = input.required<GermanHoliday>(); }
@Component({ selector: 'app-leave-balance-card', template: '' })
class LeaveCardStub {
  readonly report = input<unknown>();
  readonly state = input<unknown>();
  readonly editable = input<boolean>();
  readonly localOnly = input<boolean>();
  readonly retry = output<void>();
  readonly editEntitlement = output<void>();
}
@Component({ selector: 'app-time-input', template: '' })
class TimeInputStub {
  readonly label = input<string>();
  readonly value = input<unknown>();
  readonly disabled = input<boolean>();
  readonly showClear = input<boolean>();
  readonly timeSelected = output<Date>();
}

describe('DashboardComponent Feiertags-Banner', () => {
  const holiday = signal<GermanHoliday | null>(null);
  const isLoading = signal(false);
  let fixture: ComponentFixture<DashboardComponent>;

  beforeEach(() => {
    holiday.set(null);
    isLoading.set(false);
    TestBed.overrideComponent(DashboardComponent, {
      remove: { imports: [HolidayBannerComponent, LeaveBalanceCardComponent, TimeInputComponent] },
      add: { imports: [HolidayBannerStub, LeaveCardStub, TimeInputStub] },
    });
    TestBed.configureTestingModule({
      providers: [
        provideTranslateService(),
        { provide: DashboardService, useValue: {
          isLoading, holidayToday: holiday, isLoggedIn: signal(false),
          netDuration: signal(0), grossDuration: signal(0), dailyOvertime: signal(0), totalOvertime: signal(0),
          isTimerRunning: signal(false), isBreakRunning: signal(false), expectedEndTime: signal(null),
          expectedEndTotalZero: signal(null), breaks: signal([]),
          workEntry: signal({ id: 'x', date: new Date(2026, 9, 3), breaks: [], isManuallyEntered: false, type: WorkEntryType.Work }),
        } },
        { provide: LeaveBalanceService, useValue: {
          currentYearReport: signal(null), currentYearState: signal('loading'), refresh: vi.fn() } },
        { provide: Router, useValue: { navigate: vi.fn() } },
        { provide: MatDialog, useValue: {} },
        { provide: MatSnackBar, useValue: {} },
      ],
    });
    fixture = TestBed.createComponent(DashboardComponent);
  });

  const banner = (): HTMLElement | null => fixture.nativeElement.querySelector('app-holiday-banner');

  it('rendert das Banner oberhalb des Inhalts, wenn heute Feiertag ist', () => {
    holiday.set('germanUnityDay');
    fixture.detectChanges();
    const el = banner()!;
    expect(el).toBeTruthy();
    expect(el.textContent).toContain('germanUnityDay');
    const content = fixture.nativeElement.querySelector('.dashboard-content') as HTMLElement;
    expect(el.compareDocumentPosition(content) & Node.DOCUMENT_POSITION_FOLLOWING).toBeTruthy();
  });

  it('rendert kein Banner ohne Feiertag', () => {
    fixture.detectChanges();
    expect(banner()).toBeNull();
    expect(fixture.nativeElement.querySelector('.dashboard-content')).toBeTruthy();
  });

  it('rendert kein Banner während des Ladens', () => {
    holiday.set('germanUnityDay');
    isLoading.set(true);
    fixture.detectChanges();
    expect(banner()).toBeNull();
  });
});
