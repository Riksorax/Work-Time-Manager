import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Type } from '@angular/core';
import { BarChartComponent } from './bar-chart';
import { LineChartComponent } from './line-chart';
import { ChartLabels, ChartPoint } from '../../utils/chart-scale.util';

const H = 3_600_000;

const LABELS: ChartLabels = {
  title: 'Arbeitszeit je Woche', period: 'Zeitraum', value: 'Ist', reference: 'Soll',
  noData: 'keine Einträge', partial: 'läuft noch',
};
const LINE_LABELS: ChartLabels = {
  title: 'Überstunden im Zeitraum', period: 'Zeitraum', value: 'Summe', secondary: 'Woche',
  noData: 'keine Einträge', partial: 'läuft noch',
};

function pt(i: number, value: number, extra: Partial<ChartPoint> = {}): ChartPoint {
  return {
    key: `k${i}`, axisLabel: `KW ${i + 1}`, label: `KW ${i + 1} lang`, value, hasData: true, partial: false, ...extra,
  };
}

function twelve(value: (i: number) => number, extra: (i: number) => Partial<ChartPoint> = () => ({})): ChartPoint[] {
  return Array.from({ length: 12 }, (_, i) => pt(i, value(i), { partial: i === 11, ...extra(i) }));
}

function mount<T>(type: Type<T>, points: ChartPoint[], labels: ChartLabels): { fixture: ComponentFixture<T>; el: HTMLElement } {
  const fixture = TestBed.createComponent(type);
  fixture.componentRef.setInput('points', points);
  fixture.componentRef.setInput('labels', labels);
  fixture.detectChanges();
  return { fixture, el: fixture.nativeElement as HTMLElement };
}

/** Alle numerischen SVG-Attribute sind endlich (kein NaN/Infinity bei Randfällen). */
function allFinite(el: HTMLElement): boolean {
  const attrs = ['x', 'y', 'width', 'height', 'x1', 'x2', 'y1', 'y2', 'cx', 'cy'];
  return [...el.querySelectorAll('svg *')].every(n =>
    attrs.every(a => !n.hasAttribute(a) || Number.isFinite(Number(n.getAttribute(a)))));
}

const slots = (el: HTMLElement) => [...el.querySelectorAll<SVGGElement>('.chart-slot')];

