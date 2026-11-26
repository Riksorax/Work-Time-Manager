import { ComponentFixture, TestBed } from '@angular/core/testing';
import { computed, signal } from '@angular/core';
import { TranslateService, provideTranslateService } from '@ngx-translate/core';
import { InsightsViewComponent } from './insights-view';
import { InsightsState, InsightsViewService } from './insights-view.service';
import { InsightsReport } from '../../../../domain/models/insights.models';
import de from '../../../../../../public/i18n/de.json';
import en from '../../../../../../public/i18n/en.json';

const H = 3_600_000;
const M = 60_000;

function report(over: Partial<InsightsReport> = {}): InsightsReport {
  return {
    from: '2026-09-01', to: '2026-11-30', timeZone: 'Europe/Berlin', dailyTargetMs: 8 * H,
    weekdayAverages: [
      { weekday: 1, averageWorkedMs: 8 * H + 45 * M, deviationMs: 30 * M, sampleCount: 12 },
      { weekday: 5, averageWorkedMs: 7 * H + 15 * M, deviationMs: -(1 * H), sampleCount: 1 },
      { weekday: 3, averageWorkedMs: 8 * H + 15 * M, deviationMs: 0, sampleCount: 11 },
    ],
    overtimeStreak: { currentStreak: 3, longestStreak: 8, isWarning: false, warningThresholdDays: 5 },
    startTimeHeatmap: [
      { startHour: 7, averageOvertimeMs: 45 * M, sampleCount: 5 },
      { startHour: 9, averageOvertimeMs: -(20 * M), sampleCount: 2 },
    ],
    ...over,
  };
}

