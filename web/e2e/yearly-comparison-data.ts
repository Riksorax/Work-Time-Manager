/**
 * Gemockte Antworten für `GET /api/reports/yearly-comparison/{year}?until=MM-dd` (#530) in E2E-Tests und Screenshots.
 * Reine Testdaten im Format des Backend-DTOs (`YearlyComparisonDto`); die echte Rechnung testet das Backend.
 */

const HOUR = 3_600_000;
const MINUTE = 60_000;

export interface YearlyComparisonMockOptions {
  /** Stichtag `MM-dd` (laufendes Jahr) oder `null`. */
  until?: string | null;
  /** Vorjahr ohne Einträge (dann `delta: null`). */
  previousEmpty?: boolean;
  /** Gewähltes Jahr ohne Einträge. */
  currentEmpty?: boolean;
  /** `workedPercent: null`. */
  noPercent?: boolean;
}

function months(): unknown[] {
  return Array.from({ length: 12 }, (_, i) => ({ month: i + 1, workedMs: 0, overtimeMs: 0, workDays: 0 }));
}

function summary(year: number, s: { worked: number; overtime: number; work: number; vac: number; sick: number; hol: number } | null) {
  return {
    year,
    hasData: s !== null,
    totalWorkedMs: s?.worked ?? 0,
    totalBreaksMs: s ? 95 * HOUR : 0,
    overtimeMs: s?.overtime ?? 0,
    workDays: s?.work ?? 0,
    vacationDays: s?.vac ?? 0,
    sickDays: s?.sick ?? 0,
    holidayDays: s?.hol ?? 0,
    months: months(),
  };
}

export function yearlyComparisonResponse(year: number, opts: YearlyComparisonMockOptions = {}): unknown {
  const partial = !!opts.until;
  const cur = opts.currentEmpty ? null : partial
    ? { worked: 1498 * HOUR + 30 * MINUTE, overtime: 18 * HOUR + 45 * MINUTE, work: 189, vac: 24, sick: 3, hol: 9 }
    : { worked: 1712 * HOUR + 15 * MINUTE, overtime: 22 * HOUR + 30 * MINUTE, work: 214, vac: 30, sick: 6, hol: 10 };
  const prev = opts.previousEmpty ? null : partial
    ? { worked: 1421 * HOUR, overtime: -(4 * HOUR + 15 * MINUTE), work: 183, vac: 27, sick: 7, hol: 9 }
    : { worked: 1650 * HOUR, overtime: 6 * HOUR, work: 208, vac: 30, sick: 9, hol: 10 };
  const delta = cur && prev ? {
    workedMs: cur.worked - prev.worked,
    workedPercent: opts.noPercent ? null : Math.round(((cur.worked - prev.worked) / prev.worked) * 1000) / 10,
    overtimeMs: cur.overtime - prev.overtime,
    workDays: cur.work - prev.work,
    vacationDays: cur.vac - prev.vac,
    sickDays: cur.sick - prev.sick,
    holidayDays: cur.hol - prev.hol,
  } : null;
  // Die Differenzen stehen hier nur, damit die Testdaten in sich stimmig sind; im Client wird nichts gerechnet.
  return { until: opts.until ?? null, current: summary(year, cur), previous: summary(year - 1, prev), delta };
}