describe('BarChartComponent (#531)', () => {
  it('SVG ist eine benannte Gruppe, jede Spalte ein benanntes Bild mit Werten', () => {
    const { el } = mount(BarChartComponent, twelve(() => 40 * H, () => ({ reference: 40 * H })), LABELS);
    const svg = el.querySelector('svg.chart-svg')!;
    expect(svg.getAttribute('role')).toBe('group');
    expect(svg.getAttribute('aria-label')).toBe('Arbeitszeit je Woche');
    expect(slots(el)).toHaveLength(12);
    expect(slots(el)[0].getAttribute('role')).toBe('img');
    expect(slots(el)[0].getAttribute('aria-label')).toBe('KW 1 lang: Ist 40:00 · Soll 40:00');
  });

  it('Zeiträume ohne Daten sind eine Lücke: kein Balken, keine Soll-Marke, gestrichelte Grundlinie', () => {
    const points = twelve(i => (i === 3 ? 0 : 38 * H), i => (i === 3 ? { hasData: false, reference: 0 } : { reference: 40 * H }));
    const { el } = mount(BarChartComponent, points, LABELS);
    const gap = slots(el)[3];
    expect(gap.classList).toContain('is-gap');
    expect(gap.querySelector('.chart-bar')).toBeNull();
    expect(gap.querySelector('.chart-target')).toBeNull();
    expect(gap.querySelector('.chart-gap')).not.toBeNull();
    expect(gap.getAttribute('aria-label')).toBe('KW 4 lang: keine Einträge');
    expect(el.querySelectorAll('.chart-bar').length).toBeGreaterThanOrEqual(11);
    expect(el.querySelector('.chart-legend .is-gap')?.textContent).toContain('keine Einträge');
  });

  it('laufender Zeitraum ist gekennzeichnet (Klasse, Legende, Beschriftung)', () => {
    const { el } = mount(BarChartComponent, twelve(() => 20 * H, () => ({ reference: 40 * H })), LABELS);
    const last = slots(el)[11];
    expect(last.classList).toContain('is-partial');
    expect(slots(el)[10].classList).not.toContain('is-partial');
    expect(last.getAttribute('aria-label')).toContain('(läuft noch)');
    expect(el.querySelector('.chart-legend .is-partial')?.textContent).toContain('läuft noch');
  });

  it('robuste Skalierung: alle 0, nur negative, sehr große Werte, ein Ausreißer', () => {
    for (const values of [
      () => 0,
      (i: number) => -(i + 1) * H,
      (i: number) => (i + 1) * 1_000_000 * H,
      (i: number) => (i === 5 ? 5_000 * H : 40 * H),
    ]) {
      TestBed.resetTestingModule();
      const { el } = mount(BarChartComponent, twelve(values, () => ({ reference: 40 * H })), LABELS);
      expect(allFinite(el)).toBe(true);
      const heights = [...el.querySelectorAll('.chart-slot .chart-bar')].map(b => Number(b.getAttribute('height')));
      expect(heights.every(h => h >= 0)).toBe(true);
      // 4 bis 6 Teilstriche (Nachbesserung zu #531: Obergrenze nah am größten Wert).
      const ticks = el.querySelectorAll('.chart-grid text').length;
      expect(ticks).toBeGreaterThanOrEqual(4);
      expect(ticks).toBeLessThanOrEqual(6);
    }
  });

  it('Textalternative: Tabelle mit denselben Werten, Lücke als „keine Einträge“', () => {
    const points = twelve(i => (i === 0 ? 0 : 38.5 * H), i => (i === 0 ? { hasData: false } : { reference: 40 * H }));
    const { el } = mount(BarChartComponent, points, LABELS);
    const table = el.querySelector('table')!;
    expect(table.classList).toContain('cdk-visually-hidden');
    expect(table.querySelector('caption')?.textContent?.trim()).toBe('Arbeitszeit je Woche');
    const rows = [...table.querySelectorAll('tbody tr')];
    expect(rows).toHaveLength(12);
    expect([...rows[0].children].map(c => c.textContent?.trim())).toEqual(['KW 1 lang', 'keine Einträge', '–']);
    expect([...rows[1].children].map(c => c.textContent?.trim())).toEqual(['KW 2 lang', '38:30', '40:00']);
    expect(rows[11].querySelector('th')?.textContent).toContain('läuft noch');
  });

  it('Tastatur: ein Tab-Stopp (jüngster Zeitraum), Pfeile/Home/End bewegen Fokus und Detailzeile', () => {
    const { fixture, el } = mount(BarChartComponent, twelve(i => (i + 30) * H, () => ({ reference: 40 * H })), LABELS);
    document.body.appendChild(el);
    const tabbable = () => slots(el).filter(s => s.getAttribute('tabindex') === '0');
    expect(tabbable()).toHaveLength(1);
    expect(tabbable()[0]).toBe(slots(el)[11]);
    expect(el.querySelector('.chart-detail')?.textContent).toContain('KW 12 lang');

    slots(el)[11].dispatchEvent(new KeyboardEvent('keydown', { key: 'ArrowLeft', bubbles: true }));
    fixture.detectChanges();
    expect(document.activeElement).toBe(slots(el)[10]);
    expect(tabbable()[0]).toBe(slots(el)[10]);
    expect(el.querySelector('.chart-detail')?.textContent).toContain('KW 11 lang: Ist 40:00');
    expect(slots(el)[10].classList).toContain('is-active');

    slots(el)[10].dispatchEvent(new KeyboardEvent('keydown', { key: 'Home', bubbles: true }));
    fixture.detectChanges();
    expect(document.activeElement).toBe(slots(el)[0]);
    slots(el)[0].dispatchEvent(new KeyboardEvent('keydown', { key: 'ArrowLeft', bubbles: true }));
    fixture.detectChanges();
    expect(document.activeElement).toBe(slots(el)[0]);
    slots(el)[0].dispatchEvent(new KeyboardEvent('keydown', { key: 'End', bubbles: true }));
    fixture.detectChanges();
    expect(document.activeElement).toBe(slots(el)[11]);
    el.remove();
  });

  it('Hover zeigt die Werte des Balkens in der Detailzeile', () => {
    const { fixture, el } = mount(BarChartComponent, twelve(i => (i + 30) * H, () => ({ reference: 40 * H })), LABELS);
    slots(el)[2].dispatchEvent(new MouseEvent('mouseenter'));
    fixture.detectChanges();
    expect(el.querySelector('.chart-detail')?.textContent).toContain('KW 3 lang: Ist 32:00 · Soll 40:00');
    slots(el)[2].dispatchEvent(new MouseEvent('mouseleave'));
    fixture.detectChanges();
    expect(el.querySelector('.chart-detail')?.textContent).toContain('KW 12 lang');
  });
});

