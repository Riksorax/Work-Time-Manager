import { WorkEntry, WorkEntryType } from '../../shared/models/index';
import { entryDayKey } from '../../shared/utils/entry-day.util';

/** Home-Office-Auswertung (#282/#483): Port von Mobile `home_office_stats.dart`. */
export interface HomeOfficeStats {
  /** Tage mit erfasster Zeit, an denen im Home-Office gearbeitet wurde. */
  homeOfficeDays: number;
  /** Tage mit erfasster Zeit ohne Home-Office-Flag. */
  officeDays: number;
  /** Home-Office plus Büro. */
  totalDays: number;
  /** Anteil der Home-Office-Tage (0..1), `null` ohne Bezugstage. */
  ratio: number | null;
}

/**
 * Einzige Zählregel: gezählt werden Arbeitstage mit erfasster Zeit (`type == work` und Start gesetzt; offene Einträge
 * zählen, leere nicht). Urlaub, Krankheit und Feiertage zählen nie, auch nicht mit gesetztem Flag. Mehrere Einträge am
 * selben Kalendertag (`entryDayKey`) zählen einmal; der Tag ist Home-Office, wenn irgendein Eintrag das Flag trägt.
 */
export function calculateHomeOfficeStats(entries: readonly WorkEntry[]): HomeOfficeStats {
  const days = new Map<string, boolean>();
  for (const e of entries) {
    if (e.type !== WorkEntryType.Work || !e.workStart) continue;
    const key = entryDayKey(e);
    days.set(key, (days.get(key) ?? false) || e.isHomeOffice === true);
  }
  let homeOfficeDays = 0;
  for (const isHome of days.values()) if (isHome) homeOfficeDays++;
  const totalDays = days.size;
  return {
    homeOfficeDays,
    officeDays: totalDays - homeOfficeDays,
    totalDays,
    ratio: totalDays === 0 ? null : homeOfficeDays / totalDays,
  };
}
