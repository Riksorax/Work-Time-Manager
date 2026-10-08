import { Page } from '@playwright/test';

/**
 * Testdaten für die App im localStorage-Modus (kein Konto). Das Format ist identisch zu
 * `WorkEntryService` (`local_work_entries_<yyyy>_<MM>` mit `days`-Map plus Index `local_monthly_keys`).
 */

/** Fester „Jetzt"-Zeitpunkt (Mittwoch), damit die Tests nicht vom Tag der Ausführung abhängen. */
export const FIXED_NOW = new Date('2026-03-18T10:00:00+01:00');

export interface SeedBreak { name: string; start: string; end?: string }
export interface SeedEntry {
  /** Kalendertag `yyyy-MM-dd` (lokal, Europe/Berlin). */
  day: string;
  /** ISO-Zeitstempel; `null`/fehlend = nicht gesetzt. */
  start?: string;
  end?: string;
  type?: 'work' | 'vacation' | 'sick' | 'holiday';
  breaks?: SeedBreak[];
}

/** Friert die Uhr ein (läuft danach weiter) und muss VOR `page.goto` aufgerufen werden. */
export async function freezeTime(page: Page, now: Date = FIXED_NOW): Promise<void> {
  await page.clock.install({ time: now });
}

/** Schreibt Einträge vor dem App-Start in den localStorage (nur beim ersten Laden, Neuladen behält App-Stand). */
export async function seedEntries(page: Page, entries: SeedEntry[]): Promise<void> {
  await page.addInitScript((list: SeedEntry[]) => {
    if (window.top !== window) return; // nur das Hauptdokument (Frames ohne Speicherzugriff werfen sonst)
    try { if (localStorage.getItem('e2e_seeded') !== null) return; } catch { return; }
    const months = new Map<string, { days: Record<string, unknown> }>();
    for (const e of list) {
      const [y, m, d] = e.day.split('-').map(Number);
      const key = `local_work_entries_${y}_${String(m).padStart(2, '0')}`;
      const month = months.get(key) ?? { days: {} };
      month.days[String(d)] = {
        workStart: e.start ?? null,
        workEnd: e.end ?? null,
        type: e.type ?? 'work',
        isManuallyEntered: false,
        manualOvertimeMinutes: null,
        description: null,
        breaks: (e.breaks ?? []).map((b, i) => ({
          id: `b${i}`, name: b.name, isAutomatic: false, start: b.start, end: b.end ?? null,
        })),
      };
      months.set(key, month);
    }
    for (const [key, month] of months) localStorage.setItem(key, JSON.stringify(month));
    localStorage.setItem('local_monthly_keys', JSON.stringify([...months.keys()]));
    localStorage.setItem('e2e_seeded', '1');
  }, entries);
}

/** Abgeschlossener Arbeitstag 08:00–16:30 mit 30 min Pause. */
export function workDay(day: string): SeedEntry {
  return {
    day,
    start: `${day}T08:00:00+01:00`,
    end: `${day}T16:30:00+01:00`,
    breaks: [{ name: 'Pause', start: `${day}T12:00:00+01:00`, end: `${day}T12:30:00+01:00` }],
  };
}

/** Offener Eintrag: gestartet, nie beendet. */
export function openDay(day: string, startTime = '08:00'): SeedEntry {
  return { day, start: `${day}T${startTime}:00+01:00` };
}
