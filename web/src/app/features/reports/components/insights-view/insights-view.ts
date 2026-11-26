import { ChangeDetectionStrategy, Component, DestroyRef, computed, inject } from '@angular/core';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatProgressSpinnerModule } from '@angular/material/progress-spinner';
import { TranslatePipe, TranslateService } from '@ngx-translate/core';
import { LanguageService } from '../../../../core/services/language';
import { formatDurationHm, formatSignedDurationHm } from '../../../../shared/utils/duration-format.util';
import { InsightsViewService } from './insights-view.service';

/** Kalendertag `yyyy-MM-dd` als lokale Mitternacht (nur für die Beschriftung, nie über eine Zeitzone gelesen). */
function localDay(key: string): Date | null {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(key);
  return match ? new Date(Number(match[1]), Number(match[2]) - 1, Number(match[3])) : null;
}

/** Vorzeichen: positiv, negativ oder genau 0 (dann ohne Wertungsfarbe und ohne Vorzeichen). */
type Sign = 'pos' | 'neg' | 'zero';
const signOf = (ms: number): Sign => (ms > 0 ? 'pos' : ms < 0 ? 'neg' : 'zero');

interface WeekdayRow {
  weekday: number;
  label: string;
  average: string;
  /** Balkenlänge in Prozent der längsten Durchschnittszeit. */
  barPercent: number;
  deviation: string;
  sign: Sign;
  days: string;
}

interface HeatCell {
  hour: number;
  label: string;
  value: string;
  sign: Sign;
  /** Stärke 0..100 relativ zum größten Betrag (kleiner Balken in der Zelle, zusätzlich zur Zahl). */
  strength: number;
  days: string;
}

/**
 * Insights der Berichte (#537, Premium): Wochentags-Analyse, Überstunden-Serie und Startzeit-Heatmap, Port der
 * Mobile-Insights (`reports_page.dart`, `InsightsView`). Alle Werte kommen fertig vom Backend; hier wird nur formatiert.
 * Alle Werte stehen als Text da, Balken und Farben sind Zusatz (`aria-hidden`). Gate in `reports.html`.
 */
@Component({
  selector: 'app-insights-view',
  imports: [MatButtonModule, MatIconModule, MatProgressSpinnerModule, TranslatePipe],
  templateUrl: './insights-view.html',
  styleUrl: './insights-view.scss',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class InsightsViewComponent {
  protected readonly svc = inject(InsightsViewService);
  private readonly translate = inject(TranslateService);
  private readonly language = inject(LanguageService);

  constructor() {
    const detach = this.svc.attach();
    inject(DestroyRef).onDestroy(detach);
  }

  private readonly locale = computed(() => this.language.locale());

  /** Zeitraum „1. Sept. – 30. Nov. 2026“ in der App-Sprache. */
  protected readonly periodLabel = computed(() => {
    const r = this.svc.report();
    const from = r ? localDay(r.from) : null;
    const to = r ? localDay(r.to) : null;
    if (!from || !to) return '';
    return new Intl.DateTimeFormat(this.locale(), { day: 'numeric', month: 'short', year: 'numeric' }).formatRange(from, to);
  });

  protected readonly weekdays = computed((): WeekdayRow[] => {
    const r = this.svc.report();
    if (!r) return [];
    this.locale();
    const max = Math.max(...r.weekdayAverages.map(w => w.averageWorkedMs), 1);
    const fmt = new Intl.DateTimeFormat(this.locale(), { weekday: 'long' });
    return r.weekdayAverages.map(w => ({
      weekday: w.weekday,
      // 1. Januar 2024 war ein Montag: Tag `weekday` des Monats ist der passende Wochentag.
      label: fmt.format(new Date(2024, 0, w.weekday)),
      average: formatDurationHm(w.averageWorkedMs),
      barPercent: Math.max(0, Math.min(100, (w.averageWorkedMs / max) * 100)),
      deviation: this.formatSigned(w.deviationMs),
      sign: signOf(w.deviationMs),
      days: this.days(w.sampleCount),
    }));
  });

  protected readonly streak = computed(() => {
    const r = this.svc.report();
    if (!r) return null;
    this.locale();
    const s = r.overtimeStreak;
    return {
      current: this.workdays(s.currentStreak),
      longest: this.workdays(s.longestStreak),
      isWarning: s.isWarning,
      warning: this.translate.instant('insights.streakWarning', { days: s.currentStreak }),
      threshold: this.translate.instant('insights.streakThreshold', { count: s.warningThresholdDays }),
    };
  });

  protected readonly heatmap = computed((): HeatCell[] => {
    const r = this.svc.report();
    if (!r) return [];
    this.locale();
    const max = Math.max(...r.startTimeHeatmap.map(b => Math.abs(b.averageOvertimeMs)), 1);
    return r.startTimeHeatmap.map(b => ({
      hour: b.startHour,
      label: this.translate.instant('insights.heatmapHour', { hour: String(b.startHour).padStart(2, '0') }),
      value: this.formatSigned(b.averageOvertimeMs),
      sign: signOf(b.averageOvertimeMs),
      strength: Math.round((Math.abs(b.averageOvertimeMs) / max) * 100),
      days: this.days(b.sampleCount),
    }));
  });

  protected readonly dailyTarget = computed(() => formatDurationHm(this.svc.report()?.dailyTargetMs ?? 0));

  /** Dauer mit Vorzeichen wie in den Berichten („+00:30“), 0 ohne Vorzeichen. */
  private formatSigned(ms: number): string {
    return ms === 0 ? formatDurationHm(0) : formatSignedDurationHm(ms);
  }

  private days(n: number): string {
    return this.translate.instant(n === 1 ? 'insights.daysOne' : 'insights.daysMany', { count: n });
  }

  private workdays(n: number): string {
    return this.translate.instant(n === 1 ? 'insights.workdaysOne' : 'insights.workdaysMany', { count: n });
  }
}
