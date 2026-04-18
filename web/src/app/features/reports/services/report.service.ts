import { Injectable, inject } from '@angular/core';
import { Firestore, doc, docData } from '@angular/fire/firestore';
import { AuthService } from '../../../../core/auth/auth.service';
import { WorkEntry, WeeklyReport, MonthlyReport, YearlyReport, DailyReport } from '../../../../shared/models';
import { Observable, map, of, switchMap, forkJoin, combineLatest } from 'rxjs';
import { 
  format, 
  startOfWeek, 
  endOfWeek, 
  eachDayOfInterval, 
  isSameDay, 
  startOfMonth, 
  endOfMonth,
  addMonths,
  subMonths
} from 'date-fns';
import { calculateNetDuration, calculateOvertime } from '../../../../shared/utils/time-calculations.util';

@Injectable({
  providedIn: 'root'
})
export class ReportService {
  private firestore = inject(Firestore);
  private auth = inject(AuthService);

  private getMonthId(date: Date): string {
    return format(date, 'yyyy-MM');
  }

  private getMonthDoc(userId: string, monthId: string) {
    return docData(doc(this.firestore, `users/${userId}/work_entries/${monthId}`));
  }

  getWeeklyReport(date: Date, targetDailyMinutes: number = 480): Observable<WeeklyReport> {
    const start = startOfWeek(date, { weekStartsOn: 1 });
    const end = endOfWeek(date, { weekStartsOn: 1 });
    const days = eachDayOfInterval({ start, end });
    
    // Wir müssen evtl. zwei Monate laden, wenn die Woche einen Monatswechsel hat
    const monthIds = Array.from(new Set(days.map(d => this.getMonthId(d))));

    return this.auth.currentUser$.pipe(
      switchMap(user => {
        if (!user) return of(null);
        
        const monthRequests = monthIds.map(id => this.getMonthDoc(user.uid, id));
        return combineLatest(monthRequests).pipe(
          map(monthsData => {
            const allDays: { [key: string]: any } = {};
            monthsData.forEach(data => {
              if (data && (data as any).days) {
                Object.assign(allDays, (data as any).days);
              }
            });

            const dailyReports: DailyReport[] = days.map(day => {
              const dayKey = day.getDate().toString();
              const dayData = allDays[dayKey];
              
              let workedMinutes = 0;
              let type: any = 'work';

              if (dayData && isSameDay(dayData.date.toDate(), day)) {
                workedMinutes = calculateNetDuration(this.mapFromFirestore(dayData, day));
                type = dayData.type;
              }

              return {
                date: day,
                workedMinutes,
                targetMinutes: targetDailyMinutes,
                overtimeMinutes: calculateOvertime(workedMinutes, targetDailyMinutes),
                type
              };
            });

            const totalWorked = dailyReports.reduce((sum, r) => sum + r.workedMinutes, 0);
            const totalTarget = dailyReports.reduce((sum, r) => sum + r.targetMinutes, 0);

            return {
              startDate: start,
              endDate: end,
              totalWorkedMinutes: totalWorked,
              totalTargetMinutes: totalTarget,
              overtimeMinutes: totalWorked - totalTarget,
              dailyReports
            };
          })
        );
      }),
      map(report => report as WeeklyReport)
    );
  }

  getMonthlyReport(year: number, month: number, targetDailyMinutes: number = 480): Observable<MonthlyReport> {
    const date = new Date(year, month - 1);
    const monthId = this.getMonthId(date);
    
    return this.auth.currentUser$.pipe(
      switchMap(user => {
        if (!user) return of(null);
        return this.getMonthDoc(user.uid, monthId).pipe(
          map((data: any) => {
            if (!data || !data.days) return { year, month, totalWorkedMinutes: 0, totalTargetMinutes: 0, overtimeMinutes: 0 };
            
            const days = Object.values(data.days);
            const totalWorked = days.reduce((sum: number, d: any) => sum + calculateNetDuration(this.mapFromFirestore(d, d.date.toDate())), 0);
            // Einfache Annahme: 20 Arbeitstage pro Monat für das Ziel, wenn nicht genauer berechnet
            const totalTarget = 20 * targetDailyMinutes; 

            return {
              year,
              month,
              totalWorkedMinutes: totalWorked,
              totalTargetMinutes: totalTarget,
              overtimeMinutes: totalWorked - totalTarget
            };
          })
        );
      }),
      map(report => report as MonthlyReport)
    );
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
