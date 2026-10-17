import { TestBed, ComponentFixture } from '@angular/core/testing';
import { Component, input, output, signal } from '@angular/core';
import { MatDialog } from '@angular/material/dialog';
import { MatSnackBar } from '@angular/material/snack-bar';
import { provideTranslateService } from '@ngx-translate/core';
import { Router } from '@angular/router';
import { DashboardComponent } from './dashboard';
import { DashboardService } from './dashboard.service';
import { OpenEntryService } from './open-entry';
import { createFakeOpenEntry } from '../../shared/testing/open-entry-fake';
import { TimeInputComponent } from '../../shared/components/time-input/time-input';
import { WorkEntry, WorkEntryType } from '../../shared/models/index';

@Component({ selector: 'app-time-input', template: '' })
class TimeInputStub {
  readonly label = input<string>();
  readonly value = input<unknown>();
  readonly disabled = input<boolean>();
  readonly showClear = input<boolean>();
  readonly settle = input<boolean>(false);
  readonly timeSelected = output<Date>();
}

/** Home-Office-Toggle im Dashboard (#277). */
describe('DashboardComponent Home-Office-Toggle (#277)', () => {
  const base: WorkEntry = { id: 'x', date: new Date(2026, 5, 5), breaks: [], isManuallyEntered: false, type: WorkEntryType.Work };
  const workEntry = signal<WorkEntry>(base);
  const isSaving = signal(false);
  let setHomeOffice: ReturnType<typeof vi.fn>;
  let fixture: ComponentFixture<DashboardComponent>;

  beforeEach(() => {
    workEntry.set(base);
    isSaving.set(false);
    setHomeOffice = vi.fn().mockResolvedValue(undefined);
    TestBed.overrideComponent(DashboardComponent, {
      remove: { imports: [TimeInputComponent] },
      add: { imports: [TimeInputStub] },
    });
    TestBed.configureTestingModule({
      providers: [
        provideTranslateService(),
        { provide: DashboardService, useValue: {
          isLoading: signal(false), holidayToday: signal(null), isLoggedIn: signal(false), isSaving,
          netDuration: signal(0), grossDuration: signal(0), dailyOvertime: signal(0), totalOvertime: signal(0),
          isTimerRunning: signal(false), isBreakRunning: signal(false), expectedEndTime: signal(null),
          expectedEndTotalZero: signal(null), breaks: signal([]), workEntry, setHomeOffice,
        } },
        { provide: OpenEntryService, useValue: createFakeOpenEntry() },
        { provide: Router, useValue: { navigate: vi.fn() } },
        { provide: MatDialog, useValue: {} },
        { provide: MatSnackBar, useValue: {} },
      ],
    });
    fixture = TestBed.createComponent(DashboardComponent);
  });

  const toggle = (): HTMLElement | null => fixture.nativeElement.querySelector('mat-slide-toggle');
  const input$ = (): HTMLButtonElement => fixture.nativeElement.querySelector('mat-slide-toggle button[role="switch"]');

  it('ist bei Typ Arbeit sichtbar', () => {
    fixture.detectChanges();
    expect(toggle()).toBeTruthy();
  });

  it.each([WorkEntryType.Vacation, WorkEntryType.Sick, WorkEntryType.Holiday])('ist bei Typ %s ausgeblendet', type => {
    workEntry.set({ ...base, type });
    fixture.detectChanges();
    expect(toggle()).toBeNull();
  });

  it('zeigt den Zustand des Eintrags', () => {
    workEntry.set({ ...base, isHomeOffice: true });
    fixture.detectChanges();
    expect(input$().getAttribute('aria-checked')).toBe('true');
  });

  it('ruft svc.setHomeOffice mit dem neuen Wert', () => {
    fixture.detectChanges();
    input$().click();
    expect(setHomeOffice).toHaveBeenCalledWith(true);
  });

  it('ist während isSaving deaktiviert', () => {
    isSaving.set(true);
    fixture.detectChanges();
    expect(input$().disabled).toBe(true);
  });
});
