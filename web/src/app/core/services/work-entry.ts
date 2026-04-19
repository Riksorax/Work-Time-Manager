import { Injectable, inject } from '@angular/core';
import {
  Firestore,
  collection,
  doc,
  docData,
  setDoc,
  query,
  where,
  collectionData,
  Timestamp,
  deleteDoc,
  orderBy
} from '@angular/fire/firestore';
import { AuthService } from '../auth/auth';
import { WorkEntry, WorkEntryType, Break } from '../../shared/models';
import { Observable, map, of, switchMap } from 'rxjs';

// localStorage Keys — identisch zu Flutter LocalWorkRepositoryImpl
const LS_PREFIX  = 'local_work_entries_';
const LS_KEYS    = 'local_monthly_keys';

@Injectable({ providedIn: 'root' })
export class WorkEntryService {
  private readonly firestore = inject(Firestore);
  private readonly auth      = inject(AuthService);

  // ─── Public API ────────────────────────────────────────────────────────────

  getTodayEntry(): Observable<WorkEntry | null> {
    return this.auth.user$.pipe(
      switchMap(user => {
        if (user) return this._firebaseToday(user.uid);
        const entry = this._localGet(new Date());
        return of(entry);
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
    if (uid) {
      await this._firebaseSave(uid, entry);
    } else {
      this._localSave(entry);
    }
  }

  async deleteEntry(id: string): Promise<void> {
    const uid = this.auth.uid;
    if (uid) {
      await deleteDoc(doc(this.firestore, `users/${uid}/work_entries/${id}`));
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

  // ─── Firebase ──────────────────────────────────────────────────────────────

  private _firebaseToday(uid: string): Observable<WorkEntry | null> {
    const id  = this._dateId(new Date());
    const ref = doc(this.firestore, `users/${uid}/work_entries/${id}`);
    return docData(ref).pipe(
      map(data => data ? this._fromFirestore(data, id) : null)
    );
  }

  private _firebaseMonth(uid: string, year: number, month: number): Observable<WorkEntry[]> {
    const start = new Date(year, month - 1, 1);
    const end   = new Date(year, month, 0, 23, 59, 59);
    const col   = collection(this.firestore, `users/${uid}/work_entries`);
    const q     = query(
      col,
      where('date', '>=', Timestamp.fromDate(start)),
      where('date', '<=', Timestamp.fromDate(end)),
      orderBy('date', 'asc')
    );
    return collectionData(q, { idField: 'id' }).pipe(
      map(list => list.map(d => this._fromFirestore(d, (d as WorkEntry & {id: string}).id)))
    );
  }

  private async _firebaseSave(uid: string, entry: WorkEntry): Promise<void> {
    const ref = doc(this.firestore, `users/${uid}/work_entries/${entry.id}`);
    await setDoc(ref, this._toFirestore(entry), { merge: true });
  }

  private _toFirestore(entry: WorkEntry): Record<string, unknown> {
    return {
      date:                  Timestamp.fromDate(entry.date),
      workStart:             entry.workStart ? Timestamp.fromDate(entry.workStart) : null,
      workEnd:               entry.workEnd   ? Timestamp.fromDate(entry.workEnd)   : null,
      type:                  entry.type,
      isManuallyEntered:     entry.isManuallyEntered,
      manualOvertimeMinutes: entry.manualOvertimeMinutes ?? 0,
      description:           entry.description ?? null,
      breaks: entry.breaks.map(b => ({
        id: b.id, name: b.name, isAutomatic: b.isAutomatic,
        start: Timestamp.fromDate(b.start),
        end:   b.end ? Timestamp.fromDate(b.end) : null,
      })),
    };
  }

  private _fromFirestore(data: Record<string, unknown>, id: string): WorkEntry {
    const ts = (v: unknown) => v ? (v as Timestamp).toDate() : undefined;
    return {
      id,
      date:                  ts(data['date'])!,
      workStart:             ts(data['workStart']),
      workEnd:               ts(data['workEnd']),
      type:                  (data['type'] as WorkEntryType) ?? WorkEntryType.Work,
      isManuallyEntered:     (data['isManuallyEntered'] as boolean) ?? false,
      manualOvertimeMinutes: (data['manualOvertimeMinutes'] as number) ?? 0,
      description:           data['description'] as string | undefined,
      breaks: ((data['breaks'] as Record<string, unknown>[]) ?? []).map(b => ({
        id:          b['id'] as string,
        name:        b['name'] as string,
        isAutomatic: (b['isAutomatic'] as boolean) ?? false,
        start:       ts(b['start'])!,
        end:         ts(b['end']),
      })) as Break[],
    };
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
    // id is YYYY-MM-DD
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

  private _fromLocalJson(data: Record<string, unknown>, date: Date): WorkEntry {
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
