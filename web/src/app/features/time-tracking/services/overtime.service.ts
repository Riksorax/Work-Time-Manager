import { Injectable, inject } from '@angular/core';
import { 
  Firestore, 
  doc, 
  docData, 
  setDoc,
  Timestamp 
} from '@angular/fire/firestore';
import { AuthService } from '../../../core/auth/auth.service';
import { OvertimeBalance } from '../../../shared/models';
import { Observable, map, of, switchMap } from 'rxjs';
import { User } from '@angular/fire/auth';

@Injectable({
  providedIn: 'root'
})
export class OvertimeService {
  private firestore = inject(Firestore);
  private auth = inject(AuthService);

  private readonly LOCAL_STORAGE_KEY = 'wtm_local_overtime';

  getBalance(): Observable<OvertimeBalance | null> {
    return (this.auth.currentUser$ as Observable<User | null>).pipe(
      switchMap(user => {
        if (!user) {
          // GAST-MODUS
          return of(this.getLocalBalance());
        }

        // CLOUD-MODUS
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
    const user = this.auth.currentUser() as User | null;
    
    if (!user) {
      // GAST-MODUS
      this.saveLocalBalance(minutes);
      return;
    }

    // CLOUD-MODUS
    const docRef = doc(this.firestore, `users/${user.uid}/overtime/balance`);
    await setDoc(docRef, {
      minutes: minutes,
      lastUpdated: Timestamp.now()
    }, { merge: true });
  }

  private getLocalBalance(): OvertimeBalance {
    const raw = localStorage.getItem(this.LOCAL_STORAGE_KEY);
    if (!raw) return { minutes: 0, lastUpdated: new Date() };
    const data = JSON.parse(raw);
    return {
      minutes: data.minutes || 0,
      lastUpdated: new Date(data.lastUpdated)
    };
  }

  private saveLocalBalance(minutes: number): void {
    const data = {
      minutes,
      lastUpdated: new Date().toISOString()
    };
    localStorage.setItem(this.LOCAL_STORAGE_KEY, JSON.stringify(data));
  }
}
