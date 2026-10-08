/** Jahres-Urlaubsübersicht (1:1 das DTO von GET /api/reports/yearly/{year}). */
export interface YearlyLeaveReport {
  year: number;
  vacationDaysPerYear: number;
  vacationDaysTaken: number;
  /** Kann negativ sein (Überschreitung des Anspruchs). */
  vacationDaysRemaining: number;
  sickDays: number;
}
