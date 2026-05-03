import { Injectable, Injector, inject, runInInjectionContext } from '@angular/core';
import {
  Firestore,
  doc,
  onSnapshot,
  setDoc,
  updateDoc,
  deleteField,
  Timestamp,
} from '@angular/fire/firestore';
import { AuthService } from '../auth/auth';
import { WorkEntry, WorkEntryType, Break } from '../../shared/models';
import { Observable, of, switchMap } from 'rxjs';

// localStorage Keys — identisch zu Flutter LocalWorkRepositoryImpl
const LS_PREFIX = 'local_work_entries_';
const LS_KEYS   = 'local_monthly_keys';

@Injectable({ providedIn: 'root' })
export class WorkEntryService {
  private readonly firestore = inject(Firestore);
  private readonly auth      = inject(AuthService);
  private readonly injector  = inject(Injector);

  // ─── Public API ────────────────────────────────────────────────────────────

  getTodayEntry(): Observable<WorkEntry | null> {
    return this.auth.user$.pipe(
      switchMap(user => {
        if (user) return this._firebaseToday(user.uid);
        return of(this._localGet(new Date()));
      })
    );
  }

  getEntriesForMonth(year: number, month: number): Observable<WorkEntry[]> {
    return this.auth.user$.pipe(
      switchMap(user => {
        if (user) return this._firebaseMonth(user.uid, year, month);
        return of(this._localGetMonth(year, month));
      })
    );
  }

  async saveEntry(entry: WorkEntry): Promise<void> {
    const uid = this.auth.uid;
    if (uid) await this._firebaseSave(uid, entry);
    else     this._localSave(entry);
  }

  async deleteEntry(id: string): Promise<void> {
    const uid = this.auth.uid;
    if (uid) {
      // id = yyyy-MM-dd → Monatsdok aktualisieren: days.{day} löschen
      const [year, month, day] = id.split('-');
      const monthId = `${year}-${month}`;
      const dayKey  = String(Number(day)); // "05" → "5" (Flutter-Format)
      const ref = doc(this.firestore, `users/${uid}/work_entries/${monthId}`);
      await runInInjectionContext(this.injector, () =>
        updateDoc(ref, { [`days.${dayKey}`]: deleteField() })
      );
    } else {
      this._localDelete(id);
    }
  }

  emptyEntry(date: Date): WorkEntry {
    return {
      id: this._dateId(date),
      date,
      workStart: undefined,
      workEnd: undefined,
      breaks: [],
      isManuallyEntered: false,
      type: WorkEntryType.Work,
    };
  }

  // ─── Firebase (Flutter-kompatibles Format: work_entries/{yyyy-MM}/days/{day}) ─

  private _firebaseToday(uid: string): Observable<WorkEntry | null> {
    const today   = new Date();
    const monthId = this._monthId(today);
    const dayKey  = String(today.getDate());
    const id      = this._dateId(today);

    return new Observable<WorkEntry | null>(observer => {
      let unsub: (() => void) | undefined;
      runInInjectionContext(this.injector, () => {
        const ref = doc(this.firestore, `users/${uid}/work_entries/${monthId}`);
        unsub = onSnapshot(ref,
          snap => {
            if (!snap.exists()) { observer.next(null); return; }
            const days = (snap.data()['days'] as Record<string, unknown>) ?? {};
            const dayData = days[dayKey];
            observer.next(dayData ? this._fromFirestore(dayData as Record<string, unknown>, id) : null);
          },
          err => observer.error(err),
        );
      });
      return () => unsub?.();
    });
  }

  private _firebaseMonth(uid: string, year: number, month: number): Observable<WorkEntry[]> {
    const monthId = `${year}-${String(month).padStart(2, '0')}`;

    return new Observable<WorkEntry[]>(observer => {
      let unsub: (() => void) | undefined;
      runInInjectionContext(this.injector, () => {
        const ref = doc(this.firestore, `users/${uid}/work_entries/${monthId}`);
        unsub = onSnapshot(ref,
          snap => {
            if (!snap.exists()) { observer.next([]); return; }
            const days = (snap.data()['days'] as Record<string, unknown>) ?? {};
            const entries = Object.entries(days)
              .map(([dayStr, dayData]) => {
                const id = `${monthId}-${String(Number(dayStr)).padStart(2, '0')}`;
                return this._fromFirestore(dayData as Record<string, unknown>, id);
              })
              .filter((e): e is WorkEntry => e !== null)
              .sort((a, b) => a.date.getTime() - b.date.getTime());
            observer.next(entries);
          },
          err => observer.error(err),
        );
      });
      return () => unsub?.();
    });
  }

