import { TestBed } from '@angular/core/testing';
import { of } from 'rxjs';
import { DataSyncService } from './data-sync';
import { WorkEntryService } from './work-entry';
import { OvertimeService } from './overtime';
import { SettingsService } from './settings';
import { LeaveBalanceService } from './leave-balance';
import { AuthService } from '../auth/auth';
import { DEFAULT_SETTINGS, UserSettings } from '../../shared/models/index';

describe('DataSyncService - Einstellungen', () => {
  let current: UserSettings = { ...DEFAULT_SETTINGS, vacationDaysPerYear: 25 };
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
    current = { ...DEFAULT_SETTINGS, vacationDaysPerYear: 25 };
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

  describe('bundesland (#279)', () => {
    it('übernimmt ein lokales Bundesland, wenn die Cloud keines hat', async () => {
      localStorage.setItem('user_settings', JSON.stringify({ bundesland: 'bayern' }));
      const result = await create().syncAll();
      expect(saveSettings).toHaveBeenCalledTimes(1);
      expect(saveSettings).toHaveBeenCalledWith({ ...current, bundesland: 'bayern' });
      expect(result.settingsSynced).toBe(true);
    });

    it('überschreibt kein Cloud-Bundesland (kein Save ohne weitere Felder)', async () => {
      current = { ...current, bundesland: 'hessen' };
      localStorage.setItem('user_settings', JSON.stringify({ bundesland: 'bayern' }));
      await create().syncAll();
      expect(saveSettings).not.toHaveBeenCalled();
    });

    it('behält das Cloud-Bundesland, wenn andere Felder migriert werden', async () => {
      current = { ...current, bundesland: 'hessen' };
      localStorage.setItem('user_settings', JSON.stringify({ bundesland: 'bayern', weeklyTargetHours: 35 }));
      await create().syncAll();
      expect(saveSettings).toHaveBeenCalledTimes(1);
      expect(saveSettings).toHaveBeenCalledWith({ ...current, weeklyTargetHours: 35, bundesland: 'hessen' });
    });

    it.each(['"xyz"', '""', 'null', '5'])('ignoriert ungültiges lokales Bundesland %s', async raw => {
      localStorage.setItem('user_settings', `{"bundesland":${raw}}`);
      await create().syncAll();
      expect(saveSettings).not.toHaveBeenCalled();
    });

    it('sendet bei ungültigem Bundesland + anderen Feldern nie "" als Bundesland', async () => {
      localStorage.setItem('user_settings', JSON.stringify({ bundesland: '', weeklyTargetHours: 35 }));
      await create().syncAll();
      expect(saveSettings).toHaveBeenCalledTimes(1);
      const [arg, opts] = saveSettings.mock.calls[0];
      expect(arg.bundesland).toBeNull();
      expect(opts).toBeUndefined();
    });

    it('kombiniert alle Patches in einem Aufruf', async () => {
      localStorage.setItem('user_settings', JSON.stringify({
        bundesland: 'sachsen', weeklyTargetHours: 30, workdays: [1, 2], vacationDaysPerYear: 20,
      }));
      await create().syncAll();
      expect(saveSettings).toHaveBeenCalledTimes(1);
      expect(saveSettings).toHaveBeenCalledWith({
        ...current, bundesland: 'sachsen', weeklyTargetHours: 30, workdays: [1, 2], vacationDaysPerYear: 20,
      });
    });

    it('meldet Cloud-Fehler beim Speichern', async () => {
      saveSettings.mockRejectedValue(new Error('x'));
      localStorage.setItem('user_settings', JSON.stringify({ bundesland: 'bayern' }));
      const result = await create().syncAll();
      expect(result.errors.length).toBe(1);
      expect(result.settingsSynced).toBe(false);
    });
  });
});
