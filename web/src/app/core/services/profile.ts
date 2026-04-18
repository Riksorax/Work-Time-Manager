import { Injectable, inject } from '@angular/core';
import { 
  Firestore, 
  doc, 
  docData 
} from '@angular/fire/firestore';
import { AuthService } from '../auth/auth';
import { UserProfile } from '../../shared/models';
import { Observable, map, of, switchMap } from 'rxjs';
import { toSignal } from '@angular/core/rxjs-interop';

@Injectable({
  providedIn: 'root'
})
export class ProfileService {
  private firestore = inject(Firestore);
  private auth = inject(AuthService);

  /**
   * Stream des Benutzerprofils inkl. Premium-Status.
   */
  readonly profile$ = this.auth.user$.pipe(
    switchMap(user => {
      if (!user) return of(null);
      const docRef = doc(this.firestore, `users/${user.uid}`);
      return docData(docRef).pipe(
        map(data => (data as UserProfile) || null)
      );
    })
  );

  /**
   * Profil-Signal für die UI.
   */
  readonly profile = toSignal(this.profile$);

  /**
   * Reiner Premium-Status als Signal.
   */
  readonly isPremium = toSignal(this.profile$.pipe(
    map(profile => profile?.isPremium ?? false)
  ), { initialValue: false });
}
