/**
 * Jahresvergleich mit dem Vorjahr (#530), 1:1 das DTO von `GET /api/reports/yearly-comparison/{year}?until=MM-dd`.
 * Alle Werte rechnet das Backend (auch Differenzen und Prozentwert); der Client stellt nur dar. Dauern in ms.
 */
export interface YearlyComparison {
  /** Stichtag `MM-dd` wie übergeben (beide Jahre nur bis einschließlich dieses Tags), `null` = ganzes Jahr. */
  until: string | null;
  current: YearlySummary;
  previous: YearlySummary;
  /** `current − previous` je Feld; `null`, wenn das Vorjahr keine Einträge hat. */
  delta: YearlyDelta | null;
}

export interface YearlySummary {
  year: number;
  /** `false`: im (abgeschnittenen) Jahr gibt es keinen Eintrag, alle Werte sind 0. */
  hasData: boolean;
  /** Netto-Arbeitszeit (ohne Pausen; Urlaub/Krank/Feiertag mit Tagessoll). */
  totalWorkedMs: number;
  totalBreaksMs: number;
  /** Überstunden des Jahres (Summe der Monate), nicht der Gleitzeit-Saldo. */
  overtimeMs: number;
  workDays: number;
  vacationDays: number;
  sickDays: number;
  holidayDays: number;
  /** Immer 12 Monate; in diesem Schritt nicht angezeigt. */
  months: YearlySummaryMonth[];
}

export interface YearlySummaryMonth {
  month: number;
  workedMs: number;
  overtimeMs: number;
  workDays: number;
}

export interface YearlyDelta {
  workedMs: number;
  /** Prozent zur Netto-Arbeitszeit des Vorjahres, eine Nachkommastelle; `null`, wenn die Vorjahres-Arbeitszeit 0 ist. */
  workedPercent: number | null;
  overtimeMs: number;
  workDays: number;
  vacationDays: number;
  sickDays: number;
  holidayDays: number;
}
