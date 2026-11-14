import { DestroyRef, Injectable, computed, inject, signal } from '@angular/core';
import { takeUntilDestroyed, toObservable } from '@angular/core/rxjs-interop';
import {
  Observable, Subject, catchError, combineLatest, distinctUntilChanged, map, of, startWith, switchMap,
} from 'rxjs';
import { AuthService } from '../../../../core/auth/auth';
import { ApiClient } from '../../../../core/services/api-client';
import { ProfileService } from '../../../../core/services/profile';
import { TodayService } from '../../../../core/services/today';
import { WorkProfileService } from '../../../../core/services/work-profile';
import { TrendGranularity, TrendReport } from '../../../../domain/models/trend.models';

export type TrendState =
  | { status: 'idle' }
  | { status: 'loading' }
  | { status: 'data'; report: TrendReport }
  | { status: 'error' };

/**
 * Lädt den Trend (#531) vom Backend (`GET /api/reports/trend/...`). Keine Rechnung und kein Offline-Fallback im
 * Client: Lade-, Fehler- und Leerzustand. Geladen wird nur, solange die Ansicht angehängt ist (`attach()` aus der
 * Trend-Komponente, die erst im sichtbaren Tab entsteht) und nur für angemeldete Premium-Nutzer. Bezugstag ist
 * `TodayService.today()` (lokaler Kalendertag, folgt dem Tageswechsel); Profil- und Tageswechsel laden neu.
 *
 * Bereitgestellt von `ReportsComponent` (nicht root): die Wahl Wochen/Monate bleibt beim Tab-Wechsel erhalten,
 * endet aber mit der Berichtsseite.
 */
@Injectable()
export class TrendViewService {
  private readonly auth = inject(AuthService);
  private readonly api = inject(ApiClient);
  private readonly profile = inject(ProfileService);
  private readonly workProfile = inject(WorkProfileService);
  private readonly today = inject(TodayService);
  private readonly destroyRef = inject(DestroyRef);

  private readonly _granularity = signal<TrendGranularity>('week');
  private readonly _attached = signal(0);
  private readonly _retry = new Subject<void>();
  private readonly _state = signal<TrendState>({ status: 'idle' });

  readonly granularity = this._granularity.asReadonly();
  readonly state = this._state.asReadonly();
  readonly report = computed(() => {
    const s = this._state();
    return s.status === 'data' ? s.report : null;
  });
  /** Daten geladen, aber in keinem der 12 Zeiträume ein Eintrag. */
  readonly isEmpty = computed(() => {
    const r = this.report();
    return !!r && r.buckets.every(b => !b.hasData);
  });

  constructor() {
    const uid$ = this.auth.user$.pipe(map(u => u?.uid ?? null), distinctUntilChanged());
    combineLatest([
      toObservable(computed(() => this._attached() > 0)),
      uid$,
      toObservable(this.profile.isPremium),
      this.workProfile.activeProfileId$.pipe(distinctUntilChanged()),
      toObservable(this.today.today),
      toObservable(this._granularity),
    ]).pipe(
      switchMap(([attached, uid, premium, , todayKey, granularity]) =>
        attached && uid && premium
          ? this._retry.pipe(startWith(undefined), switchMap(() => this._load(todayKey, granularity)))
          : of<TrendState>({ status: 'idle' })),
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

  setGranularity(granularity: TrendGranularity): void {
    this._granularity.set(granularity);
  }

  retry(): void {
    this._retry.next();
  }

  private _load(todayKey: string, granularity: TrendGranularity): Observable<TrendState> {
    const [y, m, d] = todayKey.split('-').map(Number);
    return this.api.getTrendReport(new Date(y, m - 1, d), granularity, this.workProfile.activeProfileIdForApi).pipe(
      map((report): TrendState => ({ status: 'data', report })),
      catchError(() => of<TrendState>({ status: 'error' })),
      startWith<TrendState>({ status: 'loading' }),
    );
  }
}
