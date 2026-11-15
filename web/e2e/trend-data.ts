/**
 * Gemockte Antworten für `GET /api/reports/trend/{y}/{m}/{d}` (#531) in E2E-Tests und Screenshots. Reine Testdaten im
 * Format des Backend-DTOs (`TrendReportDto`); die echte Rechnung testet das Backend.
 */

const HOUR = 3_600_000;
const pad = (n: number) => String(n).padStart(2, '0');
const utcIso = (d: Date) => `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T00:00:00+00:00`;

function isoWeekKey(d: Date): string {
  const t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
  t.setUTCDate(t.getUTCDate() + 4 - (t.getUTCDay() || 7));
  const y0 = new Date(Date.UTC(t.getUTCFullYear(), 0, 1));
  const week = Math.ceil(((t.getTime() - y0.getTime()) / 86_400_000 + 1) / 7);
  return `${t.getUTCFullYear()}-W${pad(week)}`;
}

export interface TrendMockOptions {
  /** Indizes (0 = älteste) ohne Einträge. */
  gaps?: number[];
  /** Arbeitszeit je Zeitraum in Stunden (12 Werte); Standard: realistische Woche bzw. Monat. */
  workedHours?: number[];
  /** `null` = zu wenig Daten für den Wochen-Trend. */
  weeklyTrend?: 'default' | null;
  /** Prognose zum Jahresende (#532): `'default'` = positiv, `'negative'`, `null` = zu wenig Daten. Standard: positiv. */
  forecast?: 'default' | 'negative' | null;
}

const WEEK_HOURS = [38.5, 41, 40, 36.5, 42.5, 39, 40, 44, 37.5, 40.5, 41.5, 22];
const MONTH_HOURS = [168, 152, 171, 160, 158, 175, 120, 166, 172, 169, 174, 86];

/** Prognose im Format von `OvertimeForecastDto`: 6 Wochen, 7 Restwochen; Zahlen fest, nicht aus dem Datum abgeleitet. */
function forecastMock(year: number, negative: boolean): unknown {
  return {
    targetDate: `${year}-12-31`,
    currentBalanceMs: (negative ? -2.5 : 18.75) * HOUR,
    averageWeeklyOvertimeMs: (negative ? -0.75 : 1.25) * HOUR,
    weeksUsed: 6,
    remainingWeeks: 7,
    projectedBalanceMs: (negative ? -7.75 : 27.5) * HOUR,
  };
}

/** Antwort für den Bezugstag `y-m-d` und `granularity` (Buckets wie das Backend: 12, älteste zuerst). */
export function trendResponse(y: number, m: number, d: number, granularity: string, opts: TrendMockOptions = {}): unknown {
  const ref = new Date(y, m - 1, d);
  const gaps = new Set(opts.gaps ?? []);
  const worked = opts.workedHours ?? (granularity === 'week' ? WEEK_HOURS : MONTH_HOURS);
  let cumulative = 0;
  const buckets = Array.from({ length: 12 }, (_, i) => {
    const back = 11 - i;
    let start: Date, end: Date, key: string, targetH: number;
    if (granularity === 'week') {
      const monday = new Date(ref.getFullYear(), ref.getMonth(), ref.getDate() - ((ref.getDay() + 6) % 7) - 7 * back);
      start = monday;
      end = new Date(monday.getFullYear(), monday.getMonth(), monday.getDate() + 6);
      key = isoWeekKey(monday);
      targetH = back === 0 ? 24 : 40;
    } else {
      start = new Date(ref.getFullYear(), ref.getMonth() - back, 1);
      end = new Date(ref.getFullYear(), ref.getMonth() - back + 1, 0);
      key = `${start.getFullYear()}-${pad(start.getMonth() + 1)}`;
      targetH = back === 0 ? 88 : 168;
    }
    const hasData = !gaps.has(i);
    const workedMs = hasData ? Math.round(worked[i] * HOUR) : 0;
    const targetMs = hasData ? targetH * HOUR : 0;
    const overtimeMs = workedMs - targetMs;
    cumulative += overtimeMs;
    return {
      key, start: utcIso(start), end: utcIso(end), workedMs, targetMs, overtimeMs, cumulativeOvertimeMs: cumulative, hasData,
    };
  });
  const lastMonday = new Date(ref.getFullYear(), ref.getMonth(), ref.getDate() - ((ref.getDay() + 6) % 7) - 7);
  const weeklyTrend = opts.weeklyTrend === null ? null : {
    lastWeekKey: isoWeekKey(lastMonday), lastWeekWorkedMs: 41.5 * HOUR, averageWorkedMs: 39 * HOUR,
    deltaMs: 2.5 * HOUR, comparedWeeks: 4,
  };
  const forecast = opts.forecast === null ? null : forecastMock(y, opts.forecast === 'negative');
  return { granularity, buckets, weeklyTrend, forecast };
}

/** Leere Antwort: kein Zeitraum mit Einträgen. */
export function emptyTrendResponse(y: number, m: number, d: number, granularity: string): unknown {
  return trendResponse(y, m, d, granularity, { gaps: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11], weeklyTrend: null, forecast: null });
}
