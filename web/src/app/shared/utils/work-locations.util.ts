import { WorkEntry, WorkEntryType } from '../models/index';

/** Höchstzahl Arbeitsorte je Tag (#526, wie Backend `FirestoreMappings.IsValidWorkLocations`). */
export const MAX_WORK_LOCATIONS = 5;
/** Höchstlänge eines Arbeitsorts in Zeichen (nach Trimmen). */
export const MAX_WORK_LOCATION_LENGTH = 60;
/** Höchstzahl Vorschläge in der Orte-Eingabe. */
export const MAX_WORK_LOCATION_SUGGESTIONS = 10;

const key = (s: string): string => s.trim().toLowerCase();

/**
 * Bereinigt eine Orte-Liste genauso wie das Backend (`NormalizeWorkLocations`): trimmen, leere Einträge verwerfen,
 * Duplikate ohne Beachtung der Groß-/Kleinschreibung verwerfen (der erste bleibt). Zusätzlich als Schutz vor einem
 * 400 des Backends: Orte auf 60 Zeichen kürzen und auf 5 Einträge begrenzen. Der Client ruft das vor dem Senden
 * und vor dem lokalen Speichern auf, weil die PUT-Antwort die gesendete, nicht die bereinigte Liste enthält.
 */
export function normalizeWorkLocations(raw: readonly unknown[] | null | undefined): string[] {
  if (!raw) return [];
  const seen = new Set<string>();
  const result: string[] = [];
  for (const item of raw) {
    if (typeof item !== 'string') continue;
    const trimmed = item.trim().slice(0, MAX_WORK_LOCATION_LENGTH).trim();
    if (!trimmed) continue;
    const k = key(trimmed);
    if (seen.has(k)) continue;
    seen.add(k);
    result.push(trimmed);
    if (result.length >= MAX_WORK_LOCATIONS) break;
  }
  return result;
}

/** Liest ein gespeichertes Feld (Firestore/localStorage): fehlend oder kein Array = `[]`. */
export function readWorkLocations(raw: unknown): string[] {
  return Array.isArray(raw) ? raw.filter((v): v is string => typeof v === 'string') : [];
}

export type AddWorkLocationError = 'empty' | 'duplicate' | 'tooLong' | 'max';

export interface AddWorkLocationResult {
  /** Neue Liste; bei Fehler die unveränderte. */
  locations: string[];
  error?: AddWorkLocationError;
}

/** Fügt einen Ort hinzu, sofern gültig (nicht leer, höchstens 60 Zeichen, kein Duplikat, höchstens 5 Orte). */
export function addWorkLocation(current: readonly string[], input: string): AddWorkLocationResult {
  const value = input.trim();
  if (!value) return { locations: [...current], error: 'empty' };
  if (value.length > MAX_WORK_LOCATION_LENGTH) return { locations: [...current], error: 'tooLong' };
  if (current.some(c => key(c) === key(value))) return { locations: [...current], error: 'duplicate' };
  if (current.length >= MAX_WORK_LOCATIONS) return { locations: [...current], error: 'max' };
  return { locations: [...current, value] };
}

/**
 * Vorschläge aus den bereits geladenen Einträgen (kein zusätzlicher Lesezugriff): Orte von Arbeitstagen,
 * zuletzt verwendete zuerst (jüngster Tag zuerst, innerhalb eines Tages in gespeicherter Reihenfolge), ohne Duplikate
 * (Groß-/Kleinschreibung egal) und ohne die schon gewählten, höchstens `limit`. Mit `filter` nur Orte, die den Text enthalten.
 */
export function suggestWorkLocations(
  entries: readonly Pick<WorkEntry, 'date' | 'type' | 'workLocations'>[],
  selected: readonly string[] = [],
  limit: number = MAX_WORK_LOCATION_SUGGESTIONS,
  filter = '',
): string[] {
  const taken = new Set(selected.map(key));
  const needle = key(filter);
  const sorted = [...entries].sort((a, b) => b.date.getTime() - a.date.getTime());
  const out: string[] = [];
  for (const entry of sorted) {
    if (entry.type !== WorkEntryType.Work) continue;
    for (const loc of entry.workLocations ?? []) {
      const k = key(loc);
      if (!k || taken.has(k)) continue;
      if (needle && !k.includes(needle)) continue;
      taken.add(k);
      out.push(loc.trim());
      if (out.length >= limit) return out;
    }
  }
  return out;
}
