import { Injectable, Injector, inject, signal, computed, effect, untracked, DestroyRef } from '@angular/core';
import { takeUntilDestroyed, toSignal } from '@angular/core/rxjs-interop';
import { catchError, distinctUntilChanged, firstValueFrom, interval, of } from 'rxjs';
import { WorkEntryService } from '../../core/services/work-entry';
import { OvertimeService }  from '../../core/services/overtime';
import { SettingsService }  from '../../core/services/settings';
import { AuthService }      from '../../core/auth/auth';
import { TodayService }     from '../../core/services/today';
import { ProfileSwitchRequest, WorkProfileService } from '../../core/services/work-profile';
import { ProfileSwitchConfirmService } from '../../shared/components/work-profile-switcher/profile-switch-confirm';
import { GermanHoliday, getGermanHolidayIds, toDateKey } from '../../shared/utils/german-holidays.util';
import { DEFAULT_SETTINGS, WorkEntry, WorkEntryType, Break } from '../../shared/models';
import { calculateAndApplyBreaks } from '../../domain/services/break-calculator';
import { nowToMinute, roundToMinute, roundMsToMinute } from '../../shared/utils/time-precision.util';
import {
  getEffectiveDailyTarget,
  calculateInitialOvertime,
} from '../../domain/utils/overtime.utils';

/**
 * Kontext einer Schreibaktion (#380): Profil und `_init`-Generation zum Aktionsbeginn. Alle Writes der Aktion gehen
 * explizit an `pid` (nie „das gerade aktive Profil"); nach jedem `await` verhindert `gen` zustandsändernde Folgeschritte.
 */
interface ActionCtx { pid: string; gen: number }

interface DashboardState {
  status: 'loading' | 'ready';
  workEntry: WorkEntry;
  elapsedMs: number;
  grossMs: number;
  actualWorkMs: number | null;
  totalOvertimeMs: number | null;
  initialOvertimeMs: number | null;
  dailyOvertimeMs: number | null;
  expectedEndTime: Date | null;
  expectedEndTotalZero: Date | null;
  isExtraDay: boolean;
}

function emptyEntry(): WorkEntry {
  const today = new Date();
  return {
    id:               `${today.getFullYear()}-${String(today.getMonth()+1).padStart(2,'0')}-${String(today.getDate()).padStart(2,'0')}`,
    date:             today,
    workStart:        undefined,
    workEnd:          undefined,
    breaks:           [],
    isManuallyEntered: false,
    type:             WorkEntryType.Work,
  };
}

function initialState(): DashboardState {
  return {
    status: 'loading',
    workEntry: emptyEntry(),
    elapsedMs: 0,
    grossMs: 0,
    actualWorkMs: null,
    totalOvertimeMs: null,
    initialOvertimeMs: null,
    dailyOvertimeMs: null,
    expectedEndTime: null,
    expectedEndTotalZero: null,
    isExtraDay: false,
  };
}

@Injectable({ providedIn: 'root' })
export class DashboardService {
  private readonly _s            = signal<DashboardState>(initialState());
  private readonly workSvc       = inject(WorkEntryService);
  private readonly overtimeSvc   = inject(OvertimeService);
  private readonly settingsSvc   = inject(SettingsService);
  private readonly authSvc       = inject(AuthService);
  private readonly workProfile   = inject(WorkProfileService);

  // ─── Feiertag heute (#279) ──────────────────────────────────────────────────
  // Nur der Chip wechselt um Mitternacht; das restliche Dashboard bleibt (Folge-Issue).
  private readonly _holidaySettings = toSignal(
    this.settingsSvc.getSettings().pipe(catchError(() => of(DEFAULT_SETTINGS))),
    { initialValue: DEFAULT_SETTINGS },
  );
  private readonly todayService = inject(TodayService);

  /** Feiertag des lokalen Datums laut gewähltem Bundesland, sonst `null` (rein informativ). */
  readonly holidayToday = computed<GermanHoliday | null>(() => {
    const land = this._holidaySettings().bundesland;
    if (!land) return null;
    const key = this.todayService.today();
    return getGermanHolidayIds(Number(key.slice(0, 4)), land).get(key) ?? null;
  });
  readonly isLoggedIn = computed(() => !!this.authSvc.user());
  private readonly destroyRef    = inject(DestroyRef);
  /** Nur lazy genutzt (Dialog-Service wird erst bei laufendem Timer aufgelöst, #380). */
  private readonly injector      = inject(Injector);

