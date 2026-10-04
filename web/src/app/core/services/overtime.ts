import { Injectable, inject } from '@angular/core';
import { AuthService } from '../auth/auth';
import { ApiClient } from './api-client';
import { WorkProfileService } from './work-profile';
import { profileIdForApi } from '../../shared/utils/work-profile-path.util';
import { toStoredMinutes } from '../../shared/utils/time-precision.util';

const LS_OVERTIME    = 'overtime_value';
const LS_LAST_UPDATE = 'overtime_last_update';

@Injectable({ providedIn: 'root' })
export class OvertimeService {
  private readonly auth        = inject(AuthService);
  private readonly api         = inject(ApiClient);
  private readonly workProfile = inject(WorkProfileService);

  /**
   * Alle drei Profil-Methoden nehmen optional eine Profil-ID (`'default'` oder ID, #380). Ohne Argument gilt das
   * aktive Profil zum Aufrufzeitpunkt. Anonym wird das Argument ignoriert (localStorage kennt nur das Standard-Profil).
   */
  async getOvertime(profileId?: string): Promise<number> {
    if (this.auth.uid) return this.api.getOvertimeMs(this._apiProfile(profileId));
    return this._localGetOvertime();
  }

  async getLastUpdateDate(profileId?: string): Promise<Date | null> {
    if (this.auth.uid) return this.api.getOvertimeLastUpdate(this._apiProfile(profileId));
    return this._localGetLastUpdate();
  }

  async saveOvertime(ms: number, profileId?: string): Promise<void> {
    if (this.auth.uid) {
      // Backend setzt lastUpdated automatisch beim Speichern.
      // Auf Minuten gerundet wird im ApiClient — das Backend nimmt bereits int entgegen.
      await this.api.saveOvertimeMs(ms, this._apiProfile(profileId));
    } else {
      localStorage.setItem(LS_OVERTIME, String(toStoredMinutes(ms)));
    }
  }

  async saveLastUpdateDate(date: Date): Promise<void> {
    if (this.auth.uid) {
      // No-op: lastUpdated wird vom Backend bereits in saveOvertime gesetzt (= jetzt).
      return;
    }
    localStorage.setItem(LS_LAST_UPDATE, date.toISOString());
  }

  private _apiProfile(profileId: string | undefined): string | undefined {
    return profileId === undefined ? this.workProfile.activeProfileIdForApi : profileIdForApi(profileId);
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
