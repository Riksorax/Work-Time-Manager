/**
 * Home-Office-Jahresauswertung (#537), 1:1 das DTO von `GET /api/reports/home-office/{year}`. Die Zählregel liegt nur im
 * Backend (`HomeOfficeCalculator`); der Client stellt dar.
 */
export interface HomeOfficeReport {
  year: number;
  /** Tage mit erfasster Zeit und Home-Office-Flag. */
  homeOfficeDays: number;
  /** Tage mit erfasster Zeit ohne Home-Office-Flag. */
  officeDays: number;
  /** Bezugstage: Home-Office plus Büro. */
  totalDays: number;
  /** Anteil 0..1, ungerundet; `null` ohne Bezugstage. */
  homeOfficeRatio: number | null;
  /** Immer 12 Monate (fehlt die Liste, gilt `[]`); derzeit nicht angezeigt. */
  months: HomeOfficeMonth[];
  /** Home-Office-Tage als Kalendertag `yyyy-MM-dd`, aufsteigend; derzeit nicht angezeigt. */
  homeOfficeDates: string[];
}

export interface HomeOfficeMonth {
  month: number;
  homeOfficeDays: number;
  officeDays: number;
  totalDays: number;
  homeOfficeRatio: number | null;
}
