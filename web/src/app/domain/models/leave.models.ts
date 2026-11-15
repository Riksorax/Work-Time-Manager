/** Urlaubs- und Krankheitstage eines Monats (#284). */
export interface LeaveMonth {
  /** 1–12. */
  month: number;
  vacationDays: number;
  sickDays: number;
}

/**
 * Zusammenhängender Zeitraum (#284), vom Backend zusammengefasst und auf das Jahr beschnitten.
 * `start`/`end` sind Kalendertage `yyyy-MM-dd` ohne Uhrzeit (nie als `new Date(iso)` parsen).
 */
export interface LeavePeriod {
  start: string;
  end: string;
  days: number;
}

/** Jahres-Urlaubsübersicht (1:1 das DTO von GET /api/reports/yearly/{year}). */
export interface YearlyLeaveReport {
  year: number;
  vacationDaysPerYear: number;
  vacationDaysTaken: number;
  /** Kann negativ sein (Überschreitung des Anspruchs). */
  vacationDaysRemaining: number;
  sickDays: number;
  /**
   * Ab #284: immer 12 Einträge. Optional, weil die lokale Rechnung (Gast-Modus) die Aufschlüsselung nicht liefert;
   * `ApiClient.getYearlyLeave` setzt bei einem älteren Backend eine leere Liste.
   */
  months?: LeaveMonth[];
  /** Ab #284, aufsteigend sortiert; Summe der `days` = `vacationDaysTaken`. */
  vacationPeriods?: LeavePeriod[];
  /** Ab #284, aufsteigend sortiert; Summe der `days` = `sickDays`. */
  sickPeriods?: LeavePeriod[];
}
