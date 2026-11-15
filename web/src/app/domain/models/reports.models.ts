export interface DailyStat {
  target: number;
  worked: number;
  overtime: number;
}

export interface WeeklyReportDay {
  date: Date;
  /** Brutto (Start bis Ende, inkl. Pausen). */
  worked: number;
  /** Netto: brutto − abgeschlossene Pausen des Tages (#551), nicht bei 0 gekappt. Fehlt das Feld im Backend, gilt brutto. */
  netWorked: number;
}

export interface WeeklyReport {
  weekNumber: number;
  start: Date;
  end: Date;
  totalWorked: number;
  totalBreaks: number;
  workDays: number;
  avgPerDay: number;
  overtime: number;
  days: WeeklyReportDay[];
}

export interface MonthlyReportWeek {
  weekNumber: number;
  totalWorked: number;
  /** Netto der Woche (ohne Pausen, nur Tage des Monats, #551). Fehlt das Feld im Backend, gilt brutto. */
  netWorked: number;
}

export interface MonthlyReportDay {
  date: Date;
  worked: number;
  /** Netto des Tages (#551), siehe `WeeklyReportDay.netWorked`. */
  netWorked: number;
}

export interface MonthlyReport {
  month: Date;
  totalWorked: number;
  totalBreaks: number;
  workDays: number;
  avgPerDay: number;
  avgPerWeek: number;
  monthlyOvertime: number;
  totalOvertime: number;
  weeks: MonthlyReportWeek[];
  days: MonthlyReportDay[];
}
