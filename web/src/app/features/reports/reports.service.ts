import { Injectable, computed, inject, signal } from '@angular/core';
import { toObservable, toSignal } from '@angular/core/rxjs-interop';
import { Router } from '@angular/router';
import { Observable, catchError, combineLatest, from, map, of, switchMap, tap } from 'rxjs';
import { AuthService } from '../../core/auth/auth';
import { ProfileService } from '../../core/services/profile';
import { SettingsService } from '../../core/services/settings';
import { WorkEntryService } from '../../core/services/work-entry';
import { ReportCalculatorService, isSameDayRc, toDateKey } from '../../domain/services/report-calculator.service';
import { DailyStat, MonthlyReport, WeeklyReport } from '../../domain/models/reports.models';
import { WorkEntry, WorkEntryType, UserSettings } from '../../shared/models/index';
import { OvertimeService } from '../../core/services/overtime';

// ─── Constants ─────────────────────────────────────────────────────────────────

const DEFAULT_SETTINGS: UserSettings = {
  weeklyTargetHours: 40,
  workdaysPerWeek: 5,
  notificationsEnabled: false,
  notificationTime: '08:00',
  notificationDays: [1, 2, 3, 4, 5],
  notifyWorkStart: false,
  notifyWorkEnd: false,
  notifyBreaks: false,
};

const EMPTY_DAILY_STAT: DailyStat = { target: 0, worked: 0, overtime: 0 };

const EMPTY_WEEKLY: WeeklyReport = {
  weekNumber: 0,
  start: new Date(0),
  end: new Date(0),
  totalWorked: 0,
  totalBreaks: 0,
  workDays: 0,
  avgPerDay: 0,
  overtime: 0,
  days: [],
};

const EMPTY_MONTHLY: MonthlyReport = {
  month: new Date(0),
  totalWorked: 0,
  totalBreaks: 0,
  workDays: 0,
  avgPerDay: 0,
  avgPerWeek: 0,
  monthlyOvertime: 0,
  totalOvertime: 0,
  weeks: [],
  days: [],
};

// ─── Service ───────────────────────────────────────────────────────────────────

@Injectable({ providedIn: 'root' })
export class ReportsService {
  private readonly workEntryService = inject(WorkEntryService);
  private readonly settingsService  = inject(SettingsService);
  private readonly profileService   = inject(ProfileService);
  private readonly authService      = inject(AuthService);
  private readonly overtimeService  = inject(OvertimeService);
  private readonly calc             = inject(ReportCalculatorService);
  private readonly router           = inject(Router);

  // ── Auth / Premium ────────────────────────────────────────────────────────────
  readonly isLoggedIn = computed(() => !!this.authService.user());
  readonly isPremium  = this.profileService.isPremium;

  // ── State Signals ─────────────────────────────────────────────────────────────
  private readonly _isLoading           = signal(true);
  private readonly _selectedDate        = signal<Date>(new Date());
  private readonly _isMultiSelectActive = signal(false);
  private readonly _selectedDates       = signal<Set<string>>(new Set());

  readonly isLoading           = this._isLoading.asReadonly();
  readonly selectedDate        = this._selectedDate.asReadonly();
  readonly isMultiSelectActive = this._isMultiSelectActive.asReadonly();
  readonly selectedDates       = this._selectedDates.asReadonly();

  // Monat-Navigation für Kalender (täglich-Tab)
  private readonly _viewMonth = signal({
    year:  new Date().getFullYear(),
    month: new Date().getMonth() + 1,
  });

  // Woche / Monat für Wöchentlich-/Monatlich-Tab
  private readonly _weekRef  = signal<Date>(new Date());
  private readonly _monthRef = signal<Date>(new Date(new Date().getFullYear(), new Date().getMonth(), 1));

  // ── Reactive Data ─────────────────────────────────────────────────────────────

  // Monatliche Einträge (täglich-Tab / Monatlich-Tab)
  private readonly _monthlyEntries = toSignal(
    toObservable(this._viewMonth).pipe(
      tap(() => this._isLoading.set(true)),
      switchMap(({ year, month }) =>
        this.workEntryService.getEntriesForMonth(year, month).pipe(
          catchError(() => of([] as WorkEntry[])),
        )
      ),
      tap(() => this._isLoading.set(false)),
    ),
    { initialValue: [] as WorkEntry[] }
  );

  // Wöchentliche Einträge — lade beide Monate falls Woche Monatsgrenze überschreitet
  private readonly _weeklyEntries = toSignal(
    toObservable(this._weekRef).pipe(
      switchMap(weekRef => this._loadWeekEntries(weekRef)),
    ),
    { initialValue: [] as WorkEntry[] }
  );

  // Settings
  private readonly _settings = toSignal(
    this.settingsService.getSettings(),
    { initialValue: DEFAULT_SETTINGS }
  );

  // Gespeichertes Überstundensaldo — neu laden wenn Auth-Status wechselt
  private readonly _storedOvertime = toSignal(
    this.authService.user$.pipe(
      switchMap(() => from(this.overtimeService.getOvertime())),
      catchError(() => of(0)),
    ),
    { initialValue: 0 }
  );

  // ── Computed ──────────────────────────────────────────────────────────────────

  readonly daysWithEntries = computed(() =>
    [...new Set(this._monthlyEntries().map(e => e.date.getDate()))]
  );

  readonly selectedDayEntries = computed(() => {
    const sel = this.selectedDate();
    return this._monthlyEntries().filter(e => isSameDayRc(e.date, sel));
  });

