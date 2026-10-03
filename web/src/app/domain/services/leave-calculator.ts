import { WorkEntry, WorkEntryType } from '../../shared/models/index';
import { YearlyLeaveReport } from '../models/leave.models';

/**
 * Pure Jahresübersicht für Urlaub/Krankheit (anonyme Nutzer, Parität zum Backend).
 * Jeder vacation-/sick-Eintrag zählt als ein Tag, auch an Wochenenden.
 */
export function calculateYearlyLeave(
  entries: WorkEntry[],
  year: number,
  vacationDaysPerYear: number,
): YearlyLeaveReport {
  let vacationDaysTaken = 0;
  let sickDays = 0;
  for (const e of entries) {
    if (e.date.getFullYear() !== year) continue;
    if (e.type === WorkEntryType.Vacation) vacationDaysTaken++;
    else if (e.type === WorkEntryType.Sick) sickDays++;
  }
  return {
    year,
    vacationDaysPerYear,
    vacationDaysTaken,
    vacationDaysRemaining: vacationDaysPerYear - vacationDaysTaken,
    sickDays,
  };
}
