import { Injectable, inject } from '@angular/core';
import {
  Firestore,
  collection,
  collectionData,
  doc,
  docData,
  addDoc,
  updateDoc,
  deleteDoc,
  query,
  where,
  orderBy,
  limit,
  Timestamp,
} from '@angular/fire/firestore';
import { Observable, of, switchMap } from 'rxjs';
import { AuthService } from '../../../core/auth/auth.service';
import { LocalSessionService } from '../../../core/storage/local-session.service';
import { WorkSession, WorkSessionType } from '../../../shared/models';
import { startOfDay, endOfDay, startOfWeek, endOfWeek } from '../utils/time-calculations.util';

@Injectable({ providedIn: 'root' })
export class WorkSessionService {
  private firestore = inject(Firestore);
  private auth = inject(AuthService);
  private local = inject(LocalSessionService);

  private get uid(): string | null { return this.auth.uid(); }

  private sessionsCol(uid: string) {
    return collection(this.firestore, `users/${uid}/workSessions`);
  }

  private sessionDoc(uid: string, sessionId: string) {
    return doc(this.firestore, `users/${uid}/workSessions/${sessionId}`);
  }

  // ─── Aktive Session (Echtzeit) ────────────────────────────────────────────

  activeSession$: Observable<WorkSession | null> = this.auth.currentUser$.pipe(
    switchMap(user => {
      if (!user) return this.local.activeSession$();
      const q = query(this.sessionsCol(user.uid), where('isRunning', '==', true), limit(1));
      return (collectionData(q, { idField: 'id' }) as Observable<WorkSession[]>).pipe(
        switchMap(sessions => of(sessions[0] ?? null))
      );
    })
  );

  // ─── Einzelne Session ────────────────────────────────────────────────────

  getSession$(id: string): Observable<WorkSession | null> {
    const uid = this.uid;
    if (!uid) return this.local.session$(id);
    return (docData(
      doc(this.firestore, `users/${uid}/workSessions/${id}`),
      { idField: 'id' }
    ) as Observable<WorkSession | undefined>).pipe(
      switchMap(s => of(s ?? null))
    );
  }

  // ─── Sessions in Zeitraum ─────────────────────────────────────────────────

  getSessionsForDay(date: Date): Observable<WorkSession[]> {
    const uid = this.uid;
    if (!uid) return this.local.sessionsForDay$(date);
    const q = query(
      this.sessionsCol(uid),
      where('startTime', '>=', Timestamp.fromDate(startOfDay(date))),
      where('startTime', '<=', Timestamp.fromDate(endOfDay(date))),
      orderBy('startTime', 'desc')
    );
    return collectionData(q, { idField: 'id' }) as Observable<WorkSession[]>;
  }

  getSessionsForWeek(date: Date): Observable<WorkSession[]> {
    const uid = this.uid;
    if (!uid) return this.local.sessionsInRange$(startOfWeek(date), endOfWeek(date));
    const q = query(
      this.sessionsCol(uid),
      where('startTime', '>=', Timestamp.fromDate(startOfWeek(date))),
      where('startTime', '<=', Timestamp.fromDate(endOfWeek(date))),
      orderBy('startTime', 'desc')
    );
    return collectionData(q, { idField: 'id' }) as Observable<WorkSession[]>;
  }

  getSessionsInRange(startDate: Date, endDate: Date): Observable<WorkSession[]> {
    const uid = this.uid;
    if (!uid) return this.local.sessionsInRange$(startDate, endDate);
    const q = query(
      this.sessionsCol(uid),
      where('startTime', '>=', Timestamp.fromDate(startDate)),
      where('startTime', '<=', Timestamp.fromDate(endDate)),
      orderBy('startTime', 'desc')
    );
    return collectionData(q, { idField: 'id' }) as Observable<WorkSession[]>;
  }

  // ─── CRUD ────────────────────────────────────────────────────────────────

  async startSession(options?: { note?: string; category?: string; type?: WorkSessionType; profileId?: string }): Promise<string> {
    const uid = this.uid;
    if (!uid) {
      return this.local.startSession(options);
    }
    const now = Timestamp.now();
    const session: Omit<WorkSession, 'id'> = {
      userId: uid,
      profileId: options?.profileId,
      type: options?.type ?? 'work',
      startTime: now,
      endTime: undefined,
      pauseDuration: 0,
      pauseStartTime: undefined,
      note: options?.note,
      category: options?.category,
      isRunning: true,
      isPaused: false,
      createdAt: now,
      updatedAt: now,
    };
    const ref = await addDoc(this.sessionsCol(uid), session);
    return ref.id;
  }

  async stopSession(sessionId: string): Promise<void> {
    const uid = this.uid;
    if (!uid) { this.local.stopSession(sessionId); return; }
    const now = Timestamp.now();
    await updateDoc(this.sessionDoc(uid, sessionId), {
      endTime: now, isRunning: false, isPaused: false, pauseStartTime: null, updatedAt: now,
    });
  }

  async pauseSession(sessionId: string): Promise<void> {
    const uid = this.uid;
    if (!uid) { this.local.pauseSession(sessionId); return; }
    await updateDoc(this.sessionDoc(uid, sessionId), {
      isPaused: true, pauseStartTime: Timestamp.now(), updatedAt: Timestamp.now(),
    });
  }

  async resumeSession(sessionId: string, currentPauseStartTime: Timestamp): Promise<void> {
    const uid = this.uid;
    if (!uid) { this.local.resumeSession(sessionId, currentPauseStartTime); return; }
    const now = new Date();
    const additionalPauseMinutes = Math.floor((now.getTime() - currentPauseStartTime.toDate().getTime()) / 60_000);
    await updateDoc(this.sessionDoc(uid, sessionId), {
      isPaused: false, pauseStartTime: null, updatedAt: Timestamp.now(),
    });
    const { increment } = await import('@angular/fire/firestore');
    await updateDoc(this.sessionDoc(uid, sessionId), { pauseDuration: increment(additionalPauseMinutes) });
  }

  async updateSession(sessionId: string, updates: Partial<WorkSession>): Promise<void> {
    const uid = this.uid;
    if (!uid) { this.local.updateSession(sessionId, updates); return; }
    const { id, userId, createdAt, ...safeUpdates } = updates as WorkSession;
    await updateDoc(this.sessionDoc(uid, sessionId), { ...safeUpdates, updatedAt: Timestamp.now() });
  }

  async deleteSession(sessionId: string): Promise<void> {
    const uid = this.uid;
    if (!uid) { this.local.deleteSession(sessionId); return; }
    try {
      await deleteDoc(this.sessionDoc(uid, sessionId));
    } catch (err) {
      throw new Error('Die Arbeitszeit konnte nicht gelöscht werden. Bitte erneut versuchen.');
    }
  }

  // ─── Migration: local → Firestore nach Login ─────────────────────────────

  async migrateLocalToFirestore(): Promise<void> {
    const uid = this.uid;
    if (!uid) return;
    const localSessions = this.local.getAll();
    if (localSessions.length === 0) return;
    for (const session of localSessions) {
      const { id, userId, ...data } = session;
      await addDoc(this.sessionsCol(uid), { ...data, userId: uid });
    }
    this.local.clearAll();
  }
}
