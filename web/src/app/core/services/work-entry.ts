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
import { WorkEntry, WorkEntryType } from '../../shared/models';
import { Observable, map, of, switchMap, from } from 'rxjs';

@Injectable({
  providedIn: 'root'
})
export class WorkEntryService {
  private firestore = inject(Firestore);
  private auth = inject(AuthService);

  /**
   * Lädt alle Arbeitseinträge für einen bestimmten Monat.
   */
  getEntriesForMonth(year: number, month: number): Observable<WorkEntry[]> {
    return this.auth.user$.pipe(
      switchMap(user => {
        if (!user) return of([]);

        const startOfMonth = new Date(year, month - 1, 1);
        const endOfMonth = new Date(year, month, 0, 23, 59, 59);

        const colRef = collection(this.firestore, `users/${user.uid}/work_entries`);
        const q = query(
          colRef,
          where('date', '>=', Timestamp.fromDate(startOfMonth)),
          where('date', '<=', Timestamp.fromDate(endOfMonth)),
          orderBy('date', 'asc')
        );

        return collectionData(q, { idField: 'id' }).pipe(
          map(list => list.map(data => this.mapFromFirestore(data, data.id)))
        );
      })
    );
  }

  /**
   * Löscht einen Arbeitseintrag.
   */
  async deleteEntry(id: string): Promise<void> {
    const uid = this.auth.uid;
    if (!uid) throw new Error('Kein User angemeldet');

    const docRef = doc(this.firestore, `users/${uid}/work_entries/${id}`);
    await deleteDoc(docRef);
  }

  /**
   * Lädt den heutigen Arbeitseintrag für den aktuell angemeldeten Nutzer.
   */
  getTodayEntry(): Observable<WorkEntry | null> {
    return this.auth.user$.pipe(
      switchMap(user => {
        if (!user) return of(null);
        
        const todayId = this.formatDateId(new Date());
        const docRef = doc(this.firestore, `users/${user.uid}/work_entries/${todayId}`);
        
        return docData(docRef).pipe(
          map(data => {
            if (!data) return null;
            return this.mapFromFirestore(data, todayId);
          })
        );
      })
    );
  }

  /**
   * Speichert oder aktualisiert einen Arbeitseintrag.
   */
  async saveEntry(entry: WorkEntry): Promise<void> {
    const uid = this.auth.uid;
    if (!uid) throw new Error('Kein User angemeldet');

    const docRef = doc(this.firestore, `users/${uid}/work_entries/${entry.id}`);
    const data = this.mapToFirestore(entry);
    
    await setDoc(docRef, data, { merge: true });
  }

  private formatDateId(date: Date): string {
    return date.toISOString().split('T')[0];
  }

  private mapToFirestore(entry: WorkEntry): any {
    return {
      date: Timestamp.fromDate(entry.date),
      workStart: entry.workStart ? Timestamp.fromDate(entry.workStart) : null,
      workEnd: entry.workEnd ? Timestamp.fromDate(entry.workEnd) : null,
      type: entry.type,
      isManuallyEntered: entry.isManuallyEntered,
      manualOvertimeMinutes: entry.manualOvertimeMinutes || 0,
      breaks: entry.breaks.map(b => ({
        id: b.id,
        name: b.name,
        start: Timestamp.fromDate(b.start),
        end: b.end ? Timestamp.fromDate(b.end) : null,
        isAutomatic: b.isAutomatic
      }))
    };
  }

  private mapFromFirestore(data: any, id: string): WorkEntry {
    return {
      id,
      date: data.date.toDate(),
      workStart: data.workStart?.toDate(),
      workEnd: data.workEnd?.toDate(),
      type: data.type as WorkEntryType,
      isManuallyEntered: data.isManuallyEntered,
      manualOvertimeMinutes: data.manualOvertimeMinutes,
      breaks: (data.breaks || []).map((b: any) => ({
        ...b,
        start: b.start.toDate(),
        end: b.end?.toDate()
      }))
    };
  }
}
