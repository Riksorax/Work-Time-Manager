import { Injectable, inject, effect } from '@angular/core';
import { AuthService } from './auth.service';
import { UserProfileService } from '../../features/settings/services/user-profile.service';
import { WorkEntryService } from '../../features/time-tracking/services/work-entry.service';
import { OvertimeService } from '../../features/time-tracking/services/overtime.service';
import { Router } from '@angular/router';
import { 
  Firestore, 
  doc, 
  setDoc,
  Timestamp 
} from '@angular/fire/firestore';

@Injectable({
  providedIn: 'root'
})
export class AuthCallbackService {
  private authService = inject(AuthService);
  private profileService = inject(UserProfileService);
  private workEntryService = inject(WorkEntryService);
  private overtimeService = inject(OvertimeService);
  private firestore = inject(Firestore);
  private router = inject(Router);

  constructor() {
    effect(async () => {
      const user = this.authService.currentUser();
      if (user) {
        await this.profileService.ensureProfile(user);
        
        // Lokale Daten synchronisieren
        await this.syncLocalDataToCloud(user.uid);
        
        // Nach Login zum Dashboard, falls wir auf /auth waren
        if (this.router.url.includes('/auth/')) {
          this.router.navigate(['/dashboard']);
        }
      }
    });
  }

  private async syncLocalDataToCloud(userId: string): Promise<void> {
    console.log('[Sync] Starte Synchronisierung lokaler Daten...');

    // 1. Work Entries synchronisieren
    const localEntriesRaw = localStorage.getItem('wtm_local_work_entries');
    if (localEntriesRaw) {
      try {
        const localData = JSON.parse(localEntriesRaw);
        for (const monthId of Object.keys(localData)) {
          const docRef = doc(this.firestore, `users/${userId}/work_entries/${monthId}`);
          const monthData = localData[monthId];
          
          // Daten konvertieren (JSON -> Firestore Timestamps)
          const cloudDays: any = {};
          for (const dayKey of Object.keys(monthData.days)) {
            const entry = monthData.days[dayKey];
            cloudDays[dayKey] = this.mapToFirestore(entry);
          }

          await setDoc(docRef, { days: cloudDays }, { merge: true });
        }
        localStorage.removeItem('wtm_local_work_entries');
        console.log('[Sync] Work Entries erfolgreich synchronisiert.');
      } catch (e) {
        console.error('[Sync] Fehler bei Work Entry Synchronisierung:', e);
      }
    }

    // 2. Overtime Balance synchronisieren
    const localOvertimeRaw = localStorage.getItem('wtm_local_overtime');
    if (localOvertimeRaw) {
      try {
        const overtimeData = JSON.parse(localOvertimeRaw);
        const docRef = doc(this.firestore, `users/${userId}/overtime/balance`);
        
        await setDoc(docRef, {
          minutes: overtimeData.minutes,
          lastUpdated: Timestamp.now()
        }, { merge: true });
        
        localStorage.removeItem('wtm_local_overtime');
        console.log('[Sync] Overtime Balance erfolgreich synchronisiert.');
      } catch (e) {
        console.error('[Sync] Fehler bei Overtime Synchronisierung:', e);
      }
    }
  }

  private mapToFirestore(entry: any): any {
    return {
      date: Timestamp.fromDate(new Date(entry.date)),
      workStart: entry.workStart ? Timestamp.fromDate(new Date(entry.workStart)) : null,
      workEnd: entry.workEnd ? Timestamp.fromDate(new Date(entry.workEnd)) : null,
      type: entry.type,
      description: entry.description || '',
      isManuallyEntered: entry.isManuallyEntered || false,
      manualOvertimeMinutes: entry.manualOvertimeMinutes || 0,
      breaks: (entry.breaks || []).map((b: any) => ({
        id: b.id,
        name: b.name,
        start: Timestamp.fromDate(new Date(b.start)),
        end: b.end ? Timestamp.fromDate(new Date(b.end)) : null,
        isAutomatic: b.isAutomatic || false
      }))
    };
  }
}