  // ─── Public Signals ────────────────────────────────────────────────────────
  readonly isLoading       = computed(() => this._s().status === 'loading');
  readonly workEntry       = computed(() => this._s().workEntry);
  readonly isTimerRunning  = computed(() => {
    const e = this._s().workEntry;
    return !!e.workStart && !e.workEnd;
  });
  readonly isBreakRunning  = computed(() => {
    const b = this._s().workEntry.breaks;
    return b.length > 0 && !b[b.length - 1].end;
  });
  readonly netDuration     = computed(() => this._s().actualWorkMs ?? this._s().elapsedMs);
  readonly grossDuration   = computed(() => this._s().grossMs);
  readonly totalOvertime   = computed(() => this._s().totalOvertimeMs);
  readonly dailyOvertime   = computed(() => this._s().dailyOvertimeMs);
  readonly expectedEndTime      = computed(() => this._s().expectedEndTime);
  readonly expectedEndTotalZero = computed(() => this._s().expectedEndTotalZero);
  readonly breaks          = computed(() => this._s().workEntry.breaks);

  // ─── Private timer state ────────────────────────────────────────────────────
  private _timerUnsub: (() => void) | null = null;
  private _autoSaveTick = 0;
  private _initGen = 0;
  /** Letzter laufender `_init` (für `_ensureCurrentDay`, damit überholte Aktionen auf den neuesten warten). */
  private _initRun: Promise<void> | null = null;
  /** Profil, dessen Daten gerade im Dashboard stehen (#380). Wird synchron zu Beginn jedes `_init` gesetzt. */
  private _loadedProfileId = '';
  /** Letzter Wert, den `activeProfileId$` geliefert hat (das Observable hinkt dem Signal hinterher). */
  private _lastObservedProfileId: string | undefined;
  /** Der letzte `_init` lief im Lag-Fenster (Signal schon neu, Observable noch alt): Einstellungen evtl. vom alten Profil. */
  private _settingsMaybeStale = false;

  constructor() {
    // Startwert = aktuelles Profil. Bewusst im Constructor und nicht als `= DEFAULT_WORK_PROFILE_ID`-Feldinitializer:
    // Vites SSR-Transform hebt eine nackte importierte Referenz als Schnappschuss vor die Klasse; im gebündelten Vollauf
    // der Tests ist sie dann (nicht deterministisch) `undefined`. Siehe web/CLAUDE.md, „Test-Falle“.
    this._loadedProfileId = this.workProfile.activeProfileId();

    // Interaktive Profilwechsel (#380, Stufe 2): bei laufendem Timer erst bestätigen lassen, stoppen und speichern.
    // Hier und nicht in der Component: der Timer läuft auch, wenn das Dashboard nie gerendert wurde (Start auf /settings).
    const unregisterGuard = this.workProfile.registerSwitchGuard(req => this._confirmSwitch(req));
    this.destroyRef.onDestroy(unregisterGuard);

    // Re-init on auth state change (Flow 11)
    effect(() => {
      const user = this.authSvc.user();
      // untracked: `_init` liest synchron `activeProfileId()`; der Profilwechsel läuft nur über `activeProfileId$` (#380).
      untracked(() => { void this._init(user?.uid ?? null); });
    });

    // Profilwechsel (#380): Trigger ist das Observable (nicht das Signal), damit der Replay von `getTodayEntry()`
    // beim neuen Abonnieren garantiert das neue Profil liefert. Ein laufender Timer wird dabei eingefroren: `_init`
    // stoppt ihn ohne zu speichern, der Eintrag bleibt im alten Profil laufend und setzt sich beim Rückwechsel fort.
    this.workProfile.activeProfileId$
      .pipe(distinctUntilChanged(), takeUntilDestroyed(this.destroyRef))
      .subscribe(id => {
        this._lastObservedProfileId = id;
        this._onProfileChange(id);
      });

    // Tageswechsel (#372): erster Lauf = Startzustand, übersprungen. Nur gestoppte/leere Einträge wechseln still;
    // ein laufender Timer läuft über Mitternacht weiter und der Eintrag bleibt am Starttag.
    let firstDayRun = true;
    effect(() => {
      const day = this.todayService.today();
      if (firstDayRun) { firstDayRun = false; return; }
      untracked(() => this._onDayChange(day));
    });

    // Einstellungen reaktiv halten — Überstunden bei Änderung neu berechnen
    this.settingsSvc.getSettings()
      .pipe(takeUntilDestroyed(this.destroyRef))
      .subscribe(s => {
        this._settingsCache = { weeklyTargetHours: s.weeklyTargetHours, workdays: s.workdays };
        if (this._s().status === 'ready') {
          this._recalculateOvertime();
        }
      });
  }

