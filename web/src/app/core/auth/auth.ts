import { Injectable, inject } from '@angular/core';
import {
  Auth,
  authState,
  signInWithEmailAndPassword,
  createUserWithEmailAndPassword,
  signOut,
  deleteUser,
  GoogleAuthProvider,
  signInWithPopup,
  User
} from '@angular/fire/auth';
import { Router } from '@angular/router';
import { toSignal } from '@angular/core/rxjs-interop';
import { Observable } from 'rxjs';

@Injectable({
  providedIn: 'root'
})
export class AuthService {
  private auth = inject(Auth);
  private router = inject(Router);

  // User Signal für die UI (Signals sind perfekt für Angular 18+)
  readonly user = toSignal(authState(this.auth));

  // Observable für Guards
  readonly user$: Observable<User | null> = authState(this.auth);

  async signInWithGoogle() {
    const provider = new GoogleAuthProvider();
    return signInWithPopup(this.auth, provider);
  }

  async signOut(): Promise<void> {
    await signOut(this.auth);
    this.router.navigate(['/auth/login']);
  }

  async deleteAccount(): Promise<void> {
    const user = this.auth.currentUser;
    if (!user) throw new Error('Kein Benutzer angemeldet');
    await deleteUser(user);
    this.router.navigate(['/auth/login']);
  }

  get currentUser(): User | null | undefined {
    return this.user();
  }

  get uid(): string | null {
    return this.auth.currentUser?.uid ?? null;
  }
}
