import { Injectable, inject } from '@angular/core';
import { 
  Firestore, 
  doc, 
  docData, 
  setDoc
} from '@angular/fire/firestore';
import { AuthService } from '../auth/auth';
import { UserSettings } from '../../shared/models';
import { Observable, map, of, switchMap } from 'rxjs';

@Injectable({
  providedIn: 'root'
})
export class SettingsService {
  private firestore = inject(Firestore);
  private auth = inject(AuthService);

  private readonly defaultSettings: UserSettings = {
    weeklyTargetHours: 40,
    workdaysPerWeek: 5,
    notificationsEnabled: false,
    notificationTime: '08:00',
    notificationDays: [1, 2, 3, 4, 5],
    notifyWorkStart: false,
    notifyWorkEnd: false,
    notifyBreaks: false
  };

  getSettings(): Observable<UserSettings> {
    return this.auth.user$.pipe(
      switchMap(user => {
        if (!user) return of(this.defaultSettings);
        
        const docRef = doc(this.firestore, `users/${user.uid}/settings/current`);
        return docData(docRef).pipe(
          map(data => (data as UserSettings) || this.defaultSettings)
        );
      })
    );
  }

  async saveSettings(settings: UserSettings): Promise<void> {
    const uid = this.auth.uid;
    if (!uid) throw new Error('Kein User angemeldet');

    const docRef = doc(this.firestore, `users/${uid}/settings/current`);
    await setDoc(docRef, settings, { merge: true });
  }
}
