import { ComponentFixture, TestBed } from '@angular/core/testing';
import { signal } from '@angular/core';
import { TranslateService, provideTranslateService } from '@ngx-translate/core';
import { BehaviorSubject, Observable, Subject, of, throwError } from 'rxjs';
import { TrendViewComponent } from './trend-view';
import { TrendViewService } from './trend-view.service';
import { AuthService } from '../../../../core/auth/auth';
import { ApiClient } from '../../../../core/services/api-client';
import { ProfileService } from '../../../../core/services/profile';
import { TodayService } from '../../../../core/services/today';
import { WorkProfileService } from '../../../../core/services/work-profile';
import { OvertimeForecast, TrendBucket, TrendGranularity, TrendReport, WeeklyTrend } from '../../../../domain/models/trend.models';
import { FakeWorkProfile, createFakeWorkProfile } from '../../../../shared/testing/work-profile-fake';
import de from '../../../../../../public/i18n/de.json';
import en from '../../../../../../public/i18n/en.json';

const H = 3_600_000;

function buckets(g: TrendGranularity, hasData: (i: number) => boolean = () => true): TrendBucket[] {
  return Array.from({ length: 12 }, (_, i) => {
    const start = g === 'week' ? new Date(2026, 7, 24 + 7 * i) : new Date(2025, 11 + i, 1);
    const end = g === 'week' ? new Date(2026, 7, 30 + 7 * i) : new Date(2025, 12 + i, 0);
    const data = hasData(i);
    return {
      key: g === 'week' ? `2026-W${35 + i}` : `${start.getFullYear()}-${String(start.getMonth() + 1).padStart(2, '0')}`,
      start, end,
      worked: data ? 38 * H : 0, target: data ? 40 * H : 0, overtime: data ? -2 * H : 0,
      cumulativeOvertime: data ? -2 * H * (i + 1) : 0, hasData: data,
    };
  });
}

const TREND: WeeklyTrend = { lastWeekKey: '2026-W45', lastWeekWorked: 41.5 * H, averageWorked: 39 * H, delta: 2.5 * H, comparedWeeks: 4 };

const FORECAST: OvertimeForecast = {
  targetDate: new Date(2026, 11, 31), currentBalance: 18.75 * H, averageWeeklyOvertime: 1.25 * H,
  weeksUsed: 6, remainingWeeks: 7.14, projectedBalance: 32.5 * H,
};

function forecast(over: Partial<OvertimeForecast> = {}): OvertimeForecast {
  return { ...FORECAST, ...over };
}

function report(
  g: TrendGranularity, weeklyTrend: WeeklyTrend | null = TREND, hasData?: (i: number) => boolean,
  fc: OvertimeForecast | null = FORECAST,
): TrendReport {
  return { granularity: g, buckets: buckets(g, hasData), weeklyTrend, forecast: fc };
}

interface World {
  user$: BehaviorSubject<{ uid: string } | null>;
  isPremium: ReturnType<typeof signal<boolean>>;
  today: ReturnType<typeof signal<string>>;
  workProfile: FakeWorkProfile;
  getTrendReport: ReturnType<typeof vi.fn>;
}

function setup(respond: (date: Date, g: TrendGranularity, pid?: string) => Observable<TrendReport>): World {
  const world: World = {
    user$: new BehaviorSubject<{ uid: string } | null>({ uid: 'u1' }),
    isPremium: signal(true),
    today: signal('2026-11-12'),
    workProfile: createFakeWorkProfile(),
    getTrendReport: vi.fn(respond),
  };
  TestBed.configureTestingModule({
    providers: [
      provideTranslateService({ fallbackLang: 'de' }),
      TrendViewService,
      { provide: AuthService, useValue: { user$: world.user$ } },
      { provide: ProfileService, useValue: { isPremium: world.isPremium } },
      { provide: TodayService, useValue: { today: world.today } },
      { provide: WorkProfileService, useValue: world.workProfile },
      { provide: ApiClient, useValue: { getTrendReport: world.getTrendReport } },
    ],
  });
  const translate = TestBed.inject(TranslateService);
  translate.setTranslation('de', de);
  translate.setTranslation('en', en);
  translate.use('de');
  return world;
}

