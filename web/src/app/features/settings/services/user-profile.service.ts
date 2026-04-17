// features/settings/services/user-profile.service.ts
// Agent 9 — Settings & Profile

import { Injectable, inject, signal } from '@angular/core';
import {
  Firestore,
  doc,
  docData,
  setDoc,
  updateDoc,
  Timestamp,
} from '@angular/fire/firestore';
import { AuthService } from '../../../core/auth/auth.service';
import { UserProfile, UserSettings, DEFAULT_USER_PROFILE } from '../../../shared/models';
import { Observable, switchMap, of } from 'rxjs';
import { toSignal } from '@angular/core/rxjs-interop';

@Injectable({ providedIn: 'root' })
export class UserProfileService {
  private firestore = inject(Firestore);
  private auth = inject(AuthService);

  // ─── Echtzeit-Profil als Signal ──────────────────────────────────────────

  private profile$: Observable<UserProfile | null> = this.auth.currentUser$.pipe(
    switchMap(user => {
      if (!user) return of(null);
      return docData(
        doc(this.firestore, `users/${user.uid}`),
        { idField: 'uid' }
      ) as Observable<UserProfile>;
    })
  );

  readonly profile = toSignal(this.profile$, { initialValue: null });

  // ─── Profil anlegen (nach erstem Login) ──────────────────────────────────

  async ensureProfile(user: { uid: string; email: string; displayName?: string | null; photoURL?: string | null }): Promise<void> {
    const ref = doc(this.firestore, `users/${user.uid}`);
    const now = Timestamp.now();

    // Nur anlegen wenn noch nicht vorhanden (merge: false würde überschreiben)
    await setDoc(ref, {
      uid: user.uid,
      email: user.email,
      displayName: user.displayName ?? '',
      photoURL: user.photoURL ?? '',
      ...DEFAULT_USER_PROFILE,
      createdAt: now,
      updatedAt: now,
    }, { merge: true }); // merge: true → überschreibt nur geänderte Felder
  }

  // ─── Profil aktualisieren ─────────────────────────────────────────────────

  async updateProfile(updates: Partial<Pick<UserProfile, 'displayName' | 'photoURL' | 'weeklyTargetHours' | 'dailyTargetHours' | 'defaultPauseDuration' | 'overtimeAdjustmentMinutes' | 'activeProfileId'>>): Promise<void> {
    const uid = this.auth.uid();
    if (!uid) throw new Error('Nicht eingeloggt');

    await updateDoc(doc(this.firestore, `users/${uid}`), {
      ...updates,
      updatedAt: Timestamp.now(),
    });
  }

  // ─── Einstellungen aktualisieren ──────────────────────────────────────────

  async updateSettings(settings: Partial<UserSettings>): Promise<void> {
    const uid = this.auth.uid();
    if (!uid) throw new Error('Nicht eingeloggt');

    const updates: Record<string, any> = { updatedAt: Timestamp.now() };
    // Nested field updates mit Dot-Notation für Firestore
    for (const [key, value] of Object.entries(settings)) {
      updates[`settings.${key}`] = value;
    }

    await updateDoc(doc(this.firestore, `users/${uid}`), updates);
  }

  // ─── Premium-Status synchron halten ──────────────────────────────────────

  async updatePremiumStatus(isPremium: boolean, expiresAt: Date | null): Promise<void> {
    const uid = this.auth.uid();
    if (!uid) return;

    await updateDoc(doc(this.firestore, `users/${uid}`), {
      isPremium,
      premiumExpiresAt: expiresAt ? Timestamp.fromDate(expiresAt) : null,
      updatedAt: Timestamp.now(),
    });
  }
}
