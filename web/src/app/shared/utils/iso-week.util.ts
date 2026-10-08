/**
 * ISO-8601-Kalenderwoche (Montag = Wochenbeginn, Woche 1 enthaelt den ersten
 * Donnerstag des Jahres). Gemeinsame Util fuer alle Wochenberechnungen im Web.
 *
 * Rechnet ausschliesslich mit den lokalen Kalenderfeldern (Jahr/Monat/Tag) und
 * macht die Tagesarithmetik in UTC. Damit ist das Ergebnis unabhaengig von
 * Sommerzeit, Prozess-Zeitzone und Uhrzeit. Entspricht Mobile
 * (`isoWeekNumber`) und Backend (`ReportCalculator.GetIsoWeekNumber`).
 */
export function getIsoWeekNumber(date: Date): number {
  const thursday = thursdayOfWeekUtc(date);
  const jan1 = Date.UTC(thursday.getUTCFullYear(), 0, 1);
  const dayOfYear = Math.round((thursday.getTime() - jan1) / 86400000) + 1;
  return Math.floor((dayOfYear - 1) / 7) + 1;
}

/** ISO-Wochenjahr (am Jahreswechsel evtl. abweichend vom Kalenderjahr). */
export function getIsoWeekYear(date: Date): number {
  return thursdayOfWeekUtc(date).getUTCFullYear();
}

/** Verschiebt ein Datum um Kalendertage (DST-sicher, behaelt die Uhrzeit). */
export function addCalendarDays(date: Date, days: number): Date {
  return new Date(
    date.getFullYear(), date.getMonth(), date.getDate() + days,
    date.getHours(), date.getMinutes(), date.getSeconds(), date.getMilliseconds(),
  );
}

/** Montag 00:00 bis Sonntag 00:00 (lokale Zeit) der ISO-Woche von `date`. */
export function getIsoWeekBounds(date: Date): { start: Date; end: Date } {
  const wd = date.getDay() === 0 ? 7 : date.getDay();
  const start = new Date(date.getFullYear(), date.getMonth(), date.getDate() - (wd - 1));
  const end = new Date(start.getFullYear(), start.getMonth(), start.getDate() + 6);
  return { start, end };
}

function thursdayOfWeekUtc(date: Date): Date {
  const wd = date.getDay() === 0 ? 7 : date.getDay();
  return new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate() + 4 - wd));
}
