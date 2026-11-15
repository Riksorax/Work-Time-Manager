import { ComponentFixture, TestBed } from '@angular/core/testing';
import { signal } from '@angular/core';
import { TranslateService, provideTranslateService } from '@ngx-translate/core';
import { BehaviorSubject, Observable, Subject, of, throwError } from 'rxjs';
import { YearlyComparisonCardComponent } from './yearly-comparison-card';
import { AuthService } from '../../../core/auth/auth';
import { ApiClient } from '../../../core/services/api-client';
import { LEAVE_NOW } from '../../../core/services/leave-balance';
import { ProfileService } from '../../../core/services/profile';
import { WorkProfileService } from '../../../core/services/work-profile';
import { YearlyComparison, YearlySummary } from '../../../domain/models/yearly-comparison.models';
import { FakeWorkProfile, createFakeWorkProfile } from '../../testing/work-profile-fake';
import de from '../../../../../public/i18n/de.json';
import en from '../../../../../public/i18n/en.json';

const H = 3_600_000;
const M = 60_000;

function summary(year: number, over: Partial<YearlySummary> = {}): YearlySummary {
  return {
    year, hasData: true, totalWorkedMs: 1600 * H, totalBreaksMs: 100 * H, overtimeMs: 12 * H + 30 * M, workDays: 200,
    vacationDays: 28, sickDays: 4, holidayDays: 9,
    months: Array.from({ length: 12 }, (_, i) => ({ month: i + 1, workedMs: 0, overtimeMs: 0, workDays: 0 })),
    ...over,
  };
}

/** Antwort wie vom Backend: Differenzen kommen fertig mit (der Client rechnet nichts). */
function comparison(year: number, over: Partial<YearlyComparison> = {}): YearlyComparison {
  return {
    until: null,
    current: summary(year, { totalWorkedMs: 1680 * H + 15 * M, overtimeMs: -(3 * H + 45 * M), workDays: 205, vacationDays: 25, sickDays: 4, holidayDays: 10 }),
    previous: summary(year - 1),
    delta: {
      workedMs: 80 * H + 15 * M, workedPercent: 5, overtimeMs: -(16 * H + 15 * M), workDays: 5, vacationDays: -3,
      sickDays: 0, holidayDays: 1,
    },
    ...over,
  };
}

interface World {
  user$: BehaviorSubject<{ uid: string } | null>;
  isPremium: ReturnType<typeof signal<boolean>>;
  workProfile: FakeWorkProfile;
  getYearlyComparison: ReturnType<typeof vi.fn>;
}