describe('TrendViewService (#531)', () => {
  afterEach(() => TestBed.resetTestingModule());

  it('lädt erst, wenn die Ansicht angehängt ist, mit dem Bezugstag aus TodayService', () => {
    const w = setup((_d, g) => of(report(g)));
    const svc = TestBed.inject(TrendViewService);
    TestBed.tick();
    expect(w.getTrendReport).not.toHaveBeenCalled();
    expect(svc.state().status).toBe('idle');

    svc.attach();
    TestBed.tick();
    expect(w.getTrendReport).toHaveBeenCalledTimes(1);
    const [date, g, pid] = w.getTrendReport.mock.calls[0] as [Date, TrendGranularity, string | undefined];
    expect([date.getFullYear(), date.getMonth(), date.getDate(), date.getHours()]).toEqual([2026, 10, 12, 0]);
    expect(g).toBe('week');
    expect(pid).toBeUndefined();
    expect(svc.state().status).toBe('data');
  });

  it('kein API-Aufruf ohne Premium oder ohne Anmeldung', () => {
    const w = setup((_d, g) => of(report(g)));
    w.isPremium.set(false);
    const svc = TestBed.inject(TrendViewService);
    svc.attach();
    TestBed.tick();
    expect(w.getTrendReport).not.toHaveBeenCalled();

    w.isPremium.set(true);
    w.user$.next(null);
    TestBed.tick();
    expect(w.getTrendReport).not.toHaveBeenCalled();
    expect(svc.state().status).toBe('idle');
  });

  it('Umschalten auf Monate, Profilwechsel und Tageswechsel laden neu', () => {
    const w = setup((_d, g) => of(report(g)));
    const svc = TestBed.inject(TrendViewService);
    svc.attach();
    TestBed.tick();

    svc.setGranularity('month');
    TestBed.tick();
    expect(w.getTrendReport.mock.calls.at(-1)?.[1]).toBe('month');
    expect(svc.report()?.granularity).toBe('month');

    w.workProfile.set('p2');
    TestBed.tick();
    expect(w.getTrendReport.mock.calls.at(-1)?.[2]).toBe('p2');

    w.today.set('2026-11-13');
    TestBed.tick();
    expect((w.getTrendReport.mock.calls.at(-1)?.[0] as Date).getDate()).toBe(13);
    expect(w.getTrendReport).toHaveBeenCalledTimes(4);
  });

  it('nach dem Abhängen lädt ein Profilwechsel nicht mehr', () => {
    const w = setup((_d, g) => of(report(g)));
    const svc = TestBed.inject(TrendViewService);
    const detach = svc.attach();
    TestBed.tick();
    detach();
    detach();
    TestBed.tick();
    w.workProfile.set('p2');
    TestBed.tick();
    expect(w.getTrendReport).toHaveBeenCalledTimes(1);
  });

  it('Fehler ergibt den Fehlerzustand, „Erneut versuchen“ lädt neu', () => {
    let fail = true;
    const w = setup((_d, g) => (fail ? throwError(() => new Error('offline')) : of(report(g))));
    const svc = TestBed.inject(TrendViewService);
    svc.attach();
    TestBed.tick();
    expect(svc.state().status).toBe('error');

    fail = false;
    svc.retry();
    TestBed.tick();
    expect(w.getTrendReport).toHaveBeenCalledTimes(2);
    expect(svc.state().status).toBe('data');
  });

  it('isEmpty, wenn kein Zeitraum Daten hat', () => {
    setup((_d, g) => of(report(g, null, () => false)));
    const svc = TestBed.inject(TrendViewService);
    svc.attach();
    TestBed.tick();
    expect(svc.isEmpty()).toBe(true);
  });
});

