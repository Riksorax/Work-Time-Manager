/**
 * Arbeitszeit-Insights (#537), 1:1 das DTO von `GET /api/reports/insights/{y}/{m}/{d}?tz=<IANA>`. Alle Werte rechnet das
 * Backend (`InsightsCalculator`); der Client formatiert nur. Dauern in ms, Kalendertage als `yyyy-MM-dd`.
 */
export interface InsightsReport {
  /** Erster Tag des Zeitfensters (1. des Monats zwei Monate vor dem Bezugsmonat). */
  from: string;
  /** Letzter Tag des Zeitfensters (Monatsletzter des Bezugsmonats). */
  to: string;
  /** Die übergebene IANA-Zeitzone. */
  timeZone: string;
  /** Tagessoll, Bezug für Serie und Heatmap. */
  dailyTargetMs: number;
  /** Nur Wochentage mit Daten, aufsteigend (1 = Mo … 7 = So). */
  weekdayAverages: WeekdayAverage[];
  overtimeStreak: OvertimeStreak;
  /** Nur Startstunden mit Daten (Backend: mindestens 2 Einträge), aufsteigend. */
  startTimeHeatmap: StartTimeBucket[];
}

export interface WeekdayAverage {
  /** 1 = Montag … 7 = Sonntag. */
  weekday: number;
  averageWorkedMs: number;
  /** Mittel des Wochentags minus Mittel aller Einträge (kann negativ sein). */
  deviationMs: number;
  sampleCount: number;
}

export interface OvertimeStreak {
  currentStreak: number;
  longestStreak: number;
  isWarning: boolean;
  warningThresholdDays: number;
}

export interface StartTimeBucket {
  /** Lokale Startstunde 0..23 in der übergebenen Zeitzone. */
  startHour: number;
  /** Durchschnittliche Abweichung vom Tagessoll. */
  averageOvertimeMs: number;
  sampleCount: number;
}
