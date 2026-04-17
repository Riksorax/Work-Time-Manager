import { Injectable } from '@angular/core';
import { BehaviorSubject, Observable } from 'rxjs';
import { map } from 'rxjs/operators';
import { Timestamp } from 'firebase/firestore';
import { WorkSession, WorkSessionType } from '../../shared/models';

const STORAGE_KEY = 'wtm_local_sessions';
const GUEST_ID_KEY = 'wtm_guest_id';

type StoredSession = Omit<WorkSession, 'startTime' | 'endTime' | 'pauseStartTime' | 'createdAt' | 'updatedAt'> & {
  startTime: number;
  endTime?: number;
  pauseStartTime?: number;
  createdAt: number;
  updatedAt: number;
};

@Injectable({ providedIn: 'root' })
export class LocalSessionService {
  private sessions$ = new BehaviorSubject<WorkSession[]>(this.load());

  get guestId(): string {
    let id = localStorage.getItem(GUEST_ID_KEY);
    if (!id) {
      id = crypto.randomUUID();
      localStorage.setItem(GUEST_ID_KEY, id);
    }
    return id;
  }

  // ─── Observable ──────────────────────────────────────────────────────────

  allSessions$(): Observable<WorkSession[]> {
    return this.sessions$.asObservable();
  }

  activeSession$(): Observable<WorkSession | null> {
    return this.sessions$.pipe(map(ss => ss.find(s => s.isRunning) ?? null));
  }

  sessionsForDay$(date: Date): Observable<WorkSession[]> {
    return this.sessions$.pipe(
      map(ss => ss.filter(s => isSameDay(s.startTime.toDate(), date))
        .sort((a, b) => b.startTime.toMillis() - a.startTime.toMillis()))
    );
  }

  session$(id: string): Observable<WorkSession | null> {
    return this.sessions$.pipe(map(ss => ss.find(s => s.id === id) ?? null));
  }

  sessionsInRange$(start: Date, end: Date): Observable<WorkSession[]> {
    return this.sessions$.pipe(
      map(ss => ss.filter(s => {
        const d = s.startTime.toDate();
        return d >= start && d <= end;
      }).sort((a, b) => b.startTime.toMillis() - a.startTime.toMillis()))
    );
  }

  // ─── CRUD ────────────────────────────────────────────────────────────────

  startSession(options?: { note?: string; category?: string; type?: WorkSessionType }): string {
    const now = Timestamp.now();
    const id = crypto.randomUUID();
    const session: WorkSession = {
      id,
      userId: this.guestId,
      type: options?.type ?? 'work',
      startTime: now,
      pauseDuration: 0,
      note: options?.note,
      category: options?.category,
      isRunning: true,
      isPaused: false,
      createdAt: now,
      updatedAt: now,
    };
    this.save([...this.sessions$.value, session]);
    return id;
  }

  stopSession(sessionId: string): void {
    const now = Timestamp.now();
    this.update(sessionId, s => ({
      ...s,
      endTime: now,
      isRunning: false,
      isPaused: false,
      pauseStartTime: undefined,
      updatedAt: now,
    }));
  }

  pauseSession(sessionId: string): void {
    this.update(sessionId, s => ({
      ...s,
      isPaused: true,
      pauseStartTime: Timestamp.now(),
      updatedAt: Timestamp.now(),
    }));
  }

  resumeSession(sessionId: string, pauseStartTime: Timestamp): void {
    const pauseMs = Date.now() - pauseStartTime.toMillis();
    const additionalPauseMinutes = Math.floor(pauseMs / 60_000);
    this.update(sessionId, s => ({
      ...s,
      isPaused: false,
      pauseStartTime: undefined,
      pauseDuration: s.pauseDuration + additionalPauseMinutes,
      updatedAt: Timestamp.now(),
    }));
  }

  updateSession(sessionId: string, updates: Partial<WorkSession>): void {
    const { id, userId, createdAt, ...safe } = updates as WorkSession;
    this.update(sessionId, s => ({ ...s, ...safe, updatedAt: Timestamp.now() }));
  }

  deleteSession(sessionId: string): void {
    this.save(this.sessions$.value.filter(s => s.id !== sessionId));
  }

  // ─── Migration ───────────────────────────────────────────────────────────

  getAll(): WorkSession[] {
    return this.sessions$.value;
  }

  clearAll(): void {
    this.save([]);
  }

  // ─── Private ─────────────────────────────────────────────────────────────

  private update(id: string, fn: (s: WorkSession) => WorkSession): void {
    this.save(this.sessions$.value.map(s => s.id === id ? fn(s) : s));
  }

  private save(sessions: WorkSession[]): void {
    const stored: StoredSession[] = sessions.map(s => ({
      ...s,
      startTime: s.startTime.toMillis(),
      endTime: s.endTime?.toMillis(),
      pauseStartTime: s.pauseStartTime?.toMillis(),
      createdAt: s.createdAt.toMillis(),
      updatedAt: s.updatedAt.toMillis(),
    }));
    localStorage.setItem(STORAGE_KEY, JSON.stringify(stored));
    this.sessions$.next(sessions);
  }

  private load(): WorkSession[] {
    try {
      const raw = localStorage.getItem(STORAGE_KEY);
      if (!raw) return [];
      const stored: StoredSession[] = JSON.parse(raw);
      return stored.map(s => ({
        ...s,
        startTime: Timestamp.fromMillis(s.startTime),
        endTime: s.endTime != null ? Timestamp.fromMillis(s.endTime) : undefined,
        pauseStartTime: s.pauseStartTime != null ? Timestamp.fromMillis(s.pauseStartTime) : undefined,
        createdAt: Timestamp.fromMillis(s.createdAt),
        updatedAt: Timestamp.fromMillis(s.updatedAt),
      }));
    } catch {
      return [];
    }
  }
}

function isSameDay(a: Date, b: Date): boolean {
  return a.getFullYear() === b.getFullYear() &&
    a.getMonth() === b.getMonth() &&
    a.getDate() === b.getDate();
}
