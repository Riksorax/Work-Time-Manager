import { DestroyRef, Injectable, computed, inject, signal } from '@angular/core';
import { takeUntilDestroyed, toObservable } from '@angular/core/rxjs-interop';
import {
  Observable, Subject, catchError, combineLatest, distinctUntilChanged, map, of, startWith, switchMap,
} from 'rxjs';
import { AuthService } from '../../../../core/auth/auth';
import { ApiClient } from '../../../../core/services/api-client';
import { ProfileService } from '../../../../core/services/profile';
import { BROWSER_TIME_ZONE } from '../../../../core/services/time-zone';
import { TodayService } from '../../../../core/services/today';
import { WorkProfileService } from '../../../../core/services/work-profile';
import { InsightsReport } from '../../../../domain/models/insights.models';

export type InsightsState =
  | { status: 'idle' }
  | { status: 'loading' }
  | { status: 'data'; report: InsightsReport }
  | { status: 'error' };

/**
 * Lädt die Insights (#537) vom Backend (`GET /api/reports/insights/{y}/{m}/{d}?tz=`). Keine Rechnung und kein
 * Offline-Fallback: Lade-, Fehler- und Leerzustand. Geladen wird nur, solange die Ansicht angehängt ist (`attach()`, die
 * Komponente entsteht erst im sichtbaren Tab) und nur angemeldet mit Premium. Bezugstag ist `TodayService.today()`,
 * `tz` die Zone des Browsers; Profil- und Tageswechsel laden neu. Muster: `TrendViewService` (#531).
 */
@Injectable()
export class InsightsViewService {
  private readonly auth = inject(AuthService);
  private readonly api = inject(ApiClient);
  private readonly profile = inject(ProfileService);
  private readonly workProfile = inject(WorkProfileService);
  private readonly today = inject(TodayService);
  private readonly timeZone = inject(BROWSER_TIME_ZONE);
  private readonly destroyRef = inject(DestroyRef);

  private readonly _attached = signal(0);
  private readonly _retry = new Subject<void>();
  private readonly _state = signal<InsightsState>({ status: 'idle' });

  readonly state = this._state.asReadonly();
  readonly report = computed(() => {
    const s = this._state();
    return s.status === 'data' ? s.report : null;
  });
  /** Wie Mobile (`hasNoData`): weder Wochentage noch Startstunden mit Daten. */
  readonly isEmpty = computed(() => {
    const r = this.report();
    return !!r && r.weekdayAverages.length === 0 && r.startTimeHeatmap.length === 0;
  });

  constructor() {
    const uid$ = this.auth.user$.pipe(map(u => u?.uid ?? null), distinctUntilChanged());
    combineLatest([
      toObservable(computed(() => this._attached() > 0)),
      uid$,
      toObservable(this.profile.isPremium),
      this.workProfile.activeProfileId$.pipe(distinctUntilChanged()),
      toObservable(this.today.today),
    ]).pipe(
      switchMap(([attached, uid, premium, , todayKey]) =>
        attached && uid && premium
          ? this._retry.pipe(startWith(undefined), switchMap(() => this._load(todayKey)))
          : of<InsightsState>({ status: 'idle' })),
      takeUntilDestroyed(this.destroyRef),
    ).subscribe(state => this._state.set(state));
  }

  /** Die Ansicht ist sichtbar; liefert die Abmeldung (beim Zerstören der Ansicht aufrufen). */
  attach(): () => void {
    this._attached.update(n => n + 1);
    let done = false;
    return () => {
      if (done) return;
      done = true;
      this._attached.update(n => Math.max(0, n - 1));
    };
  }

  retry(): void {
    this._retry.next();
  }

  private _load(todayKey: string): Observable<InsightsState> {
    const [y, m, d] = todayKey.split('-').map(Number);
    return this.api.getInsightsReport(new Date(y, m - 1, d), this.timeZone(), this.workProfile.activeProfileIdForApi).pipe(
      map((report): InsightsState => ({ status: 'data', report })),
      catchError(() => of<InsightsState>({ status: 'error' })),
      startWith<InsightsState>({ status: 'loading' }),
    );
  }
}
