import { Injectable, Injector, inject, runInInjectionContext } from '@angular/core';
import { Firestore, doc, onSnapshot } from '@angular/fire/firestore';
import { BehaviorSubject, Observable, combineLatest, switchMap } from 'rxjs';
import { AuthService } from '../auth/auth';
import { ApiClient } from './api-client';
import { WorkProfileService } from './work-profile';
import { DEFAULT_SETTINGS, UserSettings } from '../../shared/models';
import { normalizeBundesland } from '../../shared/utils/bundesland.util';
import { normalizeVacationDays } from '../../shared/utils/vacation-days.util';
import { normalizeWorkdays } from '../../shared/utils/workdays.util';
import { profileIdForApi, profileScopedPath } from '../../shared/utils/work-profile-path.util';

const LS_KEY = 'user_settings';

/**
 * Migriert das alte `workdaysPerWeek`-Feld (Anzahl) in das neue `workdays`-
 * Feld (konkrete ISO-Wochentage), damit bestehende Nutzer ihr bisheriges
 * Verhalten ("erste N Tage ab Montag") behalten. Siehe #217.
 */
function migrateWorkdays(raw: Partial<UserSettings> & { workdaysPerWeek?: number }): Partial<UserSettings> {
  if (raw.workdays == null && typeof raw.workdaysPerWeek === 'number') {
    const count = Math.min(Math.max(raw.workdaysPerWeek, 0), 7);
    return { ...raw, workdays: Array.from({ length: count }, (_, i) => i + 1) };
  }
  return raw;
}

/** Merged Rohdaten (Firestore/localStorage) mit Defaults und normalisiert den Urlaubsanspruch. */
function mergeSettings(raw: Partial<UserSettings> & { workdaysPerWeek?: number }): UserSettings {
  const merged = { ...DEFAULT_SETTINGS, ...migrateWorkdays(raw) };
  return {
    ...merged,
    // Heilt bereits gespeicherte Duplikate ([1,1,2,2,…], Fehler im Arbeitstage-Dialog), die das tägliche Soll verfälschten.
    workdays: normalizeWorkdays(merged.workdays),
    vacationDaysPerYear: normalizeVacationDays(raw.vacationDaysPerYear),
    bundesland: normalizeBundesland(raw.bundesland),
  };
}

@Injectable({ providedIn: 'root' })
export class SettingsService {
  private readonly firestore   = inject(Firestore);
  private readonly auth        = inject(AuthService);
  private readonly injector    = inject(Injector);
  private readonly api         = inject(ApiClient);
  private readonly workProfile = inject(WorkProfileService);

  private readonly _local$ = new BehaviorSubject<UserSettings>(this._localGet());

  getSettings(): Observable<UserSettings> {
    return combineLatest([this.auth.user$, this.workProfile.activeProfileId$]).pipe(
      switchMap(([user, profileId]) => {
        if (!user) return this._local$.asObservable();

        return new Observable<UserSettings>(observer => {
          let unsub: (() => void) | undefined;
          runInInjectionContext(this.injector, () => {
            const ref = doc(this.firestore, `${profileScopedPath(user.uid, 'settings', profileId)}/current`);
            unsub = onSnapshot(ref,
              snap => observer.next(mergeSettings((snap.data() ?? {}) as Partial<UserSettings>)),
              err  => observer.error(err),
            );
          });
          return () => unsub?.();
        });
      })
    );
  }

  /**
   * Einmaliger Abruf der Einstellungen eines festen Profils (#385): eingeloggt `GET /settings` mit explizitem Profil
   * (kein Lag-Fenster des Profil-Observables), ausgeloggt localStorage. Fehler werden geworfen. `getSettings()` bleibt
   * für reaktive Aufrufer unverändert.
   */
  async getSettingsOnce(profileId?: string): Promise<UserSettings> {
    if (!this.auth.uid) return this._localGet();
    const raw = await this.api.getSettings(
      profileId === undefined ? this.workProfile.activeProfileIdForApi : profileIdForApi(profileId),
    );
    return mergeSettings((raw ?? {}) as Partial<UserSettings>);
  }

  /** `opts.clearBundesland`: nur bei expliziter Abwahl, sendet `""` ans Backend (Details `ApiClient.saveSettings`). */
  async saveSettings(settings: UserSettings, opts?: { clearBundesland?: boolean }): Promise<void> {
    // Eingeloggt: Schreibvorgang über die API; getSettings bleibt onSnapshot (Hybrid).
    if (this.auth.uid) await this.api.saveSettings(settings, this.workProfile.activeProfileIdForApi, opts);
    else               this._localSave(settings);
  }

  // ── localStorage ─────────────────────────────────────────────────────────

  private _localGet(): UserSettings {
    const raw = localStorage.getItem(LS_KEY);
    if (!raw) return { ...DEFAULT_SETTINGS };
    try {
      return mergeSettings(JSON.parse(raw) as Partial<UserSettings>);
    } catch { return { ...DEFAULT_SETTINGS }; }
  }

  private _localSave(settings: UserSettings): void {
    localStorage.setItem(LS_KEY, JSON.stringify(settings));
    this._local$.next(settings);
  }
}
