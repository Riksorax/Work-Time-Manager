import { Injectable, computed, effect, inject, signal, untracked } from '@angular/core';
import { AuthService } from '../../core/auth/auth';
import { TodayService } from '../../core/services/today';
import { WorkEntryService } from '../../core/services/work-entry';
import { SettingsService } from '../../core/services/settings';
import { WorkProfileService } from '../../core/services/work-profile';
import { canResumeOpenEntry, effectiveTargetMsForDate, localDateFromEntryId } from '../../domain/utils/open-entry.utils';
import { WorkEntry, WorkEntryType } from '../../shared/models';
import { DashboardService } from './dashboard.service';
import { CloseResult, OpenEntryCandidate, OpenEntryCloseService } from './open-entry-close';

/** Fehlerzustand einer Beenden-Aktion; jedes Vorkommen ist ein neues Objekt (gleicher Fehler zweimal löst zweimal aus). */
export interface OpenEntrySaveError {
  result: 'failed' | 'invalidEnd' | 'invalidEntry';
}

/** Daten für den Beenden-Dialog: der gefundene Eintrag und das Soll seines Tages. */
export interface OpenEntryEndData {
  entry: WorkEntry;
  targetMs: number;
}

/**
 * Zustand der Offene-Einträge-Anzeige (#385): sucht offene Einträge vor heute (aktives Profil, aktueller und
 * Vormonat), verwaltet „Später" (nur für diese Sitzung) und orchestriert das Beenden. Der Kalendertag eines Eintrags
 * kommt immer aus der `id`, nie aus `date`. Der Dashboard-Zustand wird nur über
 * `DashboardService.reloadAfterRetroClose` angefasst (Richtung: OpenEntry -> Dashboard, nie umgekehrt).
 */
@Injectable({ providedIn: 'root' })
export class OpenEntryService {
  private readonly auth = inject(AuthService);
  private readonly workProfile = inject(WorkProfileService);
  private readonly todayService = inject(TodayService);
  private readonly workEntries = inject(WorkEntryService);
  private readonly dashboard = inject(DashboardService);
  private readonly closer = inject(OpenEntryCloseService);
  private readonly settings = inject(SettingsService);

  private readonly _candidates = signal<OpenEntryCandidate[]>([]);
  /** Die zugehörigen Einträge der letzten Suche (Startzeit fürs Banner, Vorschlag im Dialog). */
  private readonly _found = signal<ReadonlyMap<string, WorkEntry>>(new Map<string, WorkEntry>());
  /** Schlüssel `uid|pid|yyyy-MM-dd` (ausgeloggt `anon`), nicht persistent: gilt bis zum Neuladen der Seite. */
  private readonly _dismissed = signal<ReadonlySet<string>>(new Set<string>());
  private readonly _busy = signal(false);
  private readonly _saveError = signal<OpenEntrySaveError | null>(null);
  private readonly _closedCount = signal(0);

  /** Tag des im Dashboard angezeigten Eintrags: ein dort laufender Vortag ist nie ein Kandidat (#372). */
  private readonly _dashEntryId = computed(() => this.dashboard.workEntry().id);

  /** Kontext (Nutzer + Profil) der aktuellen Kandidaten; ändert er sich, werden laufende Aktionen/Suchen obsolet. */
  private _ctxUid = '';
  private _ctxPid = '';
  private _ctxEpoch = 0;
  /** Jede Suche trägt eine Sequenznummer; nur die neueste darf ihr Ergebnis setzen. */
  private _searchSeq = 0;
  /** Dashboard-Eintrags-Id des letzten Effect-Laufs (Flash-Schutz); `''` = noch keiner. */
  private _prevDashId = '';
  /** `Date.now()` ist nicht reaktiv: wird erhöht, wenn `canResume` neu bewertet werden soll. */
  private readonly _clockTick = signal(0);

  readonly busy = this._busy.asReadonly();
  readonly saveError = this._saveError.asReadonly();
  /** Zählt Einträge, die nach Aktion „Beenden" aus der Anzeige verschwunden sind (für Fokus und Ansage im UI). */
  readonly closedCount = this._closedCount.asReadonly();