  /** Idempotent: ein bereits geladenes Profil (Start-Replay, Doppel-Auslöser Auth + Profil) lädt nicht erneut. */
  private _onProfileChange(id: string): void {
    if (id === this._loadedProfileId && !this._settingsMaybeStale) return;
    void this._init(this._uid());
  }

  /** Kontext (Profil + Generation) für eine Schreibaktion; synchron zusammen mit dem gelesenen Eintrag erfassen. */
  private _ctx(): ActionCtx {
    return { pid: this._loadedProfileId, gen: this._initGen };
  }

  private _uid(): string | null {
    return this.authSvc.user()?.uid ?? null;
  }

  /**
   * Aktionen-Guard: ein gestoppter Eintrag eines früheren Tages wird vor jeder Aktion auf den heutigen Tag
   * umgestellt, damit „Start" nach Mitternacht nie in den Vortag schreibt. Laufende Einträge sind ausgenommen
   * (Stop/Pause gehören zum Starttag).
   *
   * Liefert `false`, wenn der Zustand danach nicht zum heutigen Tag passt (Reinit überholt/fehlgeschlagen):
   * die Aktion MUSS dann abbrechen — sonst liefe sie auf dem veralteten Vortags-Eintrag und schriebe dorthin.
   * Läuft ein anderer `_init` (Doppelklick, Login), wird dessen Ende abgewartet.
   */
  private async _ensureCurrentDay(): Promise<boolean> {
    this.todayService.refresh();
    // Lädt gerade (Login, Profilwechsel, Tageswechsel): nie auf dem Lade-Platzhalter schreiben, erst den Lauf abwarten.
    while (this._s().status === 'loading' && this._initRun !== null) await this._initRun;
    if (this._isCurrentDay()) return true;
    await this._init(this._uid(), { dayChange: true });
    // Überholt? Dann auf den neuesten Lauf warten (er setzt den endgültigen Zustand).
    while (this._initRun !== null) await this._initRun;
    this.todayService.refresh();
    return this._isCurrentDay();
  }

  /** Eintrag läuft (Starttag bleibt) oder gehört zum heutigen Tag. */
  private _isCurrentDay(): boolean {
    const e = this._s().workEntry;
    if (!!e.workStart && !e.workEnd) return true;
    return toDateKey(e.date) === this.todayService.today();
  }

  private _onDayChange(day: string): void {
    const e = this._s().workEntry;
    if (!!e.workStart && !e.workEnd) return; // laufender Timer: nichts anfassen
    if (toDateKey(e.date) === day && this._s().status === 'ready') return;
    void this._init(this._uid(), { dayChange: true });
  }

  // ─── Flow 1: Initialisierung ────────────────────────────────────────────────
  // Generationszähler: ein überholter Lauf (Login, Tageswechsel) darf Zustand/Timer nicht mehr verändern.
  private _init(_uid: string | null, opts: { dayChange?: boolean } = {}): Promise<void> {
    const run: Promise<void> = this._initInner(opts).finally(() => {
      if (this._initRun === run) this._initRun = null;
    });
    this._initRun = run;
    return run;
  }

