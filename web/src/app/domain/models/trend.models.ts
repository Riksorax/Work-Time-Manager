/** Zeitfenster der Trend-Ansicht (#531): 12 Wochen oder 12 Monate bis zum Bezugstag. */
export type TrendGranularity = 'week' | 'month';

/**
 * Eine Woche (Mo–So) oder ein Kalendermonat im Trend (#531), 1:1 aus `TrendBucketDto` des Backends.
 * Alle Dauern in Millisekunden; `worked` ist netto. Der Client rechnet nichts nach.
 */
export interface TrendBucket {
  /** Woche: `yyyy-Www` (ISO-Wochenjahr), Monat: `yyyy-MM`. */
  key: string;
  /** Erster Kalendertag als lokale Mitternacht (aus der UTC-Mitternacht des Backends, #407). */
  start: Date;
  /** Letzter Kalendertag als lokale Mitternacht. */
  end: Date;
  worked: number;
  target: number;
  overtime: number;
  /** Laufende Summe der Überstunden im Zeitfenster ab 0, kein Gleitzeit-Saldo. */
  cumulativeOvertime: number;
  hasData: boolean;
}

/** Kennzahl „Wochen-Trend“ (#531): letzte abgeschlossene Woche gegen das Mittel der Vergleichswochen. */
export interface WeeklyTrend {
  lastWeekKey: string;
  lastWeekWorked: number;
  averageWorked: number;
  delta: number;
  comparedWeeks: number;
}

/**
 * Überstunden-Prognose zum Jahresende (#532), 1:1 aus `OvertimeForecastDto` des Backends. Der Client rechnet nichts.
 * Geplanter Urlaub und Feiertage im Rest des Jahres sind nicht berücksichtigt.
 */
export interface OvertimeForecast {
  /** 31.12. des Jahres des Bezugstags als lokale Mitternacht (Kalendertag, nicht über eine Zeitzone gelesen). */
  targetDate: Date;
  /** Gespeicherter Gleitzeit-Saldo. */
  currentBalance: number;
  /** Mittel der Wochen-Überstunden über die eingerechneten Wochen. */
  averageWeeklyOvertime: number;
  /** Eingerechnete Wochen (4–8). */
  weeksUsed: number;
  /** Kalendertage bis einschließlich 31.12. / 7, nicht gerundet (am 31.12. 0). */
  remainingWeeks: number;
  /** Aktueller Saldo + Mittel × Restwochen. */
  projectedBalance: number;
}

export interface TrendReport {
  granularity: TrendGranularity;
  /** Immer 12, älteste zuerst; der letzte enthält den Bezugstag und ist ggf. unvollständig. */
  buckets: TrendBucket[];
  weeklyTrend: WeeklyTrend | null;
  /** Bei beiden Granularitäten gleich; `null` bei zu wenig Daten oder fehlendem Feld (älteres Backend). */
  forecast: OvertimeForecast | null;
}
