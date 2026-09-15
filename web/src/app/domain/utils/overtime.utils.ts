import { WorkEntry } from '../../shared/models';

/** ISO-Wochentag (1 = Montag, 7 = Sonntag) für ein Datum. */
function isoWeekday(d: Date): number {
  const day = d.getDay();
  return day === 0 ? 7 : day;
}

export function getEffectiveDailyTarget(
  date: Date,
  workdays: number[],
  regularDailyTargetMs: number,
): number {
  return workdays.includes(isoWeekday(date)) ? regularDailyTargetMs : 0;
}

export function getEffectiveWorkDays(entries: WorkEntry[], workdays: number[]): number {
  const uniqueDays = new Map<string, Date>();
  for (const e of entries) {
    if (e.workStart) uniqueDays.set(toDateKey(e.date), e.date);
  }
  return [...uniqueDays.values()].filter(d => workdays.includes(isoWeekday(d))).length;
}

export function getWeekEntriesForDate(date: Date, monthlyEntries: WorkEntry[]): WorkEntry[] {
  const d = startOfDay(date);
  const dayOfWeek = d.getDay() === 0 ? 7 : d.getDay(); // ISO: Mo=1, So=7
  const startOfWeek = new Date(d.getTime() - (dayOfWeek - 1) * 86400000);
  const endOfWeek   = new Date(startOfWeek.getTime() + 6 * 86400000);

  return monthlyEntries.filter(e => {
    const ed = startOfDay(e.date);
    return ed >= startOfWeek && ed <= endOfWeek;
  });
}

export function calculateInitialOvertime(
  storedOvertimeMs: number,
  lastUpdateDate: Date | null,
  initialDailyOvertimeMs: number,
): number {
  if (lastUpdateDate && isSameDay(lastUpdateDate, new Date())) {
    // Heute bereits gespeichert → Base = Stored − Daily
    return storedOvertimeMs - initialDailyOvertimeMs;
  }
  return storedOvertimeMs;
}

// ─── Helpers ───────────────────────────────────────────────────────────────

function toDateKey(d: Date): string {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

function startOfDay(d: Date): Date {
  return new Date(d.getFullYear(), d.getMonth(), d.getDate());
}

export function isSameDay(a: Date, b: Date): boolean {
  return a.getFullYear() === b.getFullYear()
    && a.getMonth() === b.getMonth()
    && a.getDate() === b.getDate();
}