describe('YearlyComparisonCardComponent (#530)', () => {
  let fixture: ComponentFixture<YearlyComparisonCardComponent>;

  afterEach(() => TestBed.resetTestingModule());

  function mount(
    respond: (year: number, until?: string, pid?: string) => Observable<YearlyComparison>,
    opts: { year?: number; lang?: 'de' | 'en'; now?: Date; premium?: boolean; loggedIn?: boolean } = {},
  ): World {
    const world: World = {
      user$: new BehaviorSubject<{ uid: string } | null>(opts.loggedIn === false ? null : { uid: 'u1' }),
      isPremium: signal(opts.premium ?? true),
      workProfile: createFakeWorkProfile(),
      getYearlyComparison: vi.fn(respond),
    };
    // Fester „heute“-Tag über dieselbe Uhr wie die Urlaubsübersicht: unabhängig vom Ausführungsdatum.
    const now = opts.now ?? new Date(2026, 10, 14, 9, 30);
    TestBed.configureTestingModule({
      imports: [YearlyComparisonCardComponent],
      providers: [
        provideTranslateService({ fallbackLang: 'de' }),
        { provide: AuthService, useValue: { user$: world.user$ } },
        { provide: ProfileService, useValue: { isPremium: world.isPremium } },
        { provide: WorkProfileService, useValue: world.workProfile },
        { provide: ApiClient, useValue: { getYearlyComparison: world.getYearlyComparison } },
        { provide: LEAVE_NOW, useValue: () => now },
      ],
    });
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('de', de);
    translate.setTranslation('en', en);
    translate.use(opts.lang ?? 'de');
    fixture = TestBed.createComponent(YearlyComparisonCardComponent);
    fixture.componentRef.setInput('year', opts.year ?? 2025);
    render();
    return world;
  }

  function render(): void {
    fixture.detectChanges();
    TestBed.tick();
    fixture.detectChanges();
  }

  const el = (): HTMLElement => fixture.nativeElement as HTMLElement;
  const text = (): string => el().textContent?.replace(/\s+/g, ' ').trim() ?? '';
  const cells = (key: string): string[] =>
    [...el().querySelectorAll(`tr[data-row="${key}"] > *`)].map(c => c.textContent?.replace(/\s+/g, ' ').trim() ?? '');

  it('abgeschlossenes Jahr: Anfrage ohne until, alle sechs Zeilen mit Jahr, Vorjahr und Differenz', () => {
    const w = mount(year => of(comparison(year)));
    expect(w.getYearlyComparison).toHaveBeenCalledTimes(1);
    expect(w.getYearlyComparison).toHaveBeenCalledWith(2025, undefined, undefined);

    expect(text()).toContain('Vergleich 2025 mit 2024');
    const head = [...el().querySelectorAll('thead th')].map(c => c.textContent?.trim());
    expect(head).toEqual(['Kennzahl', '2025', '2024', 'Differenz']);
    expect(el().querySelectorAll('thead th[scope="col"]')).toHaveLength(4);
    expect(el().querySelectorAll('tbody th[scope="row"]')).toHaveLength(6);
    expect(el().querySelector('caption')?.textContent?.trim()).toBe('Jahresvergleich 2025 mit dem Vorjahr 2024');

    expect(cells('worked')).toEqual(['Arbeitszeit (netto)', '1680:15', '1600:00', '+80:15 (+5,0 %)']);
    expect(cells('overtime')).toEqual(['Überstunden', '-03:45', '+12:30', '-16:15']);
    expect(cells('workDays')).toEqual(['Arbeitstage', '205', '200', '+5']);
    expect(cells('vacationDays')).toEqual(['Urlaubstage', '25', '28', '-3']);
    expect(cells('sickDays')).toEqual(['Krankheitstage', '4', '4', '0']);
    expect(cells('holidayDays')).toEqual(['Feiertage', '10', '9', '+1']);
    // Kein Stichtag-Hinweis für ein abgeschlossenes Jahr, Hinweis zu Saldo/Einstellungen vorhanden.
    expect(el().querySelector('.yc-until')).toBeNull();
    expect(text()).toContain('nicht dein Gleitzeit-Saldo');
  });

  it('Differenzen nur über Vorzeichen, keine Wertungsfarbe', () => {
    mount(year => of(comparison(year)));
    const diffs = [...el().querySelectorAll('.yc-diff')];
    expect(diffs).toHaveLength(6);
    for (const d of diffs) expect(d.className).not.toMatch(/positive|negative|good|bad|up|down/);
  });

  it('laufendes Jahr: until=MM-dd aus der Uhr der Urlaubsübersicht und Hinweis „jeweils bis TT.MM.“', () => {
    const w = mount(year => of(comparison(year, { until: '11-14' })), { year: 2026 });
    expect(w.getYearlyComparison).toHaveBeenCalledWith(2026, '11-14', undefined);
    expect(el().querySelector('.yc-until span')?.textContent?.trim())
      .toBe('Laufendes Jahr: beide Jahre jeweils bis 14.11.');
  });

  it('laufendes Jahr im Januar: until mit führenden Nullen', () => {
    const w = mount(year => of(comparison(year, { until: '01-05' })), { year: 2027, now: new Date(2027, 0, 5) });
    expect(w.getYearlyComparison).toHaveBeenCalledWith(2027, '01-05', undefined);
    expect(text()).toContain('jeweils bis 05.01.');
  });

  it('Hinweis kommt aus dem until der Antwort (Englisch)', () => {
    mount(year => of(comparison(year, { until: '02-29' })), { year: 2026, lang: 'en' });
    expect(text()).toContain('Current year: both years up to 02/29');
    expect(cells('worked')).toEqual(['Working time (net)', '1680:15', '1600:00', '+80:15 (+5.0 %)']);
  });

  it('Vorjahr ohne Daten: Spalte „keine Daten“, keine Differenz und keine 0', () => {
    mount(year => of(comparison(year, {
      previous: summary(year - 1, {
        hasData: false, totalWorkedMs: 0, totalBreaksMs: 0, overtimeMs: 0, workDays: 0, vacationDays: 0, sickDays: 0, holidayDays: 0,
      }),
      delta: null,
    })));
    for (const key of ['worked', 'overtime', 'workDays', 'vacationDays', 'sickDays', 'holidayDays']) {
      const [, , previous, diff] = cells(key);
      expect(previous).toBe('keine Daten');
      expect(diff).toBe('–keine Differenz'); // „–“ nur sichtbar (aria-hidden), Screenreader hören „keine Differenz“
      expect(diff).not.toContain('0');
    }
    expect(text()).toContain('Für 2024 gibt es keine Einträge, deshalb gibt es keine Differenz.');
  });

  it('workedPercent = null: Differenz ohne Prozent', () => {
    mount(year => {
      const c = comparison(year);
      return of({ ...c, delta: { ...c.delta!, workedPercent: null } });
    });
    expect(cells('worked')[3]).toBe('+80:15');
    expect(el().querySelector('.yc-percent')).toBeNull();
  });

  it('negativer Prozentwert mit einer Nachkommastelle', () => {
    mount(year => {
      const c = comparison(year);
      return of({ ...c, delta: { ...c.delta!, workedMs: -(12 * H), workedPercent: -12.4 } });
    });
    expect(cells('worked')[3]).toBe('-12:00 (-12,4 %)');
  });

  it('aktuelles Jahr ohne Daten: Leerzustand statt Tabelle', () => {
    mount(year => of(comparison(year, {
      current: summary(year, {
        hasData: false, totalWorkedMs: 0, totalBreaksMs: 0, overtimeMs: 0, workDays: 0, vacationDays: 0, sickDays: 0, holidayDays: 0,
      }),
    })));
    expect(el().querySelector('table')).toBeNull();
    expect(text()).toContain('Für 2025 gibt es noch keine Einträge, deshalb ist kein Vergleich möglich.');
  });

  it('Ladezustand: Spinner mit Statusrolle, aria-busy', () => {
    mount(() => new Subject<YearlyComparison>());
    expect(el().querySelector('.yc-loading[role="status"]')).not.toBeNull();
    expect(el().querySelector('section')?.getAttribute('aria-busy')).toBe('true');
    expect(el().querySelector('table')).toBeNull();
  });

  it('Fehlerzustand mit „Erneut versuchen“, das neu lädt', () => {
    let fail = true;
    const w = mount(year => (fail ? throwError(() => new Error('offline')) : of(comparison(year))));
    expect(el().querySelector('.yc-error[role="alert"]')).not.toBeNull();
    expect(text()).toContain('Der Jahresvergleich konnte nicht geladen werden.');

    fail = false;
    el().querySelector<HTMLButtonElement>('.yc-error button')!.click();
    render();
    expect(w.getYearlyComparison).toHaveBeenCalledTimes(2);
    expect(el().querySelector('table')).not.toBeNull();
  });

  it('Jahreswechsel und Profilwechsel laden neu', () => {
    const w = mount(year => of(comparison(year)));
    fixture.componentRef.setInput('year', 2024);
    render();
    expect(w.getYearlyComparison).toHaveBeenLastCalledWith(2024, undefined, undefined);
    expect(text()).toContain('Vergleich 2024 mit 2023');

    w.workProfile.set('p2');
    render();
    expect(w.getYearlyComparison).toHaveBeenLastCalledWith(2024, undefined, 'p2');
    expect(w.getYearlyComparison).toHaveBeenCalledTimes(3);
  });

  it('Jahr 2000: keine Anfrage, Hinweis statt Vergleich', () => {
    const w = mount(year => of(comparison(year)), { year: 2000 });
    expect(w.getYearlyComparison).not.toHaveBeenCalled();
    expect(text()).toContain('Für 2000 ist kein Vergleich mit dem Vorjahr möglich.');
    expect(el().querySelector('table')).toBeNull();
  });

  it('kein API-Aufruf ohne Premium oder ohne Anmeldung, dann auch keine Karte', () => {
    const free = mount(year => of(comparison(year)), { premium: false });
    expect(free.getYearlyComparison).not.toHaveBeenCalled();
    expect(el().querySelector('section')).toBeNull();
    TestBed.resetTestingModule();

    const anon = mount(year => of(comparison(year)), { premium: false, loggedIn: false });
    expect(anon.getYearlyComparison).not.toHaveBeenCalled();
    expect(el().querySelector('section')).toBeNull();
  });

  it('Premium läuft ab bzw. Abmelden: Karte verschwindet, kein weiterer Aufruf', () => {
    const w = mount(year => of(comparison(year)));
    expect(w.getYearlyComparison).toHaveBeenCalledTimes(1);
    w.isPremium.set(false);
    render();
    expect(el().querySelector('section')).toBeNull();
    w.isPremium.set(true);
    w.user$.next(null);
    render();
    expect(el().querySelector('section')).toBeNull();
    expect(w.getYearlyComparison).toHaveBeenCalledTimes(1);
  });
});
