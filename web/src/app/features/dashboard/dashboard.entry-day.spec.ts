import { TestBed } from '@angular/core/testing';
import { computed, signal } from '@angular/core';
import { MatDialog } from '@angular/material/dialog';
import { MatSnackBar } from '@angular/material/snack-bar';
import { provideTranslateService } from '@ngx-translate/core';
import { Router } from '@angular/router';
import { of } from 'rxjs';
import { DashboardComponent } from './dashboard';
import { DashboardService } from './dashboard.service';
import { OpenEntryService } from './open-entry';
import { createFakeOpenEntry } from '../../shared/testing/open-entry-fake';
import { toDateKey } from '../../shared/utils/german-holidays.util';
import { Break, WorkEntry, WorkEntryType } from '../../shared/models/index';

/**
 * Zonenunabhängig (#407, Block B): der Pausen-Dialog erhält als `entryDate` den Kalendertag des Eintrags (`entryDay`), nicht
 * `entry.date`. Fixture: `id` Montag 05.10.2026, `date` Sonntag 04.10. (wie nach einer Lesegrenze, die den Vortag lieferte).
 */
describe('DashboardComponent: entryDate des Pausen-Dialogs (#407)', () => {
  const pause: Break = {
    id: 'b1', name: 'Pause 1', start: new Date(2026, 9, 5, 9, 0), end: new Date(2026, 9, 5, 9, 15), isAutomatic: false,
  };
  const inconsistent: WorkEntry = {
    id: '2026-10-05', date: new Date(2026, 9, 4), workStart: new Date(2026, 9, 5, 8, 0), breaks: [pause],
    isManuallyEntered: false, type: WorkEntryType.Work,
  };

  it('onEditBreak übergibt den Tag der id (05.10.), nicht den Sonntag aus date', () => {
    const workEntry = signal<WorkEntry>(inconsistent);
    const dialogOpen = vi.fn(() => ({ afterClosed: () => of(undefined) }));
    TestBed.configureTestingModule({
      providers: [
        provideTranslateService(),
        { provide: DashboardService, useValue: {
          isLoading: signal(false), holidayToday: signal(null), isLoggedIn: signal(false), isSaving: signal(false),
          netDuration: signal(0), grossDuration: signal(0), dailyOvertime: signal(0), totalOvertime: signal(0),
          isTimerRunning: signal(true), isBreakRunning: signal(false), expectedEndTime: signal(null),
          expectedEndTotalZero: signal(null), breaks: computed(() => workEntry().breaks), workEntry,
        } },
        { provide: OpenEntryService, useValue: createFakeOpenEntry() },
        { provide: Router, useValue: { navigate: vi.fn() } },
        { provide: MatDialog, useValue: { open: dialogOpen } },
        { provide: MatSnackBar, useValue: { open: vi.fn() } },
      ],
    });
    const component = TestBed.createComponent(DashboardComponent).componentInstance;

    component.onEditBreak(pause);

    expect(dialogOpen).toHaveBeenCalledTimes(1);
    const data = (dialogOpen.mock.calls[0] as unknown as [unknown, { data: { break: Break; entryDate: Date } }])[1].data;
    expect(data.break).toBe(pause);
    expect(toDateKey(data.entryDate)).toBe('2026-10-05');
    expect(data.entryDate.getHours()).toBe(0);
    TestBed.resetTestingModule();
  });
});
