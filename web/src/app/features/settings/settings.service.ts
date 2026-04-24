import { Injectable, computed, effect, inject, signal } from '@angular/core';
import { toSignal } from '@angular/core/rxjs-interop';
import { Router } from '@angular/router';
import { AuthService } from '../../core/auth/auth';
import { ProfileService } from '../../core/services/profile';
import { SettingsService } from '../../core/services/settings';
import { OvertimeService } from '../../core/services/overtime';
import { ThemeService } from '../../core/services/theme';
import { DataSyncService, DataSyncResult } from '../../core/services/data-sync';
import { UserSettings } from '../../shared/models/index';

const DEFAULT_SETTINGS: UserSettings = {
  weeklyTargetHours: 40,
  workdaysPerWeek: 5,
  notificationsEnabled: false,
  notificationTime: '08:00',
  notificationDays: [1, 2, 3, 4, 5],
  notifyWorkStart: false,
  notifyWorkEnd: false,
  notifyBreaks: false,
};

@Injectable({ providedIn: 'root' })
export class SettingsPageService {
  private readonly coreSettings  = inject(SettingsService);
  private readonly authService   = inject(AuthService);
  private readonly profileService = inject(ProfileService);
  private readonly overtimeSvc   = inject(OvertimeService);
  private readonly themeSvc      = inject(ThemeService);
  private readonly dataSyncSvc   = inject(DataSyncService);
  private readonly router        = inject(Router);

  // ── Auth / Premium ────────────────────────────────────────────────────────
  readonly user       = this.authService.user;
  readonly isLoggedIn = computed(() => !!this.authService.user());
  readonly isPremium  = this.profileService.isPremium;

  // ── Loading ───────────────────────────────────────────────────────────────
  private readonly _isLoading = signal(true);
  readonly isLoading = this._isLoading.asReadonly();

  // ── Settings ──────────────────────────────────────────────────────────────
  readonly settings = toSignal(
    this.coreSettings.getSettings(),
    { initialValue: DEFAULT_SETTINGS }
  );

  // ── Overtime ──────────────────────────────────────────────────────────────
  private readonly _overtimeMs         = signal(0);
  private readonly _lastOvertimeUpdate = signal<Date | null>(null);
  readonly overtimeMs         = this._overtimeMs.asReadonly();
  readonly lastOvertimeUpdate = this._lastOvertimeUpdate.asReadonly();

  // ── Theme ─────────────────────────────────────────────────────────────────
  readonly isDarkMode = this.themeSvc.isDarkMode;

  // ── Sync ──────────────────────────────────────────────────────────────────
  readonly isSyncing = this.dataSyncSvc.isSyncing;

  // ── Computed ──────────────────────────────────────────────────────────────
  readonly dailyTargetHours = computed(() => {
    const s = this.settings();
    if (!s || s.workdaysPerWeek === 0) return '0.0';
    return (s.weeklyTargetHours / s.workdaysPerWeek).toFixed(1);
  });

  constructor() {
    effect(() => {
      // Neu laden wenn Auth-Status wechselt
      this.authService.user();
      this._loadOvertime();
    });

    effect(() => {
      if (this.settings()) this._isLoading.set(false);
    });
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  async saveSettings(s: UserSettings): Promise<void> {
    await this.coreSettings.saveSettings(s);
  }

  async setTargetHours(hours: number): Promise<void> {
    const current = this.settings();
    await this.coreSettings.saveSettings({ ...current, weeklyTargetHours: hours });
  }

  async setWorkdays(days: number): Promise<void> {
    const current = this.settings();
    await this.coreSettings.saveSettings({ ...current, workdaysPerWeek: days });
  }

  async setOvertime(ms: number): Promise<void> {
    await this.overtimeSvc.saveOvertime(ms);
    this._overtimeMs.set(ms);
    this._lastOvertimeUpdate.set(new Date());
    await this.overtimeSvc.saveLastUpdateDate(new Date());
  }

  setTheme(dark: boolean): void {
    this.themeSvc.setTheme(dark);
  }

  async sync(): Promise<DataSyncResult> {
    return this.dataSyncSvc.syncAll();
  }

  async logout(): Promise<void> {
    await this.authService.signOut();
  }

  async deleteAccount(): Promise<void> {
    await this.authService.deleteAccount();
  }

  navigateToLogin(): void {
    this.router.navigate(['/auth/login']);
  }

  // ── Private ───────────────────────────────────────────────────────────────

  private _loadOvertime(): void {
    this.overtimeSvc.getOvertime().then(ms => this._overtimeMs.set(ms));
    this.overtimeSvc.getLastUpdateDate().then(d => this._lastOvertimeUpdate.set(d));
  }
}