describe('LineChartComponent (#531)', () => {
  it('Nulllinie sichtbar, negative Werte liegen darunter, positive darüber', () => {
    const { el } = mount(LineChartComponent, twelve(i => (i - 6) * H, i => ({ secondary: H * (i % 2 ? 1 : -1) })), LINE_LABELS);
    const zero = el.querySelector('line.chart-zero')!;
    const zeroY = Number(zero.getAttribute('y1'));
    const dots = [...el.querySelectorAll('.chart-slot .chart-dot')].map(d => Number(d.getAttribute('cy')));
    expect(dots[0]).toBeGreaterThan(zeroY);
    expect(dots[6]).toBeCloseTo(zeroY);
    expect(dots[11]).toBeLessThan(zeroY);
    expect([...el.querySelectorAll('.chart-grid text')].map(t => t.textContent?.trim())).toContain('0 h');
    expect([...el.querySelectorAll('.chart-grid text')].some(t => t.textContent?.trim().startsWith('+'))).toBe(true);
  });

  it('nur negative Werte und alle 0: endliche Koordinaten, 0 bleibt im Bild', () => {
    for (const values of [(i: number) => -(i + 1) * 3 * H, () => 0]) {
      TestBed.resetTestingModule();
      const { el } = mount(LineChartComponent, twelve(values), LINE_LABELS);
      expect(allFinite(el)).toBe(true);
      expect(el.querySelector('line.chart-zero')).not.toBeNull();
      expect(el.querySelector('path.chart-line')?.getAttribute('d')).not.toContain('NaN');
    }
  });

  it('laufender Zeitraum: gestricheltes letztes Stück, hohler Punkt, Legende', () => {
    const { el } = mount(LineChartComponent, twelve(i => i * H), LINE_LABELS);
    expect(el.querySelector('path.is-partial-line')).not.toBeNull();
    expect(slots(el)[11].classList).toContain('is-partial');
    expect(el.querySelector('.chart-legend .is-partial')).not.toBeNull();
  });

  it('ohne laufenden Zeitraum kein gestricheltes Stück', () => {
    const { el } = mount(LineChartComponent, twelve(i => i * H, () => ({ partial: false })), LINE_LABELS);
    expect(el.querySelector('svg path.is-partial-line')).toBeNull();
  });

  it('Lücke: Summe bleibt ablesbar, Hinweis „keine Einträge“, Zusatzwert in der Tabelle', () => {
    const points = twelve(() => 2 * H, i => (i === 4 ? { hasData: false, secondary: 0 } : { secondary: -30 * 60_000 }));
    const { el } = mount(LineChartComponent, points, LINE_LABELS);
    expect(slots(el)[4].classList).toContain('is-gap');
    expect(slots(el)[4].getAttribute('aria-label')).toBe('KW 5 lang: Summe +02:00 · keine Einträge');
    const rows = [...el.querySelectorAll('table tbody tr')];
    expect([...rows[4].children].map(c => c.textContent?.trim())).toEqual(['KW 5 lang', '+02:00', 'keine Einträge']);
    expect([...rows[0].children].map(c => c.textContent?.trim())).toEqual(['KW 1 lang', '+02:00', '-00:30']);
    expect(el.querySelector('table thead')?.textContent).toContain('Woche');
  });

  it('Tastatur wie beim Balkendiagramm', () => {
    const { fixture, el } = mount(LineChartComponent, twelve(i => i * H), LINE_LABELS);
    document.body.appendChild(el);
    slots(el)[11].dispatchEvent(new KeyboardEvent('keydown', { key: 'ArrowLeft', bubbles: true }));
    fixture.detectChanges();
    expect(document.activeElement).toBe(slots(el)[10]);
    expect(el.querySelector('.chart-detail')?.textContent).toContain('KW 11 lang: Summe +10:00');
    el.remove();
  });
});

describe('Achsenbeschriftung bei schmaler Breite (#531)', () => {
  it('auf Handy-Breite wird ausgedünnt, der jüngste Zeitraum bleibt beschriftet', () => {
    const { fixture, el } = mount(BarChartComponent, twelve(() => 40 * H), LABELS);
    (fixture.componentInstance as unknown as { width: { set(v: number): void } }).width.set(330);
    fixture.detectChanges();
    const labelled = slots(el).map(s => !!s.querySelector('text'));
    expect(labelled.filter(Boolean).length).toBeLessThan(12);
    expect(labelled[11]).toBe(true);
  });
});
