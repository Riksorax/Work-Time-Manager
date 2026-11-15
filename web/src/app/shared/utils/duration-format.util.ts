/**
 * Dauern im Format der Berichte (`HH:MM`, Überstunden mit Vorzeichen `+HH:MM`/`-HH:MM`).
 * Gleiche Regeln wie `ReportsComponent.formatDuration`/`formatOvertime`: Minuten werden abgeschnitten, nicht gerundet;
 * nicht endliche Werte ergeben `00:00` bzw. `+00:00`.
 */
export function formatDurationHm(ms: number): string {
  if (!isFinite(ms)) return '00:00';
  const abs = Math.abs(ms);
  const h = Math.floor(abs / 3_600_000);
  const m = Math.floor((abs % 3_600_000) / 60_000);
  return `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}`;
}

export function formatSignedDurationHm(ms: number): string {
  if (!isFinite(ms)) return '+00:00';
  return `${ms >= 0 ? '+' : '-'}${formatDurationHm(ms)}`;
}
