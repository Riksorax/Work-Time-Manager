import {
  DestroyRef, Directive, ElementRef, afterNextRender, computed, inject, input, signal,
} from '@angular/core';
import {
  ChartLabels, ChartPoint, LinearScale, axisLabelStep, estimateTextWidth, formatAxisHours, niceScale,
} from '../../utils/chart-scale.util';

/** Zeile der Textalternative (Tabelle für Screenreader). */
export interface ChartTableRow {
  key: string;
  label: string;
  value: string;
  reference: string | null;
  secondary: string | null;
}

/** Ein Teilstrich der Wertachse in Pixeln. */
export interface ChartTick {
  value: number;
  y: number;
  label: string;
  zero: boolean;
}

/** Ein Zeitraum (Spalte) in Pixeln. */
export interface ChartSlot {
  index: number;
  point: ChartPoint;
  /** Linke Kante der Spalte. */
  x0: number;
  /** Mitte der Spalte. */
  cx: number;
  width: number;
  showAxisLabel: boolean;
}

const DEFAULT_WIDTH = 600;
const PLOT_HEIGHT = 180;
const MARGIN_TOP = 10;
const MARGIN_RIGHT = 8;
const MARGIN_BOTTOM = 26;
const AXIS_FONT_PX = 11;

/**
 * Gemeinsame Grundlage der SVG-Diagramme (#531): Breite (ResizeObserver, Pixel statt viewBox, damit die
 * Schrift auf dem Handy nicht schrumpft), Skala, Spalten, ausgedünnte Achsenbeschriftung, Hover/Fokus mit
 * Detailzeile, Tastaturbedienung (Roving tabindex, Pfeile/Home/End) und die Tabelle als Textalternative.
 */
@Directive()
export abstract class ChartBase {
  readonly points = input.required<readonly ChartPoint[]>();
  readonly labels = input.required<ChartLabels>();

  private readonly host = inject<ElementRef<HTMLElement>>(ElementRef);
  private readonly destroyRef = inject(DestroyRef);

  protected readonly width = signal(DEFAULT_WIDTH);
  private readonly _hovered = signal<number | null>(null);
  private readonly _selected = signal<number | null>(null);

  /** Vorzeichen an den Achsenbeschriftungen (Überstunden). */
  protected abstract readonly signedAxis: boolean;
  /** Wert auch ohne Einträge zeigen (laufende Summe bleibt gültig); sonst nur der Hinweis „keine Einträge“. */
  protected abstract readonly valueWithoutData: boolean;
  /** Werte, die in die Skala eingehen. */
  protected abstract scaleValues(points: readonly ChartPoint[]): number[];
  protected abstract formatValue(ms: number): string;
  protected abstract formatReference(ms: number): string;
  protected abstract formatSecondary(ms: number): string;

  protected readonly plotHeight = PLOT_HEIGHT;
  protected readonly marginTop = MARGIN_TOP;

  constructor() {
    afterNextRender(() => {
      const el = this.host.nativeElement;
      if (el.clientWidth > 0) this.width.set(el.clientWidth);
      if (typeof ResizeObserver === 'undefined') return;
      const ro = new ResizeObserver(entries => {
        const w = Math.round(entries[0]?.contentRect.width ?? 0);
        if (w > 0) this.width.set(w);
      });
      ro.observe(el);
      this.destroyRef.onDestroy(() => ro.disconnect());
    });
  }

  protected readonly scale = computed<LinearScale>(() => niceScale(this.scaleValues(this.points())));

  protected readonly tickLabels = computed(() =>
    this.scale().ticks.map(t => formatAxisHours(t, this.signedAxis)));

  protected readonly marginLeft = computed(() =>
    Math.max(...this.tickLabels().map(l => estimateTextWidth(l, AXIS_FONT_PX)), 16) + 10);

  protected readonly svgHeight = MARGIN_TOP + PLOT_HEIGHT + MARGIN_BOTTOM;

  protected readonly plotWidth = computed(() =>
    Math.max(this.width() - this.marginLeft() - MARGIN_RIGHT, 40));

  /** Pixel-Y eines Wertes. */
  protected y(value: number): number {
    const { min, max } = this.scale();
    const span = max - min || 1;
    return MARGIN_TOP + ((max - value) / span) * PLOT_HEIGHT;
  }

  protected readonly zeroY = computed(() => this.y(0));

