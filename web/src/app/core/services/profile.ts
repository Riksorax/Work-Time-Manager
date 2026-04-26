import { Injectable, Injector, inject, runInInjectionContext } from '@angular/core';
import { Firestore, doc, docData } from '@angular/fire/firestore';
import { AuthService } from '../auth/auth';
import { UserProfile } from '../../shared/models';
import { Observable, map, of, switchMap } from 'rxjs';
import { toSignal } from '@angular/core/rxjs-interop';

@Injectable({ providedIn: 'root' })
export class ProfileService {
  private readonly firestore = inject(Firestore);
  private readonly auth      = inject(AuthService);
  private readonly injector  = inject(Injector);

  readonly profile$ = this.auth.user$.pipe(
    switchMap(user => {
      if (!user) return of(null);
      const docRef = doc(this.firestore, `users/${user.uid}`);
      return runInInjectionContext(this.injector, () => docData(docRef)).pipe(
        map(data => (data as UserProfile) || null)
      );
    })
  );

  readonly profile   = toSignal(this.profile$);
  readonly isPremium = toSignal(
    this.profile$.pipe(map(p => p?.isPremium ?? false)),
    { initialValue: false }
  );
}
