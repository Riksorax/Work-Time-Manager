import { Injectable, inject } from '@angular/core';
import { 
  Firestore, 
  doc, 
  docData, 
  setDoc, 
  updateDoc 
} from '@angular/fire/firestore';
import { AuthService } from '../../../core/auth/auth.service';
import { UserProfile, UserSettings, DEFAULT_USER_SETTINGS } from '../../../shared/models';
import { toSignal } from '@angular/core/rxjs-interop';
import { switchMap, of, map, Observable } from 'rxjs';
import { User as FirebaseUser } from '@angular/fire/auth';

@Injectable({
  providedIn: 'root'
})
export class UserProfileService {
  private firestore = inject(Firestore);
  private auth = inject(AuthService);

  readonly profile = toSignal<UserProfile | null>(
    (this.auth.currentUser$ as Observable<FirebaseUser | null>).pipe(
      switchMap(user => {
        if (!user) return of(null);
        const docRef = doc(this.firestore, `users/${user.uid}`);
        return docData(docRef).pipe(
          map(data => data as UserProfile)
        );
      })
    ),
    { initialValue: null }
  );

  async ensureProfile(user: FirebaseUser): Promise<void> {
    const docRef = doc(this.firestore, `users/${user.uid}`);
    const initialProfile: UserProfile = {
      uid: user.uid,
      email: user.email || '',
      displayName: user.displayName || '',
      photoURL: user.photoURL || '',
      isPremium: false,
      settings: DEFAULT_USER_SETTINGS
    };

    await setDoc(docRef, initialProfile, { merge: true });
  }

  async updateProfile(updates: Partial<UserProfile>): Promise<void> {
    const user = this.auth.currentUser() as FirebaseUser | null;
    if (!user) return;
    const docRef = doc(this.firestore, `users/${user.uid}`);
    await updateDoc(docRef, updates);
  }

  async updateSettings(settings: Partial<UserSettings>): Promise<void> {
    const user = this.auth.currentUser() as FirebaseUser | null;
    if (!user) return;
    const docRef = doc(this.firestore, `users/${user.uid}`);
    
    const updates: { [key: string]: any } = {};
    Object.keys(settings).forEach(key => {
      updates[`settings.${key}`] = (settings as any)[key];
    });

    await updateDoc(docRef, updates);
  }

  async updatePremiumStatus(isPremium: boolean, expiresAt: Date | null): Promise<void> {
    const user = this.auth.currentUser() as FirebaseUser | null;
    if (!user) return;
    const docRef = doc(this.firestore, `users/${user.uid}`);
    await updateDoc(docRef, { 
      isPremium,
      premiumExpiresAt: expiresAt 
    });
  }
}
