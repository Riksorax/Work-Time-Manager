import { Injectable, inject } from '@angular/core';
import { 
  Firestore, 
  doc, 
  docData, 
  setDoc, 
  updateDoc,
  Timestamp 
} from '@angular/fire/firestore';
import { AuthService } from '../../../../core/auth/auth.service';
import { WorkEntry, Break, WorkMonth } from '../../../../shared/models';
import { Observable, map, of, switchMap, take } from 'rxjs';
import { format } from 'date-fns';

@Injectable({
  providedIn: 'root'
})
export class WorkEntryService {
  private firestore = inject(Firestore);
  private auth = inject(AuthService);

  // Hilfsmethode zum Formatieren der IDs
  private getMonthId(date: Date): string {
    return format(date, 'yyyy-MM');
  }

  private getDayKey(date: Date): string {
    return date.getDate().toString();
  }

  private getMonthDocRef(userId: string, date: Date) {
    const monthId = this.getMonthId(date);
    return doc(this.firestore, `users/${userId}/work_entries/${monthId}`);
  }

  getWorkEntry(date: Date): Observable<WorkEntry | null> {
    return this.auth.currentUser$.pipe(
      switchMap(user => {
        if (!user) return of(null);
        const docRef = this.getMonthDocRef(user.uid, date);
        return docData(docRef).pipe(
          map((data: any) => {
            if (!data || !data.days) return null;
            const dayKey = this.getDayKey(date);
            const dayData = data.days[dayKey];
            if (!dayData) return null;
            return this.mapFromFirestore(dayData, date);
          })
        );
      })
    );
  }

  async saveWorkEntry(entry: WorkEntry): Promise<void> {
    const user = this.auth.currentUser();
    if (!user) throw new Error('Nicht angemeldet');

    const docRef = this.getMonthDocRef(user.uid, entry.date);
    const dayKey = this.getDayKey(entry.date);
    const firestoreData = this.mapToFirestore(entry);

    await setDoc(docRef, {
      days: {
        [dayKey]: firestoreData
      }
    }, { merge: true });
  }

  private mapToFirestore(entry: WorkEntry): any {
    return {
      date: Timestamp.fromDate(entry.date),
      workStart: entry.workStart ? Timestamp.fromDate(entry.workStart) : null,
      workEnd: entry.workEnd ? Timestamp.fromDate(entry.workEnd) : null,
      type: entry.type,
      description: entry.description || '',
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

  private mapFromFirestore(data: any, date: Date): WorkEntry {
    return {
      id: format(date, 'yyyy-MM-dd'),
      date: date,
      workStart: data.workStart?.toDate(),
      workEnd: data.workEnd?.toDate(),
      type: data.type,
      description: data.description,
      isManuallyEntered: data.isManuallyEntered,
      manualOvertimeMinutes: data.manualOvertimeMinutes,
      breaks: (data.breaks || []).map((b: any) => ({
        id: b.id,
        name: b.name,
        start: b.start.toDate(),
        end: b.end?.toDate(),
        isAutomatic: b.isAutomatic
      }))
    };
  }
}
