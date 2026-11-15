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
import { LEAVE_NOW } from '../../../core/services/leave-balance';
import { ProfileService } from '../../../core/services/profile';
import { WorkProfileService } from '../../../core/services/work-profile';
import { YearlyComparison, YearlySummary } from '../../../domain/models/yearly-comparison.models';
import { formatDurationHm, formatSignedDurationHm } from '../../utils/duration-format.util';

/** Kleinstes Jahr mit Vergleich: das Backend nimmt 2001–2100 an (das Vorjahr muss ab 2000 liegen). */
const MIN_COMPARISON_YEAR = 2001;

export type YearlyComparisonState =
  | { status: 'idle' }
  | { status: 'unsupported' }
  | { status: 'loading' }
  | { status: 'error' }
  | { status: 'data'; report: YearlyComparison };

/** Eine Zeile der Tabelle: Werte bereits formatiert. `diff`/`percent` fehlen, wenn das Vorjahr keine Daten hat. */
interface ComparisonRow {
  key: string;
  label: string;
  current: string;
  previous: string | null;
  diff: string | null;
  percent: string | null;
}

/**
 * Jahresvergleich mit dem Vorjahr (#530, Premium im Jahres-Tab). Alle Werte kommen fertig vom Backend
 * (`GET /api/reports/yearly-comparison/{year}`), auch Differenzen und Prozentwert; die Karte formatiert nur.
 * Kein Offline-Fallback: Lade-, Fehler- (mit „Erneut versuchen“) und Leerzustand.
 *
 * Geladen wird nur angemeldet und mit Premium. Für das laufende Jahr geht der heutige Tag als Stichtag `until=MM-dd`
 * mit; „heute“ kommt aus derselben Uhr wie die Urlaubsübersicht des Tabs (`LEAVE_NOW`). Jahres- und Profilwechsel
 * laden neu.
 */
