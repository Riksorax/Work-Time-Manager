import { Injectable, inject, signal } from '@angular/core';
import { firstValueFrom } from 'rxjs';
import { WorkEntryService } from './work-entry';
import { OvertimeService } from './overtime';
import { SettingsService } from './settings';
import { AuthService } from '../auth/auth';

export interface DataSyncResult {
  workEntriesSynced: number;
  overtimeSynced:    boolean;
  settingsSynced:    boolean;
  errors:            string[];
}

const LS_SETTINGS = 'user_settings';

@Injectable({ providedIn: 'root' })
export class DataSyncService {
  private readonly workEntryService = inject(WorkEntryService);
  private readonly overtimeService  = inject(OvertimeService);
  private readonly settingsService  = inject(SettingsService);
  private readonly authService      = inject(AuthService);

  private readonly _isSyncing = signal(false);
  readonly isSyncing = this._isSyncing.asReadonly();

  async syncAll(): Promise<DataSyncResult> {
    const result: DataSyncResult = {
      workEntriesSynced: 0,
      overtimeSynced:    false,
      settingsSynced:    false,
      errors:            [],
    };

    if (!this.authService.uid) {
      result.errors.push('Kein Benutzer angemeldet');
      return result;
    }

    this._isSyncing.set(true);
    try {
      // ── Arbeitseinträge ────────────────────────────────────────────────────
      const localEntries = this.workEntryService.getAllLocalEntries();
      for (const entry of localEntries) {
        try {
          await this.workEntryService.saveEntry(entry);
          result.workEntriesSynced++;
        } catch (e) {
          result.errors.push(`Eintrag ${entry.id}: ${String(e)}`);
        }
      }

      // ── Überstunden ───────────────────────────────────────────────────────
      const localOvertimeRaw = localStorage.getItem('overtime_value');
      const localMs = localOvertimeRaw ? Number(localOvertimeRaw) * 60 * 1000 : 0;
      if (localMs !== 0) {
        try {
          await this.overtimeService.saveOvertime(localMs);
          localStorage.removeItem('overtime_value');
          localStorage.removeItem('overtime_last_update');
          result.overtimeSynced = true;
        } catch (e) {
          result.errors.push(`Überstunden: ${String(e)}`);
        }
      } else {
        result.overtimeSynced = true;
      }

      // ── Einstellungen ─────────────────────────────────────────────────────
      // Nur weeklyTargetHours und workdaysPerWeek — Benachrichtigungen sind gerätespezifisch
      const localSettingsRaw = localStorage.getItem(LS_SETTINGS);
      if (localSettingsRaw) {
        try {
          const local = JSON.parse(localSettingsRaw) as Record<string, unknown>;
          const patch: Record<string, unknown> = {};
          if (typeof local['weeklyTargetHours'] === 'number') patch['weeklyTargetHours'] = local['weeklyTargetHours'];
          if (typeof local['workdaysPerWeek']   === 'number') patch['workdaysPerWeek']   = local['workdaysPerWeek'];
          if (Object.keys(patch).length > 0) {
            const current = await firstValueFrom(this.settingsService.getSettings());
            await this.settingsService.saveSettings({ ...current, ...patch });
          }
          result.settingsSynced = true;
        } catch (e) {
          result.errors.push(`Einstellungen: ${String(e)}`);
        }
      } else {
        result.settingsSynced = true;
      }
    } finally {
      this._isSyncing.set(false);
    }

    return result;
  }
}
