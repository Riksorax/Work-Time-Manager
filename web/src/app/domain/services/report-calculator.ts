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
import { getIsoWeekBounds, getIsoWeekNumber } from '../../shared/utils/iso-week.util';
import { roundMsToMinute } from '../../shared/utils/time-precision.util';
import { entryDay, entryDayKey } from '../../shared/utils/entry-day.util';

// ─── Module-level helpers (no Angular DI) ─────────────────────────────────────

export function toDateKey(d: Date): string {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

function keyToDate(key: string): Date {
  const [y, m, d] = key.split('-').map(Number);
  return new Date(y, m - 1, d);
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
  return getIsoWeekBounds(date);
}

function isoWeekday(d: Date): number {
  const day = d.getDay();
  return day === 0 ? 7 : day;
}

function dailyTargetMs(settings: UserSettings): number {
  // Auf volle Minuten runden — die App rechnet durchgehend minutengenau.
  if (settings.workdays.length === 0) return 0;
  return roundMsToMinute((settings.weeklyTargetHours * 3600000) / settings.workdays.length);
}

// ─── Pure functions ─────────────────────────────────────────────────────────────

// Re-Export: gemeinsame DST-sichere Util (shared/utils/iso-week.util.ts)
export { getIsoWeekNumber };

export function calculateDailyStat(
  monthEntries: WorkEntry[],
  date: Date,
  settings: UserSettings,
): DailyStat {
  const daily = dailyTargetMs(settings);

  // Effektives Tagessoll (0 wenn der Wochentag kein Vertrags-Arbeitstag ist)
  const target = settings.workdays.includes(isoWeekday(date)) ? daily : 0;

  const dayEntries = monthEntries.filter(e => isSameDayRc(entryDay(e), date));
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

export function calculateWeeklyReport(
  entries: WorkEntry[],
  date: Date,
  settings: UserSettings,
): WeeklyReport {
  const daily = dailyTargetMs(settings);
  const { start: weekStart, end: weekEnd } = weekBounds(date);
  const weekEntries = entries.filter(e => {
    const ed = entryDay(e);
    return ed >= weekStart && ed <= weekEnd;
  });

  let totalWorked = 0;
  let totalBreaks = 0;
  let manualMs = 0;
  const workDaySet = new Set<string>();
  const dayMap = new Map<string, number>();

  for (const entry of weekEntries) {
    const key = entryDayKey(entry);

    let worked: number;
    let breaks = 0;

    if (entry.type !== WorkEntryType.Work) {
      // Urlaub/Krank/Feiertag zählen als voller Arbeitstag
      worked = daily;
      workDaySet.add(key);
    } else {
      // Bruttozeit (Start bis Ende), Pausen separat erfassen
      breaks = sumBreakMs(entry.breaks);
      worked = (entry.workStart && entry.workEnd)
        ? entry.workEnd.getTime() - entry.workStart.getTime()
        : 0;
      if (entry.workStart) workDaySet.add(key);
    }

    totalWorked += worked;
    totalBreaks += breaks;
    manualMs   += (entry.manualOvertimeMinutes ?? 0) * 60000;
    dayMap.set(key, (dayMap.get(key) ?? 0) + worked);
  }

  const effectiveDays = [...workDaySet].filter(k => settings.workdays.includes(isoWeekday(keyToDate(k)))).length;
  const weekTarget    = effectiveDays * daily;
  const netWork       = totalWorked - totalBreaks;
  const overtime      = netWork - weekTarget + manualMs;
  const avgPerDay     = workDaySet.size > 0 ? netWork / workDaySet.size : 0;

  const days: WeeklyReportDay[] = Array.from(dayMap.entries())
    .map(([k, worked]) => ({ date: keyToDate(k), worked }))
    .sort((a, b) => a.date.getTime() - b.date.getTime());

  return {
    weekNumber: getIsoWeekNumber(date),
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

export function calculateMonthlyReport(
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
    const key     = entryDayKey(entry);
    const weekNum = getIsoWeekNumber(entryDay(entry));

    if (!weekWorkDays.has(weekNum)) weekWorkDays.set(weekNum, new Set());

    let worked: number;
    let breaks = 0;

    if (entry.type !== WorkEntryType.Work) {
      worked = daily;
      weekWorkDays.get(weekNum)!.add(key);
    } else {
      // Bruttozeit (Start bis Ende), Pausen separat erfassen
      breaks = sumBreakMs(entry.breaks);
      worked = (entry.workStart && entry.workEnd)
        ? entry.workEnd.getTime() - entry.workStart.getTime()
        : 0;
      if (entry.workStart) weekWorkDays.get(weekNum)!.add(key);
    }

    totalWorked += worked;
    totalBreaks += breaks;
    manualMs    += (entry.manualOvertimeMinutes ?? 0) * 60000;
    dayMap.set(key,     (dayMap.get(key)     ?? 0) + worked);
    weekTotals.set(weekNum, (weekTotals.get(weekNum) ?? 0) + worked);
  }

  // Effektive Arbeitstage: nur Tage, deren Wochentag zu den Vertrags-Arbeitstagen gehört
  let effectiveTotalWorkDays = 0;
  for (const [, daySet] of weekWorkDays) {
    effectiveTotalWorkDays += [...daySet].filter(k => settings.workdays.includes(isoWeekday(keyToDate(k)))).length;
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
