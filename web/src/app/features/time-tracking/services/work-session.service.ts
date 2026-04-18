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
  arrayUnion,
  arrayRemove,
  query,
  where,
  orderBy,
  limit,
  Timestamp,
} from '@angular/fire/firestore';
import { Observable, of, switchMap } from 'rxjs';
import { AuthService } from '../../../core/auth/auth.service';
import { LocalSessionService } from '../../../core/storage/local-session.service';
import { WorkSession, SessionBreak, WorkSessionType } from '../../../shared/models';
import { startOfDay, endOfDay, startOfWeek, endOfWeek } from '../utils/time-calculations.util';
import { BreakCalculatorService } from './break-calculator.service';

@Injectable({ providedIn: 'root' })
export class WorkSessionService {
  private firestore = inject(Firestore);
  private auth = inject(AuthService);
  private local = inject(LocalSessionService);
  private breakCalc = inject(BreakCalculatorService);

  private get uid(): string | null { return this.auth.uid(); }

  private sessionsCol(uid: string) {
    return collection(this.firestore, `users/${uid}/workSessions`);
  }

  private sessionDoc(uid: string, sessionId: string) {
    return doc(this.firestore, `users/${uid}/workSessions/${sessionId}`);
  }

  // ─── Aktive Session ───────────────────────────────────────────────────────

  activeSession$: Observable<WorkSession | null> = this.auth.currentUser$.pipe(
    switchMap(user => {
      if (!user) return this.local.activeSession$();
      const q = query(this.sessionsCol(user.uid), where('isRunning', '==', true), limit(1));
      return (collectionData(q, { idField: 'id' }) as Observable<WorkSession[]>).pipe(
        switchMap(sessions => of(sessions[0] ?? null))
      );
    })
  );

  // ─── Einzelne Session ─────────────────────────────────────────────────────

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

  // ─── Session CRUD ─────────────────────────────────────────────────────────