  private async _initInner(opts: { dayChange?: boolean }): Promise<void> {
    const gen = ++this._initGen;
    this._stopTimer();
    // Profil dieses Laufs synchron festhalten; alle Reads gehen mit explizitem `pid`, damit nie „Eintrag A + Saldo B"
    // entsteht. Ein Profilwechsel ist nie ein stiller Tageswechsel (kein dayChange-Pfad, Ladezustand).
    const pid = this.workProfile.activeProfileId();
    const profileChanged = pid !== this._loadedProfileId;
    this._loadedProfileId = pid;
    this._settingsMaybeStale = this._lastObservedProfileId !== undefined && this._lastObservedProfileId !== pid;
    const dayChange = !!opts.dayChange && !profileChanged;
    // Beim stillen Tageswechsel den alten Zustand stehen lassen (kein Lade-Flackern), sonst zurücksetzen.
    if (!dayChange) this._s.set(initialState());

    try {
      const today = new Date();

      // 1. Heutigen Eintrag laden
      const workEntry = (await firstValueFrom(this.workSvc.getTodayEntry(pid))) ?? this.workSvc.emptyEntry(today);
      if (gen !== this._initGen) return;

      // 2. Überstunden + Datum laden
      const storedOvertimeMs = await this.overtimeSvc.getOvertime(pid);
      if (gen !== this._initGen) return;
      const lastUpdateDate   = await this.overtimeSvc.getLastUpdateDate(pid);
      if (gen !== this._initGen) return;

      // 3. Einstellungen laden + Cache sofort befüllen (firstValueFrom = take(1), keine dauerhafte Subscription)
      const settings = await firstValueFrom(this.settingsSvc.getSettings());
      if (gen !== this._initGen) return;
      this._settingsCache = { weeklyTargetHours: settings.weeklyTargetHours, workdays: settings.workdays };

      // 4. Effektives Tagessoll berechnen
      const weeklyMs          = settings.weeklyTargetHours * 60 * 60 * 1000;
      const regularDailyMs    = settings.workdays.length > 0 ? roundMsToMinute(weeklyMs / settings.workdays.length) : 0;
      const targetDailyMs     = getEffectiveDailyTarget(workEntry.date, settings.workdays, regularDailyMs);
      const isExtraDay        = targetDailyMs === 0;

      // 6. Initiales Daily Overtime berechnen
      const manualEntryMs = (workEntry.manualOvertimeMinutes ?? 0) * 60000;
      let initialDailyMs = 0;
      if (workEntry.workStart && workEntry.workEnd) {
        const breakMs    = this._totalBreakMs(workEntry.breaks, workEntry.workEnd);
        const netMs      = workEntry.workEnd.getTime() - workEntry.workStart.getTime() - breakMs;
        initialDailyMs   = netMs - targetDailyMs + manualEntryMs;
      } else if (workEntry.workStart) {
        const now        = new Date();
        const breakMs    = this._totalBreakMs(workEntry.breaks, now);
        const netMs      = now.getTime() - workEntry.workStart.getTime() - breakMs;
        initialDailyMs   = netMs - targetDailyMs + manualEntryMs;
      }

      // 7. Base-Overtime berechnen. Beim Tageswechsel ist der gespeicherte Wert die Basis: ein Vortags-Save nach
      // Mitternacht setzt `lastUpdated` auf „heute" und würde sonst den neuen Tages-Daily fälschlich abziehen.
      // Ausnahme: wurde der geladene heutige Eintrag bereits abgeschlossen UND danach gespeichert (z. B. auf einem
      // anderen Gerät), steckt sein Daily im gespeicherten Wert — dann gilt weiter die Heuristik (kein Doppelzählen).
      const dailyAlreadyStored = !!workEntry.workStart && !!workEntry.workEnd
        && !!lastUpdateDate && lastUpdateDate.getTime() >= workEntry.workEnd.getTime();
      const initialOvertimeMs = dayChange && !dailyAlreadyStored
        ? storedOvertimeMs
        : calculateInitialOvertime(storedOvertimeMs, lastUpdateDate, initialDailyMs);
      const totalOvertimeMs   = initialOvertimeMs + initialDailyMs;

      this._s.set({
        status: 'ready',
        workEntry,
        elapsedMs:        0,
        grossMs:          0,
        actualWorkMs:     null,
        totalOvertimeMs,
        initialOvertimeMs,
        dailyOvertimeMs:  initialDailyMs,
        expectedEndTime:  null,
        expectedEndTotalZero: null,
        isExtraDay,
      });

      this._recalculateState(workEntry, false);
      this._startTimerIfNeeded();
    } catch {
      if (gen !== this._initGen) return;
      // Initialisierung fehlgeschlagen — leeren Zustand zeigen statt Dauerladespinner
      this._s.update(s => ({ ...s, status: 'ready' }));
    }
  }

  // ─── Flow 2+3: Timer starten / stoppen ─────────────────────────────────────
  async startOrStopTimer(): Promise<'restart-dialog' | void> {
    if (!(await this._ensureCurrentDay())) return;
    const e = this._s().workEntry;
    const ctx = this._ctx();
    if (!e.workStart) {
      // START
      const updated = { ...e, workStart: nowToMinute(), workEnd: undefined };
      await this._recalculateState(updated, true, ctx);
      if (this._isCurrent(ctx)) this._startTimerIfNeeded();
    } else if (!e.workEnd) {
      // STOP
      await this._stopRunning(e, ctx, { reinitAfterMidnight: true });
    } else {
      // Bereits gestoppt → Restart-Dialog nötig (Flow 5)
      return 'restart-dialog';
    }
  }

