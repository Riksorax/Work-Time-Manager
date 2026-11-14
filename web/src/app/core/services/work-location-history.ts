import { Injectable } from '@angular/core';
import { WorkEntry, WorkEntryType } from '../../shared/models';
import { parseEntryId } from '../../shared/utils/entry-day.util';
import { readWorkLocations, suggestWorkLocations } from '../../shared/utils/work-locations.util';

const LS_KEY = 'work_location_history_v1';
const MAX_DAYS = 40;

type Stored = { d: string; l: string[] };
type EntryLike = Pick<WorkEntry, 'id' | 'date' | 'type' | 'workLocations'>;

/**
 * Merkt sich die Arbeitsorte der Einträge, die der Client ohnehin geladen oder gespeichert hat (#526), damit die
 * Vorschläge auch nach einem Neuladen da sind, ohne einen zusätzlichen Firestore-/API-Lesezugriff. Je Nutzer und Profil
 * (`scope`) höchstens die letzten 40 Tage mit Orten, nur lokal im Browser. Reine Datenhaltung, keine Netzzugriffe.
 */
@Injectable({ providedIn: 'root' })
export class WorkLocationHistoryService {
  private _cache: Record<string, Stored[]> | null = null;

  /** Übernimmt die Orte der übergebenen Einträge (Tage ohne Orte entfernen einen früher gemerkten Tag). */
  record(scope: string, entries: readonly EntryLike[]): void {
    const all = this._load();
    const byDay = new Map((all[scope] ?? []).map(s => [s.d, s]));
    let changed = false;
    for (const e of entries) {
      const day = parseEntryId(e.id) ? e.id : null;
      if (!day) continue;
      const locs = e.type === WorkEntryType.Work ? readWorkLocations(e.workLocations) : [];
      const prev = byDay.get(day);
      if (locs.length === 0) {
        if (prev) { byDay.delete(day); changed = true; }
        continue;
      }
      if (!prev || prev.l.join('\n') !== locs.join('\n')) {
        byDay.set(day, { d: day, l: locs });
        changed = true;
      }
    }
    if (!changed) return;
    all[scope] = [...byDay.values()].sort((a, b) => b.d.localeCompare(a.d)).slice(0, MAX_DAYS);
    this._cache = all;
    try { localStorage.setItem(LS_KEY, JSON.stringify(all)); } catch { /* voll/gesperrt: Vorschläge sind nur Komfort */ }
  }

  /** Vorschläge (zuletzt verwendete zuerst), optional mit zusätzlichen, schon geladenen Einträgen. */
  suggestions(
    scope: string, selected: readonly string[], extra: readonly EntryLike[] = [], filter = '',
  ): string[] {
    const stored = (this._load()[scope] ?? []).map(s => ({
      date: parseEntryId(s.d) ?? new Date(0), type: WorkEntryType.Work, workLocations: s.l,
    }));
    const live = extra.map(e => ({ date: e.date, type: e.type, workLocations: e.workLocations }));
    return suggestWorkLocations([...live, ...stored], selected, undefined, filter);
  }

  private _load(): Record<string, Stored[]> {
    if (this._cache) return this._cache;
    try {
      const raw = JSON.parse(localStorage.getItem(LS_KEY) ?? '{}') as unknown;
      this._cache = raw && typeof raw === 'object' && !Array.isArray(raw) ? (raw as Record<string, Stored[]>) : {};
    } catch { this._cache = {}; }
    return this._cache;
  }
}