@Component({
  selector: 'app-yearly-comparison-card',
  imports: [MatButtonModule, MatIconModule, MatProgressSpinnerModule, TranslatePipe],
  templateUrl: './yearly-comparison-card.html',
  styleUrl: './yearly-comparison-card.scss',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class YearlyComparisonCardComponent {
  private readonly auth        = inject(AuthService);
  private readonly api         = inject(ApiClient);
  private readonly profile     = inject(ProfileService);
  private readonly workProfile = inject(WorkProfileService);
  private readonly language    = inject(LanguageService);
  private readonly now         = inject(LEAVE_NOW);

  readonly year = input.required<number>();

  private readonly _retry = new Subject<void>();
  protected readonly state = signal<YearlyComparisonState>({ status: 'idle' });

  protected readonly report = computed(() => {
    const s = this.state();
    return s.status === 'data' ? s.report : null;
  });

  /** Stichtag der Antwort als „15.11.“ bzw. „11/15“ (Sprache der App), sonst `null`. */
  protected readonly untilLabel = computed(() => {
    const until = this.report()?.until;
    const match = until ? /^(\d{2})-(\d{2})$/.exec(until) : null;
    if (!match) return null;
    // 2000 ist ein Schaltjahr: 02-29 bleibt ein gültiger Tag.
    const date = new Date(2000, Number(match[1]) - 1, Number(match[2]));
    return new Intl.DateTimeFormat(this.language.locale(), { day: '2-digit', month: '2-digit' }).format(date);
  });

  protected readonly rows = computed((): ComparisonRow[] => {
    const r = this.report();
    if (!r) return [];
    const prev = r.previous.hasData ? r.previous : null;
    const d = prev ? r.delta : null;
    const days = (pick: (s: YearlySummary) => number, deltaValue: number | undefined) => ({
      current: this.formatCount(pick(r.current)),
      previous: prev ? this.formatCount(pick(prev)) : null,
      diff: d && deltaValue !== undefined ? this.formatSignedCount(deltaValue) : null,
      percent: null,
    });
    return [
      {
        key: 'worked', label: 'reports.yearCompareWorked',
        current: formatDurationHm(r.current.totalWorkedMs),
        previous: prev ? formatDurationHm(prev.totalWorkedMs) : null,
        diff: d ? this.formatSignedDuration(d.workedMs) : null,
        percent: d && d.workedPercent !== null && d.workedPercent !== undefined ? this.formatPercent(d.workedPercent) : null,
      },
      {
        key: 'overtime', label: 'reports.yearCompareOvertime',
        current: formatSignedDurationHm(r.current.overtimeMs),
        previous: prev ? formatSignedDurationHm(prev.overtimeMs) : null,
        diff: d ? this.formatSignedDuration(d.overtimeMs) : null,
        percent: null,
      },
      { key: 'workDays', label: 'reports.yearCompareWorkDays', ...days(s => s.workDays, d?.workDays) },
      { key: 'vacationDays', label: 'reports.yearCompareVacationDays', ...days(s => s.vacationDays, d?.vacationDays) },
      { key: 'sickDays', label: 'reports.yearCompareSickDays', ...days(s => s.sickDays, d?.sickDays) },
      { key: 'holidayDays', label: 'reports.yearCompareHolidayDays', ...days(s => s.holidayDays, d?.holidayDays) },
    ];
  });

  constructor() {
    const uid$ = this.auth.user$.pipe(map(u => u?.uid ?? null), distinctUntilChanged());
    combineLatest([
      toObservable(this.year),
      uid$,
      toObservable(this.profile.isPremium),
      this.workProfile.activeProfileId$.pipe(distinctUntilChanged()),
    ]).pipe(
      switchMap(([year, uid, premium]): Observable<YearlyComparisonState> => {
        if (!uid || !premium) return of({ status: 'idle' });
        if (year < MIN_COMPARISON_YEAR) return of({ status: 'unsupported' });
        return this._retry.pipe(startWith(undefined), switchMap(() => this._load(year)));
      }),
      takeUntilDestroyed(),
    ).subscribe(state => this.state.set(state));
  }

  protected retry(): void {
    this._retry.next();
  }

  private _load(year: number): Observable<YearlyComparisonState> {
    const today = this.now();
    // Stichtag nur für das laufende Jahr (lokaler Kalendertag), abgeschlossene Jahre ohne.
    const until = year === today.getFullYear()
      ? `${String(today.getMonth() + 1).padStart(2, '0')}-${String(today.getDate()).padStart(2, '0')}`
      : undefined;
    return this.api.getYearlyComparison(year, until, this.workProfile.activeProfileIdForApi).pipe(
      map((report): YearlyComparisonState => ({ status: 'data', report })),
      catchError(() => of<YearlyComparisonState>({ status: 'error' })),
      startWith<YearlyComparisonState>({ status: 'loading' }),
    );
  }

  // ── Formatierung (reine Darstellung) ────────────────────────────────────────

  private formatCount(n: number): string {
    return n.toLocaleString(this.language.locale());
  }

  /** Ganze Zahl mit Vorzeichen („+3“, „-2“), 0 ohne Vorzeichen. */
  private formatSignedCount(n: number): string {
    return new Intl.NumberFormat(this.language.locale(), { signDisplay: 'exceptZero' }).format(n);
  }

  /** Dauer mit Vorzeichen wie in den Berichten („+12:30“), 0 ohne Vorzeichen. */
  private formatSignedDuration(ms: number): string {
    return ms === 0 ? formatDurationHm(0) : formatSignedDurationHm(ms);
  }

  /** Prozent mit einer Nachkommastelle in der Sprache der App („+12,4 %“ / „+12.4 %“). */
  private formatPercent(value: number): string {
    const n = new Intl.NumberFormat(this.language.locale(), {
      minimumFractionDigits: 1, maximumFractionDigits: 1, signDisplay: 'exceptZero',
    }).format(value);
    return `${n} %`;
  }
}
