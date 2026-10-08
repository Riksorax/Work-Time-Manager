/**
 * Bringt eine Arbeitstage-Liste in die kanonische Form: nur ISO-Wochentage 1-7, ohne Duplikate, aufsteigend.
 * Schutz gegen verfälschte Daten: Doppelte Tage ließen das tägliche Soll schrumpfen (`weeklyTargetHours / workdays.length`)
 * und die Anzeige „Mo, Mo, Di, Di“ zeigen.
 */
export function normalizeWorkdays(days: readonly number[]): number[] {
  return [...new Set(days)].filter(d => Number.isInteger(d) && d >= 1 && d <= 7).sort((a, b) => a - b);
}
