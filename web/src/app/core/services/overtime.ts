import { Injectable, Injector, inject, runInInjectionContext } from '@angular/core';
import { Firestore, doc, getDoc, setDoc } from '@angular/fire/firestore';
import { AuthService } from '../auth/auth';

const LS_OVERTIME    = 'overtime_value';
const LS_LAST_UPDATE = 'overtime_last_update';

@Injectable({ providedIn: 'root' })
export class OvertimeService {
  private readonly firestore = inject(Firestore);
  private readonly auth      = inject(AuthService);
  private readonly injector  = inject(Injector);

  async getOvertime(): Promise<number> {
    const uid = this.auth.uid;
    if (uid) return this._firebaseGetOvertime(uid);
    return this._localGetOvertime();
  }

  async getLastUpdateDate(): Promise<Date | null> {
    const uid = this.auth.uid;
    if (uid) return this._firebaseGetLastUpdate(uid);
    return this._localGetLastUpdate();
  }

  async saveOvertime(ms: number): Promise<void> {
    const uid = this.auth.uid;
    if (uid) await this._firebaseSave(uid, ms, new Date());
    else     this._localSave(ms, new Date());
  }

  async saveLastUpdateDate(date: Date): Promise<void> {
    const uid = this.auth.uid;
    if (uid) await this._firebaseSave(uid, await this.getOvertime(), date);
    else     localStorage.setItem(LS_LAST_UPDATE, date.toISOString());
  }

  // ─── Firebase (Flutter-kompatibles Format: overtime/balance, minutes, lastUpdated) ─

  private async _firebaseGetOvertime(uid: string): Promise<number> {
    const ref  = doc(this.firestore, `users/${uid}/overtime/balance`);
    const snap = await runInInjectionContext(this.injector, () => getDoc(ref));
    if (!snap.exists()) return 0;
    return ((snap.data()['minutes'] as number) ?? 0) * 60 * 1000;
  }

  private async _firebaseGetLastUpdate(uid: string): Promise<Date | null> {
    const ref  = doc(this.firestore, `users/${uid}/overtime/balance`);
    const snap = await runInInjectionContext(this.injector, () => getDoc(ref));
    if (!snap.exists()) return null;
    const raw = snap.data()['lastUpdated'];
    return raw ? (raw as { toDate(): Date }).toDate() : null;
  }

  private async _firebaseSave(uid: string, ms: number, date: Date): Promise<void> {
    const ref = doc(this.firestore, `users/${uid}/overtime/balance`);
    await runInInjectionContext(this.injector, () =>
      setDoc(ref, { minutes: Math.round(ms / 60 / 1000), lastUpdated: date }, { merge: true })
    );
  }

  // ─── localStorage ──────────────────────────────────────────────────────────

  private _localGetOvertime(): number {
    const raw = localStorage.getItem(LS_OVERTIME);
    return raw ? Number(raw) * 60 * 1000 : 0;
  }

  private _localGetLastUpdate(): Date | null {
    const raw = localStorage.getItem(LS_LAST_UPDATE);
    return raw ? new Date(raw) : null;
  }

  private _localSave(ms: number, date: Date): void {
    localStorage.setItem(LS_OVERTIME, String(Math.round(ms / 60 / 1000)));
    localStorage.setItem(LS_LAST_UPDATE, date.toISOString());
  }
}
