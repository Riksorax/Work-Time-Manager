import { ComponentFixture, TestBed } from '@angular/core/testing';
import { TranslateService, provideTranslateService } from '@ngx-translate/core';
import { CalendarComponent } from './calendar';

// Home-Office-Markierung im Kalender (#277). Feste Kalendertage im Juni 2026.
describe('CalendarComponent - Home-Office (#277)', () => {
  let fixture: ComponentFixture<CalendarComponent>;

  beforeEach(async () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date(2026, 5, 15, 12));
    await TestBed.configureTestingModule({
      imports: [CalendarComponent],
      providers: [provideTranslateService({ fallbackLang: 'de' })],
    }).compileComponents();
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('de', {
      common: { weekdaysShort: ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'] },
      shared: {
        calendarPrevMonthAria: 'Vorheriger Monat',
        calendarNextMonthAria: 'Nächster Monat',
        calendarHasEntryAria: '{{label}}, Eintrag vorhanden',
        calendarHomeOfficeAria: '{{label}}, Home-Office-Tag',
      },
    });
    translate.use('de');
    fixture = TestBed.createComponent(CalendarComponent);
    fixture.componentRef.setInput('selectedDate', new Date(2026, 5, 15));
    fixture.componentRef.setInput('daysWithEntries', [3, 4]);
    fixture.detectChanges();
  });

  afterEach(() => {
    vi.useRealTimers();
    vi.restoreAllMocks();
  });

  const cell = (key: string): HTMLElement => fixture.nativeElement.querySelector(`[data-date="${key}"]`) as HTMLElement;
  const icon = (key: string): HTMLElement | null => cell(key).querySelector('.home-office-icon');

  it('ohne Input keine Icons und unveränderte Aria-Labels', () => {
    expect(fixture.nativeElement.querySelectorAll('.home-office-icon')).toHaveLength(0);
    expect(cell('2026-06-03').getAttribute('aria-label')).toContain('Eintrag vorhanden');
    expect(cell('2026-06-03').getAttribute('aria-label')).not.toContain('Home-Office');
  });

  it('rendert das Icon nur an Home-Office-Tagen, aria-hidden', () => {
    fixture.componentRef.setInput('homeOfficeDays', [3]);
    fixture.detectChanges();
    expect(icon('2026-06-03')).toBeTruthy();
    expect(icon('2026-06-03')!.getAttribute('aria-hidden')).toBe('true');
    expect(icon('2026-06-04')).toBeNull();
    expect(fixture.nativeElement.querySelectorAll('.home-office-icon')).toHaveLength(1);
  });

  it('Aria-Label: Eintrag, danach Home-Office-Tag', () => {
    fixture.componentRef.setInput('homeOfficeDays', [3]);
    fixture.detectChanges();
    const label = cell('2026-06-03').getAttribute('aria-label')!;
    expect(label).toContain('Eintrag vorhanden');
    expect(label.endsWith('Home-Office-Tag')).toBe(true);
    expect(label.indexOf('Eintrag vorhanden')).toBeLessThan(label.indexOf('Home-Office-Tag'));
    expect(cell('2026-06-04').getAttribute('aria-label')).not.toContain('Home-Office');
  });
});