  protected readonly ticks = computed<ChartTick[]>(() => {
    const labels = this.tickLabels();
    return this.scale().ticks.map((value, i) => ({ value, y: this.y(value), label: labels[i], zero: value === 0 }));
  });

  protected readonly slots = computed<ChartSlot[]>(() => {
    const points = this.points();
    const n = points.length;
    if (n === 0) return [];
    const left = this.marginLeft();
    const width = this.plotWidth() / n;
    const longest = Math.max(...points.map(p => estimateTextWidth(p.axisLabel, AXIS_FONT_PX)));
    const every = axisLabelStep(n, this.plotWidth(), longest + 6);
    return points.map((point, index) => ({
      index,
      point,
      x0: left + index * width,
      cx: left + (index + 0.5) * width,
      width,
      showAxisLabel: (n - 1 - index) % every === 0,
    }));
  });

  protected readonly axisLabelY = MARGIN_TOP + PLOT_HEIGHT + 17;

  /** Spalte mit `tabindex="0"`: zuletzt gewählte, sonst der jüngste Zeitraum. */
  protected readonly rovingIndex = computed(() => {
    const n = this.points().length;
    const sel = this._selected();
    return sel !== null && sel < n ? sel : n - 1;
  });

  /** Spalte, deren Werte die Detailzeile zeigt (Hover vor Auswahl). */
  protected readonly activeIndex = computed(() => {
    const h = this._hovered();
    return h !== null && h < this.points().length ? h : this.rovingIndex();
  });

  /** Hervorhebung nur, solange der Nutzer zeigt oder gewählt hat. */
  protected readonly highlightIndex = computed(() =>
    this._hovered() !== null || this._selected() !== null ? this.activeIndex() : -1);

  protected readonly hasPartial = computed(() => this.points().some(p => p.partial));
  protected readonly hasGap = computed(() => this.points().some(p => !p.hasData));

  /** Text der Detailzeile und `aria-label` einer Spalte. */
  protected describe(p: ChartPoint): string {
    const l = this.labels();
    const parts: string[] = [];
    if (!p.hasData) {
      if (this.valueWithoutData) parts.push(`${l.value} ${this.formatValue(p.value)}`);
      parts.push(l.noData);
    } else {
      parts.push(`${l.value} ${this.formatValue(p.value)}`);
      if (l.reference && p.reference !== undefined) parts.push(`${l.reference} ${this.formatReference(p.reference)}`);
    }
    if (l.secondary && p.secondary !== undefined && p.hasData) {
      parts.push(`${l.secondary} ${this.formatSecondary(p.secondary)}`);
    }
    const suffix = p.partial ? ` (${l.partial})` : '';
    return `${p.label}${suffix}: ${parts.join(' · ')}`;
  }

  protected readonly detail = computed(() => {
    const p = this.points()[this.activeIndex()];
    return p ? this.describe(p) : '';
  });

  protected readonly tableRows = computed<ChartTableRow[]>(() => {
    const l = this.labels();
    return this.points().map(p => ({
      key: p.key,
      label: p.partial ? `${p.label} (${l.partial})` : p.label,
      value: p.hasData || this.valueWithoutData ? this.formatValue(p.value) : l.noData,
      reference: l.reference ? (p.hasData && p.reference !== undefined ? this.formatReference(p.reference) : '–') : null,
      secondary: l.secondary
        ? (p.hasData && p.secondary !== undefined ? this.formatSecondary(p.secondary) : this.valueWithoutData ? l.noData : '–')
        : null,
    }));
  });

  // ── Interaktion ──────────────────────────────────────────────────────────────

  protected onHover(index: number | null): void {
    this._hovered.set(index);
  }

  protected onSelect(index: number): void {
    this._selected.set(index);
  }

  protected onKeydown(event: KeyboardEvent, index: number): void {
    const n = this.points().length;
    let next: number;
    switch (event.key) {
      case 'ArrowRight': case 'ArrowDown': next = Math.min(index + 1, n - 1); break;
      case 'ArrowLeft': case 'ArrowUp': next = Math.max(index - 1, 0); break;
      case 'Home': next = 0; break;
      case 'End': next = n - 1; break;
      default: return;
    }
    event.preventDefault();
    this._selected.set(next);
    const target = this.host.nativeElement.querySelectorAll<SVGGElement>('.chart-slot')[next];
    target?.focus();
  }
}
