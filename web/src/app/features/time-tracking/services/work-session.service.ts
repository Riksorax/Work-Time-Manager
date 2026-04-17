// features/time-tracking/services/work-session.service.ts
// Agent 5 — Time Tracking Feature (Kern-Business-Logik)

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
import { WorkSession } from '../../../shared/models';
import { startOfDay, endOfDay, startOfWeek, endOfWeek } from '../utils/time-calculations.util';
import { v4 as uuidv4 } from 'uuid';

@Injectable({ providedIn: 'root' })
export class WorkSessionService {
  private firestore = inject(Firestore);
  private auth = inject(AuthService);

  // ─── Collections ─────────────────────────────────────────────────────────

  private sessionsCol(uid: string) {
    return collection(this.firestore, `users/${uid}/workSessions`);
  }

  private sessionDoc(uid: string, sessionId: string) {
    return doc(this.firestore, `users/${uid}/workSessions/${sessionId}`);
  }

  // ─── Aktive Session (Echtzeit) ────────────────────────────────────────────

  activeSession$: Observable<WorkSession | null> = this.auth.currentUser$.pipe(
    switchMap(user => {
      if (!user) return of(null);
      const q = query(
        this.sessionsCol(user.uid),
        where('isRunning', '==', true),
        limit(1)
      );
      return (collectionData(q, { idField: 'id' }) as Observable<WorkSession[]>).pipe(
        switchMap(sessions => of(sessions[0] ?? null))
      );
    })
  );

  // ─── Sessions in Zeitraum ─────────────────────────────────────────────────

  getSessionsForDay(date: Date): Observable<WorkSession[]> {
    return this.auth.currentUser$.pipe(
      switchMap(user => {
        if (!user) return of([]);
        const q = query(
          this.sessionsCol(user.uid),
          where('startTime', '>=', Timestamp.fromDate(startOfDay(date))),
          where('startTime', '<=', Timestamp.fromDate(endOfDay(date))),
          orderBy('startTime', 'desc')
        );
        return collectionData(q, { idField: 'id' }) as Observable<WorkSession[]>;
      })
    );
  }

  getSessionsForWeek(date: Date): Observable<WorkSession[]> {
    return this.auth.currentUser$.pipe(
      switchMap(user => {
        if (!user) return of([]);
        const q = query(
          this.sessionsCol(user.uid),
          where('startTime', '>=', Timestamp.fromDate(startOfWeek(date))),
          where('startTime', '<=', Timestamp.fromDate(endOfWeek(date))),
          orderBy('startTime', 'desc')
        );
        return collectionData(q, { idField: 'id' }) as Observable<WorkSession[]>;
      })
    );
  }

  getSessionsInRange(startDate: Date, endDate: Date): Observable<WorkSession[]> {
    return this.auth.currentUser$.pipe(
      switchMap(user => {
        if (!user) return of([]);
        const q = query(
          this.sessionsCol(user.uid),
          where('startTime', '>=', Timestamp.fromDate(startDate)),
          where('startTime', '<=', Timestamp.fromDate(endDate)),
          orderBy('startTime', 'desc')
        );
        return collectionData(q, { idField: 'id' }) as Observable<WorkSession[]>;
      })
    );
  }

  // ─── CRUD ────────────────────────────────────────────────────────────────

  async startSession(options?: { note?: string; category?: string; profileId?: string }): Promise<string> {
    const user = this.auth.currentUser();
    if (!user) throw new Error('Nicht eingeloggt');

    const now = Timestamp.now();
    const session: Omit<WorkSession, 'id'> = {
      userId: user.uid,
      profileId: options?.profileId,
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

    const ref = await addDoc(this.sessionsCol(user.uid), session);
    return ref.id;
  }

  async stopSession(sessionId: string): Promise<void> {
    const user = this.auth.currentUser();
    if (!user) throw new Error('Nicht eingeloggt');

    const now = Timestamp.now();
    await updateDoc(this.sessionDoc(user.uid, sessionId), {
      endTime: now,
      isRunning: false,
      isPaused: false,
      pauseStartTime: null,
      updatedAt: now,
    });
  }

  async pauseSession(sessionId: string): Promise<void> {
    const user = this.auth.currentUser();
    if (!user) throw new Error('Nicht eingeloggt');

    await updateDoc(this.sessionDoc(user.uid, sessionId), {
      isPaused: true,
      pauseStartTime: Timestamp.now(),
      updatedAt: Timestamp.now(),
    });
  }

  async resumeSession(sessionId: string, currentPauseStartTime: Timestamp): Promise<void> {
    const user = this.auth.currentUser();
    if (!user) throw new Error('Nicht eingeloggt');

    const now = new Date();
    const pauseStart = currentPauseStartTime.toDate();
    const additionalPauseMinutes = Math.floor((now.getTime() - pauseStart.getTime()) / 60_000);

    // Bestehende pauseDuration + neue Pausenzeit akkumulieren
    // Firestore increment wäre ideal, aber wir lesen den aktuellen Wert aus der Session
    // Die aufrufende Komponente übergibt die aktuelle pauseDuration
    await updateDoc(this.sessionDoc(user.uid, sessionId), {
      isPaused: false,
      pauseStartTime: null,
      updatedAt: Timestamp.now(),
    });

    // pauseDuration separat aktualisieren (increment via FieldValue)
    const { increment } = await import('@angular/fire/firestore');
    await updateDoc(this.sessionDoc(user.uid, sessionId), {
      pauseDuration: increment(additionalPauseMinutes),
    });
  }

  async updateSession(sessionId: string, updates: Partial<WorkSession>): Promise<void> {
    const user = this.auth.currentUser();
    if (!user) throw new Error('Nicht eingeloggt');

    // Immutable/server-only Felder explizit ausschließen
    const { id, userId, createdAt, ...safeUpdates } = updates as WorkSession;

    await updateDoc(this.sessionDoc(user.uid, sessionId), {
      ...safeUpdates,
      updatedAt: Timestamp.now(),
    });
  }

  async deleteSession(sessionId: string): Promise<void> {
    const user = this.auth.currentUser();
    if (!user) throw new Error('Nicht eingeloggt');

    // Bug #108 Fix: explizite Fehlerbehandlung beim Löschen
    try {
      await deleteDoc(this.sessionDoc(user.uid, sessionId));
    } catch (err) {
      console.error('[WorkSessionService] Löschen fehlgeschlagen:', err);
      throw new Error('Die Arbeitszeit konnte nicht gelöscht werden. Bitte erneut versuchen.');
    }
  }
}