  readonly dailyStat = computed((): DailyStat => {
    if (this.isLoading()) return EMPTY_DAILY_STAT;
    return this.calc.calculateDailyStat(
      this._monthlyEntries(), this.selectedDate(), this._settings()
    );
  });

  readonly weeklyReport = computed((): WeeklyReport => {
    if (!this.isLoggedIn() || !this.isPremium()) return EMPTY_WEEKLY;
    return this.calc.calculateWeeklyReport(
      this._weeklyEntries(), this._weekRef(), this._settings()
    );
  });

  readonly monthlyReport = computed((): MonthlyReport => {
    if (!this.isLoggedIn() || !this.isPremium()) return EMPTY_MONTHLY;
    return this.calc.calculateMonthlyReport(
      this._monthlyEntries(), this._monthRef(), this._settings(), this._storedOvertime()
    );
  });

  // ── Actions ───────────────────────────────────────────────────────────────────

  selectDate(date: Date): void {
    const prev = this.selectedDate();
    this._selectedDate.set(date);
    // Monat gewechselt → Einträge neu laden
    if (date.getMonth() !== prev.getMonth() || date.getFullYear() !== prev.getFullYear()) {
      this._viewMonth.set({ year: date.getFullYear(), month: date.getMonth() + 1 });
    }
  }

  onMonthChanged(event: { year: number; month: number }): void {
    this._viewMonth.set(event);
  }

  navigateWeek(delta: number): void {
    const ref = this._weekRef();
    this._weekRef.set(new Date(ref.getTime() + delta * 7 * 86400000));
  }

  navigateMonth(delta: number): void {
    const ref = this._monthRef();
    const next = new Date(ref.getFullYear(), ref.getMonth() + delta, 1);
    this._monthRef.set(next);
    this._viewMonth.set({ year: next.getFullYear(), month: next.getMonth() + 1 });
  }

  async saveEntry(entry: WorkEntry): Promise<void> {
    await this.workEntryService.saveEntry(entry);
    this._reloadCurrentMonth();
  }

  async deleteEntry(id: string): Promise<void> {
    await this.workEntryService.deleteEntry(id);
    this._reloadCurrentMonth();
  }

  async saveBatchEntries(dates: Date[], type: WorkEntryType): Promise<void> {
    const entries: WorkEntry[] = dates.map(date => ({
      id: this._dateId(date),
      date,
      breaks: [],
      isManuallyEntered: true,
      type,
    }));
    await Promise.all(entries.map(e => this.workEntryService.saveEntry(e)));
    this.clearDateSelection();
    this._reloadCurrentMonth();
  }

  toggleMultiSelect(): void {
    this._isMultiSelectActive.update((v: boolean) => !v);
    if (!this.isMultiSelectActive()) {
      this._selectedDates.set(new Set());
    }
  }

  toggleDateSelection(date: Date): void {
    const key = toDateKey(date);
    this._selectedDates.update((prev: Set<string>) => {
      const next = new Set(prev);
      if (next.has(key)) next.delete(key);
      else next.add(key);
      return next;
    });
  }

  addDateRangeSelection(dates: Date[]): void {
    // Drag-Auswahl aktiviert Multi-Select automatisch
    if (!this.isMultiSelectActive()) this._isMultiSelectActive.set(true);
    this._selectedDates.update((prev: Set<string>) => {
      const next = new Set(prev);
      dates.forEach(d => next.add(toDateKey(d)));
      return next;
    });
  }

  clearDateSelection(): void {
    this._selectedDates.set(new Set());
  }

  navigateToLogin(): void {
    this.router.navigate(['/auth/login']);
  }

  entryNetDuration(entry: WorkEntry): number {
    if (!entry.workStart || !entry.workEnd) return 0;
    const gross  = entry.workEnd.getTime() - entry.workStart.getTime();
    const breaks = entry.breaks.reduce((sum, b) => {
      if (!b.end) return sum;
      return sum + (b.end.getTime() - b.start.getTime());
    }, 0);
    return Math.max(0, gross - breaks);
  }

  // ── Private ───────────────────────────────────────────────────────────────────

  private _reloadCurrentMonth(): void {
    const vm = this._viewMonth();
    // Trigger erneuten Load durch neues Objekt
    this._viewMonth.set({ ...vm });
  }

  private _loadWeekEntries(weekRef: Date): Observable<WorkEntry[]> {
    const dow   = weekRef.getDay() === 0 ? 7 : weekRef.getDay();
    const start = new Date(weekRef.getFullYear(), weekRef.getMonth(), weekRef.getDate() - (dow - 1));
    const end   = new Date(start.getTime() + 6 * 86400000);

    const year1 = start.getFullYear(), month1 = start.getMonth() + 1;
    const year2 = end.getFullYear(),   month2 = end.getMonth()   + 1;

    if (year1 === year2 && month1 === month2) {
      return this.workEntryService.getEntriesForMonth(year1, month1).pipe(
        catchError(() => of([] as WorkEntry[])),
      );
    }

    // Monatsübergreifende Woche: beide Monate laden + deduplizieren
    return combineLatest([
      this.workEntryService.getEntriesForMonth(year1, month1).pipe(catchError(() => of([]))),
      this.workEntryService.getEntriesForMonth(year2, month2).pipe(catchError(() => of([]))),
    ]).pipe(
      map(([a, b]: [WorkEntry[], WorkEntry[]]) => {
        const all = [...a, ...b];
        return all.filter(e => {
          const ed = new Date(e.date.getFullYear(), e.date.getMonth(), e.date.getDate());
          return ed >= start && ed <= end;
        });
      }),
    );
  }

  private _dateId(date: Date): string {
    return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`;
  }
}
