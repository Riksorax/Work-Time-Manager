import { Injectable, computed, effect, inject, signal, untracked } from '@angular/core';
import { toSignal } from '@angular/core/rxjs-interop';
import { Router } from '@angular/router';
import { AuthService } from '../../core/auth/auth';
import { ProfileService } from '../../core/services/profile';
import { SettingsService } from '../../core/services/settings';
import { OvertimeService } from '../../core/services/overtime';
import { WorkProfileService } from '../../core/services/work-profile';
import { ThemeService } from '../../core/services/theme';
import { LanguageService } from '../../core/services/language';
import { DataSyncService, DataSyncResult } from '../../core/services/data-sync';
import { WebPremiumService } from '../../core/services/web-premium';
import { LeaveBalanceService } from '../../core/services/leave-balance';
import { DashboardService } from '../dashboard/dashboard.service';
import { Bundesland, DEFAULT_SETTINGS, UserSettings } from '../../shared/models/index';
import { normalizeWorkdays } from '../../shared/utils/workdays.util';

@Injectable({ providedIn: 'root' })
export class SettingsPageService {
  private readonly coreSettings   = inject(SettingsService);
  private readonly leave          = inject(LeaveBalanceService);
  private readonly authService    = inject(AuthService);
  private readonly profileService = inject(ProfileService);
  private readonly overtimeSvc    = inject(OvertimeService);
  private readonly workProfile    = inject(WorkProfileService);
  private readonly themeSvc       = inject(ThemeService);
  private readonly languageSvc    = inject(LanguageService);
  private readonly dataSyncSvc    = inject(DataSyncService);
  private readonly premiumSvc     = inject(WebPremiumService);
  private readonly dashboardSvc   = inject(DashboardService);
  private readonly router         = inject(Router);

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
  /** Profil, dessen Saldo gerade angezeigt wird (#380): nur dorthin darf `setOvertime` schreiben. */
  private _overtimeProfileId = this.workProfile.activeProfileId();
  private _overtimeGen = 0;

  // ── Theme ─────────────────────────────────────────────────────────────────
  readonly isDarkMode = this.themeSvc.isDarkMode;

  // ── Sprache ───────────────────────────────────────────────────────────────
  readonly locale = this.languageSvc.locale;

  // ── Sync ──────────────────────────────────────────────────────────────────
  readonly isSyncing = this.dataSyncSvc.isSyncing;

  // ── Premium ───────────────────────────────────────────────────────────────
  readonly isRcConfigured = this.premiumSvc.isConfigured;
  readonly isRestoring    = this.premiumSvc.isRestoring;
  readonly isPurchasing   = this.premiumSvc.isPurchasing;

  // ── Computed ──────────────────────────────────────────────────────────────
  readonly dailyTargetHours = computed(() => {
    const s = this.settings();
    if (!s || s.workdays.length === 0) return '0.0';
    return (s.weeklyTargetHours / s.workdays.length).toFixed(1);
  });

  constructor() {
    effect(() => {
      // Neu laden wenn Auth-Status oder aktives Arbeitszeit-Profil wechselt (#380)
      this.authService.user();
      const profileId = this.workProfile.activeProfileId();
      untracked(() => this._loadOvertime(profileId));
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

  /** Setzt das Bundesland (#279). Nur die explizite Abwahl (`null`) sendet über `clearBundesland` ein `""` ans Backend. */
  async setBundesland(bundesland: Bundesland | null): Promise<void> {
    const current = this.settings();
    if (bundesland === null) await this.coreSettings.saveSettings({ ...current, bundesland: null }, { clearBundesland: true });
    else                     await this.coreSettings.saveSettings({ ...current, bundesland });
  }

  async setVacationDays(days: number): Promise<void> {
    const current = this.settings();
    await this.coreSettings.saveSettings({ ...current, vacationDaysPerYear: days });
    this.leave.refresh();
  }

  async setWorkdays(days: number[]): Promise<void> {
    const current = this.settings();
    await this.coreSettings.saveSettings({ ...current, workdays: normalizeWorkdays(days) });
  }

  async setOvertime(ms: number): Promise<void> {
    // Dashboard live aktualisieren + Basis-Wert speichern (ohne lastUpdated zu setzen).
    // Der eingegebene Wert ist die Basis aus Vortagen, nicht der heutige Gesamtstand.
    // Geschrieben wird in das Profil, dessen Saldo der Nutzer sieht (#380), nie blind ins gerade aktive.
    const profileId = this._overtimeProfileId;
    await this.dashboardSvc.updateInitialOvertime(ms, profileId);
    if (profileId === this._overtimeProfileId) this._overtimeMs.set(ms);
  }

  setTheme(dark: boolean): void {
    this.themeSvc.setTheme(dark);
  }

  setLocale(locale: string): void {
    this.languageSvc.setLocale(locale);
  }

  async sync(): Promise<DataSyncResult> {
    return this.dataSyncSvc.syncAll();
  }

  async restorePurchases(): Promise<boolean> {
    return this.premiumSvc.restorePurchases();
  }

  async presentPaywall(): Promise<boolean> {
    return this.premiumSvc.presentPaywall();
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

  /** Lädt Saldo + Datum des Profils; eine überholte Antwort (Profil/Login gewechselt) wird verworfen. */
  private _loadOvertime(profileId: string): void {
    const gen = ++this._overtimeGen;
    void Promise.all([
      this.overtimeSvc.getOvertime(profileId),
      this.overtimeSvc.getLastUpdateDate(profileId),
    ]).then(([ms, lastUpdate]) => {
      if (gen !== this._overtimeGen) return;
      this._overtimeProfileId = profileId;
      this._overtimeMs.set(ms);
      this._lastOvertimeUpdate.set(lastUpdate);
    });
  }
}
