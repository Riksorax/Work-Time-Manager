// features/reports/services/report.service.ts
// Agent 6 — Reports & Statistics

import { Injectable, inject } from '@angular/core';
import { Observable, map, combineLatest } from 'rxjs';
import { WorkSessionService } from '../../time-tracking/services/work-session.service';
import { UserProfileService } from '../../settings/services/user-profile.service';
import {
  WorkSession, WeeklyReport, MonthlyReport, YearlyReport,
  DailyReport, CategoryBreakdown,
} from '../../../shared/models';
import {
  calculateNetMinutes, calculateDailyTotal, calculateOvertimeMinutes,
  calculateCategoryBreakdown, startOfDay, endOfDay, startOfWeek, endOfWeek,
  startOfMonth, endOfMonth, startOfYear, endOfYear, isSameDay,
} from '../../time-tracking/utils/time-calculations.util';

@Injectable({ providedIn: 'root' })
export class ReportService {
  private sessionService = inject(WorkSessionService);
  private profileService = inject(UserProfileService);

  // ─── Wochenbericht ────────────────────────────────────────────────────────

  getWeeklyReport(weekDate: Date): Observable<WeeklyReport> {
    const weekStart = startOfWeek(weekDate);
    const weekEnd = endOfWeek(weekDate);

    return this.sessionService.getSessionsInRange(weekStart, weekEnd).pipe(
      map(sessions => {
        const profile = this.profileService.profile();
        const dailyTargetMinutes = (profile?.dailyTargetHours ?? 8) * 60;
        const weeklyTargetMinutes = (profile?.weeklyTargetHours ?? 40) * 60;

        // 7 Tage (Mo–So) aufbauen
        const dailyReports: DailyReport[] = [];
        for (let i = 0; i < 7; i++) {
          const day = new Date(weekStart);
          day.setDate(weekStart.getDate() + i);

          const daySessions = sessions.filter(s =>
            isSameDay(s.startTime.toDate(), day)
          );
          const totalMinutes = calculateDailyTotal(daySessions);
          dailyReports.push({
            date: day,
            sessions: daySessions,
            totalMinutes,
            targetMinutes: dailyTargetMinutes,
            overtimeMinutes: calculateOvertimeMinutes(totalMinutes, dailyTargetMinutes),
          });
        }

        const totalMinutes = dailyReports.reduce((s, d) => s + d.totalMinutes, 0);
        return {
          weekStart,
          weekEnd,
          dailyReports,
          totalMinutes,
          targetMinutes: weeklyTargetMinutes,
          overtimeMinutes: calculateOvertimeMinutes(totalMinutes, weeklyTargetMinutes),
        };
      })
    );
  }

  // ─── Monatsbericht (Premium) ──────────────────────────────────────────────

  getMonthlyReport(monthDate: Date): Observable<MonthlyReport> {
    const monthStart = startOfMonth(monthDate);
    const monthEnd = endOfMonth(monthDate);

    return this.sessionService.getSessionsInRange(monthStart, monthEnd).pipe(
      map(sessions => {
        const profile = this.profileService.profile();
        const weeklyTargetMinutes = (profile?.weeklyTargetHours ?? 40) * 60;

        // Wochen im Monat aufbauen
        const weeks: WeeklyReport[] = [];
        let cur = startOfWeek(monthStart);
        while (cur <= monthEnd) {
          const wEnd = endOfWeek(cur);
          const wSessions = sessions.filter(s => {
            const d = s.startTime.toDate();
            return d >= cur && d <= wEnd;
          });
          const totalMinutes = calculateDailyTotal(wSessions);
          weeks.push({
            weekStart: new Date(cur),
            weekEnd: wEnd,
            dailyReports: [],
            totalMinutes,
            targetMinutes: weeklyTargetMinutes,
            overtimeMinutes: calculateOvertimeMinutes(totalMinutes, weeklyTargetMinutes),
          });
          cur = new Date(cur);
          cur.setDate(cur.getDate() + 7);
        }

        const totalMinutes = weeks.reduce((s, w) => s + w.totalMinutes, 0);
        // Arbeitstage im Monat × tägliche Soll-Stunden
        const workDays = this.countWorkdays(monthStart, monthEnd);
        const targetMinutes = workDays * (profile?.dailyTargetHours ?? 8) * 60;

        return {
          month: monthDate,
          weeklyReports: weeks,
          totalMinutes,
          targetMinutes,
          overtimeMinutes: calculateOvertimeMinutes(totalMinutes, targetMinutes),
        };
      })
    );
  }

  // ─── Jahresbericht (Premium) ──────────────────────────────────────────────

  getYearlyReport(year: number): Observable<YearlyReport> {
    return this.sessionService.getSessionsInRange(startOfYear(year), endOfYear(year)).pipe(
      map(sessions => {
        const profile = this.profileService.profile();

        const monthlyReports: MonthlyReport[] = [];
        for (let m = 0; m < 12; m++) {
          const monthDate = new Date(year, m, 1);
          const mStart = startOfMonth(monthDate);
          const mEnd = endOfMonth(monthDate);
          const mSessions = sessions.filter(s => {
            const d = s.startTime.toDate();
            return d >= mStart && d <= mEnd;
          });
          const totalMinutes = calculateDailyTotal(mSessions);
          const workDays = this.countWorkdays(mStart, mEnd);
          const targetMinutes = workDays * (profile?.dailyTargetHours ?? 8) * 60;

          monthlyReports.push({
            month: monthDate,
            weeklyReports: [],
            totalMinutes,
            targetMinutes,
            overtimeMinutes: calculateOvertimeMinutes(totalMinutes, targetMinutes),
          });
        }

        const totalMinutes = monthlyReports.reduce((s, m) => s + m.totalMinutes, 0);
        const totalTarget = monthlyReports.reduce((s, m) => s + m.targetMinutes, 0);

        return {
          year,
          monthlyReports,
          totalMinutes,
          targetMinutes: totalTarget,
          overtimeMinutes: calculateOvertimeMinutes(totalMinutes, totalTarget),
        };
      })
    );
  }

  // ─── Kategorie-Auswertung (Premium) ──────────────────────────────────────

  getCategoryBreakdown(startDate: Date, endDate: Date): Observable<CategoryBreakdown[]> {
    return this.sessionService.getSessionsInRange(startDate, endDate).pipe(
      map(sessions => calculateCategoryBreakdown(sessions))
    );
  }

  // ─── Hilfsfunktionen ─────────────────────────────────────────────────────

  private countWorkdays(start: Date, end: Date): number {
    let count = 0;
    const cur = new Date(start);
    while (cur <= end) {
      const day = cur.getDay();
      if (day !== 0 && day !== 6) count++; // Mo(1)–Fr(5)
      cur.setDate(cur.getDate() + 1);
    }
    return count;
  }
}
