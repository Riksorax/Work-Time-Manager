import { ChangeDetectionStrategy, Component, computed } from '@angular/core';
import { ChartBase } from './chart-base';
import { ChartPoint } from '../../utils/chart-scale.util';
import { formatSignedDurationHm } from '../../utils/duration-format.util';

/**
 * Liniendiagramm als eigene SVG-Komponente (#531) für vorzeichenbehaftete Werte (Überstunden): Nulllinie
 * immer sichtbar und hervorgehoben, Fläche zwischen Linie und Null leicht gefüllt, Achse mit Vorzeichen.
 * Zeiträume ohne Einträge haben einen hohlen, kleinen Punkt; das Stück zum laufenden Zeitraum ist gestrichelt.
 * Textalternative: visuell versteckte Tabelle mit denselben Werten.
 */
@Component({
  selector: 'app-line-chart',
  templateUrl: './line-chart.html',
  styleUrl: './chart.scss',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class LineChartComponent extends ChartBase {
  protected readonly signedAxis = true;
  protected readonly valueWithoutData = true;

  protected scaleValues(points: readonly ChartPoint[]): number[] {
    return points.map(p => p.value);
  }

  protected formatValue(ms: number): string { return formatSignedDurationHm(ms); }
  protected formatReference(ms: number): string { return formatSignedDurationHm(ms); }
  protected formatSecondary(ms: number): string { return formatSignedDurationHm(ms); }

  private readonly coords = computed(() => this.slots().map(s => ({ x: s.cx, y: this.y(s.point.value) })));

  /** Durchgezogener Teil: bis zum letzten abgeschlossenen Zeitraum (ohne den laufenden). */
  protected readonly solidPath = computed(() => {
    const c = this.coords();
    const last = this.slots().at(-1);
    const end = last?.point.partial ? c.length - 1 : c.length;
    return c.slice(0, end).map((p, i) => `${i === 0 ? 'M' : 'L'}${p.x},${p.y}`).join(' ');
  });

  /** Gestrichelter Teil zum laufenden Zeitraum (leer, wenn der letzte abgeschlossen ist). */
  protected readonly partialPath = computed(() => {
    const c = this.coords();
    const last = this.slots().at(-1);
    if (!last?.point.partial || c.length < 2) return '';
    const a = c[c.length - 2], b = c[c.length - 1];
    return `M${a.x},${a.y} L${b.x},${b.y}`;
  });

  protected readonly areaPath = computed(() => {
    const c = this.coords();
    if (c.length === 0) return '';
    const z = this.zeroY();
    return `M${c[0].x},${z} ` + c.map(p => `L${p.x},${p.y}`).join(' ') + ` L${c[c.length - 1].x},${z} Z`;
  });
}
