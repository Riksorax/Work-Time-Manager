import { Injectable, inject, signal } from '@angular/core';
import { WorkEntryService } from './work-entry';
import { OvertimeService } from './overtime';
import { AuthService } from '../auth/auth';

export interface DataSyncResult {
  workEntriesSynced: number;
  overtimeSynced: boolean;
  errors: string[];
}

@Injectable({ providedIn: 'root' })
export class DataSyncService {
  private readonly workEntryService = inject(WorkEntryService);
  private readonly overtimeService  = inject(OvertimeService);
  private readonly authService      = inject(AuthService);

  private readonly _isSyncing = signal(false);
  readonly isSyncing = this._isSyncing.asReadonly();

  async syncAll(): Promise<DataSyncResult> {
    const result: DataSyncResult = { workEntriesSynced: 0, overtimeSynced: false, errors: [] };

    if (!this.authService.uid) {
      result.errors.push('Kein Benutzer angemeldet');
      return result;
    }

    this._isSyncing.set(true);
    try {
      // ── Arbeitseinträge ───────────────────────────���────────────────────────
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
      // Lokaler Wert: direkt aus localStorage (ohne Auth-Switch)
      const localOvertimeRaw = localStorage.getItem('overtime_value');
      const localMs = localOvertimeRaw ? Number(localOvertimeRaw) * 60 * 1000 : 0;
      if (localMs !== 0) {
        try {
          await this.overtimeService.saveOvertime(localMs);
          // Lokalen Wert nach erfolgreichem Sync zurücksetzen
          localStorage.removeItem('overtime_value');
          localStorage.removeItem('overtime_last_update');
          result.overtimeSynced = true;
        } catch (e) {
          result.errors.push(`Überstunden: ${String(e)}`);
        }
      } else {
        result.overtimeSynced = true;
      }
    } finally {
      this._isSyncing.set(false);
    }

    return result;
  }
}
