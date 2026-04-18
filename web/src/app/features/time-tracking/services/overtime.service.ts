import { Injectable, inject } from '@angular/core';
import { 
  Firestore, 
  doc, 
  docData, 
  setDoc,
  Timestamp 
} from '@angular/fire/firestore';
import { AuthService } from '../../../../core/auth/auth.service';
import { OvertimeBalance } from '../../../../shared/models';
import { Observable, map, of, switchMap } from 'rxjs';

@Injectable({
  providedIn: 'root'
})
export class OvertimeService {
  private firestore = inject(Firestore);
  private auth = inject(AuthService);

  getBalance(): Observable<OvertimeBalance | null> {
    return this.auth.currentUser$.pipe(
      switchMap(user => {
        if (!user) return of(null);
        const docRef = doc(this.firestore, `users/${user.uid}/overtime/balance`);
        return docData(docRef).pipe(
          map((data: any) => {
            if (!data) return { minutes: 0, lastUpdated: new Date() };
            return {
              minutes: data.minutes || 0,
              lastUpdated: data.lastUpdated?.toDate() || new Date()
            };
          })
        );
      })
    );
  }

  async updateBalance(minutes: number): Promise<void> {
    const user = this.auth.currentUser();
    if (!user) throw new Error('Nicht angemeldet');

    const docRef = doc(this.firestore, `users/${user.uid}/overtime/balance`);
    await setDoc(docRef, {
      minutes: minutes,
      lastUpdated: Timestamp.now()
    }, { merge: true });
  }
}
