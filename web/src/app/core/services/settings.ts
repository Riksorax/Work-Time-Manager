import { Injectable, Injector, inject, runInInjectionContext } from '@angular/core';
import { Firestore, doc, onSnapshot } from '@angular/fire/firestore';
import { BehaviorSubject, Observable, combineLatest, switchMap } from 'rxjs';
import { AuthService } from '../auth/auth';
import { ApiClient } from './api-client';
import { WorkProfileService } from './work-profile';
import { UserSettings } from '../../shared/models';
import { profileScopedPath } from '../../shared/utils/work-profile-path.util';

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

@Injectable({ providedIn: 'root' })
export class SettingsService {
  private readonly firestore   = inject(Firestore);
  private readonly auth        = inject(AuthService);
  private readonly injector    = inject(Injector);
  private readonly api         = inject(ApiClient);
  private readonly workProfile = inject(WorkProfileService);

  private readonly defaultSettings: UserSettings = {
    weeklyTargetHours: 40,
    workdays: [1, 2, 3, 4, 5],
    notificationsEnabled: false,
    notificationTime: '08:00',
    notificationDays: [1, 2, 3, 4, 5],
    notifyWorkStart: false,
    notifyWorkEnd: false,
    notifyBreaks: false,
  };

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
              snap => observer.next({
                ...this.defaultSettings,
                ...migrateWorkdays((snap.data() ?? {}) as Partial<UserSettings>),
              }),
              err  => observer.error(err),
            );
          });
          return () => unsub?.();
        });
      })
    );
  }

  async saveSettings(settings: UserSettings): Promise<void> {
    // Eingeloggt: Schreibvorgang über die API; getSettings bleibt onSnapshot (Hybrid).
    if (this.auth.uid) await this.api.saveSettings(settings, this.workProfile.activeProfileIdForApi);
    else               this._localSave(settings);
  }

  // ── localStorage ─────────────────────────────────────────────────────────

  private _localGet(): UserSettings {
    const raw = localStorage.getItem(LS_KEY);
    if (!raw) return { ...this.defaultSettings };
    try {
      return { ...this.defaultSettings, ...migrateWorkdays(JSON.parse(raw) as Partial<UserSettings>) };
    } catch { return { ...this.defaultSettings }; }
  }

  private _localSave(settings: UserSettings): void {
    localStorage.setItem(LS_KEY, JSON.stringify(settings));
    this._local$.next(settings);
  }
}
