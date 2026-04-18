// shared/utils/time-calculations.util.ts
// KERN-BUSINESS-LOGIK — 1:1 aus Flutter-App übernommen (AGENT-00)
// Alle Berechnungen hier zentralisieren, NIE in Komponenten berechnen

import { Timestamp } from 'firebase/firestore';
import { WorkSession } from '../../../shared/models';

// ─── Nettoarbeitszeit ─────────────────────────────────────────────────────────

/**
 * Berechnet die Nettoarbeitszeit einer Session in Minuten.
 * Nettozeit = Bruttozeit - akkumulierte Pausen
 * Wenn Session noch läuft: aktuelle Zeit als endTime verwenden
 * Wenn Session gerade pausiert: laufende Pausenzeit einrechnen
 */
export function calculateNetMinutes(session: WorkSession): number {
  const start = session.startTime.toDate();
  const end = session.endTime?.toDate() ?? new Date();

  const grossMinutes = Math.floor((end.getTime() - start.getTime()) / 60_000);

  // Laufende Pause (falls aktuell pausiert) zur gespeicherten Pausenzeit addieren
  let currentPauseMinutes = 0;
  if (session.isPaused && session.pauseStartTime) {
    const pauseStart = session.pauseStartTime.toDate();
    currentPauseMinutes = Math.floor((new Date().getTime() - pauseStart.getTime()) / 60_000);
  }

  const totalPauseMinutes = session.pauseDuration + currentPauseMinutes;
  return Math.max(0, grossMinutes - totalPauseMinutes);
}

/**
 * Berechnet die Tages-Summe (Nettoarbeitszeit) für eine Liste von Sessions.
 * Enthält laufende Sessions (falls vorhanden).
 */
export function calculateDailyTotal(sessions: WorkSession[]): number {
  return sessions.reduce((sum, s) => sum + calculateNetMinutes(s), 0);
}

/**
 * Berechnet Überstunden in Minuten (positiv = Überstunden, negativ = Unterzeit).
 */
export function calculateOvertimeMinutes(workedMinutes: number, targetMinutes: number): number {
  return workedMinutes - targetMinutes;
}

// ─── Zeitformatierung ─────────────────────────────────────────────────────────

/**
 * Formatiert Minuten als "Xh YYmin"
 * Beispiele: 510 → "8h 30min" | -90 → "-1h 30min" | 0 → "0h 00min"
 */
export function formatDuration(totalMinutes: number): string {
  const abs = Math.abs(totalMinutes);
  const h = Math.floor(abs / 60);
  const m = abs % 60;
  const sign = totalMinutes < 0 ? '-' : '';
  return `${sign}${h}h ${m.toString().padStart(2, '0')}min`;
}

/**
 * Formatiert Minuten als "HH:MM" (für Timer-Anzeige)
 * Beispiele: 90 → "01:30" | 3661 → "61:01" (Stunden über 24 erlaubt)
 */
export function formatTimer(totalSeconds: number): string {
  const abs = Math.abs(totalSeconds);
  const h = Math.floor(abs / 3600);
  const m = Math.floor((abs % 3600) / 60);
  const s = abs % 60;
  return `${h.toString().padStart(2, '0')}:${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`;
}

/**
 * Gibt die Brutto-Sekunden einer aktiven Session zurück (inkl. Pausen).
 */
export function getGrossSeconds(session: WorkSession): number {
  const start = session.startTime.toDate();
  return Math.floor((new Date().getTime() - start.getTime()) / 1000);
}

/**
 * Gibt die laufenden Sekunden einer aktiven Session zurück (für Timer-Anzeige).
 */
export function getElapsedSeconds(session: WorkSession): number {
  const start = session.startTime.toDate();
  const gross = Math.floor((new Date().getTime() - start.getTime()) / 1000);
  const pauseSeconds = session.pauseDuration * 60;

  let currentPauseSeconds = 0;
  if (session.isPaused && session.pauseStartTime) {
    currentPauseSeconds = Math.floor(
      (new Date().getTime() - session.pauseStartTime.toDate().getTime()) / 1000
    );
  }

  return Math.max(0, gross - pauseSeconds - currentPauseSeconds);
}

// ─── Datums-Hilfsfunktionen ───────────────────────────────────────────────────

/** Gibt Anfang des Tages (00:00:00) zurück */
export function startOfDay(date: Date): Date {
  const d = new Date(date);
  d.setHours(0, 0, 0, 0);
  return d;
}

/** Gibt Ende des Tages (23:59:59) zurück */
export function endOfDay(date: Date): Date {
  const d = new Date(date);
  d.setHours(23, 59, 59, 999);
  return d;
}

/** Gibt Montag der aktuellen Woche (00:00:00) zurück */
export function startOfWeek(date: Date): Date {
  const d = new Date(date);
  const day = d.getDay();
  const diff = day === 0 ? -6 : 1 - day; // Montag = Wochenstart
  d.setDate(d.getDate() + diff);
  d.setHours(0, 0, 0, 0);
  return d;
}

/** Gibt Sonntag der aktuellen Woche (23:59:59) zurück */
export function endOfWeek(date: Date): Date {
  const start = startOfWeek(date);
  const end = new Date(start);
  end.setDate(start.getDate() + 6);
  end.setHours(23, 59, 59, 999);
  return end;
}

/** Gibt ersten Tag des Monats (00:00:00) zurück */
export function startOfMonth(date: Date): Date {
  return new Date(date.getFullYear(), date.getMonth(), 1, 0, 0, 0, 0);
}

/** Gibt letzten Tag des Monats (23:59:59) zurück */
export function endOfMonth(date: Date): Date {
  return new Date(date.getFullYear(), date.getMonth() + 1, 0, 23, 59, 59, 999);
}

/** Gibt ersten Tag des Jahres zurück */
export function startOfYear(year: number): Date {
  return new Date(year, 0, 1, 0, 0, 0, 0);
}

/** Gibt letzten Tag des Jahres zurück */
export function endOfYear(year: number): Date {
  return new Date(year, 11, 31, 23, 59, 59, 999);
}

/** Prüft ob zwei Dates am selben Tag sind */
export function isSameDay(a: Date, b: Date): boolean {
  return (
    a.getFullYear() === b.getFullYear() &&
    a.getMonth() === b.getMonth() &&
    a.getDate() === b.getDate()
  );
}

/** Firestore Timestamp → Date */
export function tsToDate(ts: Timestamp): Date {
  return ts.toDate();
}

// ─── Kategorie-Auswertung (Premium) ──────────────────────────────────────────

export function calculateCategoryBreakdown(
  sessions: WorkSession[]
): Array<{ category: string; totalMinutes: number; sessionCount: number; percentage: number }> {
  const map = new Map<string, { totalMinutes: number; sessionCount: number }>();
  const totalMinutes = calculateDailyTotal(sessions);

  for (const session of sessions) {
    const cat = session.category ?? 'Keine Kategorie';
    const minutes = calculateNetMinutes(session);
    const existing = map.get(cat) ?? { totalMinutes: 0, sessionCount: 0 };
    map.set(cat, {
      totalMinutes: existing.totalMinutes + minutes,
      sessionCount: existing.sessionCount + 1,
    });
  }

  return Array.from(map.entries())
    .map(([category, data]) => ({
      category,
      ...data,
      percentage: totalMinutes > 0 ? Math.round((data.totalMinutes / totalMinutes) * 100) : 0,
    }))
    .sort((a, b) => b.totalMinutes - a.totalMinutes);
}
