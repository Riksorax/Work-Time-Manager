import { Injectable, inject } from '@angular/core';
import { AuthService } from '../auth/auth';
import { ApiClient } from './api-client';

const LS_OVERTIME    = 'overtime_value';
const LS_LAST_UPDATE = 'overtime_last_update';

@Injectable({ providedIn: 'root' })
export class OvertimeService {
  private readonly auth = inject(AuthService);
  private readonly api  = inject(ApiClient);

  async getOvertime(): Promise<number> {
    if (this.auth.uid) return this.api.getOvertimeMs();
    return this._localGetOvertime();
  }

  async getLastUpdateDate(): Promise<Date | null> {
    if (this.auth.uid) return this.api.getOvertimeLastUpdate();
    return this._localGetLastUpdate();
  }

  async saveOvertime(ms: number): Promise<void> {
    if (this.auth.uid) {
      // Backend setzt lastUpdated automatisch beim Speichern.
      await this.api.saveOvertimeMs(ms);
    } else {
      localStorage.setItem(LS_OVERTIME, String(Math.round(ms / 60000)));
    }
  }

  async saveLastUpdateDate(date: Date): Promise<void> {
    if (this.auth.uid) {
      // No-op: lastUpdated wird vom Backend bereits in saveOvertime gesetzt (= jetzt).
      return;
    }
    localStorage.setItem(LS_LAST_UPDATE, date.toISOString());
  }

  // ─── localStorage ──────────────────────────────────────────────────────────

  private _localGetOvertime(): number {
    const raw = localStorage.getItem(LS_OVERTIME);
    return raw ? Number(raw) * 60 * 1000 : 0;
  }

  private _localGetLastUpdate(): Date | null {
    const raw = localStorage.getItem(LS_LAST_UPDATE);
    return raw ? new Date(raw) : null;
  }
}
