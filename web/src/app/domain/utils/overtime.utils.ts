import { WorkEntry } from '../../shared/models';

export function getEffectiveDailyTarget(
  date: Date,
  weekEntries: WorkEntry[],
  workdaysPerWeek: number,
  regularDailyTargetMs: number,
): number {
  const workDays = [...new Set(
    weekEntries
      .filter(e => e.workStart)
      .map(e => toDateKey(e.date))
  )].sort();

  const dayKey = toDateKey(date);
  const idx = workDays.indexOf(dayKey);

  if (idx === -1) return regularDailyTargetMs;
  if (idx < workdaysPerWeek) return regularDailyTargetMs;
  return 0;
}

export function getEffectiveWorkDays(entries: WorkEntry[], workdaysPerWeek: number): number {
  const unique = new Set(entries.filter(e => e.workStart).map(e => toDateKey(e.date))).size;
  return Math.min(unique, workdaysPerWeek);
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