describe('TrendViewComponent (#531)', () => {
  let fixture: ComponentFixture<TrendViewComponent>;

  afterEach(() => TestBed.resetTestingModule());

  function mount(respond: (date: Date, g: TrendGranularity, pid?: string) => Observable<TrendReport>): World {
    const w = setup(respond);
    fixture = TestBed.createComponent(TrendViewComponent);
    fixture.detectChanges();
    TestBed.tick();
    fixture.detectChanges();
    return w;
  }

  const el = (): HTMLElement => fixture.nativeElement as HTMLElement;
  const text = (): string => el().textContent?.replace(/\s+/g, ' ') ?? '';

  it('Ladezustand: Spinner mit Statusrolle, keine Diagramme', () => {
    mount(() => new Subject<TrendReport>());
    expect(el().querySelector('.trend-loading[role="status"]')).not.toBeNull();
    expect(el().querySelector('app-bar-chart')).toBeNull();
  });

  it('Daten: Wochen-Trend als Text, Balken- und Liniendiagramm mit 12 Zeiträumen', () => {
    mount((_d, g) => of(report(g)));
    expect(text()).toContain('Wochen-Trend');
    expect(text()).toContain('+02:30 h gegenüber dem Durchschnitt der letzten 4 Wochen');
    expect(text()).toContain('KW 45: 41:30 h · Durchschnitt 39:00 h');
    expect(el().querySelectorAll('app-bar-chart .chart-slot')).toHaveLength(12);
    expect(el().querySelectorAll('app-line-chart .chart-slot')).toHaveLength(12);
    expect(text()).toContain('Arbeitszeit je Woche');
    expect(text()).toContain('Überstunden im Zeitraum');
    expect(text()).toContain('nicht dein Gleitzeit-Saldo');
    const lastSlot = el().querySelectorAll('app-bar-chart .chart-slot')[11];
    expect(lastSlot.querySelector('text')?.textContent?.trim()).toBe('KW 46');
    expect(el().querySelector('app-bar-chart table tbody th')?.textContent).toContain('KW 35 · ');
    // Der laufende (letzte) Zeitraum ist gekennzeichnet.
    expect(el().querySelectorAll('app-bar-chart .chart-slot')[11].classList).toContain('is-partial');
  });

  it('weeklyTrend = null: Hinweis auf zu wenig Daten, Diagramme bleiben', () => {
    mount((_d, g) => of(report(g, null)));
    expect(text()).toContain('Für den Wochen-Trend liegen noch zu wenig Daten vor.');
    expect(el().querySelector('app-bar-chart')).not.toBeNull();
  });

  it('Leerzustand: keine Einträge im Zeitfenster, keine Diagramme', () => {
    mount((_d, g) => of(report(g, null, () => false)));
    expect(el().querySelector('.trend-empty[role="status"]')).not.toBeNull();
    expect(text()).toContain('In den letzten 12 Wochen gibt es noch keine Einträge.');
    expect(el().querySelector('app-bar-chart')).toBeNull();
  });

  it('Fehler: Meldung mit „Erneut versuchen“, Klick lädt neu', () => {
    let fail = true;
    const w = mount((_d, g) => (fail ? throwError(() => new Error('x')) : of(report(g))));
    expect(el().querySelector('.trend-error[role="alert"]')).not.toBeNull();
    fail = false;
    (el().querySelector('.trend-error button') as HTMLButtonElement).click();
    TestBed.tick();
    fixture.detectChanges();
    expect(w.getTrendReport).toHaveBeenCalledTimes(2);
    expect(el().querySelector('app-bar-chart')).not.toBeNull();
  });

  it('Umschalter Wochen/Monate: Standard 12 Wochen, Klick auf 12 Monate lädt Monate mit Monatsnamen', () => {
    const w = mount((_d, g) => of(report(g)));
    const toggles = [...el().querySelectorAll<HTMLButtonElement>('mat-button-toggle button')];
    expect(toggles.map(b => b.textContent?.trim())).toEqual(['12 Wochen', '12 Monate']);
    expect(el().querySelectorAll('mat-button-toggle')[0].classList).toContain('mat-button-toggle-checked');
    toggles[1].click();
    TestBed.tick();
    fixture.detectChanges();
    expect(w.getTrendReport.mock.calls.at(-1)?.[1]).toBe('month');
    expect(text()).toContain('Arbeitszeit je Monat');
    const labels = [...el().querySelectorAll('app-bar-chart table tbody th')].map(t => t.textContent?.trim());
    expect(labels[0]).toBe('Dezember 2025');
    expect(labels[11]).toContain('November 2026');
  });

  it('Englisch: Beschriftung folgt der App-Sprache', () => {
    mount((_d, g) => of(report(g)));
    TestBed.inject(TranslateService).use('en');
    fixture.detectChanges();
    expect(text()).toContain('compared with the average of the previous 4 weeks');
    expect(text()).toContain('Working time per week');
  });

  describe('Karte „Prognose zum Jahresende“ (#532)', () => {
    const card = (): HTMLElement => el().querySelector('.trend-forecast') as HTMLElement;
    const cardText = (): string => card().textContent?.replace(/\s+/g, ' ') ?? '';

    it('positive Prognose: Hauptzeile, Herleitung, Hinweis; Karte direkt unter dem Wochen-Trend', () => {
      mount((_d, g) => of(report(g)));
      expect(card().querySelector('h3')?.textContent).toContain('Prognose zum Jahresende');
      expect(card().getAttribute('aria-label')).toBe('Prognose zum Jahresende');
      expect(cardText()).toContain('Voraussichtlich +32:30 h zum 31.12.2026');
      expect(cardText()).toContain('Aktueller Saldo +18:45 h · im Schnitt +01:15 h pro Woche (letzte 6 Wochen) · noch rund 7 Wochen');
      expect(cardText()).toContain('Hochrechnung aus deinen letzten Wochen. Geplanter Urlaub und Feiertage sind nicht berücksichtigt.');
      expect(card().previousElementSibling?.textContent).toContain('Wochen-Trend');
      expect(card().querySelector('mat-icon')?.textContent?.trim()).toBe('trending_up');
    });

    it('negative Prognose: Vorzeichen minus, Icon trending_down', () => {
      mount((_d, g) => of(report(g, TREND, undefined, forecast({
        currentBalance: -2 * H, averageWeeklyOvertime: -0.5 * H, projectedBalance: -5.5 * H,
      }))));
      expect(cardText()).toContain('Voraussichtlich -05:30 h zum 31.12.2026');
      expect(cardText()).toContain('Aktueller Saldo -02:00 h · im Schnitt -00:30 h pro Woche');
      expect(card().querySelector('mat-icon')?.textContent?.trim()).toBe('trending_down');
    });

    it('Prognose 0: +00:00 h, Icon trending_flat', () => {
      mount((_d, g) => of(report(g, TREND, undefined, forecast({
        currentBalance: 0, averageWeeklyOvertime: 0, projectedBalance: 0,
      }))));
      expect(cardText()).toContain('Voraussichtlich +00:00 h zum 31.12.2026');
      expect(card().querySelector('mat-icon')?.textContent?.trim()).toBe('trending_flat');
    });

    it('forecast = null: Hinweis auf fehlende Daten, Diagramme bleiben', () => {
      mount((_d, g) => of(report(g, TREND, undefined, null)));
      expect(cardText()).toContain('Für eine Prognose fehlen noch Daten (mindestens 4 der letzten 8 Wochen mit Einträgen).');
      expect(cardText()).not.toContain('Voraussichtlich');
      expect(cardText()).not.toContain('Hochrechnung');
      expect(el().querySelector('app-bar-chart')).not.toBeNull();
    });

    it('Restwochen: gerundet, 1 Woche, unter einer Woche, 0', () => {
      const detail = (remainingWeeks: number): string => {
        TestBed.resetTestingModule();
        mount((_d, g) => of(report(g, TREND, undefined, forecast({ remainingWeeks }))));
        return cardText();
      };
      expect(detail(7.14)).toContain('noch rund 7 Wochen');
      expect(detail(7.6)).toContain('noch rund 8 Wochen');
      expect(detail(1.2)).toContain('noch rund 1 Woche');
      expect(detail(0.857)).toContain('weniger als eine Woche');
      const end = detail(0);
      expect(end).toContain('das Jahr endet heute');
      expect(end).toContain('entspricht die Prognose dem aktuellen Saldo: +32:30 h');
      expect(end).not.toContain('pro Woche');
    });

    it('Granularität Monate: Karte bleibt gleich', () => {
      mount((_d, g) => of(report(g)));
      const before = cardText();
      (el().querySelectorAll<HTMLButtonElement>('mat-button-toggle button')[1]).click();
      TestBed.tick();
      fixture.detectChanges();
      expect(cardText()).toBe(before);
    });

    it('Leerzustand zeigt keine Karte', () => {
      mount((_d, g) => of(report(g, null, () => false, null)));
      expect(el().querySelector('.trend-forecast')).toBeNull();
    });

    it('Englisch: Texte und Datum in der App-Sprache', () => {
      mount((_d, g) => of(report(g)));
      TestBed.inject(TranslateService).use('en');
      fixture.detectChanges();
      expect(cardText()).toContain('Year-end forecast');
      expect(cardText()).toContain('Expected +32:30 h by 12/31/2026');
      expect(cardText()).toContain('Current balance +18:45 h · on average +01:15 h per week (last 6 weeks) · about 7 weeks left');
      expect(cardText()).toContain('Planned vacation and public holidays are not included.');
    });
  });
});
