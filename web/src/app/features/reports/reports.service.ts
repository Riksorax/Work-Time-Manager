import { Injectable, computed, inject, signal } from '@angular/core';
import { toObservable, toSignal } from '@angular/core/rxjs-interop';
import { Router } from '@angular/router';
import { catchError, combineLatest, of, switchMap, tap } from 'rxjs';
import { AuthService } from '../../core/auth/auth';
import { ProfileService } from '../../core/services/profile';
import { SettingsService } from '../../core/services/settings';
import { WorkEntryService } from '../../core/services/work-entry';
import { ApiClient } from '../../core/services/api-client';
import { ReportCalculatorService, isSameDayRc, toDateKey } from '../../domain/services/report-calculator.service';
import { DailyStat, MonthlyReport, WeeklyReport } from '../../domain/models/reports.models';
import { WorkEntry, WorkEntryType, UserSettings } from '../../shared/models/index';

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
  private readonly apiClient        = inject(ApiClient);
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
      switchMap(({ year, month }) =>
        this.workEntryService.getEntriesForMonth(year, month).pipe(
          catchError(() => of([] as WorkEntry[])),
          // isLoading nur für den Erstladevorgang ausschalten — beim Monatswechsel
          // NICHT erneut auf true setzen, sonst wird die gesamte UI (inkl. Kalender,
          // der den Monatszustand hält) zerstört und springt auf den alten Monat zurück.
          tap(() => this._isLoading.set(false)),
        )
      ),
    ),
    { initialValue: [] as WorkEntry[] }
  );

  // Settings
  private readonly _settings = toSignal(
    this.settingsService.getSettings().pipe(
      catchError(() => of(DEFAULT_SETTINGS)),
    ),
    { initialValue: DEFAULT_SETTINGS }
  );

  // ── Reports aus der Backend-API (eingeloggt) ───────────────────────────────────
  // Berechnung erfolgt server-seitig (zentrale, korrigierte Logik). Roh-Einträge
  // (_monthlyEntries via onSnapshot) bleiben für Kalender/Tagesliste erhalten.

  private readonly _apiDaily = toSignal(
    combineLatest([toObservable(this._selectedDate), this.authService.user$]).pipe(
      switchMap(([date, user]) =>
        user
          ? this.apiClient.getDailyReport(date.getFullYear(), date.getMonth() + 1, date.getDate())
              .pipe(catchError(() => of(EMPTY_DAILY_STAT)))
          : of(null)
      ),
    ),
    { initialValue: null as DailyStat | null }
  );

  private readonly _apiWeekly = toSignal(
    combineLatest([toObservable(this._weekRef), this.authService.user$, toObservable(this.isPremium)]).pipe(
      switchMap(([date, user, premium]) =>
        user && premium
          ? this.apiClient.getWeeklyReport(date.getFullYear(), date.getMonth() + 1, date.getDate())
              .pipe(catchError(() => of(EMPTY_WEEKLY)))
          : of(EMPTY_WEEKLY)
      ),
    ),
    { initialValue: EMPTY_WEEKLY }
  );

  private readonly _apiMonthly = toSignal(
    combineLatest([toObservable(this._monthRef), this.authService.user$, toObservable(this.isPremium)]).pipe(
      switchMap(([date, user, premium]) =>
        user && premium
          ? this.apiClient.getMonthlyReport(date.getFullYear(), date.getMonth() + 1)
              .pipe(catchError(() => of(EMPTY_MONTHLY)))
          : of(EMPTY_MONTHLY)
      ),
    ),
    { initialValue: EMPTY_MONTHLY }
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
    // Eingeloggt: server-berechnet. Anonym: lokale Berechnung aus localStorage-Einträgen.
    if (this.isLoggedIn()) return this._apiDaily() ?? EMPTY_DAILY_STAT;
    if (this.isLoading()) return EMPTY_DAILY_STAT;
    return this.calc.calculateDailyStat(
      this._monthlyEntries(), this.selectedDate(), this._settings()
    );
  });

  readonly weeklyReport = computed((): WeeklyReport => {
    if (!this.isLoggedIn() || !this.isPremium()) return EMPTY_WEEKLY;
    return this._apiWeekly();
  });

  readonly monthlyReport = computed((): MonthlyReport => {
    if (!this.isLoggedIn() || !this.isPremium()) return EMPTY_MONTHLY;
    return this._apiMonthly();
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
    if (!this.isMultiSelectActive()) this._isMultiSelectActive.set(true);
    const workdays = this._settings().workdaysPerWeek;
    const filtered = dates.filter(d => this._isWorkday(d, workdays));
    this._selectedDates.update((prev: Set<string>) => {
      const next = new Set(prev);
      filtered.forEach(d => next.add(toDateKey(d)));
      return next;
    });
  }

  private _isWorkday(date: Date, workdaysPerWeek: number): boolean {
    const dow = date.getDay(); // 0=So, 1=Mo, ..., 6=Sa
    if (workdaysPerWeek >= 7) return true;
    if (workdaysPerWeek >= 6) return dow !== 0;          // Mo–Sa
    return dow >= 1 && dow <= 5;                         // Mo–Fr
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

  private _dateId(date: Date): string {
    return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`;
  }
}
