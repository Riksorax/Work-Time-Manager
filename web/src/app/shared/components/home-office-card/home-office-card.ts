import { ChangeDetectionStrategy, Component, computed, inject, input, signal } from '@angular/core';
import { takeUntilDestroyed, toObservable } from '@angular/core/rxjs-interop';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatProgressSpinnerModule } from '@angular/material/progress-spinner';
import { TranslatePipe } from '@ngx-translate/core';
import {
  Observable, Subject, catchError, combineLatest, distinctUntilChanged, map, of, startWith, switchMap,
} from 'rxjs';
import { AuthService } from '../../../core/auth/auth';
import { ApiClient } from '../../../core/services/api-client';
import { LanguageService } from '../../../core/services/language';
import { ProfileService } from '../../../core/services/profile';
import { WorkProfileService } from '../../../core/services/work-profile';
import { HomeOfficeReport } from '../../../domain/models/home-office.models';

export type HomeOfficeCardState =
  | { status: 'idle' }
  | { status: 'loading' }
  | { status: 'error' }
  | { status: 'data'; report: HomeOfficeReport };

/**
 * Home-Office-Jahresauswertung (#283/#483, seit #537 vom Backend): `GET /api/reports/home-office/{year}`. Die Zählregel
 * liegt nur im Backend; die Karte formatiert. Kein Offline-Fallback: Lade-, Fehler- (mit „Erneut versuchen“) und
 * Leerzustand. Geladen wird nur angemeldet und mit Premium (die Karte steht nur für Premium im Jahres-Tab); Jahres- und
 * Profilwechsel laden neu.
 */
@Component({
  selector: 'app-home-office-card',
  imports: [MatButtonModule, MatIconModule, MatProgressSpinnerModule, TranslatePipe],
  templateUrl: './home-office-card.html',
  styleUrl: './home-office-card.scss',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class HomeOfficeCardComponent {
  private readonly auth        = inject(AuthService);
  private readonly api         = inject(ApiClient);
  private readonly profile     = inject(ProfileService);
  private readonly workProfile = inject(WorkProfileService);
  private readonly language    = inject(LanguageService);

  readonly year = input.required<number>();

  private readonly _retry = new Subject<void>();
  protected readonly state = signal<HomeOfficeCardState>({ status: 'idle' });

  protected readonly report = computed(() => {
    const s = this.state();
    return s.status === 'data' ? s.report : null;
  });

  constructor() {
    const uid$ = this.auth.user$.pipe(map(u => u?.uid ?? null), distinctUntilChanged());
    combineLatest([
      toObservable(this.year),
      uid$,
      toObservable(this.profile.isPremium),
      this.workProfile.activeProfileId$.pipe(distinctUntilChanged()),
    ]).pipe(
      switchMap(([year, uid, premium]): Observable<HomeOfficeCardState> =>
        uid && premium
          ? this._retry.pipe(startWith(undefined), switchMap(() => this._load(year)))
          : of({ status: 'idle' })),
      takeUntilDestroyed(),
    ).subscribe(state => this.state.set(state));
  }

  /** Anteil mit einer Nachkommastelle in der Sprache der App ("33,3 %" / "33.3 %"). */
  protected formatRatio(ratio: number): string {
    return `${(ratio * 100).toLocaleString(this.language.locale(), { minimumFractionDigits: 1, maximumFractionDigits: 1 })} %`;
  }

  protected retry(): void {
    this._retry.next();
  }

  private _load(year: number): Observable<HomeOfficeCardState> {
    return this.api.getHomeOfficeReport(year, this.workProfile.activeProfileIdForApi).pipe(
      map((report): HomeOfficeCardState => ({ status: 'data', report })),
      catchError(() => of<HomeOfficeCardState>({ status: 'error' })),
      startWith<HomeOfficeCardState>({ status: 'loading' }),
    );
  }
}
