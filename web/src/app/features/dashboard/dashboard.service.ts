import { Injectable, inject, signal, computed, effect, DestroyRef } from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { firstValueFrom, interval } from 'rxjs';
import { WorkEntryService } from '../../core/services/work-entry';
import { OvertimeService }  from '../../core/services/overtime';
import { SettingsService }  from '../../core/services/settings';
import { AuthService }      from '../../core/auth/auth';
import { WorkEntry, WorkEntryType, Break } from '../../shared/models';
import { calculateAndApplyBreaks } from '../../domain/services/break-calculator.service';
import {
  getEffectiveDailyTarget,
  getWeekEntriesForDate,
  calculateInitialOvertime,
  isSameDay,
} from '../../domain/utils/overtime.utils';

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
  private readonly destroyRef    = inject(DestroyRef);

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
  private _timerSub: ReturnType<typeof interval> | null = null;
  private _timerUnsub: (() => void) | null = null;
  private _autoSaveTick = 0;
  private _weekEntries: WorkEntry[] = [];

  constructor() {
    // Re-init on auth state change (Flow 11)
    effect(() => {
      const user = this.authSvc.user();
      void this._init(user?.uid ?? null);
    });

    // Einstellungen reaktiv halten — Überstunden bei Änderung neu berechnen
    this.settingsSvc.getSettings()
      .pipe(takeUntilDestroyed(this.destroyRef))
      .subscribe(s => {
        this._settingsCache = { weeklyTargetHours: s.weeklyTargetHours, workdaysPerWeek: s.workdaysPerWeek };
        if (this._s().status === 'ready') {
          this._recalculateOvertime();
        }
      });

    // Page Visibility API — re-sync elapsed on tab focus (Flow 4)
    document.addEventListener('visibilitychange', () => {
      if (document.visibilityState === 'visible' && this.isTimerRunning()) {
        this._recalculateOvertime();
      }
    });
  }

  // ─── Flow 1: Initialisierung ────────────────────────────────────────────────
  private async _init(uid: string | null): Promise<void> {
    this._stopTimer();
    this._s.set(initialState());

    try {
      const today = new Date();

      // 1. Heutigen Eintrag laden
      const workEntry = (await firstValueFrom(this.workSvc.getTodayEntry())) ?? this.workSvc.emptyEntry(today);

      // 2. Überstunden + Datum laden
      const storedOvertimeMs = await this.overtimeSvc.getOvertime();
      const lastUpdateDate   = await this.overtimeSvc.getLastUpdateDate();

      // 3. Wocheneinträge laden (inkl. Vormonat falls nötig)
      await this._loadWeekEntries(today);

      // 4. Einstellungen laden + Cache sofort befüllen (firstValueFrom = take(1), keine dauerhafte Subscription)
      const settings = await firstValueFrom(this.settingsSvc.getSettings());
      this._settingsCache = { weeklyTargetHours: settings.weeklyTargetHours, workdaysPerWeek: settings.workdaysPerWeek };

      // 5. Effektives Tagessoll berechnen
      const weeklyMs          = settings.weeklyTargetHours * 60 * 60 * 1000;
      const regularDailyMs    = settings.workdaysPerWeek > 0 ? Math.round(weeklyMs / settings.workdaysPerWeek) : 0;
      const targetDailyMs     = getEffectiveDailyTarget(today, this._weekEntries, settings.workdaysPerWeek, regularDailyMs);
      const isExtraDay        = targetDailyMs === 0;

      // 6. Initiales Daily Overtime berechnen
      let initialDailyMs = 0;
      if (workEntry.workStart && workEntry.workEnd) {
        const breakMs    = this._totalBreakMs(workEntry.breaks, workEntry.workEnd);
        const netMs      = workEntry.workEnd.getTime() - workEntry.workStart.getTime() - breakMs;
        initialDailyMs   = netMs - targetDailyMs;
      } else if (workEntry.workStart) {
        const now        = new Date();
        const breakMs    = this._totalBreakMs(workEntry.breaks, now);
        const netMs      = now.getTime() - workEntry.workStart.getTime() - breakMs;
        initialDailyMs   = netMs - targetDailyMs;
      }

      // 7. Base-Overtime berechnen
      const initialOvertimeMs = calculateInitialOvertime(storedOvertimeMs, lastUpdateDate, initialDailyMs);
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
      // Initialisierung fehlgeschlagen — UI zeigt leeren Zustand
    }
  }

  private async _loadWeekEntries(today: Date): Promise<void> {
    const monthEntries = await firstValueFrom(
      this.workSvc.getEntriesForMonth(today.getFullYear(), today.getMonth() + 1)
    );

    this._weekEntries = getWeekEntriesForDate(today, monthEntries);

    const startOfWeek = new Date(today);
    startOfWeek.setDate(today.getDate() - ((today.getDay() || 7) - 1));
    if (startOfWeek.getMonth() !== today.getMonth()) {
      const prevEntries = await firstValueFrom(
        this.workSvc.getEntriesForMonth(startOfWeek.getFullYear(), startOfWeek.getMonth() + 1)
      );
      this._weekEntries = [...getWeekEntriesForDate(today, prevEntries), ...this._weekEntries];
    }
  }

  // ─── Flow 2+3: Timer starten / stoppen ─────────────────────────────────────
  async startOrStopTimer(): Promise<'restart-dialog' | void> {
    const e = this._s().workEntry;
    if (!e.workStart) {
      // START
      const updated = { ...e, workStart: new Date(), workEnd: undefined };
      await this._recalculateState(updated, true);
      this._startTimerIfNeeded();
    } else if (!e.workEnd) {
      // STOP
      this._stopTimer();
      let updated: WorkEntry = { ...e, workEnd: new Date() };
      const hasRunningBreak = updated.breaks.some(b => !b.end);
      if (!hasRunningBreak && updated.type === WorkEntryType.Work) {
        updated = calculateAndApplyBreaks(updated);
      }
      await this._recalculateState(updated, true);
      await this._saveOvertime();
    } else {
      // Bereits gestoppt → Restart-Dialog nötig (Flow 5)
      return 'restart-dialog';
    }
  }

  // ─── Flow 5: Restart Session ────────────────────────────────────────────────
  async startNewSession(keepBreaks: boolean): Promise<void> {
    const e = this._s().workEntry;
    const updated: WorkEntry = {
      ...e,
      workStart:         new Date(),
      workEnd:           undefined,
      breaks:            keepBreaks ? e.breaks : [],
      isManuallyEntered: false,
    };
    await this._recalculateState(updated, true);
    this._startTimerIfNeeded();
  }

  // ─── Flow 6: Pause starten/stoppen ──────────────────────────────────────────
  async startOrStopBreak(): Promise<void> {
    const e = this._s().workEntry;
    const runningBreak = e.breaks.find(b => !b.end);
    let updatedBreaks: Break[];

    if (runningBreak) {
      updatedBreaks = e.breaks.map(b => b.id === runningBreak.id ? { ...b, end: new Date() } : b);
    } else {
      const newBreak: Break = {
        id:          crypto.randomUUID(),
        name:        `Pause ${e.breaks.length + 1}`,
        start:       new Date(),
        end:         undefined,
        isAutomatic: false,
      };
      updatedBreaks = [...e.breaks, newBreak];
    }
    await this._recalculateState({ ...e, breaks: updatedBreaks }, true);
  }

  // ─── Flow 7: Manuelle Startzeit ──────────────────────────────────────────────
  async setManualStartTime(timeStr: string): Promise<void> {
    const e = this._s().workEntry;
    let updated: WorkEntry = { ...e, workStart: this._parseTime(e.date, timeStr) };
    const hasRunning = updated.breaks.some(b => !b.end);
    if (updated.workStart && updated.workEnd && !hasRunning && updated.type === WorkEntryType.Work) {
      updated = calculateAndApplyBreaks(updated);
    }
    await this._recalculateState(updated, true);
    this._startTimerIfNeeded();
  }

  // ─── Flow 8: Manuelle Endzeit ─────────────────────────────────────────────
  async setManualEndTime(timeStr: string): Promise<void> {
    const e = this._s().workEntry;
    let updated: WorkEntry = { ...e, workEnd: this._parseTime(e.date, timeStr) };
    const hasRunning = updated.breaks.some(b => !b.end);
    if (updated.workStart && updated.workEnd && !hasRunning && updated.type === WorkEntryType.Work) {
      updated = calculateAndApplyBreaks(updated);
    }
    await this._recalculateState(updated, true);
  }

  async clearEndTime(): Promise<void> {
    const e = this._s().workEntry;
    const updated = { ...e, workEnd: undefined };
    await this._recalculateState(updated, true);
    this._startTimerIfNeeded();
  }

  // ─── Flow 9: Pause bearbeiten ─────────────────────────────────────────────
  async updateBreak(updated: Break): Promise<void> {
    const e = this._s().workEntry;
    const breaks = e.breaks.map(b => b.id === updated.id ? updated : b);
    await this._recalculateState({ ...e, breaks }, true);
  }

  // ─── Flow 10: Pause löschen ───────────────────────────────────────────────
  async deleteBreak(id: string): Promise<void> {
    const e = this._s().workEntry;
    const breaks = e.breaks.filter(b => b.id !== id);
    await this._recalculateState({ ...e, breaks }, true);
  }

  // ─── Flow 12: Überstunden manuell anpassen ────────────────────────────────
  async updateInitialOvertime(newTotalMs: number): Promise<void> {
    const daily = this._s().dailyOvertimeMs ?? 0;
    const newInitial = newTotalMs - daily;
    this._s.update(s => ({
      ...s,
      initialOvertimeMs: newInitial,
      totalOvertimeMs:   newTotalMs,
    }));
    await this.overtimeSvc.saveOvertime(newTotalMs);
    await this.overtimeSvc.saveLastUpdateDate(new Date());
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
    const now    = new Date();
    const breakMs = this._totalBreakMs(e.breaks, now);
    const elapsed = now.getTime() - e.workStart.getTime() - breakMs;
    const gross   = now.getTime() - e.workStart.getTime();
    this._s.update(s => ({ ...s, elapsedMs: elapsed, grossMs: gross }));
    this._recalculateOvertime();
  }

  private async _autoSave(): Promise<void> {
    if (!this._s().workEntry.workStart) return;
    try { await this.workSvc.saveEntry(this._s().workEntry); } catch { /* silent */ }
  }

  // ─── Overtime Calculation ─────────────────────────────────────────────────
  private _recalculateOvertime(): void {
    const e = this._s().workEntry;
    if (!e.workStart) return;

    const settings = this._currentSettings();
    const targetMs = this._targetDailyMs(settings);
    const now      = new Date();
    const breakMs  = this._totalBreakMs(e.breaks, now);
    const elapsed  = now.getTime() - e.workStart.getTime() - breakMs;
    const daily    = elapsed - targetMs;
    const base     = this._s().initialOvertimeMs ?? 0;
    const total    = base + daily;

    const expectedEnd         = this._calcExpectedEnd(e.workStart, targetMs, this._totalBreakMs(e.breaks, now));
    const remainingForZero    = Math.max(0, targetMs - base);
    const expectedEndTotalZero = this._calcExpectedEnd(e.workStart, remainingForZero, this._totalBreakMs(e.breaks, now));

    this._s.update(s => ({
      ...s,
      dailyOvertimeMs:      daily,
      totalOvertimeMs:      total,
      expectedEndTime:      expectedEnd,
      expectedEndTotalZero,
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
  private async _recalculateState(entry: WorkEntry, save: boolean): Promise<void> {
    let actualWorkMs: number | null = null;
    let dailyMs: number | null = null;
    let totalMs = this._s().totalOvertimeMs;
    let grossMs: number | null = null;

    if (entry.workStart && entry.workEnd) {
      grossMs      = entry.workEnd.getTime() - entry.workStart.getTime();
      const breaks = this._totalBreakMs(entry.breaks, entry.workEnd);
      actualWorkMs = grossMs - breaks;
      const settings  = this._currentSettings();
      const targetMs  = this._targetDailyMs(settings);
      dailyMs    = actualWorkMs - targetMs;
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
    }));

    if (save) {
      await this.workSvc.saveEntry(entry);
      if (entry.workEnd && actualWorkMs !== null && totalMs !== null) {
        await this._saveOvertime();
      }
    }
  }

  private async _saveOvertime(): Promise<void> {
    const ms = this._s().totalOvertimeMs;
    if (ms === null) return;
    await this.overtimeSvc.saveOvertime(ms);
    await this.overtimeSvc.saveLastUpdateDate(new Date());
  }

  // ─── Settings Cache (from Observable) ─────────────────────────────────────
  private _settingsCache: { weeklyTargetHours: number; workdaysPerWeek: number } = {
    weeklyTargetHours: 40,
    workdaysPerWeek: 5,
  };

  private _currentSettings() {
    return this._settingsCache;
  }

  private _targetDailyMs(settings: { weeklyTargetHours: number; workdaysPerWeek: number }): number {
    if (settings.workdaysPerWeek <= 0) return 0;
    const weeklyMs    = settings.weeklyTargetHours * 3600000;
    const regularMs   = Math.round(weeklyMs / settings.workdaysPerWeek);
    return getEffectiveDailyTarget(new Date(), this._weekEntries, settings.workdaysPerWeek, regularMs);
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
