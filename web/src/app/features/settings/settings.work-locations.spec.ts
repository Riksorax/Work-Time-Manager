import { TestBed } from '@angular/core/testing';
import { signal } from '@angular/core';
import { MatDialog } from '@angular/material/dialog';
import { MatSnackBar } from '@angular/material/snack-bar';
import { TranslateService } from '@ngx-translate/core';
import { of } from 'rxjs';
import { SettingsComponent } from './settings';
import { SettingsPageService } from './settings.service';
import { LeaveBalanceService } from '../../core/services/leave-balance';
import { AuthService } from '../../core/auth/auth';
import { ProfileService } from '../../core/services/profile';
import { SettingsService } from '../../core/services/settings';
import { OvertimeService } from '../../core/services/overtime';
import { ThemeService } from '../../core/services/theme';
import { LanguageService } from '../../core/services/language';
import { DataSyncService } from '../../core/services/data-sync';
import { WebPremiumService } from '../../core/services/web-premium';
import { WorkProfileService } from '../../core/services/work-profile';
import { createFakeWorkProfile } from '../../shared/testing/work-profile-fake';
import { DashboardService } from '../dashboard/dashboard.service';
import { Router } from '@angular/router';
import { DEFAULT_SETTINGS } from '../../shared/models/index';

describe('SettingsPageService: Dashboard-Anzeige (#526)', () => {
  let saveSettings: ReturnType<typeof vi.fn>;
  let svc: SettingsPageService;

  beforeEach(() => {
    saveSettings = vi.fn().mockResolvedValue(undefined);
    TestBed.configureTestingModule({
      providers: [
        { provide: SettingsService, useValue: { getSettings: () => of(DEFAULT_SETTINGS), saveSettings } },
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
        { provide: WorkProfileService, useValue: createFakeWorkProfile() },
        { provide: DashboardService, useValue: {} },
        { provide: Router, useValue: { navigate: vi.fn() } },
      ],
    });
    svc = TestBed.inject(SettingsPageService);
  });

  it('Arbeitsort einschalten ändert nur dieses Feld', async () => {
    await svc.setShowWorkLocationOnDashboard(true);
    expect(saveSettings).toHaveBeenCalledWith({ ...DEFAULT_SETTINGS, showWorkLocationOnDashboard: true });
  });

  it('Home-Office ausschalten ändert nur dieses Feld', async () => {
    await svc.setShowHomeOfficeOnDashboard(false);
    expect(saveSettings).toHaveBeenCalledWith({ ...DEFAULT_SETTINGS, showHomeOfficeOnDashboard: false });
  });
});

describe('SettingsComponent: Dashboard-Anzeige (#526)', () => {
  let setWork: ReturnType<typeof vi.fn>;
  let setHome: ReturnType<typeof vi.fn>;
  let snackOpen: ReturnType<typeof vi.fn>;
  let cmp: SettingsComponent;

  beforeEach(() => {
    setWork = vi.fn().mockResolvedValue(undefined);
    setHome = vi.fn().mockResolvedValue(undefined);
    snackOpen = vi.fn();
    TestBed.overrideComponent(SettingsComponent, { set: { template: '', imports: [] } });
    TestBed.configureTestingModule({
      providers: [
        { provide: SettingsPageService, useValue: {
          settings: signal({ ...DEFAULT_SETTINGS }),
          setShowWorkLocationOnDashboard: setWork, setShowHomeOfficeOnDashboard: setHome } },
        { provide: MatDialog, useValue: {} },
        { provide: MatSnackBar, useValue: { open: snackOpen } },
        { provide: TranslateService, useValue: { instant: (k: string) => k } },
        { provide: LeaveBalanceService, useValue: {} },
      ],
    });
    cmp = TestBed.createComponent(SettingsComponent).componentInstance;
  });

  it('Schalter rufen den Service mit dem neuen Wert', async () => {
    await cmp.onShowWorkLocationChange(true);
    await cmp.onShowHomeOfficeChange(false);
    expect(setWork).toHaveBeenCalledWith(true);
    expect(setHome).toHaveBeenCalledWith(false);
    expect(snackOpen).not.toHaveBeenCalled();
  });

  it('Speicherfehler zeigt die Fehler-Snackbar', async () => {
    setWork.mockRejectedValue(new Error('fail'));
    await cmp.onShowWorkLocationChange(true);
    expect(snackOpen.mock.calls[0][0]).toBe('settings.dashboardDisplay.saveError');
  });
});
