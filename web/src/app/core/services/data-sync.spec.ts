import { TestBed } from '@angular/core/testing';
import { of } from 'rxjs';
import { DataSyncService } from './data-sync';
import { WorkEntryService } from './work-entry';
import { OvertimeService } from './overtime';
import { SettingsService } from './settings';
import { LeaveBalanceService } from './leave-balance';
import { AuthService } from '../auth/auth';
import { DEFAULT_SETTINGS } from '../../shared/models/index';

describe('DataSyncService - Einstellungen', () => {
  const current = { ...DEFAULT_SETTINGS, vacationDaysPerYear: 25 };
  let saveSettings: ReturnType<typeof vi.fn>;
  let refresh: ReturnType<typeof vi.fn>;
  let uid: string | null;

  function create(): DataSyncService {
    TestBed.configureTestingModule({
      providers: [
        { provide: WorkEntryService, useValue: { getAllLocalEntries: () => [], saveEntry: vi.fn() } },
        { provide: OvertimeService, useValue: { saveOvertime: vi.fn() } },
        { provide: SettingsService, useValue: { getSettings: () => of(current), saveSettings } },
        { provide: AuthService, useValue: { get uid() { return uid; } } },
        { provide: LeaveBalanceService, useValue: { refresh } },
      ],
    });
    return TestBed.inject(DataSyncService);
  }

  beforeEach(() => {
    localStorage.clear();
    saveSettings = vi.fn().mockResolvedValue(undefined);
    refresh = vi.fn();
    uid = 'u1';
  });
  afterEach(() => localStorage.clear());

  it('migriert einen abweichenden lokalen Urlaubsanspruch', async () => {
    localStorage.setItem('user_settings', JSON.stringify({ vacationDaysPerYear: 20 }));
    await create().syncAll();
    expect(saveSettings).toHaveBeenCalledWith({ ...current, vacationDaysPerYear: 20 });
  });

  it('migriert den Default 30 nicht (kein Save ohne weitere Felder)', async () => {
    localStorage.setItem('user_settings', JSON.stringify({ vacationDaysPerYear: 30 }));
    await create().syncAll();
    expect(saveSettings).not.toHaveBeenCalled();
  });

  it.each(['"x"', '400', '2.5'])('ignoriert ungültigen Wert %s', async raw => {
    localStorage.setItem('user_settings', `{"vacationDaysPerYear":${raw}}`);
    await create().syncAll();
    expect(saveSettings).not.toHaveBeenCalled();
  });

  it('migriert weeklyTargetHours und workdays weiterhin', async () => {
    localStorage.setItem('user_settings', JSON.stringify({ weeklyTargetHours: 35, workdays: [1, 2, 3] }));
    await create().syncAll();
    expect(saveSettings).toHaveBeenCalledWith({ ...current, weeklyTargetHours: 35, workdays: [1, 2, 3] });
  });

  it('ruft refresh() genau einmal am Ende auf, auch bei Teilfehlern', async () => {
    saveSettings.mockRejectedValue(new Error('x'));
    localStorage.setItem('user_settings', JSON.stringify({ vacationDaysPerYear: 20 }));
    const result = await create().syncAll();
    expect(result.errors.length).toBe(1);
    expect(refresh).toHaveBeenCalledTimes(1);
  });

  it('ruft ohne uid kein refresh() auf', async () => {
    uid = null;
    await create().syncAll();
    expect(refresh).not.toHaveBeenCalled();
  });
});