  private async _firebaseSave(uid: string, entry: WorkEntry): Promise<void> {
    const monthId = this._monthId(entry.date);
    const dayKey  = String(entry.date.getDate()); // Flutter nutzt "5", nicht "05"
    const ref = doc(this.firestore, `users/${uid}/work_entries/${monthId}`);
    await runInInjectionContext(this.injector, () =>
      setDoc(ref, { days: { [dayKey]: this._toFirestore(entry) } }, { merge: true })
    );
  }

  // ─── Serialisierung (Flutter-kompatibel) ───────────────────────────────────

  private _toFirestore(entry: WorkEntry): Record<string, unknown> {
    return {
      date:                  Timestamp.fromDate(new Date(Date.UTC(entry.date.getFullYear(), entry.date.getMonth(), entry.date.getDate()))),
      workStart:             entry.workStart ? Timestamp.fromDate(entry.workStart) : null,
      workEnd:               entry.workEnd   ? Timestamp.fromDate(entry.workEnd)   : null,
      type:                  entry.type ?? WorkEntryType.Work,
      isManuallyEntered:     entry.isManuallyEntered ?? false,
      manualOvertimeMinutes: entry.manualOvertimeMinutes ?? null,
      description:           entry.description ?? null,
      // Flutter liest nur name/start/end — extra Felder werden ignoriert
      breaks: entry.breaks.map(b => ({
        id:          b.id,
        name:        b.name,
        isAutomatic: b.isAutomatic,
        start:       Timestamp.fromDate(b.start),
        end:         b.end ? Timestamp.fromDate(b.end) : null,
      })),
    };
  }

  private _fromFirestore(data: Record<string, unknown>, id: string): WorkEntry | null {
    try {
      const ts = (v: unknown) => v ? (v as Timestamp).toDate() : undefined;
      return {
        id,
        date:                  ts(data['date'])!,
        workStart:             ts(data['workStart']),
        workEnd:               ts(data['workEnd']),
        type:                  (data['type'] as WorkEntryType) ?? WorkEntryType.Work,
        isManuallyEntered:     (data['isManuallyEntered'] as boolean) ?? false,
        manualOvertimeMinutes: (data['manualOvertimeMinutes'] as number) ?? undefined,
        description:           data['description'] as string | undefined,
        breaks: ((data['breaks'] as Record<string, unknown>[]) ?? []).map(b => ({
          id:          (b['id'] as string) || `break-${b['start']}`,
          name:        (b['name'] as string) || 'Pause',
          isAutomatic: (b['isAutomatic'] as boolean) ?? false,
          start:       ts(b['start'])!,
          end:         ts(b['end']),
        })) as Break[],
      };
    } catch {
      return null;
    }
  }

  // ─── localStorage (identisch zu Flutter LocalWorkRepositoryImpl) ───────────

  private _localGet(date: Date): WorkEntry | null {
    const monthKey = this._monthKey(date.getFullYear(), date.getMonth() + 1);
    const dayKey   = String(date.getDate());
    const raw = localStorage.getItem(monthKey);
    if (!raw) return null;
    try {
      const month = JSON.parse(raw) as { days: Record<string, unknown> };
      const day   = month.days?.[dayKey];
      if (!day) return null;
      return this._fromLocalJson(day as Record<string, unknown>, date);
    } catch { return null; }
  }

  private _localGetMonth(year: number, month: number): WorkEntry[] {
    const monthKey = this._monthKey(year, month);
    const raw = localStorage.getItem(monthKey);
    if (!raw) return [];
    try {
      const data = JSON.parse(raw) as { days: Record<string, Record<string, unknown>> };
      return Object.entries(data.days ?? {})
        .map(([day, dayData]) => this._fromLocalJson(dayData, new Date(year, month - 1, Number(day))))
        .filter((e): e is WorkEntry => e !== null)
        .sort((a, b) => a.date.getTime() - b.date.getTime());
    } catch { return []; }
  }