  // ─── Stop-Logik (Stop-Button und Profilwechsel, #380) ──────────────────────────────────────────────────
  /**
   * Beendet den laufenden Timer: Pflichtpausen, Eintrag und Saldo werden in das festgehaltene Profil geschrieben.
   * Wirft bei Speicherfehlern (der Zustand ist dann schon gesetzt, Rollback macht der Aufrufer).
   * `reinitAfterMidnight`: nach einem Lauf über Mitternacht auf den neuen Tag umschalten (Stop-Button); der Profilwechsel
   * lädt ohnehin neu und braucht das nicht.
   */
  private async _stopRunning(e: WorkEntry, ctx: ActionCtx, opts: { reinitAfterMidnight: boolean }): Promise<void> {
    this._stopTimer();
    let updated: WorkEntry = { ...e, workEnd: nowToMinute() };
    const hasRunningBreak = updated.breaks.some(b => !b.end);
    if (!hasRunningBreak && updated.type === WorkEntryType.Work) {
      updated = calculateAndApplyBreaks(updated);
    }
    const totalMs = await this._recalculateState(updated, true, ctx);
    // Saldo mit dem VOR dem ersten await eingefrorenen Wert und dem festgehaltenen Profil (auch nach Überholung).
    await this._saveOvertime(ctx.pid, totalMs);
    if (!opts.reinitAfterMidnight || !this._isCurrent(ctx)) return;
    // Über Mitternacht gelaufen: der Eintrag gehört zum Starttag, die Anzeige wechselt auf den neuen Tag.
    this.todayService.refresh();
    if (toDateKey(updated.date) !== this.todayService.today()) {
      await this._init(this._uid(), { dayChange: true });
    }
  }

  /**
   * Guard für interaktive Profilwechsel: ohne laufenden Timer sofort `true`; sonst Bestätigung, dann Stoppen und
   * Speichern im alten Profil. `false` = Wechsel nicht durchführen.
   */
  private async _confirmSwitch(req: ProfileSwitchRequest): Promise<boolean> {
    if (!this.isTimerRunning()) return true;
    const confirm = this.injector.get(ProfileSwitchConfirmService);
    if (!(await confirm.confirmStopAndSwitch(req))) return false;
    const ok = await this.stopRunningTimerForSwitch(req.from);
    if (!ok) confirm.notifySaveFailed();
    return ok;
  }

  /**
   * Stoppt und speichert den laufenden Timer des Profils `from` vor einem Profilwechsel. `true` = es läuft nichts
   * (mehr) oder der Stop wurde gespeichert; `false` = Speichern fehlgeschlagen oder das Profil ist nicht mehr `from`.
   * Bei einem Fehler wird der Zustand zurückgesetzt und der Timer läuft weiter.
   */
  async stopRunningTimerForSwitch(from: string): Promise<boolean> {
    // Lädt gerade (Reload-Wechsel): erst abwarten, nie auf dem Lade-Platzhalter arbeiten.
    while (this._s().status === 'loading' && this._initRun !== null) await this._initRun;
    // Der Dialog war offen: das Profil kann sich nicht-interaktiv geändert haben.
    if (this._loadedProfileId !== from || this.workProfile.activeProfileId() !== from) return false;
    // Der Timer kann in der Zwischenzeit manuell gestoppt worden sein.
    if (!this.isTimerRunning()) return true;
    const e = this._s().workEntry;
    const ctx = this._ctx();
    const snapshot = this._s();
    try {
      await this._stopRunning(e, ctx, { reinitAfterMidnight: false });
      return true;
    } catch {
      if (this._isCurrent(ctx)) {
        this._s.set(snapshot);
        this._startTimerIfNeeded();
      }
      return false;
    }
  }

  // ─── Flow 5: Restart Session ────────────────────────────────────────────────
  async startNewSession(keepBreaks: boolean): Promise<void> {
    if (!(await this._ensureCurrentDay())) return;
    const e = this._s().workEntry;
    const ctx = this._ctx();
    const updated: WorkEntry = {
      ...e,
      workStart:         nowToMinute(),
      workEnd:           undefined,
      breaks:            keepBreaks ? e.breaks : [],
      isManuallyEntered: false,
    };
    await this._recalculateState(updated, true, ctx);
    if (this._isCurrent(ctx)) this._startTimerIfNeeded();
  }

