// core/auth/auth.service.ts
// Agent 4 — Auth Feature

import { Injectable, inject, signal, computed } from '@angular/core';
import { Router } from '@angular/router';
import {
  Auth,
  authState,
  signInWithEmailAndPassword,
  createUserWithEmailAndPassword,
  signInWithPopup,
  GoogleAuthProvider,
  sendPasswordResetEmail,
  updateProfile,
  updateEmail,
  updatePassword,
  reauthenticateWithCredential,
  EmailAuthProvider,
  deleteUser,
  User,
  UserCredential,
} from '@angular/fire/auth';
import { toSignal } from '@angular/core/rxjs-interop';
import { map } from 'rxjs/operators';
import { from, Observable } from 'rxjs';

@Injectable({ providedIn: 'root' })
export class AuthService {
  private auth = inject(Auth);
  private router = inject(Router);

  // ─── Reactive State ──────────────────────────────────────────────────────
  readonly currentUser$ = authState(this.auth);
  readonly currentUser = toSignal(this.currentUser$, { initialValue: null });
  readonly isLoggedIn = computed(() => !!this.currentUser());
  readonly uid = computed(() => this.currentUser()?.uid ?? null);

  // ─── Sign In ─────────────────────────────────────────────────────────────

  signInWithEmail(email: string, password: string): Promise<UserCredential> {
    return signInWithEmailAndPassword(this.auth, email, password);
  }

  async signInWithGoogle(): Promise<UserCredential> {
    const provider = new GoogleAuthProvider();
    provider.setCustomParameters({ prompt: 'select_account' });
    return signInWithPopup(this.auth, provider);
  }

  // ─── Register ────────────────────────────────────────────────────────────

  async register(
    email: string,
    password: string,
    displayName?: string
  ): Promise<UserCredential> {
    const credential = await createUserWithEmailAndPassword(this.auth, email, password);
    if (displayName && credential.user) {
      await updateProfile(credential.user, { displayName });
    }
    return credential;
  }

  // ─── Password Reset ───────────────────────────────────────────────────────

  sendPasswordReset(email: string): Promise<void> {
    return sendPasswordResetEmail(this.auth, email);
  }

  // ─── Profile Update ───────────────────────────────────────────────────────

  async updateDisplayName(displayName: string): Promise<void> {
    const user = this.auth.currentUser;
    if (!user) throw new Error('Nicht eingeloggt');
    return updateProfile(user, { displayName });
  }

  async updateUserEmail(newEmail: string, currentPassword: string): Promise<void> {
    const user = this.auth.currentUser;
    if (!user || !user.email) throw new Error('Nicht eingeloggt');
    // Re-Auth vor E-Mail-Änderung
    const credential = EmailAuthProvider.credential(user.email, currentPassword);
    await reauthenticateWithCredential(user, credential);
    return updateEmail(user, newEmail);
  }

  async updateUserPassword(currentPassword: string, newPassword: string): Promise<void> {
    const user = this.auth.currentUser;
    if (!user || !user.email) throw new Error('Nicht eingeloggt');
    const credential = EmailAuthProvider.credential(user.email, currentPassword);
    await reauthenticateWithCredential(user, credential);
    return updatePassword(user, newPassword);
  }

  // ─── Account Deletion ─────────────────────────────────────────────────────

  async deleteAccount(currentPassword: string): Promise<void> {
    const user = this.auth.currentUser;
    if (!user || !user.email) throw new Error('Nicht eingeloggt');
    const credential = EmailAuthProvider.credential(user.email, currentPassword);
    await reauthenticateWithCredential(user, credential);
    // Firestore-Daten werden über Cloud Function gelöscht (onUserDeleted trigger)
    return deleteUser(user);
  }

  // ─── Token ───────────────────────────────────────────────────────────────

  getIdToken(): Promise<string | null> {
    return this.auth.currentUser?.getIdToken() ?? Promise.resolve(null);
  }

  // ─── Sign Out ─────────────────────────────────────────────────────────────

  async signOut(): Promise<void> {
    await this.auth.signOut();
    await this.router.navigate(['/auth/login']);
  }
}