  private _localSave(entry: WorkEntry): void {
    const monthKey = this._monthKey(entry.date.getFullYear(), entry.date.getMonth() + 1);
    const dayKey   = String(entry.date.getDate());
    let month: { days: Record<string, unknown> } = { days: {} };
    const raw = localStorage.getItem(monthKey);
    if (raw) {
      try { month = JSON.parse(raw); } catch { /* use default */ }
    }
    month.days ??= {};
    month.days[dayKey] = this._toLocalJson(entry);
    localStorage.setItem(monthKey, JSON.stringify(month));
    this._addToIndex(monthKey);
  }

  private _localDelete(id: string): void {
    const [year, month, day] = id.split('-').map(Number);
    const monthKey = this._monthKey(year, month);
    const raw = localStorage.getItem(monthKey);
    if (!raw) return;
    try {
      const data = JSON.parse(raw) as { days: Record<string, unknown> };
      delete data.days[String(day)];
      if (Object.keys(data.days).length === 0) {
        localStorage.removeItem(monthKey);
        this._removeFromIndex(monthKey);
      } else {
        localStorage.setItem(monthKey, JSON.stringify(data));
      }
    } catch { /* ignore */ }
  }

  private _toLocalJson(entry: WorkEntry): Record<string, unknown> {
    return {
      workStart:             entry.workStart?.toISOString() ?? null,
      workEnd:               entry.workEnd?.toISOString()   ?? null,
      type:                  entry.type,
      isManuallyEntered:     entry.isManuallyEntered,
      manualOvertimeMinutes: entry.manualOvertimeMinutes ?? null,
      description:           entry.description ?? null,
      breaks: entry.breaks.map(b => ({
        id: b.id, name: b.name, isAutomatic: b.isAutomatic,
        start: b.start.toISOString(),
        end:   b.end?.toISOString() ?? null,
      })),
    };
  }

  private _fromLocalJson(data: Record<string, unknown>, date: Date): WorkEntry | null {
    try {
      const parseDate = (v: unknown) => v ? new Date(v as string) : undefined;
      return {
        id:                    this._dateId(date),
        date,
        workStart:             parseDate(data['workStart']),
        workEnd:               parseDate(data['workEnd']),
        type:                  (data['type'] as WorkEntryType) ?? WorkEntryType.Work,
        isManuallyEntered:     (data['isManuallyEntered'] as boolean) ?? false,
        manualOvertimeMinutes: (data['manualOvertimeMinutes'] as number) ?? undefined,
        description:           data['description'] as string | undefined,
        breaks: ((data['breaks'] as Record<string, unknown>[]) ?? []).map(b => ({
          id:          b['id'] as string,
          name:        b['name'] as string,
          isAutomatic: (b['isAutomatic'] as boolean) ?? false,
          start:       new Date(b['start'] as string),
          end:         b['end'] ? new Date(b['end'] as string) : undefined,
        })) as Break[],
      };
    } catch { return null; }
  }

  getAllLocalEntries(): WorkEntry[] {
    const keys = JSON.parse(localStorage.getItem(LS_KEYS) ?? '[]') as string[];
    return keys.flatMap(key => {
      const raw = localStorage.getItem(key);
      if (!raw) return [];
      try {
        const data = JSON.parse(raw) as { days: Record<string, Record<string, unknown>> };
        const match = key.replace(LS_PREFIX, '').split('_');
        const year  = Number(match[0]);
        const month = Number(match[1]);
        return Object.entries(data.days ?? {})
          .map(([day, dayData]) => this._fromLocalJson(dayData, new Date(year, month - 1, Number(day))))
          .filter((e): e is WorkEntry => e !== null);
      } catch { return []; }
    });
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  private _monthId(date: Date): string {
    return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}`;
  }

  private _monthKey(year: number, month: number): string {
    return `${LS_PREFIX}${year}_${String(month).padStart(2, '0')}`;
  }

  private _dateId(date: Date): string {
    return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`;
  }

  private _addToIndex(key: string): void {
    const keys = JSON.parse(localStorage.getItem(LS_KEYS) ?? '[]') as string[];
    if (!keys.includes(key)) {
      keys.push(key);
      localStorage.setItem(LS_KEYS, JSON.stringify(keys));
    }
  }

  private _removeFromIndex(key: string): void {
    const keys = (JSON.parse(localStorage.getItem(LS_KEYS) ?? '[]') as string[]).filter(k => k !== key);
    localStorage.setItem(LS_KEYS, JSON.stringify(keys));
  }
}
