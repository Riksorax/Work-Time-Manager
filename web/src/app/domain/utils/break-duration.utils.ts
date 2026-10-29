import { Break } from '../../shared/models/index';

/** Dauer einer Pause in ms (#504): bei laufender Pause bis [now], nie negativ. */
export function breakDurationMs(b: Pick<Break, 'start' | 'end'>, now: Date): number {
  const end = b.end ?? now;
  return Math.max(0, end.getTime() - b.start.getTime());
}

/** i18n-Schlüssel samt Parametern für die Anzeige einer Pausendauer (volle Minuten, wie im restlichen Dashboard). */
export interface BreakDurationLabel {
  key: 'dashboard.breakDurationLessThanMinute' | 'dashboard.breakDurationMinutes' | 'dashboard.breakDurationHoursMinutes';
  params: { hours: number; minutes: number };
}

export function breakDurationLabel(ms: number): BreakDurationLabel {
  const totalMinutes = Math.floor(Math.max(0, ms) / 60000);
  const hours = Math.floor(totalMinutes / 60);
  const minutes = totalMinutes % 60;
  const params = { hours, minutes };
  if (totalMinutes < 1) return { key: 'dashboard.breakDurationLessThanMinute', params };
  if (hours < 1) return { key: 'dashboard.breakDurationMinutes', params };
  return { key: 'dashboard.breakDurationHoursMinutes', params };
}
