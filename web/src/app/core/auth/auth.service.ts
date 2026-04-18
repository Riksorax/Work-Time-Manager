import { Injectable, inject, signal, computed } from '@angular/core';
import { 
  Auth, 
  authState, 
  signInWithEmailAndPassword, 
  createUserWithEmailAndPassword, 
  signOut, 
  GoogleAuthProvider, 
  signInWithPopup,
  sendPasswordResetEmail,
  updateProfile,
  updateEmail,
  updatePassword,
  reauthenticateWithCredential,
  EmailAuthProvider,
  deleteUser,
  User,
  idToken
} from '@angular/fire/auth';
import { Router } from '@angular/router';
import { toSignal } from '@angular/core/rxjs-interop';
import { from, map, of } from 'rxjs';

@Injectable({
  providedIn: 'root'
})
export class AuthService {
  private auth = inject(Auth);
  private router = inject(Router);

  readonly currentUser$ = authState(this.auth);
  readonly currentUser = toSignal(this.currentUser$);
  readonly isLoggedIn = computed(() => !!this.currentUser());
  readonly uid = computed(() => this.currentUser()?.uid ?? null);

  async signInWithEmail(email: string, password: string) {
    return signInWithEmailAndPassword(this.auth, email, password);
  }

  async signInWithGoogle() {
    const provider = new GoogleAuthProvider();
    provider.setCustomParameters({ prompt: 'select_account' });
    return signInWithPopup(this.auth, provider);
  }

  async register(email: string, password: string, displayName?: string) {
    const credential = await createUserWithEmailAndPassword(this.auth, email, password);
    if (displayName && credential.user) {
      await updateProfile(credential.user, { displayName });
    }
    return credential;
  }

  async sendPasswordReset(email: string) {
    return sendPasswordResetEmail(this.auth, email);
  }

  async signOut() {
    await signOut(this.auth);
    this.router.navigate(['/auth/login']);
  }

  async getIdToken() {
    const user = this.auth.currentUser;
    if (user) {
      return idToken(this.auth).pipe(take(1)).toPromise();
    }
    return null;
  }
  
  // Re-Auth Hilfsmethode
  private async reauthenticate(password: string) {
    const user = this.auth.currentUser;
    if (!user || !user.email) throw new Error('Kein Benutzer angemeldet');
    const credential = EmailAuthProvider.credential(user.email, password);
    return reauthenticateWithCredential(user, credential);
  }

  async updateUserEmail(newEmail: string, currentPassword: string) {
    await this.reauthenticate(currentPassword);
    const user = this.auth.currentUser;
    if (user) await updateEmail(user, newEmail);
  }

  async updateUserPassword(newPassword: string, currentPassword: string) {
    await this.reauthenticate(currentPassword);
    const user = this.auth.currentUser;
    if (user) await updatePassword(user, newPassword);
  }

  async deleteAccount(currentPassword: string) {
    await this.reauthenticate(currentPassword);
    const user = this.auth.currentUser;
    if (user) {
      // Hier würde man normalerweise noch Daten in Firestore löschen (via Cloud Function oder Batch)
      await deleteUser(user);
      this.router.navigate(['/auth/login']);
    }
  }
}

import { take } from 'rxjs';
