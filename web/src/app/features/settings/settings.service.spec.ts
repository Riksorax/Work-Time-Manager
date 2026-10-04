import { TestBed } from '@angular/core/testing';
import { Router } from '@angular/router';
import { signal } from '@angular/core';
import { of } from 'rxjs';
import { SettingsPageService } from './settings.service';
import { AuthService } from '../../core/auth/auth';
import { ProfileService } from '../../core/services/profile';
import { SettingsService } from '../../core/services/settings';
import { OvertimeService } from '../../core/services/overtime';
import { ThemeService } from '../../core/services/theme';
import { LanguageService } from '../../core/services/language';
import { DataSyncService } from '../../core/services/data-sync';
import { WebPremiumService } from '../../core/services/web-premium';
import { LeaveBalanceService } from '../../core/services/leave-balance';
import { DashboardService } from '../dashboard/dashboard.service';
import { DEFAULT_SETTINGS, UserSettings } from '../../shared/models/index';

describe('SettingsPageService.setVacationDays', () => {
  let saveSettings: ReturnType<typeof vi.fn>;
  let refresh: ReturnType<typeof vi.fn>;
  let svc: SettingsPageService;

  beforeEach(() => {
    saveSettings = vi.fn().mockResolvedValue(undefined);
    refresh = vi.fn();
    TestBed.configureTestingModule({
      providers: [
        { provide: SettingsService, useValue: { getSettings: () => of(DEFAULT_SETTINGS), saveSettings } },
        { provide: LeaveBalanceService, useValue: { refresh } },
        { provide: AuthService, useValue: { user: signal(null) } },
        { provide: ProfileService, useValue: { isPremium: signal(false) } },
        { provide: OvertimeService, useValue: {
          getOvertime: vi.fn().mockResolvedValue(0), getLastUpdateDate: vi.fn().mockResolvedValue(null) } },
        { provide: ThemeService, useValue: { isDarkMode: signal(false) } },
        { provide: LanguageService, useValue: { locale: signal('de') } },
        { provide: DataSyncService, useValue: { isSyncing: signal(false) } },
        { provide: WebPremiumService, useValue: {
          isConfigured: signal(false), isRestoring: signal(false), isPurchasing: signal(false) } },
        { provide: DashboardService, useValue: {} },
        { provide: Router, useValue: { navigate: vi.fn() } },
      ],
    });
    svc = TestBed.inject(SettingsPageService);
  });

  it('speichert den Anspruch und lädt danach die Urlaubsübersicht neu', async () => {
    await svc.setVacationDays(25);
    expect(saveSettings).toHaveBeenCalledWith({ ...DEFAULT_SETTINGS, vacationDaysPerYear: 25 });
    expect(refresh).toHaveBeenCalledTimes(1);
  });

  it('reicht Speicherfehler weiter und lädt nicht neu', async () => {
    saveSettings.mockRejectedValue(new Error('fail'));
    await expect(svc.setVacationDays(25)).rejects.toThrow('fail');
    expect(refresh).not.toHaveBeenCalled();
  });
});

describe('SettingsPageService.setBundesland', () => {
  let saveSettings: ReturnType<typeof vi.fn>;
  let svc: SettingsPageService;

  function create(current: UserSettings): void {
    saveSettings = vi.fn().mockResolvedValue(undefined);
    TestBed.configureTestingModule({
      providers: [
        { provide: SettingsService, useValue: { getSettings: () => of(current), saveSettings } },
        { provide: LeaveBalanceService, useValue: { refresh: vi.fn() } },
        { provide: AuthService, useValue: { user: signal(null) } },
        { provide: ProfileService, useValue: { isPremium: signal(false) } },
        { provide: OvertimeService, useValue: {
          getOvertime: vi.fn().mockResolvedValue(0), getLastUpdateDate: vi.fn().mockResolvedValue(null) } },
        { provide: ThemeService, useValue: { isDarkMode: signal(false) } },
        { provide: LanguageService, useValue: { locale: signal('de') } },
        { provide: DataSyncService, useValue: { isSyncing: signal(false) } },
        { provide: WebPremiumService, useValue: {
          isConfigured: signal(false), isRestoring: signal(false), isPurchasing: signal(false) } },
        { provide: DashboardService, useValue: {} },
        { provide: Router, useValue: { navigate: vi.fn() } },
      ],
    });
    svc = TestBed.inject(SettingsPageService);
  }

  const withBayern: UserSettings = { ...DEFAULT_SETTINGS, bundesland: 'bayern', weeklyTargetHours: 35 };

  it('speichert ein Bundesland ohne clearBundesland', async () => {
    create(withBayern);
    await svc.setBundesland('sachsen');
    expect(saveSettings).toHaveBeenCalledTimes(1);
    expect(saveSettings).toHaveBeenCalledWith({ ...withBayern, bundesland: 'sachsen' });
    expect(saveSettings.mock.calls[0][1]).toBeUndefined();
  });

  it('sendet bei Abwahl clearBundesland', async () => {
    create(withBayern);
    await svc.setBundesland(null);
    expect(saveSettings).toHaveBeenCalledWith({ ...withBayern, bundesland: null }, { clearBundesland: true });
  });

  it('reicht Speicherfehler weiter', async () => {
    create(withBayern);
    saveSettings.mockRejectedValue(new Error('fail'));
    await expect(svc.setBundesland('berlin')).rejects.toThrow('fail');
  });

  it.each([['bayern', withBayern], ['null', { ...DEFAULT_SETTINGS, bundesland: null }]] as const)(
    'andere Setter senden nie clearBundesland (Bundesland %s)',
    async (_l, current) => {
      create(current);
      await svc.setTargetHours(30);
      await svc.setVacationDays(20);
      await svc.setWorkdays([1, 2]);
      await svc.saveSettings({ ...current });
      expect(saveSettings).toHaveBeenCalledTimes(4);
      for (const [arg, opts] of saveSettings.mock.calls) {
        expect(arg.bundesland).toBe(current.bundesland);
        expect(opts).toBeUndefined();
      }
    },
  );
});
