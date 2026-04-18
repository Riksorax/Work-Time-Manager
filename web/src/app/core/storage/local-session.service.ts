import { Injectable } from '@angular/core';
import { BehaviorSubject, Observable } from 'rxjs';
import { map } from 'rxjs/operators';
import { Timestamp } from 'firebase/firestore';
import { WorkSession, SessionBreak, WorkSessionType } from '../../shared/models';

const STORAGE_KEY = 'wtm_local_sessions';
const GUEST_ID_KEY = 'wtm_guest_id';

type StoredBreak = Omit<SessionBreak, 'startTime' | 'endTime'> & {
  startTime: number;
  endTime?: number;
};

type StoredSession = Omit<WorkSession, 'startTime' | 'endTime' | 'pauseStartTime' | 'createdAt' | 'updatedAt' | 'breaks'> & {
  startTime: number;
  endTime?: number;
  pauseStartTime?: number;
  createdAt: number;
  updatedAt: number;
  breaks: StoredBreak[];
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

  // ─── Observables ─────────────────────────────────────────────────────────

  allSessions$(): Observable<WorkSession[]> {
    return this.sessions$.asObservable();
  }

  activeSession$(): Observable<WorkSession | null> {
    return this.sessions$.pipe(map(ss => ss.find(s => s.isRunning) ?? null));
  }

  session$(id: string): Observable<WorkSession | null> {
    return this.sessions$.pipe(map(ss => ss.find(s => s.id === id) ?? null));
  }

  sessionsForDay$(date: Date): Observable<WorkSession[]> {
    return this.sessions$.pipe(
      map(ss => ss.filter(s => isSameDay(s.startTime.toDate(), date))
        .sort((a, b) => b.startTime.toMillis() - a.startTime.toMillis()))
    );
  }

  sessionsInRange$(start: Date, end: Date): Observable<WorkSession[]> {
    return this.sessions$.pipe(
      map(ss => ss.filter(s => {
        const d = s.startTime.toDate();
        return d >= start && d <= end;
      }).sort((a, b) => b.startTime.toMillis() - a.startTime.toMillis()))
    );
  }

  // ─── Session CRUD ─────────────────────────────────────────────────────────

  startSession(options?: { note?: string; category?: string; type?: WorkSessionType }): string {
    const now = Timestamp.now();
    const id = crypto.randomUUID();
    const session: WorkSession = {
      id,
      userId: this.guestId,
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
    const now = Timestamp.now();
    const breakId = crypto.randomUUID();
    const newBreak: SessionBreak = {
      id: breakId,
      name: `Pause ${new Date().toLocaleTimeString('de-DE', { hour: '2-digit', minute: '2-digit' })}`,
      startTime: now,
      isAutomatic: false,
    };
    this.update(sessionId, s => ({
      ...s,
      isPaused: true,
      pauseStartTime: now,
      breaks: [...s.breaks, newBreak],
      updatedAt: now,
    }));
  }

  resumeSession(sessionId: string, pauseStartTime: Timestamp): void {
    const now = Timestamp.now();
    const pauseMs = now.toMillis() - pauseStartTime.toMillis();
    const additionalPauseMinutes = Math.floor(pauseMs / 60_000);
    this.update(sessionId, s => {
      const breaks = s.breaks.map(b =>
        !b.endTime ? { ...b, endTime: now } : b
      );
      return {
        ...s,
        isPaused: false,
        pauseStartTime: undefined,
        pauseDuration: s.pauseDuration + additionalPauseMinutes,
        breaks,
        updatedAt: now,
      };
    });
  }

  updateSession(sessionId: string, updates: Partial<WorkSession>): void {
    const { id, userId, createdAt, ...safe } = updates as WorkSession;
    this.update(sessionId, s => ({ ...s, ...safe, updatedAt: Timestamp.now() }));
  }

  updateSessionTimes(sessionId: string, startTime: Date, endTime?: Date): void {
    this.update(sessionId, s => ({
      ...s,
      startTime: Timestamp.fromDate(startTime),
      endTime: endTime ? Timestamp.fromDate(endTime) : s.endTime,
      updatedAt: Timestamp.now(),
    }));
  }

  deleteSession(sessionId: string): void {
    this.save(this.sessions$.value.filter(s => s.id !== sessionId));
  }

  // ─── Break CRUD ───────────────────────────────────────────────────────────

  startBreak(sessionId: string): void {
    const now = Timestamp.now();
    const breakId = crypto.randomUUID();
    const newBreak: SessionBreak = {
      id: breakId,
      name: `Pause ${new Date().toLocaleTimeString('de-DE', { hour: '2-digit', minute: '2-digit' })}`,
      startTime: now,
      isAutomatic: false,
    };
    this.update(sessionId, s => ({
      ...s,
      isPaused: true,
      pauseStartTime: now,
      breaks: [...s.breaks, newBreak],
      updatedAt: now,
    }));
  }

  stopBreak(sessionId: string): void {
    const now = Timestamp.now();
    this.update(sessionId, s => {
      const runningBreak = s.breaks.find(b => !b.endTime);
      if (!runningBreak) return s;
      const pauseMs = now.toMillis() - runningBreak.startTime.toMillis();
      const additionalMinutes = Math.floor(pauseMs / 60_000);
      const breaks = s.breaks.map(b =>
        b.id === runningBreak.id ? { ...b, endTime: now } : b
      );
      return {
        ...s,
        isPaused: false,
        pauseStartTime: undefined,
        pauseDuration: s.pauseDuration + additionalMinutes,
        breaks,
        updatedAt: now,
      };
    });
  }

  addManualBreak(sessionId: string, breakData: { name: string; startTime: Date; endTime: Date }): void {
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
    this.update(sessionId, s => ({
      ...s,
      pauseDuration: s.pauseDuration + Math.max(0, durationMinutes),
      breaks: [...s.breaks, newBreak].sort((a, b) => a.startTime.toMillis() - b.startTime.toMillis()),
      updatedAt: Timestamp.now(),
    }));
  }

  updateBreak(sessionId: string, breakId: string, updates: { name?: string; startTime?: Date; endTime?: Date }): void {
    this.update(sessionId, s => {
      const breaks = s.breaks.map(b => {
        if (b.id !== breakId) return b;
        const updated = {
          ...b,
          name: updates.name ?? b.name,
          startTime: updates.startTime ? Timestamp.fromDate(updates.startTime) : b.startTime,
          endTime: updates.endTime ? Timestamp.fromDate(updates.endTime) : b.endTime,
        };
        return updated;
      });
      const pauseDuration = breaks
        .filter(b => b.endTime)
        .reduce((sum, b) => sum + Math.floor((b.endTime!.toMillis() - b.startTime.toMillis()) / 60_000), 0);
      return { ...s, breaks, pauseDuration, updatedAt: Timestamp.now() };
    });
  }

  deleteBreak(sessionId: string, breakId: string): void {
    this.update(sessionId, s => {
      const breaks = s.breaks.filter(b => b.id !== breakId);
      const pauseDuration = breaks
        .filter(b => b.endTime)
        .reduce((sum, b) => sum + Math.floor((b.endTime!.toMillis() - b.startTime.toMillis()) / 60_000), 0);
      return { ...s, breaks, pauseDuration, updatedAt: Timestamp.now() };
    });
  }

  addAutoBreaks(sessionId: string, autoBreaks: SessionBreak[]): void {
    this.update(sessionId, s => {
      const manualBreaks = s.breaks.filter(b => !b.isAutomatic);
      const allBreaks = [...manualBreaks, ...autoBreaks]
        .sort((a, b) => a.startTime.toMillis() - b.startTime.toMillis());
      const pauseDuration = allBreaks
        .filter(b => b.endTime)
        .reduce((sum, b) => sum + Math.floor((b.endTime!.toMillis() - b.startTime.toMillis()) / 60_000), 0);
      return { ...s, breaks: allBreaks, pauseDuration, updatedAt: Timestamp.now() };
    });
  }

  // ─── Migration ────────────────────────────────────────────────────────────

  getAll(): WorkSession[] { return this.sessions$.value; }
  clearAll(): void { this.save([]); }

  // ─── Private ──────────────────────────────────────────────────────────────

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
      breaks: s.breaks.map(b => ({
        ...b,
        startTime: b.startTime.toMillis(),
        endTime: b.endTime?.toMillis(),
      })),
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
        breaks: (s.breaks ?? []).map(b => ({
          ...b,
          startTime: Timestamp.fromMillis(b.startTime),
          endTime: b.endTime != null ? Timestamp.fromMillis(b.endTime) : undefined,
        })),
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