  async startSession(options?: { note?: string; category?: string; type?: WorkSessionType; profileId?: string }): Promise<string> {
    const uid = this.uid;
    if (!uid) return this.local.startSession(options);
    const now = Timestamp.now();
    const session: Omit<WorkSession, 'id'> = {
      userId: uid,
      profileId: options?.profileId,
      type: options?.type ?? 'work',
      startTime: now,
      pauseDuration: 0,
      breaks: [],
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

  async stopSessionWithAutoBreaks(session: WorkSession): Promise<void> {
    const uid = this.uid;
    const autoBreaks = this.breakCalc.calculateAutoBreaks(session);
    if (autoBreaks.length === 0) {
      await this.stopSession(session.id);
      return;
    }
    if (!uid) {
      this.local.stopSession(session.id);
      this.local.addAutoBreaks(session.id, autoBreaks);
      return;
    }
    const now = Timestamp.now();
    const manualBreaks = session.breaks.filter(b => !b.isAutomatic);
    const allBreaks = [...manualBreaks, ...autoBreaks];
    const pauseDuration = allBreaks
      .filter(b => b.endTime)
      .reduce((sum, b) => sum + Math.floor((b.endTime!.toMillis() - b.startTime.toMillis()) / 60_000), 0);
    await updateDoc(this.sessionDoc(uid, session.id), {
      endTime: now, isRunning: false, isPaused: false,
      pauseStartTime: null, breaks: allBreaks, pauseDuration, updatedAt: now,
    });
  }

  async pauseSession(sessionId: string): Promise<void> {
    const uid = this.uid;
    if (!uid) { this.local.pauseSession(sessionId); return; }
    const now = Timestamp.now();
    const newBreak: SessionBreak = {
      id: crypto.randomUUID(),
      name: `Pause ${new Date().toLocaleTimeString('de-DE', { hour: '2-digit', minute: '2-digit' })}`,
      startTime: now,
      isAutomatic: false,
    };
    await updateDoc(this.sessionDoc(uid, sessionId), {
      isPaused: true, pauseStartTime: now,
      breaks: arrayUnion(newBreak), updatedAt: now,
    });
  }

  async resumeSession(sessionId: string, currentPauseStartTime: Timestamp): Promise<void> {
    const uid = this.uid;
    if (!uid) { this.local.resumeSession(sessionId, currentPauseStartTime); return; }
    const now = Timestamp.now();
    const additionalPauseMinutes = Math.floor((now.toMillis() - currentPauseStartTime.toMillis()) / 60_000);
    const { increment } = await import('@angular/fire/firestore');
    // Wir müssen das laufende Break schließen — da arrayUnion/arrayRemove nicht für Updates geht,
    // laden wir die Session und updaten das breaks-Array direkt
    const sessionData = await this.getSessionOnce(uid, sessionId);
    if (sessionData) {
      const breaks = sessionData.breaks.map((b: SessionBreak) =>
        !b.endTime ? { ...b, endTime: now } : b
      );
      await updateDoc(this.sessionDoc(uid, sessionId), {
        isPaused: false, pauseStartTime: null,
        pauseDuration: increment(additionalPauseMinutes),
        breaks, updatedAt: now,
      });
    } else {
      await updateDoc(this.sessionDoc(uid, sessionId), {
        isPaused: false, pauseStartTime: null,
        pauseDuration: increment(additionalPauseMinutes),
        updatedAt: now,
      });
    }
  }

  async updateSession(sessionId: string, updates: Partial<WorkSession>): Promise<void> {
    const uid = this.uid;
    if (!uid) { this.local.updateSession(sessionId, updates); return; }
    const { id, userId, createdAt, ...safeUpdates } = updates as WorkSession;
    await updateDoc(this.sessionDoc(uid, sessionId), { ...safeUpdates, updatedAt: Timestamp.now() });
  }

  async updateSessionTimes(sessionId: string, startTime: Date, endTime?: Date): Promise<void> {
    const uid = this.uid;
    if (!uid) { this.local.updateSessionTimes(sessionId, startTime, endTime); return; }
    const updates: Record<string, any> = {
      startTime: Timestamp.fromDate(startTime),
      updatedAt: Timestamp.now(),
    };
    if (endTime) updates['endTime'] = Timestamp.fromDate(endTime);
    await updateDoc(this.sessionDoc(uid, sessionId), updates);
  }

  async deleteSession(sessionId: string): Promise<void> {
    const uid = this.uid;
    if (!uid) { this.local.deleteSession(sessionId); return; }
    await deleteDoc(this.sessionDoc(uid, sessionId));
  }

  // ─── Break CRUD ───────────────────────────────────────────────────────────

  async startBreak(sessionId: string): Promise<void> {
    const uid = this.uid;
    if (!uid) { this.local.startBreak(sessionId); return; }
    const now = Timestamp.now();
    const newBreak: SessionBreak = {
      id: crypto.randomUUID(),
      name: `Pause ${new Date().toLocaleTimeString('de-DE', { hour: '2-digit', minute: '2-digit' })}`,
      startTime: now,
      isAutomatic: false,
    };
    await updateDoc(this.sessionDoc(uid, sessionId), {
      isPaused: true, pauseStartTime: now,
      breaks: arrayUnion(newBreak), updatedAt: now,
    });
  }

  async stopBreak(sessionId: string): Promise<void> {
    const uid = this.uid;
    if (!uid) { this.local.stopBreak(sessionId); return; }
    const sessionData = await this.getSessionOnce(uid, sessionId);
    if (!sessionData) return;
    const now = Timestamp.now();
    const runningBreak = sessionData.breaks.find((b: SessionBreak) => !b.endTime);
    if (!runningBreak) return;
    const additionalMinutes = Math.floor((now.toMillis() - runningBreak.startTime.toMillis()) / 60_000);
    const breaks = sessionData.breaks.map((b: SessionBreak) =>
      b.id === runningBreak.id ? { ...b, endTime: now } : b
    );
    const { increment } = await import('@angular/fire/firestore');
    await updateDoc(this.sessionDoc(uid, sessionId), {
      isPaused: false, pauseStartTime: null,
      pauseDuration: increment(additionalMinutes),
      breaks, updatedAt: now,
    });
  }

  async addManualBreak(sessionId: string, breakData: { name: string; startTime: Date; endTime: Date }): Promise<void> {
    const uid = this.uid;
    if (!uid) { this.local.addManualBreak(sessionId, breakData); return; }
    const start = Timestamp.fromDate(breakData.startTime);
    const end = Timestamp.fromDate(breakData.endTime);
    const durationMinutes = Math.floor((end.toMillis() - start.toMillis()) / 60_000);
    const newBreak: SessionBreak = {
      id: crypto.randomUUID(),
      name: breakData.name,
      startTime: start,
      endTime: end,
      isAutomatic: false,
    };
    const sessionData = await this.getSessionOnce(uid, sessionId);
    if (!sessionData) return;
    const breaks = [...sessionData.breaks, newBreak]
      .sort((a, b) => a.startTime.toMillis() - b.startTime.toMillis());
    await updateDoc(this.sessionDoc(uid, sessionId), {
      breaks,
      pauseDuration: sessionData.pauseDuration + Math.max(0, durationMinutes),
      updatedAt: Timestamp.now(),
    });
  }

  async updateBreak(sessionId: string, breakId: string, updates: { name?: string; startTime?: Date; endTime?: Date }): Promise<void> {
    const uid = this.uid;
    if (!uid) { this.local.updateBreak(sessionId, breakId, updates); return; }
    const sessionData = await this.getSessionOnce(uid, sessionId);
    if (!sessionData) return;
    const breaks = sessionData.breaks.map((b: SessionBreak) => {
      if (b.id !== breakId) return b;
      return {
        ...b,
        name: updates.name ?? b.name,
        startTime: updates.startTime ? Timestamp.fromDate(updates.startTime) : b.startTime,
        endTime: updates.endTime ? Timestamp.fromDate(updates.endTime) : b.endTime,
      };
    });
    const pauseDuration = breaks
      .filter((b: SessionBreak) => b.endTime)
      .reduce((sum: number, b: SessionBreak) =>
        sum + Math.floor((b.endTime!.toMillis() - b.startTime.toMillis()) / 60_000), 0);
    await updateDoc(this.sessionDoc(uid, sessionId), { breaks, pauseDuration, updatedAt: Timestamp.now() });
  }

  async deleteBreak(sessionId: string, breakId: string): Promise<void> {
    const uid = this.uid;
    if (!uid) { this.local.deleteBreak(sessionId, breakId); return; }
    const sessionData = await this.getSessionOnce(uid, sessionId);
    if (!sessionData) return;
    const breaks = sessionData.breaks.filter((b: SessionBreak) => b.id !== breakId);
    const pauseDuration = breaks
      .filter((b: SessionBreak) => b.endTime)
      .reduce((sum: number, b: SessionBreak) =>
        sum + Math.floor((b.endTime!.toMillis() - b.startTime.toMillis()) / 60_000), 0);
    await updateDoc(this.sessionDoc(uid, sessionId), { breaks, pauseDuration, updatedAt: Timestamp.now() });
  }

  // ─── Migration ────────────────────────────────────────────────────────────

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

  // ─── Private Helpers ──────────────────────────────────────────────────────

  private async getSessionOnce(uid: string, sessionId: string): Promise<WorkSession | null> {
    return new Promise(resolve => {
      (docData(this.sessionDoc(uid, sessionId), { idField: 'id' }) as Observable<WorkSession | undefined>)
        .subscribe({ next: s => resolve(s ?? null), error: () => resolve(null) });
    });
  }
}
