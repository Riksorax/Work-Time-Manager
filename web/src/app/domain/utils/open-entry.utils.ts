import { Break, UserSettings, WorkEntry, WorkEntryType } from '../../shared/models';
import { roundMsToMinute, roundToMinute } from '../../shared/utils/time-precision.util';
import { localDateFromEntryId } from '../../shared/utils/entry-day.util';
import { getEffectiveDailyTarget } from './overtime.utils';

// Die Definition lebt seit #407 in der gemeinsamen Util; der Re-Export hält alle bisherigen Importe stabil.
export { localDateFromEntryId };

/**
 * Reine Funktionen für das nachträgliche Beenden offener Einträge vor heute (#385).
 * Kein `inject()`, keine Angular-Abhängigkeit. Der Kalendertag eines Eintrags kommt immer aus seiner `id`
 * (`yyyy-MM-dd`), nie aus `date` (UTC-Mitternacht ergibt westlich von UTC den Vortag).
 */

/** „Jetzt" wird nur für Einträge angeboten, die höchstens so alt sind (Grenze inklusive). */
export const OPEN_ENTRY_MAX_NOW_AGE_MS = 24 * 60 * 60 * 1000;

/** Ab diesem Netto-Wert warnt der Dialog weich (blockiert nicht). */
export const OPEN_ENTRY_LONG_WARNING_MS = 16 * 60 * 60 * 1000;

export interface OpenEntryEndSuggestion {
  /** Soll-Ende (Start + Soll + geschlossene Pausen); `null` bei Soll 0. */
  expectedEnd: Date | null;
  /** Vorbelegung: Soll-Ende (wenn vor jetzt), sonst „Jetzt" (wenn erlaubt), sonst `null`. */
  suggestedEnd: Date | null;
  suggestedIsNow: boolean;
  /** „Jetzt" ist erlaubt (Alter <= 24 h). */
  nowAllowed: boolean;
}

/**
 * Tagessoll des Eintragstags; gleiche Formel wie `DashboardService._targetDailyMs`
 * (`roundMsToMinute(weeklyMs / Anzahl Arbeitstage)`, Nicht-Arbeitstag und leere `workdays` ergeben 0).
 */
export function effectiveTargetMsForDate(
  settings: Pick<UserSettings, 'weeklyTargetHours' | 'workdays'>,
  date: Date,
): number {
  if (settings.workdays.length === 0) return 0;
  const weeklyMs = settings.weeklyTargetHours * 3_600_000;
  const regularMs = roundMsToMinute(weeklyMs / settings.workdays.length);
  return getEffectiveDailyTarget(date, settings.workdays, regularMs);
}

/** Summe der geschlossenen Pausen in Millisekunden (offene Pausen zählen 0). */
export function closedBreakMs(breaks: Break[]): number {
  return breaks.reduce((sum, b) => (b.end ? sum + (b.end.getTime() - b.start.getTime()) : sum), 0);
}

/**
 * Vorschlag für das Ende eines offenen Eintrags. Liegt das Soll-Ende (Millisekunden-Addition, DST-sicher) vor
 * `now`, ist es der Vorschlag; sonst „Jetzt" (auf Minute abgeschnitten), solange der Eintrag höchstens 24 h alt ist.
 */
export function suggestOpenEntryEnd(entry: WorkEntry, targetMs: number, now: Date): OpenEntryEndSuggestion {
  const start = entry.workStart!;
  const expectedEnd = targetMs > 0
    ? new Date(start.getTime() + targetMs + closedBreakMs(entry.breaks))
    : null;
  const nowAllowed = now.getTime() - start.getTime() <= OPEN_ENTRY_MAX_NOW_AGE_MS;

  if (expectedEnd && expectedEnd.getTime() < now.getTime()) {
    return { expectedEnd, suggestedEnd: expectedEnd, suggestedIsNow: false, nowAllowed };
  }
  return {
    expectedEnd,
    suggestedEnd: nowAllowed ? roundToMinute(now) : null,
    suggestedIsNow: nowAllowed,
    nowAllowed,
  };
}

/**
 * Gültiges Ende: nach dem Start, nicht nach `now`, nicht vor dem Ende einer geschlossenen bzw. dem Beginn einer
 * offenen Pause (Ende = Pausenende ist erlaubt). Das Ende wird so geprüft, wie es übergeben wird.
 */
export function isValidOpenEntryEnd(entry: WorkEntry, end: Date, now: Date): boolean {
  if (!entry.workStart) return false;
  if (end.getTime() <= entry.workStart.getTime()) return false;
  if (end.getTime() > now.getTime()) return false;
  for (const b of entry.breaks) {
    if (end.getTime() < (b.end ?? b.start).getTime()) return false;
  }
  return true;
}

/**
 * Saldo-Delta beim nachträglichen Beenden: `Netto (nur geschlossene Pausen) − Soll + manualOvertimeMinutes`
 * (wie der Dashboard-Stop). Der Aufrufer schließt offene Pausen vorher; eine offene Pause zählt hier nicht.
 */
export function retroDeltaMs(entry: WorkEntry, targetMs: number): number {
  if (!entry.workStart || !entry.workEnd) {
    throw new Error('retroDeltaMs braucht einen Eintrag mit Start und Ende');
  }
  const net = entry.workEnd.getTime() - entry.workStart.getTime() - closedBreakMs(entry.breaks);
  return net - targetMs + (entry.manualOvertimeMinutes ?? 0) * 60_000;
}

/**
 * „Fortsetzen" eines offenen Eintrags (Pinning im Dashboard): nur Typ work mit Start und ohne Ende, nur Tage vor heute
 * (Tag aus der `id`, String-Vergleich), höchstens 24 h alt (Grenze inklusive, absolute Differenz) und nur, wenn heute leer ist.
 * Einzige Regel für Anzeige und Durchsetzung.
 */
export function canResumeOpenEntry(args: {
  entry: WorkEntry;
  now: Date;
  todayId: string;
  todayIsEmpty: boolean;
}): boolean {
  const { entry, now, todayId, todayIsEmpty } = args;
  if (!todayIsEmpty) return false;
  if (entry.type !== WorkEntryType.Work) return false;
  if (!entry.workStart || entry.workEnd) return false;
  if (!(entry.id < todayId)) return false;
  return now.getTime() - entry.workStart.getTime() <= OPEN_ENTRY_MAX_NOW_AGE_MS;
}

/** Kurzer, lokalisierter Tag (Wochentag, Tag, Monat) für den Kalendertag einer Eintrags-`id`. */
export function formatEntryDay(id: string, locale: string): string {
  return new Intl.DateTimeFormat(locale, { weekday: 'short', day: 'numeric', month: 'numeric' })
    .format(localDateFromEntryId(id));
}

/** Lokale Uhrzeit als `HH:mm` (wie im restlichen Dashboard). */
export function formatHm(date: Date): string {
  return `${String(date.getHours()).padStart(2, '0')}:${String(date.getMinutes()).padStart(2, '0')}`;
}
