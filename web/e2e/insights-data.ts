/**
 * Gemockte Antworten für `GET /api/reports/insights/{y}/{m}/{d}?tz=` (#537) in E2E-Tests und Screenshots. Reine Testdaten
 * im Format des Backend-DTOs (`InsightsReportDto`); die echte Rechnung testet das Backend.
 */

const H = 3_600_000;
const M = 60_000;
const pad = (n: number) => String(n).padStart(2, '0');

export interface InsightsMockOptions {
  /** Serie über der Warnschwelle (Hinweis sichtbar). */
  warning?: boolean;
  /** Keine Daten im Zeitfenster. */
  empty?: boolean;
}

/** Zeitfenster wie im Backend: 1. des Monats zwei Monate vor dem Bezugsmonat bis Monatsletzter des Bezugsmonats. */
function window(y: number, m: number): { from: string; to: string } {
  const start = new Date(Date.UTC(y, m - 3, 1));
  const end = new Date(Date.UTC(y, m, 0));
  return {
    from: `${start.getUTCFullYear()}-${pad(start.getUTCMonth() + 1)}-01`,
    to: `${end.getUTCFullYear()}-${pad(end.getUTCMonth() + 1)}-${pad(end.getUTCDate())}`,
  };
}

export function insightsResponse(y: number, m: number, tz: string, opts: InsightsMockOptions = {}): unknown {
  const base = { ...window(y, m), timeZone: tz, dailyTargetMs: 8 * H };
  if (opts.empty) {
    return {
      ...base, weekdayAverages: [], startTimeHeatmap: [],
      overtimeStreak: { currentStreak: 0, longestStreak: 0, isWarning: false, warningThresholdDays: 5 },
    };
  }
  return {
    ...base,
    weekdayAverages: [
      { weekday: 1, averageWorkedMs: 8 * H + 50 * M, deviationMs: 32 * M, sampleCount: 12 },
      { weekday: 2, averageWorkedMs: 8 * H + 25 * M, deviationMs: 7 * M, sampleCount: 13 },
      { weekday: 3, averageWorkedMs: 8 * H + 18 * M, deviationMs: 0, sampleCount: 12 },
      { weekday: 4, averageWorkedMs: 8 * H + 5 * M, deviationMs: -(13 * M), sampleCount: 12 },
      { weekday: 5, averageWorkedMs: 7 * H + 10 * M, deviationMs: -(1 * H + 8 * M), sampleCount: 11 },
      { weekday: 6, averageWorkedMs: 3 * H + 30 * M, deviationMs: -(4 * H + 48 * M), sampleCount: 1 },
    ],
    overtimeStreak: opts.warning
      ? { currentStreak: 7, longestStreak: 9, isWarning: true, warningThresholdDays: 5 }
      : { currentStreak: 2, longestStreak: 4, isWarning: false, warningThresholdDays: 5 },
    startTimeHeatmap: [
      { startHour: 6, averageOvertimeMs: 1 * H + 5 * M, sampleCount: 4 },
      { startHour: 7, averageOvertimeMs: 35 * M, sampleCount: 18 },
      { startHour: 8, averageOvertimeMs: 10 * M, sampleCount: 22 },
      { startHour: 9, averageOvertimeMs: -(15 * M), sampleCount: 9 },
      { startHour: 10, averageOvertimeMs: -(50 * M), sampleCount: 3 },
    ],
  };
}
