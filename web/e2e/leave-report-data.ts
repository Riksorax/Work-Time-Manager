/**
 * Gemockte Antworten für `GET /api/reports/yearly/{year}` mit Aufschlüsselung (#284) in E2E-Tests und Screenshots.
 * Reine Testdaten im Format des Backend-DTOs (`YearlyReportDto`); die echte Rechnung testet das Backend.
 */

export interface LeaveReportMockOptions {
  /** Jahr ohne Urlaubs- und Krankheitstage. */
  empty?: boolean;
  /** Urlaubsanspruch (Standard 30). */
  entitlement?: number;
}

interface Period { start: string; end: string; days: number }

const pad = (n: number) => String(n).padStart(2, '0');
const day = (year: number, month: number, d: number) => `${year}-${pad(month)}-${pad(d)}`;

export function yearlyLeaveResponse(year: number, opts: LeaveReportMockOptions = {}): unknown {
  const entitlement = opts.entitlement ?? 30;
  const vacationPeriods: Period[] = opts.empty ? [] : [
    { start: day(year, 1, 2), end: day(year, 1, 2), days: 1 },
    { start: day(year, 5, 26), end: day(year, 5, 29), days: 4 },
    { start: day(year, 8, 3), end: day(year, 8, 14), days: 12 },
    { start: day(year, 12, 28), end: day(year, 12, 31), days: 4 },
  ];
  const sickPeriods: Period[] = opts.empty ? [] : [
    { start: day(year, 2, 10), end: day(year, 2, 12), days: 3 },
    { start: day(year, 10, 7), end: day(year, 10, 7), days: 1 },
  ];
  // Die Monatswerte und Summen stehen hier nur, damit die Testdaten in sich stimmig sind; im Client wird nichts gerechnet.
  const perMonth = (list: Period[], month: number) =>
    list.filter(p => Number(p.start.slice(5, 7)) === month).reduce((a, p) => a + p.days, 0);
  const months = Array.from({ length: 12 }, (_, i) => ({
    month: i + 1, vacationDays: perMonth(vacationPeriods, i + 1), sickDays: perMonth(sickPeriods, i + 1),
  }));
  const taken = vacationPeriods.reduce((a, p) => a + p.days, 0);
  return {
    year,
    vacationDaysPerYear: entitlement,
    vacationDaysTaken: taken,
    vacationDaysRemaining: entitlement - taken,
    sickDays: sickPeriods.reduce((a, p) => a + p.days, 0),
    months,
    vacationPeriods,
    sickPeriods,
  };
}
