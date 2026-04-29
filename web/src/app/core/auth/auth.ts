import { Injectable, Injector, inject, runInInjectionContext } from '@angular/core';
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
import { Observable, shareReplay } from 'rxjs';

@Injectable({
  providedIn: 'root'
})
export class AuthService {
  private auth     = inject(Auth);
  private router   = inject(Router);
  private injector = inject(Injector);

  // Shared hot Observable — ein einziger Firebase-Listener für alle Subscriber
  readonly user$: Observable<User | null> = runInInjectionContext(
    this.injector, () => authState(this.auth)
  ).pipe(shareReplay({ bufferSize: 1, refCount: false }));

  readonly user = toSignal(this.user$);

  async signInWithGoogle(): Promise<void> {
    const provider = new GoogleAuthProvider();
    await runInInjectionContext(this.injector, () => signInWithPopup(this.auth, provider));
  }

  async signOut(): Promise<void> {
    await runInInjectionContext(this.injector, () => signOut(this.auth));
    this.router.navigate(['/auth/login']);
  }

  async deleteAccount(): Promise<void> {
    const user = this.auth.currentUser;
    if (!user) throw new Error('Kein Benutzer angemeldet');
    await runInInjectionContext(this.injector, () => deleteUser(user));
    this.router.navigate(['/auth/login']);
  }

  get currentUser(): User | null | undefined {
    return this.user();
  }

  get uid(): string | null {
    return this.auth.currentUser?.uid ?? null;
  }
}