  /** Sichtbare Kandidaten, neuester zuerst. */
  readonly entries = computed<OpenEntryCandidate[]>(() => {
    if (this.dashboard.isLoading()) return [];
    const user = this.auth.user();
    if (user === undefined) return [];
    const uid = user?.uid ?? 'anon';
    const pid = this.workProfile.activeProfileId();
    const dashId = this._dashEntryId();
    const dismissed = this._dismissed();
    return this._candidates().filter(c =>
      c.profileId === pid && c.id !== dashId && !dismissed.has(this._key(uid, pid, c.id)));
  });
  readonly current = computed<OpenEntryCandidate | null>(() => this.entries()[0] ?? null);
  /**
   * „Fortsetzen" ist für den neuesten sichtbaren Kandidaten möglich (Regel `canResumeOpenEntry`: heute leer, höchstens
   * 24 h alt). Ältere Kandidaten bieten es nie an.
   */
  readonly canResume = computed(() => {
    this._clockTick();
    const cur = this.current();
    if (!cur) return false;
    const entry = this._found().get(cur.id);
    if (!entry) return false;
    return canResumeOpenEntry({
      entry,
      now: new Date(),
      todayId: this.todayService.today(),
      todayIsEmpty: this.dashboard.todayIsEmpty(),
    });
  });
  readonly moreCount = computed(() => Math.max(0, this.entries().length - 1));

  constructor() {
    effect(() => {
      const user = this.auth.user(); // undefined, bis Firebase zum ersten Mal geantwortet hat
      const pid = this.workProfile.activeProfileId();
      const today = this.todayService.today();
      const dashId = this._dashEntryId(); // Dashboard schaltet den Eintrag um (z. B. Stop eines Vortags): neu prüfen
      untracked(() => {
        // Flash-Schutz: der zuvor im Dashboard angezeigte Tag (z. B. gepinnter Vortag nach dem Stop) ist nicht mehr offen;
        // ein älteres Suchergebnis darf ihn nicht kurz wieder als Banner zeigen.
        if (this._prevDashId !== '' && this._prevDashId !== dashId) this._dropCandidate(this._prevDashId);
        this._prevDashId = dashId;
        this._onTrigger(user, pid, today);
      });
    });
  }

  /** Der bei der Suche gefundene Eintrag zum Tag `id` (reaktiv), sonst `undefined`. */
  entryOf(id: string): WorkEntry | undefined {
    return this._found().get(id);
  }

  /**
   * Daten für den Beenden-Dialog. Das Soll kommt aus den Einstellungen des Profils des Kandidaten; sind sie nicht
   * lesbar, ist es 0 (kein Soll-Ende als Vorschlag, das Beenden selbst liest sie erneut und scheitert dort sauber).
   */
  async prepareEnd(candidate: OpenEntryCandidate): Promise<OpenEntryEndData | null> {
    const entry = this._found().get(candidate.id);
    if (!entry) return null;
    let targetMs = 0;
    try {
      const settings = await this.settings.getSettingsOnce(candidate.profileId);
      targetMs = effectiveTargetMsForDate(settings, localDateFromEntryId(candidate.id));
    } catch { /* Vorschlag ohne Soll */ }
    return { entry, targetMs };
  }

  /** „Später": blendet alle aktuellen Kandidaten dieses Nutzers und Profils für die Sitzung aus. */
  later(): void {
    const uid = this._ctxUid;
    const pid = this._ctxPid;
    if (!uid) return;
    const next = new Set(this._dismissed());
    for (const c of this._candidates()) {
      if (c.profileId === pid) next.add(this._key(uid, pid, c.id));
    }
    this._dismissed.set(next);
  }

  /**
   * „Fortsetzen": lädt den Kandidaten ins Dashboard (`DashboardService.resumePastEntry`, schreibt nichts). Prüft die Regel
   * vorher mit frischer Uhr. Erfolg: Kandidat sofort entfernt, Fokus-Zähler +1. Ablehnung: still, stille Neusuche
   * (ein anderswo beendeter Eintrag verschwindet).
   */
  async resume(candidate: OpenEntryCandidate): Promise<boolean> {
    if (this._busy()) return false;
    const visible = this.entries().some(c => c.id === candidate.id && c.profileId === candidate.profileId);
    const entry = this._found().get(candidate.id);
    if (!visible || !entry) return false;
    this.todayService.refresh();
    const allowed = canResumeOpenEntry({
      entry,
      now: new Date(),
      todayId: this.todayService.today(),
      todayIsEmpty: this.dashboard.todayIsEmpty(),
    });
    if (!allowed) {
      this._clockTick.update(n => n + 1);
      return false;
    }
    this._busy.set(true);
    const epoch = this._ctxEpoch;
    try {
      const ok = await this.dashboard.resumePastEntry(entry, candidate.profileId);
      if (epoch !== this._ctxEpoch) return ok; // Profil/Nutzer gewechselt: nichts im neuen Zustand anfassen
      if (ok) {
        this._dropCandidate(candidate.id);
        this._closedCount.update(n => n + 1);
      } else {
        this._clockTick.update(n => n + 1);
        await this._search(candidate.profileId, this._ctxUid, this.todayService.today(), ++this._searchSeq);
      }
      return ok;
    } finally {
      if (epoch === this._ctxEpoch) this._busy.set(false);
    }
  }