  // ─── Flow 6: Pause starten/stoppen ──────────────────────────────────────────
  async startOrStopBreak(): Promise<void> {
    if (!(await this._ensureCurrentDay())) return;
    const e = this._s().workEntry;
    const ctx = this._ctx();
    const runningBreak = e.breaks.find(b => !b.end);
    let updatedBreaks: Break[];

    if (runningBreak) {
      updatedBreaks = e.breaks.map(b => b.id === runningBreak.id ? { ...b, end: nowToMinute() } : b);
    } else {
      const newBreak: Break = {
        id:          crypto.randomUUID(),
        name:        `Pause ${e.breaks.length + 1}`,
        start:       nowToMinute(),
        end:         undefined,
        isAutomatic: false,
      };
      updatedBreaks = [...e.breaks, newBreak];
    }
    await this._recalculateState({ ...e, breaks: updatedBreaks }, true, ctx);
  }

  // ─── Flow 7: Manuelle Startzeit ──────────────────────────────────────────────
  async setManualStartTime(timeStr: string): Promise<void> {
    if (!(await this._ensureCurrentDay())) return;
    const e = this._s().workEntry;
    const ctx = this._ctx();
    let updated: WorkEntry = { ...e, workStart: this._parseTime(e.date, timeStr) };
    const hasRunning = updated.breaks.some(b => !b.end);
    if (updated.workStart && updated.workEnd && !hasRunning && updated.type === WorkEntryType.Work) {
      updated = calculateAndApplyBreaks(updated);
    }
    await this._recalculateState(updated, true, ctx);
    if (this._isCurrent(ctx)) this._startTimerIfNeeded();
  }

  // ─── Flow 8: Manuelle Endzeit ─────────────────────────────────────────────
  async setManualEndTime(timeStr: string): Promise<void> {
    if (!(await this._ensureCurrentDay())) return;
    const e = this._s().workEntry;
    const ctx = this._ctx();
    let updated: WorkEntry = { ...e, workEnd: this._parseTime(e.date, timeStr) };
    const hasRunning = updated.breaks.some(b => !b.end);
    if (updated.workStart && updated.workEnd && !hasRunning && updated.type === WorkEntryType.Work) {
      updated = calculateAndApplyBreaks(updated);
    }
    await this._recalculateState(updated, true, ctx);
  }

  async clearEndTime(): Promise<void> {
    if (!(await this._ensureCurrentDay())) return;
    const e = this._s().workEntry;
    const ctx = this._ctx();
    const updated = { ...e, workEnd: undefined };
    await this._recalculateState(updated, true, ctx);
    if (this._isCurrent(ctx)) this._startTimerIfNeeded();
  }

  // ─── Flow 9: Pause bearbeiten ─────────────────────────────────────────────
  async updateBreak(updated: Break): Promise<void> {
    if (!(await this._ensureCurrentDay())) return;
    const e = this._s().workEntry;
    const ctx = this._ctx();
    const normalized: Break = {
      ...updated,
      start: roundToMinute(updated.start),
      end:   updated.end ? roundToMinute(updated.end) : undefined,
    };
    const breaks = e.breaks.map(b => b.id === updated.id ? normalized : b);
    await this._recalculateState({ ...e, breaks }, true, ctx);
  }

  // ─── Flow 10: Pause löschen ───────────────────────────────────────────────
  async deleteBreak(id: string): Promise<void> {
    if (!(await this._ensureCurrentDay())) return;
    const e = this._s().workEntry;
    const ctx = this._ctx();
    const breaks = e.breaks.filter(b => b.id !== id);
    await this._recalculateState({ ...e, breaks }, true, ctx);
  }

