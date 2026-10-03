import { DestroyRef, Injectable, InjectionToken, WritableSignal, computed, inject, signal } from '@angular/core';
import { takeUntilDestroyed, toObservable } from '@angular/core/rxjs-interop';
import {
  EMPTY, Observable, Subject, catchError, combineLatest, defer, distinctUntilChanged, map, of, startWith, switchMap, take,
} from 'rxjs';
import { AuthService } from '../auth/auth';
import { ApiClient } from './api-client';
import { SettingsService } from './settings';
import { WorkEntryService } from './work-entry';
import { WorkProfileService } from './work-profile';
import { YearlyLeaveReport } from '../../domain/models/leave.models';
import { calculateYearlyLeave } from '../../domain/services/leave-calculator';
import { LeaveBalanceState } from '../../shared/components/leave-balance-card/leave-balance-card';

/** Zeit-Quelle (in Tests ersetzbar, damit kein Systemdatum nötig ist). */
export const LEAVE_NOW = new InjectionToken<() => Date>('LEAVE_NOW', {
  providedIn: 'root',
  factory: () => () => new Date(),
});

type LeaveState =
  | { status: 'loading' }
  | { status: 'data'; report: YearlyLeaveReport }
  | { status: 'error' };

const MIN_YEAR = 2000;

/**
 * Hybrid-Service für die Jahres-Urlaubsübersicht (#278): eingeloggt vom Backend
 * (`GET /api/reports/yearly/{year}`), anonym lokal berechnet.
 */
@Injectable({ providedIn: 'root' })
export class LeaveBalanceService {
  private readonly auth        = inject(AuthService);
  private readonly workProfile = inject(WorkProfileService);
  private readonly api         = inject(ApiClient);
  private readonly workEntries = inject(WorkEntryService);
  private readonly settings    = inject(SettingsService);
  private readonly destroyRef  = inject(DestroyRef);
  private readonly now         = inject(LEAVE_NOW);

  private readonly _currentYear  = signal(this.now().getFullYear());
  private readonly _selectedYear = signal(this._currentYear());
  private readonly _refreshTick  = new Subject<void>();
  private readonly _currentState = signal<LeaveState>({ status: 'loading' });
  private readonly _otherState   = signal<LeaveState>({ status: 'loading' });

  readonly year          = this._selectedYear.asReadonly();
  readonly isCurrentYear = computed(() => this._selectedYear() === this._currentYear());
  readonly canGoPrevYear = computed(() => this._selectedYear() > MIN_YEAR);
  readonly canGoNextYear = computed(() => this._selectedYear() < this._currentYear());

  readonly currentYearReport = computed(() => this._reportOf(this._currentState()));
  readonly currentYearState  = computed((): LeaveBalanceState => this._currentState().status);
  readonly report = computed(() => this.isCurrentYear() ? this.currentYearReport() : this._reportOf(this._otherState()));
  readonly state  = computed((): LeaveBalanceState =>
    this.isCurrentYear() ? this.currentYearState() : this._otherState().status);

  constructor() {
    this._connect(toObservable(this._currentYear), this._currentState);
    this._connect(
      toObservable(computed(() => this.isCurrentYear() ? null : this._selectedYear())),
      this._otherState,
    );
  }

  navigateYear(delta: number): void {
    const next = Math.min(Math.max(this._selectedYear() + delta, MIN_YEAR), this._currentYear());
    this._selectedYear.set(next);
  }

  /** Lädt neu (nach Änderungen an Einträgen/Anspruch, Login-Sync oder Fehlerwiederholung). */
  refresh(): void {
    const old = this._currentYear();
    const year = this.now().getFullYear();
    if (year !== old) {
      this._currentYear.set(year);
      if (this._selectedYear() === old) this._selectedYear.set(year);
    }
    this._refreshTick.next();
  }

  private _reportOf(state: LeaveState): YearlyLeaveReport | null {
    return state.status === 'data' ? state.report : null;
  }

  private _connect(year$: Observable<number | null>, target: WritableSignal<LeaveState>): void {
    const uid$ = this.auth.user$.pipe(map(u => u?.uid ?? null), distinctUntilChanged());
    combineLatest([uid$, this.workProfile.activeProfileId$, year$]).pipe(
      switchMap(([uid, , year]) => {
        if (year === null) return EMPTY;
        target.set({ status: 'loading' });
        return this._refreshTick.pipe(
          startWith(undefined),
          switchMap((_, index) => {
            if (index > 0 && target().status === 'error') target.set({ status: 'loading' });
            return this._fetch(uid, year);
          }),
        );
      }),
      takeUntilDestroyed(this.destroyRef),
    ).subscribe(state => target.set(state));
  }

  private _fetch(uid: string | null, year: number): Observable<LeaveState> {
    const report$: Observable<YearlyLeaveReport> = defer(() => uid
      ? this.api.getYearlyLeave(year, this.workProfile.activeProfileIdForApi)
      : this.settings.getSettings().pipe(
          take(1),
          map(s => calculateYearlyLeave(this.workEntries.getAllLocalEntries(), year, s.vacationDaysPerYear)),
        ));
    return report$.pipe(
      map((report): LeaveState => ({ status: 'data', report })),
      catchError(() => of<LeaveState>({ status: 'error' })),
    );
  }
}
