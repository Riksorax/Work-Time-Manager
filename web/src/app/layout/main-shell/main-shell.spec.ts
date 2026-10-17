import { signal } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { provideTranslateService } from '@ngx-translate/core';
import { AuthService } from '../../core/auth/auth';
import { MainShellComponent } from './main-shell';

describe('MainShellComponent: Logo (#437)', () => {
  let fixture: ComponentFixture<MainShellComponent>;

  beforeEach(async () => {
    // jsdom kennt matchMedia nicht; der BreakpointObserver braucht es. Desktop-Breite: nichts passt auf XSmall/Small.
    vi.stubGlobal('matchMedia', (query: string) => ({
      matches: false, media: query, addEventListener: () => {}, removeEventListener: () => {},
      addListener: () => {}, removeListener: () => {}, onchange: null, dispatchEvent: () => false,
    }));
    await TestBed.configureTestingModule({
      imports: [MainShellComponent],
      providers: [
        provideRouter([]),
        provideTranslateService({ fallbackLang: 'de' }),
        { provide: AuthService, useValue: { user: signal(null), signOut: vi.fn() } },
      ],
    }).compileComponents();
    fixture = TestBed.createComponent(MainShellComponent);
    fixture.detectChanges();
  });

  afterEach(() => vi.unstubAllGlobals());

  const header = (): HTMLElement => fixture.nativeElement.querySelector('.sidenav-header');

  it('zeigt das Logo als dekoratives Bild (alt="") statt des schedule-Icons', () => {
    const img = header().querySelector('img.sidenav-logo') as HTMLImageElement;
    expect(img).not.toBeNull();
    expect(img.getAttribute('alt')).toBe('');
    expect(img.getAttribute('src')).toContain('logo.svg');
    expect(header().querySelector('mat-icon')).toBeNull();
    expect(header().textContent).not.toContain('schedule');
  });

  it('gibt dem Bild feste Maße gegen Layout-Sprünge', () => {
    const img = header().querySelector('img.sidenav-logo') as HTMLImageElement;
    expect(img.getAttribute('width')).toBe('28');
    expect(img.getAttribute('height')).toBe('28');
  });
});
