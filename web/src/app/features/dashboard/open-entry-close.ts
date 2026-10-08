import { Injectable, inject } from '@angular/core';
import { WorkEntryService } from '../../core/services/work-entry';
import { OvertimeService } from '../../core/services/overtime';
import { SettingsService } from '../../core/services/settings';
import { calculateAndApplyBreaks } from '../../domain/services/break-calculator';
import {
  effectiveTargetMsForDate,
  isValidOpenEntryEnd,
  localDateFromEntryId,
  retroDeltaMs,
} from '../../domain/utils/open-entry.utils';
import { WorkEntry, WorkEntryType } from '../../shared/models';
import { roundToMinute } from '../../shared/utils/time-precision.util';

/** Ein offener Eintrag vor heute: Tag (`id`, `yyyy-MM-dd`) und das Profil, in dem er liegt. */
export interface OpenEntryCandidate {
  id: string;
  profileId: string;
}

/**
 * - `closed`: Eintrag und Saldo wurden geschrieben.
 * - `alreadyClosed`: Eintrag nicht (mehr) offen oder nicht mehr vorhanden (anderer Tab/Gerät); nichts geschrieben.
 * - `invalidEnd`: Ende nicht nach dem Start, nach jetzt oder vor einer Pause; nichts geschrieben.
 * - `invalidEntry`: kein beendbarer Arbeitseintrag (Typ != work oder ohne Start); nichts geschrieben.
 * - `failed`: Lesen oder Schreiben fehlgeschlagen; der Eintrag bleibt offen.
 * - `busy`: es läuft bereits eine Aktion; dieser Aufruf wurde ignoriert.
 */
export type CloseResult = 'closed' | 'alreadyClosed' | 'invalidEnd' | 'invalidEntry' | 'failed' | 'busy';

/**
 * Beendet einen offenen Eintrag vor heute nachträglich (#385), ohne den Dashboard-Zustand anzufassen.
 *
 * Alle Zugriffe laufen mit dem Profil des Kandidaten (`candidate.profileId`), nie mit dem „gerade aktiven" Profil.
 * Ablauf: Einstellungen des Profils lesen, Eintragsmonat frisch lesen, Ende prüfen, offene Pausen schließen,
 * Pflichtpausen wie beim Stop, Saldo fortschreiben (`neu = alt + Netto − Soll(Eintragstag) [+ manuell]`, ohne
 * `lastUpdated`), erst Saldo, dann Eintrag; schlägt der Eintrag-Write fehl, wird der Saldo best-effort zurückgesetzt.
 * Nie `saveLastUpdateDate`/`getLastUpdateDate`. Keine Logs mit Eintragsinhalten.
 */
@Injectable({ providedIn: 'root' })
export class OpenEntryCloseService {
  private readonly workEntries = inject(WorkEntryService);
  private readonly overtime = inject(OvertimeService);
  private readonly settings = inject(SettingsService);

  private _running = false;

  async endEntry(candidate: OpenEntryCandidate, end: Date): Promise<CloseResult> {
    if (this._running) return 'busy';
    this._running = true;
    try {
      return await this._end(candidate, end);
    } catch {
      return 'failed';
    } finally {
      this._running = false;
    }
  }

  private async _end(candidate: OpenEntryCandidate, end: Date): Promise<CloseResult> {
    const pid = candidate.profileId;
    const workEnd = roundToMinute(end);

    const settings = await this.settings.getSettingsOnce(pid);

    const [year, month] = candidate.id.split('-').map(Number);
    const monthEntries = await this.workEntries.getEntriesForMonthOnce(year, month, pid);
    const fresh = monthEntries.find(e => e.id === candidate.id);
    if (!fresh || fresh.workEnd) return 'alreadyClosed';
    if (fresh.type !== WorkEntryType.Work || !fresh.workStart) return 'invalidEntry';

    // Frische „jetzt"-Zeit: der Dialog kann lange offen gestanden haben.
    if (!isValidOpenEntryEnd(fresh, workEnd, new Date())) return 'invalidEnd';

    const day = localDateFromEntryId(candidate.id);
    let closed: WorkEntry = {
      ...fresh,
      // `date` = lokaler Tag aus der id, damit der days-Map-Schlüssel beim Schreiben derselbe bleibt.
      date: day,
      workEnd,
      breaks: fresh.breaks.map(b => (b.end ? b : { ...b, end: workEnd })),
    };
    closed = calculateAndApplyBreaks(closed);

    const delta = retroDeltaMs(closed, effectiveTargetMsForDate(settings, day));
    const stored = await this.overtime.getOvertime(pid);

    await this.overtime.saveOvertime(stored + delta, pid, { keepLastUpdated: true });
    try {
      await this.workEntries.saveEntry(closed, pid);
    } catch {
      // Sonst zählt ein Wiederholen den Saldo doppelt (Eintrag ist noch offen). Best effort, ohne lastUpdated.
      try {
        await this.overtime.saveOvertime(stored, pid, { keepLastUpdated: true });
      } catch { /* Saldo bleibt um das Delta zu hoch; Nutzer korrigiert über „Überstunden anpassen" */ }
      return 'failed';
    }
    return 'closed';
  }
}
