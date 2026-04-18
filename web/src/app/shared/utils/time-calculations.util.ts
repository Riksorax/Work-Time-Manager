import { WorkEntry, Break, WorkEntryType } from '../models';

/**
 * Berechnet die Brutto-Arbeitszeit in Minuten.
 */
export function calculateGrossMinutes(entry: WorkEntry): number {
  if (!entry.workStart) return 0;
  const end = entry.workEnd || new Date();
  return (end.getTime() - entry.workStart.getTime()) / (1000 * 60);
}

/**
 * Berechnet die Gesamtdauer der Pausen in Minuten.
 */
export function calculateBreakMinutes(breaks: Break[]): number {
  return breaks.reduce((total, b) => {
    if (!b.end) return total;
    return total + (b.end.getTime() - b.start.getTime()) / (1000 * 60);
  }, 0);
}

/**
 * Berechnet die Netto-Arbeitszeit in Minuten.
 */
export function calculateNetMinutes(entry: WorkEntry): number {
  const gross = calculateGrossMinutes(entry);
  const breaks = calculateBreakMinutes(entry.breaks);
  const net = gross - breaks;
  return net > 0 ? net : 0;
}

/**
 * Berechnet die Überstunden für einen Tag in Minuten.
 */
export function calculateOvertimeMinutes(entry: WorkEntry, targetDailyMinutes: number): number {
  // Bei Urlaub, Krank oder Feiertag gilt die Sollzeit als erfüllt.
  if (entry.type !== WorkEntryType.Work) {
    return entry.manualOvertimeMinutes || 0;
  }

  // Überstunden werden erst berechnet, wenn der Tag beendet ist oder wir im Live-Modus sind.
  const net = calculateNetMinutes(entry);
  return net - targetDailyMinutes + (entry.manualOvertimeMinutes || 0);
}

/**
 * Prüft die Einhaltung des Arbeitszeitgesetzes (30/45 Min Regel).
 */
export function getRequiredBreakMinutes(netMinutes: number): number {
  if (netMinutes > 540) return 45; // > 9 Stunden
  if (netMinutes > 360) return 30; // > 6 Stunden
  return 0;
}
