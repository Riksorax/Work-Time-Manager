import { ChangeDetectionStrategy, Component, computed } from '@angular/core';
import { ChartBase } from './chart-base';
import { ChartPoint } from '../../utils/chart-scale.util';
import { formatDurationHm, formatSignedDurationHm } from '../../utils/duration-format.util';

/**
 * Balkendiagramm als eigene SVG-Komponente (#531), keine Chart-Bibliothek. Ein Balken je Zeitraum (`value`),
 * der Vergleichswert (`reference`, z. B. Soll) als waagrechte Marke. Zeiträume ohne Einträge sind eine Lücke
 * (gestrichelte Grundlinie statt 0-Balken), der laufende Zeitraum ist heller und gestrichelt umrandet.
 * Textalternative: visuell versteckte Tabelle mit denselben Werten.
 */
@Component({
  selector: 'app-bar-chart',
  templateUrl: './bar-chart.html',
  styleUrl: './chart.scss',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class BarChartComponent extends ChartBase {
  protected readonly signedAxis = false;
  protected readonly valueWithoutData = false;

  protected scaleValues(points: readonly ChartPoint[]): number[] {
    return points.flatMap(p => (p.hasData ? [p.value, p.reference ?? 0] : []));
  }

  protected formatValue(ms: number): string { return formatDurationHm(ms); }
  protected formatReference(ms: number): string { return formatDurationHm(ms); }
  protected formatSecondary(ms: number): string { return formatSignedDurationHm(ms); }

  protected readonly barWidth = computed(() => {
    const slot = this.slots()[0]?.width ?? 0;
    return Math.max(4, Math.min(slot * 0.6, 40));
  });

  protected readonly hasReference = computed(() =>
    !!this.labels().reference && this.points().some(p => p.hasData && (p.reference ?? 0) > 0));

  protected barY(value: number): number {
    return Math.min(this.y(value), this.zeroY());
  }

  protected barHeight(value: number): number {
    return Math.abs(this.zeroY() - this.y(value));
  }
}
