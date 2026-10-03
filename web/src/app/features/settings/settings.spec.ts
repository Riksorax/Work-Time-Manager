import { TestBed } from '@angular/core/testing';
import { signal } from '@angular/core';
import { MatDialog } from '@angular/material/dialog';
import { MatSnackBar } from '@angular/material/snack-bar';
import { TranslateService } from '@ngx-translate/core';
import { of } from 'rxjs';
import { SettingsComponent } from './settings';
import { SettingsPageService } from './settings.service';
import { LeaveBalanceService } from '../../core/services/leave-balance';
import { DEFAULT_SETTINGS } from '../../shared/models/index';

describe('SettingsComponent.openEditVacationDaysDialog', () => {
  let setVacationDays: ReturnType<typeof vi.fn>;
  let open: ReturnType<typeof vi.fn>;
  let snackOpen: ReturnType<typeof vi.fn>;
  let cmp: SettingsComponent;

  function create(dialogResult: unknown): void {
    open = vi.fn(() => ({ afterClosed: () => of(dialogResult) }));
    TestBed.overrideComponent(SettingsComponent, { set: { template: '', imports: [] } });
    TestBed.configureTestingModule({
      providers: [
        { provide: SettingsPageService, useValue: {
          settings: signal({ ...DEFAULT_SETTINGS, vacationDaysPerYear: 28 }), setVacationDays } },
        { provide: MatDialog, useValue: { open } },
        { provide: MatSnackBar, useValue: { open: snackOpen } },
        { provide: TranslateService, useValue: { instant: (k: string) => k } },
        { provide: LeaveBalanceService, useValue: {} },
      ],
    });
    cmp = TestBed.createComponent(SettingsComponent).componentInstance;
  }

  beforeEach(() => {
    setVacationDays = vi.fn().mockResolvedValue(undefined);
    snackOpen = vi.fn();
  });

  it('übergibt den aktuellen Anspruch, speichert und zeigt Erfolg', async () => {
    create({ days: 25 });
    await cmp.openEditVacationDaysDialog();
    expect(open.mock.calls[0][1].data).toEqual({ currentDays: 28 });
    expect(setVacationDays).toHaveBeenCalledWith(25);
    expect(snackOpen.mock.calls[0][0]).toBe('settings.vacationDaysSaved');
  });

  it('tut bei Abbruch nichts', async () => {
    create(undefined);
    await cmp.openEditVacationDaysDialog();
    expect(setVacationDays).not.toHaveBeenCalled();
    expect(snackOpen).not.toHaveBeenCalled();
  });

  it('zeigt bei Speicherfehler nur die Fehler-Snackbar', async () => {
    setVacationDays.mockRejectedValue(new Error('fail'));
    create({ days: 25 });
    await cmp.openEditVacationDaysDialog();
    expect(snackOpen).toHaveBeenCalledTimes(1);
    expect(snackOpen.mock.calls[0][0]).toBe('settings.vacationDaysSaveError');
  });
});