describe('InsightsViewComponent (#537)', () => {
  let fixture: ComponentFixture<InsightsViewComponent>;
  let state: ReturnType<typeof signal<InsightsState>>;
  let retry: ReturnType<typeof vi.fn>;
  let attach: ReturnType<typeof vi.fn>;
  let detach: ReturnType<typeof vi.fn>;

  afterEach(() => TestBed.resetTestingModule());

  function mount(initial: InsightsState, lang: 'de' | 'en' = 'de'): void {
    state = signal<InsightsState>(initial);
    retry = vi.fn();
    detach = vi.fn();
    attach = vi.fn(() => detach);
    const reportSig = computed(() => {
      const s = state();
      return s.status === 'data' ? s.report : null;
    });
    TestBed.configureTestingModule({
      imports: [InsightsViewComponent],
      providers: [
        provideTranslateService({ fallbackLang: 'de' }),
        { provide: InsightsViewService, useValue: {
          state, report: reportSig, retry, attach,
          isEmpty: computed(() => {
            const r = reportSig();
            return !!r && r.weekdayAverages.length === 0 && r.startTimeHeatmap.length === 0;
          }),
        } },
      ],
    });
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('de', de);
    translate.setTranslation('en', en);
    translate.use(lang);
    fixture = TestBed.createComponent(InsightsViewComponent);
    fixture.detectChanges();
  }

  const el = () => fixture.nativeElement as HTMLElement;
  const norm = (s: string | null | undefined) => (s ?? '').replace(/\s+/g, ' ').trim();
  const texts = (sel: string) => [...el().querySelectorAll(sel)].map(e => norm(e.textContent));

  it('meldet sich an und beim Zerstören wieder ab', () => {
    mount({ status: 'loading' });
    expect(attach).toHaveBeenCalledTimes(1);
    fixture.destroy();
    expect(detach).toHaveBeenCalledTimes(1);
  });

  it('Ladezustand: Spinner mit Statusrolle', () => {
    mount({ status: 'loading' });
    expect(el().querySelector('.ins-loading[role="status"]')).not.toBeNull();
    expect(el().querySelector('.insights-layout')?.getAttribute('aria-busy')).toBe('true');
  });

  it('Fehler mit „Erneut versuchen“', () => {
    mount({ status: 'error' });
    expect(el().querySelector('.ins-error[role="alert"]')?.textContent).toContain('Die Insights konnten nicht geladen werden.');
    (el().querySelector('.ins-error button') as HTMLButtonElement).click();
    expect(retry).toHaveBeenCalled();
  });

  it('leer: Hinweis, Zeitraum bleibt sichtbar, keine Abschnitte', () => {
    mount({ status: 'data', report: report({ weekdayAverages: [], startTimeHeatmap: [] }) });
    expect(el().querySelector('.ins-empty')?.textContent).toContain('Noch nicht genug Daten für Insights');
    expect(el().querySelector('.ins-period')).not.toBeNull();
    expect(el().querySelector('.ins-weekdays')).toBeNull();
    expect(el().querySelector('.ins-heatmap')).toBeNull();
  });

  it('Zeitraum aus from/to (Kalendertage, lokalisiert)', () => {
    mount({ status: 'data', report: report() });
    const period = norm(el().querySelector('.ins-period span')?.textContent);
    expect(period).toMatch(/^Zeitraum: 1\. Sept?\.? – 30\. Nov\.? 2026$/);
  });

  it('Wochentage: Name, Durchschnitt, Anzahl, Abweichung mit Vorzeichen (0 ohne)', () => {
    mount({ status: 'data', report: report() });
    expect(texts('.ins-wd-label')).toEqual(['Montag', 'Freitag', 'Mittwoch']);
    expect(texts('.ins-wd-avg')).toEqual(['Ø 08:45 h · 12 Tage', 'Ø 07:15 h · 1 Tag', 'Ø 08:15 h · 11 Tage']);
    expect(texts('.ins-wd-dev')).toEqual([
      'Abweichung vom Durchschnitt: +00:30', 'Abweichung vom Durchschnitt: -01:00', 'Abweichung vom Durchschnitt: 00:00',
    ]);
    const dev = [...el().querySelectorAll('.ins-wd-dev')].map(e => e.className);
    expect(dev[0]).toContain('is-pos');
    expect(dev[1]).toContain('is-neg');
    expect(dev[2]).toContain('is-zero');
    // Balken nur Zusatz, relativ zum längsten Durchschnitt.
    const bar = el().querySelector('.ins-wd-bar') as HTMLElement;
    expect(bar.getAttribute('aria-hidden')).toBe('true');
    expect((bar.firstElementChild as HTMLElement).style.width).toBe('100%');
  });

  it('Serie: aktuell und längste, ohne Warnung kein Hinweis', () => {
    mount({ status: 'data', report: report() });
    expect(texts('.ins-streak-values dd')).toEqual(['3 Arbeitstage', '8 Arbeitstage']);
    expect(el().querySelector('.ins-streak .ins-note')?.textContent).toContain('ab 5 Arbeitstagen');
    expect(el().querySelector('.ins-warning')).toBeNull();
  });

  it('Serie mit Warnung: ruhiger Hinweis mit Anzahl der Tage', () => {
    mount({ status: 'data', report: report({
      overtimeStreak: { currentStreak: 6, longestStreak: 6, isWarning: true, warningThresholdDays: 5 },
    }) });
    const warning = el().querySelector('.ins-warning');
    expect(warning?.getAttribute('role')).toBe('status');
    expect(norm(warning?.querySelector('p')?.textContent)).toBe(
      'Du liegst seit 6 aufeinanderfolgenden Arbeitstagen über deinem Soll. Denk an ausreichend Erholung.');
  });

  it('Heatmap: Stunde, Abweichung als Text mit Vorzeichen, Anzahl, Farbe nach Vorzeichen', () => {
    mount({ status: 'data', report: report() });
    expect(texts('.ins-heat-hour')).toEqual(['Start 07:00 Uhr', 'Start 09:00 Uhr']);
    expect(texts('.ins-heat-value')).toEqual(['Abweichung vom Tagessoll: +00:45', 'Abweichung vom Tagessoll: -00:20']);
    expect(texts('.ins-heat-days')).toEqual(['5 Tage', '2 Tage']);
    const cells = [...el().querySelectorAll('.ins-heat')].map(e => e.className);
    expect(cells[0]).toContain('is-pos');
    expect(cells[1]).toContain('is-neg');
    expect(el().querySelector('.ins-heatmap .ins-sub')?.textContent).toContain('Tagessoll (08:00 h)');
  });

  it('Heatmap ohne Startstunden, aber mit Wochentagen: kurzer Hinweis', () => {
    mount({ status: 'data', report: report({ startTimeHeatmap: [] }) });
    expect(el().querySelector('.ins-heat-grid')).toBeNull();
    expect(el().querySelector('.ins-heatmap .ins-note')?.textContent).toContain('mindestens zwei Tagen');
  });

  it('Englisch: Wochentage und Texte in der App-Sprache', () => {
    mount({ status: 'data', report: report() }, 'en');
    expect(texts('.ins-wd-label')).toEqual(['Monday', 'Friday', 'Wednesday']);
    expect(texts('.ins-heat-hour')).toEqual(['Start 07:00', 'Start 09:00']);
    expect(norm(el().querySelector('.ins-period span')?.textContent)).toMatch(/^Period: Sep 1 – Nov 30, 2026$/);
  });
});
