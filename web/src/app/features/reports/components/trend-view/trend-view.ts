import { ChangeDetectionStrategy, Component, DestroyRef, computed, inject } from '@angular/core';
import { MatButtonModule } from '@angular/material/button';
import { MatButtonToggleModule } from '@angular/material/button-toggle';
import { MatIconModule } from '@angular/material/icon';
import { MatProgressSpinnerModule } from '@angular/material/progress-spinner';
import { TranslatePipe, TranslateService } from '@ngx-translate/core';
import { LanguageService } from '../../../../core/services/language';
import { TrendBucket, TrendGranularity, TrendReport } from '../../../../domain/models/trend.models';
import { BarChartComponent } from '../../../../shared/components/charts/bar-chart';
import { LineChartComponent } from '../../../../shared/components/charts/line-chart';
import { ChartLabels, ChartPoint } from '../../../../shared/utils/chart-scale.util';
import { formatDurationHm, formatSignedDurationHm } from '../../../../shared/utils/duration-format.util';
import { TrendViewService } from './trend-view.service';

/** Wochennummer aus `yyyy-Www`. */
function weekNumberOf(key: string): number {
  return Number(key.split('-W')[1] ?? 0);
}

/** Erster Tag eines Monats-Schlüssels `yyyy-MM` als lokale Mitternacht (nur für die Beschriftung). */
function monthOf(key: string): Date {
  const [y, m] = key.split('-').map(Number);
  return new Date(y, m - 1, 1);
}

/**
 * Trend-Ansicht der Berichte (#531, Premium): Wochen-Trend als Text, Arbeitszeit je Zeitraum als Balken mit Soll,
 * aufsummierte Überstunden im Zeitraum als Linie. Alle Werte kommen fertig vom Backend; hier wird nur beschriftet
 * und gezeichnet. Das Premium-/Anmelde-Gate liegt in `reports.html`, diese Komponente entsteht nur im sichtbaren Tab.
 */
@Component({
  selector: 'app-trend-view',
  imports: [
    MatButtonModule, MatButtonToggleModule, MatIconModule, MatProgressSpinnerModule, TranslatePipe,
    BarChartComponent, LineChartComponent,
  ],
  templateUrl: './trend-view.html',
  styleUrl: './trend-view.scss',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class TrendViewComponent {
  protected readonly svc = inject(TrendViewService);
  private readonly translate = inject(TranslateService);
  private readonly language = inject(LanguageService);

  constructor() {
    const detach = this.svc.attach();
    inject(DestroyRef).onDestroy(detach);
  }

  private readonly locale = computed(() => this.language.locale());

  protected readonly isWeek = computed(() => this.svc.granularity() === 'week');

  protected onGranularity(value: TrendGranularity): void {
    this.svc.setGranularity(value);
  }

  // ── Beschriftung ─────────────────────────────────────────────────────────────

  private axisLabel(b: TrendBucket, g: TrendGranularity): string {
    return g === 'week'
      ? this.translate.instant('reports.calendarWeek', { number: weekNumberOf(b.key) })
      : new Intl.DateTimeFormat(this.locale(), { month: 'short' }).format(monthOf(b.key));
  }

  private fullLabel(b: TrendBucket, g: TrendGranularity): string {
    if (g === 'month') {
      return new Intl.DateTimeFormat(this.locale(), { month: 'long', year: 'numeric' }).format(monthOf(b.key));
    }
    const range = new Intl.DateTimeFormat(this.locale(), { day: 'numeric', month: 'short', year: 'numeric' })
      .formatRange(b.start, b.end);
    return `${this.axisLabel(b, g)} · ${range}`;
  }

  private points(report: TrendReport, pick: (b: TrendBucket) => Pick<ChartPoint, 'value' | 'reference' | 'secondary'>): ChartPoint[] {
    const g = report.granularity;
    const last = report.buckets.length - 1;
    return report.buckets.map((b, i) => ({
      key: b.key,
      axisLabel: this.axisLabel(b, g),
      label: this.fullLabel(b, g),
      hasData: b.hasData,
      partial: i === last,
      ...pick(b),
    }));
  }

  protected readonly workedPoints = computed(() => {
    const r = this.svc.report();
    return r ? this.points(r, b => ({ value: b.worked, reference: b.target })) : [];
  });

  protected readonly overtimePoints = computed(() => {
    const r = this.svc.report();
    return r ? this.points(r, b => ({ value: b.cumulativeOvertime, secondary: b.overtime })) : [];
  });

  protected readonly workedLabels = computed<ChartLabels>(() => {
    this.locale();
    const week = this.isWeek();
    return {
      title: this.translate.instant(week ? 'reports.trendWorkedTitleWeek' : 'reports.trendWorkedTitleMonth'),
      period: this.translate.instant('reports.trendPeriod'),
      value: this.translate.instant('reports.statActual'),
      reference: this.translate.instant('reports.statTarget'),
      noData: this.translate.instant('reports.trendNoData'),
      partial: this.translate.instant('reports.trendPartial'),
    };
  });

  protected readonly overtimeLabels = computed<ChartLabels>(() => {
    this.locale();
    const week = this.isWeek();
    return {
      title: this.translate.instant('reports.trendOvertimeTitle'),
      period: this.translate.instant('reports.trendPeriod'),
      value: this.translate.instant('reports.trendOvertimeSum'),
      secondary: this.translate.instant(week ? 'reports.trendOvertimePerWeek' : 'reports.trendOvertimePerMonth'),
      noData: this.translate.instant('reports.trendNoData'),
      partial: this.translate.instant('reports.trendPartial'),
    };
  });

  /** Beginn des Zeitfensters für den Hinweis „aufsummiert ab …“. */
  protected readonly windowStart = computed(() => {
    const first = this.svc.report()?.buckets[0];
    if (!first) return '';
    return this.isWeek()
      ? new Intl.DateTimeFormat(this.locale(), { day: 'numeric', month: 'short', year: 'numeric' }).format(first.start)
      : new Intl.DateTimeFormat(this.locale(), { month: 'long', year: 'numeric' }).format(monthOf(first.key));
  });

  protected readonly weeklyTrend = computed(() => this.svc.report()?.weeklyTrend ?? null);

  protected readonly lastWeekLabel = computed(() => {
    const t = this.weeklyTrend();
    return t ? this.translate.instant('reports.calendarWeek', { number: weekNumberOf(t.lastWeekKey) }) : '';
  });

  protected readonly trendIcon = computed(() => {
    const d = this.weeklyTrend()?.delta ?? 0;
    return d > 0 ? 'trending_up' : d < 0 ? 'trending_down' : 'trending_flat';
  });

  protected formatDuration(ms: number): string {
    return formatDurationHm(ms);
  }

  protected formatSigned(ms: number): string {
    return formatSignedDurationHm(ms);
  }
}
