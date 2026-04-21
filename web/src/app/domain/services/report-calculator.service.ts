import { Injectable } from '@angular/core';
import { WorkEntry, WorkEntryType, UserSettings } from '../../shared/models/index';
import { Break } from '../../shared/models/index';
import {
  DailyStat,
  MonthlyReport,
  MonthlyReportDay,
  MonthlyReportWeek,
  WeeklyReport,
  WeeklyReportDay,
} from '../models/reports.models';

// ─── Module-level helpers (no Angular DI) ─────────────────────────────────────

export function toDateKey(d: Date): string {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

function keyToDate(key: string): Date {
  const [y, m, d] = key.split('-').map(Number);
  return new Date(y, m - 1, d);
}

function startOfDay(d: Date): Date {
  return new Date(d.getFullYear(), d.getMonth(), d.getDate());
}

export function isSameDayRc(a: Date, b: Date): boolean {
  return a.getFullYear() === b.getFullYear()
    && a.getMonth() === b.getMonth()
    && a.getDate() === b.getDate();
}

function sumBreakMs(breaks: Break[]): number {
  return breaks.reduce((sum, b) => {
    if (!b.end) return sum;
    return sum + (b.end.getTime() - b.start.getTime());
  }, 0);
}

function netWorkMs(entry: WorkEntry): number {
  if (entry.type !== WorkEntryType.Work) return 0;
  if (!entry.workStart || !entry.workEnd) return 0;
  return Math.max(0, entry.workEnd.getTime() - entry.workStart.getTime() - sumBreakMs(entry.breaks));
}

function weekBounds(date: Date): { start: Date; end: Date } {
  const d = startOfDay(date);
  const dow = d.getDay() === 0 ? 7 : d.getDay(); // ISO: Mon=1, Sun=7
  const start = new Date(d.getTime() - (dow - 1) * 86400000);
  const end   = new Date(start.getTime() + 6 * 86400000);
  return { start, end };
}

function filterByWeek(entries: WorkEntry[], date: Date): WorkEntry[] {
  const { start, end } = weekBounds(date);
  return entries.filter(e => {
    const ed = startOfDay(e.date);
    return ed >= start && ed <= end;
  });
}

function dailyTargetMs(settings: UserSettings): number {
  return (settings.weeklyTargetHours * 3600000) / settings.workdaysPerWeek;
}

// ─── Injectable Service ────────────────────────────────────────────────────────

@Injectable({ providedIn: 'root' })
export class ReportCalculatorService {

  getIsoWeekNumber(date: Date): number {
    const year = date.getFullYear();
    const jan4 = new Date(year, 0, 4);
    const dow4 = jan4.getDay() === 0 ? 7 : jan4.getDay();
    const firstMonday = new Date(jan4.getTime() - (dow4 - 1) * 86400000);
    const d = startOfDay(date);
    const diff = d.getTime() - firstMonday.getTime();
    const week = Math.floor(diff / (7 * 86400000)) + 1;

    if (week < 1) {
      // Falls in letzte Woche des Vorjahres
      return this.getIsoWeekNumber(new Date(year - 1, 11, 28));
    }

    // Falls in erste Woche des Folgejahres
    const jan4Next = new Date(year + 1, 0, 4);
    const dow4Next = jan4Next.getDay() === 0 ? 7 : jan4Next.getDay();
    const firstMondayNext = new Date(jan4Next.getTime() - (dow4Next - 1) * 86400000);
    if (d >= firstMondayNext) return 1;

    return week;
  }

  calculateDailyStat(
    monthEntries: WorkEntry[],
    date: Date,
    settings: UserSettings,
  ): DailyStat {
    const daily = dailyTargetMs(settings);
    const weekEntries = filterByWeek(monthEntries, date);

    // Effektives Tagessoll (0 wenn Zusatztag jenseits workdaysPerWeek)
    const target = this._effectiveDailyTarget(date, weekEntries, settings, daily);

    const dayEntries = monthEntries.filter(e => isSameDayRc(e.date, date));
    let worked = 0;
    let manualMs = 0;

    for (const entry of dayEntries) {
      if (entry.type !== WorkEntryType.Work) {
        // Urlaub / Krank / Feiertag: Soll gilt als erfüllt
        worked += target;
      } else {
        worked += netWorkMs(entry);
      }
      manualMs += (entry.manualOvertimeMinutes ?? 0) * 60000;
    }

    return { target, worked, overtime: worked - target + manualMs };
  }

  calculateWeeklyReport(
    entries: WorkEntry[],
    date: Date,
    settings: UserSettings,
  ): WeeklyReport {
    const daily = dailyTargetMs(settings);
    const { start: weekStart, end: weekEnd } = weekBounds(date);
    const weekEntries = entries.filter(e => {
      const ed = startOfDay(e.date);
      return ed >= weekStart && ed <= weekEnd;
    });

    let totalWorked = 0;
    let totalBreaks = 0;
    let manualMs = 0;
    const workDaySet = new Set<string>();
    const dayMap = new Map<string, number>();

    for (const entry of weekEntries) {
      const key = toDateKey(entry.date);

      let worked: number;
      let breaks = 0;

      if (entry.type !== WorkEntryType.Work) {
        // Urlaub/Krank/Feiertag zählen als voller Arbeitstag
        worked = daily;
        workDaySet.add(key);
      } else {
        worked = netWorkMs(entry);
        breaks = sumBreakMs(entry.breaks);
        if (entry.workStart) workDaySet.add(key);
      }

      totalWorked += worked;
      totalBreaks += breaks;
      manualMs   += (entry.manualOvertimeMinutes ?? 0) * 60000;
      dayMap.set(key, (dayMap.get(key) ?? 0) + worked);
    }

    const effectiveDays = Math.min(workDaySet.size, settings.workdaysPerWeek);
    const weekTarget    = effectiveDays * daily;
    const netWork       = totalWorked - totalBreaks;
    const overtime      = netWork - weekTarget + manualMs;
    const avgPerDay     = workDaySet.size > 0 ? netWork / workDaySet.size : 0;

    const days: WeeklyReportDay[] = Array.from(dayMap.entries())
      .map(([k, worked]) => ({ date: keyToDate(k), worked }))
      .sort((a, b) => a.date.getTime() - b.date.getTime());

    return {
      weekNumber: this.getIsoWeekNumber(date),
      start: weekStart,
      end: weekEnd,
      totalWorked,
      totalBreaks,
      workDays: workDaySet.size,
      avgPerDay,
      overtime,
      days,
    };
  }

  calculateMonthlyReport(
    entries: WorkEntry[],
    monthRef: Date,
    settings: UserSettings,
    storedOvertimeMs: number,
  ): MonthlyReport {
    const daily = dailyTargetMs(settings);

    // weekNum → Set<dateKey> (nur für effektive Tages-Zählung)
    const weekWorkDays = new Map<number, Set<string>>();
    const weekTotals   = new Map<number, number>();
    const dayMap       = new Map<string, number>();

    let totalWorked = 0;
    let totalBreaks = 0;
    let manualMs    = 0;

    for (const entry of entries) {
      const key     = toDateKey(entry.date);
      const weekNum = this.getIsoWeekNumber(entry.date);

      if (!weekWorkDays.has(weekNum)) weekWorkDays.set(weekNum, new Set());

      let worked: number;
      let breaks = 0;

      if (entry.type !== WorkEntryType.Work) {
        worked = daily;
        weekWorkDays.get(weekNum)!.add(key);
      } else {
        worked = netWorkMs(entry);
        breaks = sumBreakMs(entry.breaks);
        if (entry.workStart) weekWorkDays.get(weekNum)!.add(key);
      }

      totalWorked += worked;
      totalBreaks += breaks;
      manualMs    += (entry.manualOvertimeMinutes ?? 0) * 60000;
      dayMap.set(key,     (dayMap.get(key)     ?? 0) + worked);
      weekTotals.set(weekNum, (weekTotals.get(weekNum) ?? 0) + worked);
    }

    // Effektive Arbeitstage: je Woche max workdaysPerWeek
    let effectiveTotalWorkDays = 0;
    for (const [, daySet] of weekWorkDays) {
      effectiveTotalWorkDays += Math.min(daySet.size, settings.workdaysPerWeek);
    }

    const monthTarget       = effectiveTotalWorkDays * daily;
    const netWork           = totalWorked - totalBreaks;
    const monthlyOvertime   = netWork - monthTarget + manualMs;
    const totalOvertime     = monthlyOvertime + storedOvertimeMs;

    const workDays  = Array.from(weekWorkDays.values()).reduce((s, set) => s + set.size, 0);
    const numWeeks  = weekWorkDays.size;
    const avgPerDay  = workDays  > 0 ? netWork / workDays  : 0;
    const avgPerWeek = numWeeks  > 0 ? netWork / numWeeks  : 0;

    const weeks: MonthlyReportWeek[] = Array.from(weekTotals.entries())
      .map(([weekNumber, totalWorkedW]) => ({ weekNumber, totalWorked: totalWorkedW }))
      .sort((a, b) => a.weekNumber - b.weekNumber);

    const days: MonthlyReportDay[] = Array.from(dayMap.entries())
      .map(([k, worked]) => ({ date: keyToDate(k), worked }))
      .sort((a, b) => a.date.getTime() - b.date.getTime());

    return {
      month: new Date(monthRef.getFullYear(), monthRef.getMonth(), 1),
      totalWorked,
      totalBreaks,
      workDays,
      avgPerDay,
      avgPerWeek,
      monthlyOvertime,
      totalOvertime,
      weeks,
      days,
    };
  }

  // ─── Private ─────────────────────────────────────────────────────────────────

  private _effectiveDailyTarget(
    date: Date,
    weekEntries: WorkEntry[],
    settings: UserSettings,
    daily: number,
  ): number {
    const workDays = [...new Set(
      weekEntries
        .filter(e => e.workStart || e.type !== WorkEntryType.Work)
        .map(e => toDateKey(e.date))
    )].sort();

    const key = toDateKey(date);
    const idx = workDays.indexOf(key);
    if (idx === -1) return daily;
    return idx < settings.workdaysPerWeek ? daily : 0;
  }
}