  /** Beendet den Eintrag (Ergebnis auch als Rückgabewert) und zieht Dashboard und Anzeige nach. */
  async endEntry(candidate: OpenEntryCandidate, end: Date): Promise<CloseResult> {
    if (this._busy()) return 'busy';
    this._busy.set(true);
    this._saveError.set(null);
    const epoch = this._ctxEpoch;
    const pid = candidate.profileId;
    try {
      const result = await this.closer.endEntry(candidate, end);
      if (epoch !== this._ctxEpoch) return result; // Profil/Nutzer gewechselt: nichts im neuen Zustand anfassen
      if (result === 'closed' || result === 'alreadyClosed') {
        await this.dashboard.reloadAfterRetroClose(pid);
        if (epoch !== this._ctxEpoch) return result;
        await this._search(pid, this._ctxUid, this.todayService.today(), ++this._searchSeq);
        if (epoch === this._ctxEpoch) this._closedCount.update(n => n + 1);
      } else if (result === 'failed' || result === 'invalidEnd' || result === 'invalidEntry') {
        this._saveError.set({ result });
      }
      return result;
    } finally {
      if (epoch === this._ctxEpoch) this._busy.set(false); // ein überholter Lauf darf busy des neuen Kontexts nicht lösen
    }
  }

  private _onTrigger(user: { uid: string } | null | undefined, pid: string, today: string): void {
    const seq = ++this._searchSeq;
    if (user === undefined) {
      this._ctxUid = '';
      this._ctxPid = '';
      this._ctxEpoch++;
      this._busy.set(false);
      this._setCandidates([], new Map());
      return;
    }
    const uid = user?.uid ?? 'anon';
    if (uid !== this._ctxUid || pid !== this._ctxPid) {
      this._ctxUid = uid;
      this._ctxPid = pid;
      this._ctxEpoch++;
      this._busy.set(false);
      this._setCandidates([], new Map());
    }
    void this._search(pid, uid, today, seq);
  }

  /** Liest aktuellen und Vormonat (je Monat eigenes try/catch) und setzt die Kandidaten, falls nicht überholt. */
  private async _search(pid: string, uid: string, today: string, seq: number): Promise<void> {
    const [year, month] = today.split('-').map(Number);
    // `new Date(y, m - 2, 1)` normalisiert den Januar auf den Dezember des Vorjahres.
    const months = [new Date(year, month - 1, 1), new Date(year, month - 2, 1)];
    const lists = await Promise.all(months.map(async d => {
      try {
        return await this.workEntries.getEntriesForMonthOnce(d.getFullYear(), d.getMonth() + 1, pid);
      } catch {
        return [];
      }
    }));
    if (seq !== this._searchSeq || uid !== this._ctxUid || pid !== this._ctxPid) return;

    const found = new Map<string, OpenEntryCandidate>();
    const entriesById = new Map<string, WorkEntry>();
    for (const e of lists.flat()) {
      if (e.type !== WorkEntryType.Work || !e.workStart || e.workEnd) continue;
      if (e.id >= today) continue; // String-Vergleich yyyy-MM-dd; der Tag kommt nur aus der id
      found.set(e.id, { id: e.id, profileId: pid });
      entriesById.set(e.id, e);
    }
    this._setCandidates([...found.values()].sort((a, b) => (a.id < b.id ? 1 : a.id > b.id ? -1 : 0)), entriesById);
  }

  private _dropCandidate(id: string): void {
    if (!this._found().has(id) && !this._candidates().some(c => c.id === id)) return;
    this._candidates.update(list => list.filter(c => c.id !== id));
    const next = new Map(this._found());
    next.delete(id);
    this._found.set(next);
  }

  private _setCandidates(list: OpenEntryCandidate[], entriesById: Map<string, WorkEntry>): void {
    this._candidates.set(list);
    this._found.set(entriesById);
  }

  private _key(uid: string, pid: string, id: string): string {
    return `${uid}|${pid}|${id}`;
  }
}
