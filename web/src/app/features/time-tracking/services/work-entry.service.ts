import { Injectable, inject } from '@angular/core';
import { 
  Firestore, 
  doc, 
  docData, 
  setDoc, 
  Timestamp 
} from '@angular/fire/firestore';
import { AuthService } from '../../../core/auth/auth.service';
import { WorkEntry, Break } from '../../../shared/models';
import { Observable, map, of, switchMap, tap } from 'rxjs';
import { format } from 'date-fns';
import { User } from '@angular/fire/auth';

@Injectable({
  providedIn: 'root'
})
export class WorkEntryService {
  private firestore = inject(Firestore);
  private auth = inject(AuthService);

  private readonly LOCAL_STORAGE_KEY = 'wtm_local_work_entries';

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
    return (this.auth.currentUser$ as Observable<User | null>).pipe(
      switchMap(user => {
        if (!user) {
          // GAST-MODUS: Aus LocalStorage laden
          return of(this.getLocalWorkEntry(date));
        }
        
        // CLOUD-MODUS
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
    const user = this.auth.currentUser() as User | null;
    
    if (!user) {
      // GAST-MODUS: In LocalStorage speichern
      this.saveLocalWorkEntry(entry);
      return;
    }

    // CLOUD-MODUS
    const docRef = this.getMonthDocRef(user.uid, entry.date);
    const dayKey = this.getDayKey(entry.date);
    const firestoreData = this.mapToFirestore(entry);

    await setDoc(docRef, {
      days: {
        [dayKey]: firestoreData
      }
    }, { merge: true });
  }

  // ── LOCAL STORAGE HELPERS ──────────────────────────────────────────────

  private getLocalWorkEntry(date: Date): WorkEntry | null {
    const allData = this.getAllLocalData();
    const monthId = this.getMonthId(date);
    const dayKey = this.getDayKey(date);
    
    const dayData = allData[monthId]?.days?.[dayKey];
    if (!dayData) return null;
    
    // Daten mappen (JSON Strings zurück zu Dates)
    return {
      ...dayData,
      date: new Date(dayData.date),
      workStart: dayData.workStart ? new Date(dayData.workStart) : undefined,
      workEnd: dayData.workEnd ? new Date(dayData.workEnd) : undefined,
      breaks: (dayData.breaks || []).map((b: any) => ({
        ...b,
        start: new Date(b.start),
        end: b.end ? new Date(b.end) : undefined
      }))
    };
  }

  private saveLocalWorkEntry(entry: WorkEntry): void {
    const allData = this.getAllLocalData();
    const monthId = this.getMonthId(entry.date);
    const dayKey = this.getDayKey(entry.date);

    if (!allData[monthId]) {
      allData[monthId] = { days: {} };
    }

    allData[monthId].days[dayKey] = entry;
    localStorage.setItem(this.LOCAL_STORAGE_KEY, JSON.stringify(allData));
  }

  private getAllLocalData(): { [monthId: string]: { days: { [dayKey: string]: any } } } {
    const raw = localStorage.getItem(this.LOCAL_STORAGE_KEY);
    return raw ? JSON.parse(raw) : {};
  }

  // ── FIRESTORE MAPPING ──────────────────────────────────────────────────

  private mapToFirestore(entry: WorkEntry): any {
    return {
      date: Timestamp.fromDate(entry.date),
      workStart: entry.workStart ? Timestamp.fromDate(entry.workStart) : null,
      workEnd: entry.workEnd ? Timestamp.fromDate(entry.workEnd) : null,
      type: entry.type,
      description: entry.description || '',
      isManuallyEntered: entry.isManuallyEntered,
      manualOvertimeMinutes: entry.manualOvertimeMinutes || 0,
      breaks: entry.breaks.map((b: Break) => ({
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
