import { toDateKey } from './german-holidays.util';

/**
 * Kalendertag eines Arbeitseintrags (#407). Reine Funktionen, kein `inject()`, keine Angular-Abhängigkeit.
 *
 * Alle Clients schreiben `date` als UTC-Mitternacht des lokalen Kalendertags. Beim Lesen daraus einen Zeitpunkt zu
 * machen (`new Date(iso)`, `Timestamp.toDate()`) und lokale Felder zu zerlegen, ergibt westlich von UTC den Vortag.
 * Der Kalendertag eines Eintrags kommt deshalb aus seiner `id` (`yyyy-MM-dd`) bzw. dem Tages-Key; die Lesegrenzen
 * (`ApiClient`, `WorkEntryService`) setzen `date` auf die lokale Mitternacht dieses Tages.
 */

/** Lokales Datum (Mitternacht) aus einer Eintrags-`id` `yyyy-MM-dd`. Erwartet eine gültige `id` (sonst `parseEntryId`). */
export function localDateFromEntryId(id: string): Date {
  const [y, m, d] = id.split('-').map(Number);
  return new Date(y, m - 1, d);
}

/**
 * Lokale Mitternacht des Tages einer Eintrags-`id`, oder `null`, wenn die `id` nicht exakt `yyyy-MM-dd` und ein
 * existierender Kalendertag ist (Platzhalter-Ids wie `'x'`, `'1'`, ISO-Strings; `2026-02-30` läuft nicht in den März über).
 */
export function parseEntryId(id: string): Date | null {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(id)) return null;
  const [y, m, d] = id.split('-').map(Number);
  const date = new Date(y, m - 1, d);
  const roundTrips = date.getFullYear() === y && date.getMonth() === m - 1 && date.getDate() === d;
  return roundTrips ? date : null;
}

/**
 * Lokale Mitternacht des Kalendertags, den die **UTC-Felder** von `d` bezeichnen. Für Werte, die das Backend als
 * UTC-Mitternacht eines Kalendertags liefert (Fallback ohne gültige `id`, Berichts-Tage): `2026-10-05T00:00:00Z`
 * ergibt in jeder Zone den 05.10., nicht den Vortag.
 */
export function calendarDateFromUtcMidnight(d: Date): Date {
  return new Date(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate());
}

/**
 * Kalendertag eines Eintrags als lokale Mitternacht (neues Objekt). Gültige `id` (`yyyy-MM-dd`): der Tag der `id`.
 * Sonst (Platzhalter-Ids wie `'x'`, `crypto.randomUUID()`, Test-Mocks) die lokalen Felder von `date`, nach den
 * Lesegrenzen ein lokales Kalenderdatum. Einzige Stelle, die den Tag eines Eintrags für Verbraucher bildet (Soll,
 * Wochentag, KW, „ist heute?“, Tages-/Wochenfilter, Jahresgrenze); die Schreibpfade bleiben bewusst auf `date`.
 */
export function entryDay(entry: { id: string; date: Date }): Date {
  return parseEntryId(entry.id) ?? new Date(entry.date.getFullYear(), entry.date.getMonth(), entry.date.getDate());
}

/** `yyyy-MM-dd` des Kalendertags eines Eintrags (siehe `entryDay`). */
export function entryDayKey(entry: { id: string; date: Date }): string {
  return toDateKey(entryDay(entry));
}
