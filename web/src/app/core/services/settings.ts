import { Injectable, Injector, inject, runInInjectionContext } from '@angular/core';
import { Firestore, doc, onSnapshot, setDoc } from '@angular/fire/firestore';
import { BehaviorSubject, Observable, switchMap } from 'rxjs';
import { AuthService } from '../auth/auth';
import { UserSettings } from '../../shared/models';

const LS_KEY = 'user_settings';

@Injectable({ providedIn: 'root' })
export class SettingsService {
  private readonly firestore = inject(Firestore);
  private readonly auth      = inject(AuthService);
  private readonly injector  = inject(Injector);

  private readonly defaultSettings: UserSettings = {
    weeklyTargetHours: 40,
    workdaysPerWeek: 5,
    notificationsEnabled: false,
    notificationTime: '08:00',
    notificationDays: [1, 2, 3, 4, 5],
    notifyWorkStart: false,
    notifyWorkEnd: false,
    notifyBreaks: false,
  };

  private readonly _local$ = new BehaviorSubject<UserSettings>(this._localGet());

  getSettings(): Observable<UserSettings> {
    return this.auth.user$.pipe(
      switchMap(user => {
        if (!user) return this._local$.asObservable();

        return new Observable<UserSettings>(observer => {
          let unsub: (() => void) | undefined;
          runInInjectionContext(this.injector, () => {
            const ref = doc(this.firestore, `users/${user.uid}/settings/current`);
            unsub = onSnapshot(ref,
              snap => observer.next((snap.data() as UserSettings) || this.defaultSettings),
              err  => observer.error(err),
            );
          });
          return () => unsub?.();
        });
      })
    );
  }

  async saveSettings(settings: UserSettings): Promise<void> {
    const uid = this.auth.uid;
    if (!uid) {
      this._localSave(settings);
      return;
    }
    await runInInjectionContext(this.injector, () => {
      const ref = doc(this.firestore, `users/${uid}/settings/current`);
      return setDoc(ref, settings, { merge: true });
    });
  }

  // ── localStorage ─────────────────────────────────────────────────────────

  private _localGet(): UserSettings {
    const raw = localStorage.getItem(LS_KEY);
    if (!raw) return { ...this.defaultSettings };
    try {
      return { ...this.defaultSettings, ...(JSON.parse(raw) as Partial<UserSettings>) };
    } catch { return { ...this.defaultSettings }; }
  }

  private _localSave(settings: UserSettings): void {
    localStorage.setItem(LS_KEY, JSON.stringify(settings));
    this._local$.next(settings);
  }
}