  // ─── Flow 12: Überstunden manuell anpassen ────────────────────────────────
  // newBaseMs = Basis-Bilanz aus Vortagen (NICHT inkl. heutiger Daily-Overtime).
  /**
   * `profileId` (#380): Profil, dessen Saldo der Nutzer gesehen hat (Settings-Seite). Ohne Argument gilt das geladene
   * Profil. Geschrieben wird immer in dieses Profil; der Dashboard-Zustand ändert sich nur, wenn es das geladene ist.
   */
  async updateInitialOvertime(newBaseMs: number, profileId?: string): Promise<void> {
    const target = profileId ?? this._loadedProfileId;
    if (target === this._loadedProfileId) {
      const daily = this._s().dailyOvertimeMs ?? 0;
      this._s.update(s => ({
        ...s,
        initialOvertimeMs: newBaseMs,
        totalOvertimeMs:   newBaseMs + daily,
      }));
    }
    // Nur minutes speichern — kein lastUpdated-Update.
    // So behandelt _init den Wert beim nächsten Load als Basis, nicht als heutigen Total.
    await this.overtimeSvc.saveOvertime(newBaseMs, target);
  }

  // ─── Timer Internals ──────────────────────────────────────────────────────
  private _startTimerIfNeeded(): void {
    const e = this._s().workEntry;
    if (!e.workStart || e.workEnd) return;

    this._stopTimer();
    this._autoSaveTick = 0;

    const sub = interval(1000).pipe(takeUntilDestroyed(this.destroyRef));
    const subscription = sub.subscribe(() => {
      this._tick();
      this._autoSaveTick++;
      if (this._autoSaveTick >= 30) {
        this._autoSaveTick = 0;
        void this._autoSave();
      }
    });
    this._timerUnsub = () => subscription.unsubscribe();
  }

  private _stopTimer(): void {
    this._timerUnsub?.();
    this._timerUnsub = null;
  }

  private _tick(): void {
    const e = this._s().workEntry;
    if (!e.workStart || e.workEnd) return;
    this.todayService.refresh(); // Standby-Härtung: Tageswechsel auch ohne feuernden Mitternachts-Timer erkennen
    const now    = new Date();
    const breakMs = this._totalBreakMs(e.breaks, now);
    const elapsed = now.getTime() - e.workStart.getTime() - breakMs;
    const gross   = now.getTime() - e.workStart.getTime();
    this._s.update(s => ({ ...s, elapsedMs: elapsed, grossMs: gross }));
    this._recalculateOvertime();
  }

  private async _autoSave(): Promise<void> {
    // Synchron aus dem aktuellen Zustand; `_init` stoppt den Timer vor jedem Zustandswechsel, ein Autosave
    // kann daher nie mit einem überholten Eintrag laufen. Das Profil ist explizit das geladene (#380): im
    // Lag-Fenster eines Profilwechsels (Signal neu, Reinit noch nicht gelaufen) gehört der Eintrag noch dorthin.
    const entry = this._s().workEntry;
    if (!entry.workStart) return;
    try { await this.workSvc.saveEntry(entry, this._loadedProfileId); } catch { /* silent */ }
  }

  // ─── Overtime Calculation ─────────────────────────────────────────────────
  private _recalculateOvertime(): void {
    const e = this._s().workEntry;
    if (!e.workStart) return;

    const settings  = this._currentSettings();
    const targetMs  = this._targetDailyMs(settings, e.date);
    const manualMs  = (e.manualOvertimeMinutes ?? 0) * 60000;
    const now       = new Date();
    const breakMs   = this._totalBreakMs(e.breaks, now);
    const elapsed   = now.getTime() - e.workStart.getTime() - breakMs;
    const daily     = elapsed - targetMs + manualMs;
    const base      = this._s().initialOvertimeMs ?? 0;
    const total     = base + daily;

    const expectedEnd          = this._calcExpectedEnd(e.workStart, targetMs, this._totalBreakMs(e.breaks, now));
    const remainingForZero     = Math.max(0, targetMs - base - manualMs);
    const expectedEndTotalZero = this._calcExpectedEnd(e.workStart, remainingForZero, this._totalBreakMs(e.breaks, now));

    this._s.update(s => ({
      ...s,
      dailyOvertimeMs:      daily,
      totalOvertimeMs:      total,
      expectedEndTime:      expectedEnd,
      expectedEndTotalZero,
      isExtraDay:           targetMs === 0,
    }));
  }

  private _calcExpectedEnd(workStart: Date, targetMs: number, currentBreakMs: number): Date | null {
    if (targetMs <= 0) return workStart;
    let projected = new Date(workStart.getTime() + targetMs + currentBreakMs);

    // Iterativ — wie Flutter (max 2 Iterationen für 6h/9h Sprünge)
    for (let i = 0; i < 2; i++) {
      const gross = projected.getTime() - workStart.getTime();
      let required = 0;
      if (gross >= 9 * 60 * 60 * 1000) required = 45 * 60 * 1000;
      else if (gross >= 6 * 60 * 60 * 1000) required = 30 * 60 * 1000;
      const missing = required - currentBreakMs;
      if (missing > 0) {
        currentBreakMs += missing;
        projected = new Date(workStart.getTime() + targetMs + currentBreakMs);
      } else break;
    }
    return projected;
  }

