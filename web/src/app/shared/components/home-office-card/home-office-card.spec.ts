import { ComponentFixture, TestBed } from '@angular/core/testing';
import { signal } from '@angular/core';
import { TranslateService, provideTranslateService } from '@ngx-translate/core';
import { BehaviorSubject, Observable, Subject, of, throwError } from 'rxjs';
import { HomeOfficeCardComponent } from './home-office-card';
import { AuthService } from '../../../core/auth/auth';
import { ApiClient } from '../../../core/services/api-client';
import { ProfileService } from '../../../core/services/profile';
import { WorkProfileService } from '../../../core/services/work-profile';
import { HomeOfficeReport } from '../../../domain/models/home-office.models';
import { FakeWorkProfile, createFakeWorkProfile } from '../../testing/work-profile-fake';
import de from '../../../../../public/i18n/de.json';
import en from '../../../../../public/i18n/en.json';

function report(year: number, over: Partial<HomeOfficeReport> = {}): HomeOfficeReport {
  return {
    year, homeOfficeDays: 7, officeDays: 5, totalDays: 12, homeOfficeRatio: 7 / 12,
    months: Array.from({ length: 12 }, (_, i) => ({ month: i + 1, homeOfficeDays: 0, officeDays: 0, totalDays: 0, homeOfficeRatio: null })),
    homeOfficeDates: [],
    ...over,
  };
}

interface World {
  user$: BehaviorSubject<{ uid: string } | null>;
  isPremium: ReturnType<typeof signal<boolean>>;
  workProfile: FakeWorkProfile;
  getHomeOfficeReport: ReturnType<typeof vi.fn>;
}

describe('HomeOfficeCardComponent (#283, Backend seit #537)', () => {
  let fixture: ComponentFixture<HomeOfficeCardComponent>;

  afterEach(() => TestBed.resetTestingModule());

  function mount(
    respond: (year: number, pid?: string) => Observable<HomeOfficeReport>,
    opts: { year?: number; lang?: 'de' | 'en'; premium?: boolean; loggedIn?: boolean } = {},
  ): World {
    const world: World = {
      user$: new BehaviorSubject<{ uid: string } | null>(opts.loggedIn === false ? null : { uid: 'u1' }),
      isPremium: signal(opts.premium ?? true),
      workProfile: createFakeWorkProfile(),
      getHomeOfficeReport: vi.fn(respond),
    };
    TestBed.configureTestingModule({
      imports: [HomeOfficeCardComponent],
      providers: [
        provideTranslateService({ fallbackLang: 'de' }),
        { provide: AuthService, useValue: { user$: world.user$ } },
        { provide: ProfileService, useValue: { isPremium: world.isPremium } },
        { provide: WorkProfileService, useValue: world.workProfile },
        { provide: ApiClient, useValue: { getHomeOfficeReport: world.getHomeOfficeReport } },
      ],
    });
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('de', de);
    translate.setTranslation('en', en);
    translate.use(opts.lang ?? 'de');
    fixture = TestBed.createComponent(HomeOfficeCardComponent);
    fixture.componentRef.setInput('year', opts.year ?? 2026);
    render();
    return world;
  }

  function render(): void {
    fixture.detectChanges();
    TestBed.tick();
    fixture.detectChanges();
  }

  const el = () => fixture.nativeElement as HTMLElement;
  const text = (sel: string) => el().querySelector(sel)?.textContent?.replace(/\s+/g, ' ').trim() ?? null;

  it('lädt das Jahr vom Backend und zeigt die Werte wie bisher', () => {
    const w = mount(y => of(report(y)));
    expect(w.getHomeOfficeReport).toHaveBeenCalledTimes(1);
    expect(w.getHomeOfficeReport).toHaveBeenCalledWith(2026, undefined);
    expect(text('.ho-title')).toBe('Home-Office 2026');
    expect(text('.ho-value')).toBe('7');
    expect(text('.ho-of')).toBe('von 12 Arbeitstagen');
    const rows = [...el().querySelectorAll('.ho-row')].map(r => [...r.children].map(c => c.textContent?.trim()).join(' '));
    expect(rows).toEqual(['Anteil Home-Office 58,3 %', 'Tage im Büro 5']);
  });

  it('Anteil in der App-Sprache (Englisch mit Punkt)', () => {
    mount(y => of(report(y)), { lang: 'en' });
    expect(el().querySelectorAll('.ho-row dd')[0].textContent?.trim()).toBe('58.3 %');
  });

  it('ohne Bezugstage: Leerhinweis statt Zahlen', () => {
    mount(y => of(report(y, { homeOfficeDays: 0, officeDays: 0, totalDays: 0, homeOfficeRatio: null })));
    expect(el().querySelector('.ho-empty')).not.toBeNull();
    expect(el().querySelector('.ho-value')).toBeNull();
  });

  it('Ladezustand: Spinner mit Statusrolle und aria-busy', () => {
    const pending = new Subject<HomeOfficeReport>();
    mount(() => pending);
    expect(el().querySelector('.ho-loading[role="status"]')).not.toBeNull();
    expect(el().querySelector('.ho-card')?.getAttribute('aria-busy')).toBe('true');
    pending.next(report(2026));
    render();
    expect(el().querySelector('.ho-loading')).toBeNull();
    expect(text('.ho-value')).toBe('7');
  });

  it('Fehler zeigt „Erneut versuchen“, das neu lädt', () => {
    let fail = true;
    const w = mount(y => (fail ? throwError(() => new Error('offline')) : of(report(y))));
    expect(el().querySelector('.ho-error[role="alert"]')).not.toBeNull();
    fail = false;
    (el().querySelector('.ho-error button') as HTMLButtonElement).click();
    render();
    expect(w.getHomeOfficeReport).toHaveBeenCalledTimes(2);
    expect(text('.ho-value')).toBe('7');
  });

  it('Jahres- und Profilwechsel laden neu, mit profileId des aktiven Profils', () => {
    const w = mount(y => of(report(y)));
    fixture.componentRef.setInput('year', 2025);
    render();
    expect(w.getHomeOfficeReport).toHaveBeenLastCalledWith(2025, undefined);
    w.workProfile.set('p2');
    render();
    expect(w.getHomeOfficeReport).toHaveBeenLastCalledWith(2025, 'p2');
    expect(w.getHomeOfficeReport).toHaveBeenCalledTimes(3);
  });

  it('kein Aufruf ohne Premium oder ohne Anmeldung, dann auch keine Karte', () => {
    const w = mount(y => of(report(y)), { premium: false });
    expect(w.getHomeOfficeReport).not.toHaveBeenCalled();
    expect(el().querySelector('.ho-card')).toBeNull();
    TestBed.resetTestingModule();
    const w2 = mount(y => of(report(y)), { loggedIn: false });
    expect(w2.getHomeOfficeReport).not.toHaveBeenCalled();
    expect(el().querySelector('.ho-card')).toBeNull();
  });
});