  // ─── State + Save ─────────────────────────────────────────────────────────
  /**
   * Setzt den Zustand und speichert optional. Liefert den (vor dem ersten `await` eingefrorenen) Gesamtsaldo.
   * Alle Writes gehen mit den festgehaltenen Werten explizit an `ctx.pid`, auch wenn das Profil währenddessen wechselt.
   */
  private async _recalculateState(entry: WorkEntry, save: boolean, ctx?: ActionCtx): Promise<number | null> {
    let actualWorkMs: number | null = null;
    let dailyMs: number | null = null;
    let totalMs = this._s().totalOvertimeMs;
    let grossMs: number | null = null;

    if (entry.workStart && entry.workEnd) {
      grossMs      = entry.workEnd.getTime() - entry.workStart.getTime();
      const breaks = this._totalBreakMs(entry.breaks, entry.workEnd);
      actualWorkMs = grossMs - breaks;
      const settings  = this._currentSettings();
      const targetMs  = this._targetDailyMs(settings, entry.date);
      const manualMs  = (entry.manualOvertimeMinutes ?? 0) * 60000;
      dailyMs    = actualWorkMs - targetMs + manualMs;
      const base = this._s().initialOvertimeMs ?? 0;
      totalMs    = base + dailyMs;
    }

    this._s.update(s => ({
      ...s,
      workEntry:      entry,
      actualWorkMs,
      grossMs:        grossMs ?? s.grossMs,
      dailyOvertimeMs: dailyMs,
      totalOvertimeMs: totalMs,
      isExtraDay:     dailyMs !== null ? this._targetDailyMs(this._currentSettings(), entry.date) === 0 : s.isExtraDay,
    }));

    if (save) {
      const pid = ctx?.pid ?? this._loadedProfileId;
      await this.workSvc.saveEntry(entry, pid);
      if (entry.workEnd && actualWorkMs !== null && totalMs !== null) {
        await this._saveOvertime(pid, totalMs);
      }
    }
    return totalMs;
  }

  /** Schreibt den Saldo in das festgehaltene Profil, mit dem übergebenen (nicht nach einem `await` neu gelesenen) Wert. */
  private async _saveOvertime(pid: string, ms: number | null): Promise<void> {
    if (ms === null) return;
    await this.overtimeSvc.saveOvertime(ms, pid);
    await this.overtimeSvc.saveLastUpdateDate(new Date());
  }

  /** Läuft noch derselbe Zustand wie zum Aktionsbeginn (kein Profil-/Reinit-Überholer)? */
  private _isCurrent(ctx: ActionCtx): boolean {
    return ctx.gen === this._initGen;
  }

  // ─── Settings Cache (from Observable) ─────────────────────────────────────
  private _settingsCache: { weeklyTargetHours: number; workdays: number[] } = {
    weeklyTargetHours: 40,
    workdays: [1, 2, 3, 4, 5],
  };

  private _currentSettings() {
    return this._settingsCache;
  }

  /** Tagessoll für das Eintragsdatum (nicht für „jetzt"): ein über Mitternacht laufender Eintrag behält sein Soll (#372). */
  private _targetDailyMs(settings: { weeklyTargetHours: number; workdays: number[] }, forDate: Date): number {
    if (settings.workdays.length === 0) return 0;
    const weeklyMs    = settings.weeklyTargetHours * 3600000;
    const regularMs   = roundMsToMinute(weeklyMs / settings.workdays.length);
    return getEffectiveDailyTarget(forDate, settings.workdays, regularMs);
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────
  private _totalBreakMs(breaks: Break[], until: Date): number {
    return breaks.reduce((sum, b) => {
      if (b.start > until) return sum;
      const end = b.end ?? until;
      return sum + Math.max(0, end.getTime() - b.start.getTime());
    }, 0);
  }

  private _parseTime(base: Date, timeStr: string): Date {
    const [h, m] = timeStr.split(':').map(Number);
    return new Date(base.getFullYear(), base.getMonth(), base.getDate(), h, m, 0, 0);
  }
}
