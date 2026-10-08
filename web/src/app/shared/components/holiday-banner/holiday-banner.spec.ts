import { ComponentFixture, TestBed } from '@angular/core/testing';
import { TranslateService, provideTranslateService } from '@ngx-translate/core';
import { HolidayBannerComponent } from './holiday-banner';

describe('HolidayBannerComponent', () => {
  let fixture: ComponentFixture<HolidayBannerComponent>;
  let translate: TranslateService;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [HolidayBannerComponent],
      providers: [provideTranslateService({ fallbackLang: 'de' })],
    }).compileComponents();
    translate = TestBed.inject(TranslateService);
    translate.setTranslation('de', {
      dashboard: { holidayToday: 'Heute ist Feiertag: {{name}}' },
      holidays: { germanUnityDay: 'Tag der Deutschen Einheit', newYear: 'Neujahr', repentanceDay: 'Buß- und Bettag' },
    });
    translate.setTranslation('en', {
      dashboard: { holidayToday: 'Today is a public holiday: {{name}}' },
      holidays: { repentanceDay: 'Repentance and Prayer Day' },
    });
    translate.use('de');
    fixture = TestBed.createComponent(HolidayBannerComponent);
    fixture.componentRef.setInput('holiday', 'germanUnityDay');
    fixture.detectChanges();
  });

  const root = (): HTMLElement => fixture.nativeElement.querySelector('.holiday-banner');

  it('zeigt Satz und übersetzten Namen', () => {
    expect(root().textContent).toContain('Heute ist Feiertag: Tag der Deutschen Einheit');
  });

  it('hat role="status" und ein aria-hidden-Icon', () => {
    expect(root().getAttribute('role')).toBe('status');
    expect(root().querySelector('mat-icon')!.getAttribute('aria-hidden')).toBe('true');
  });

  it('rendert die englische Variante mit langem Namen vollständig', () => {
    translate.use('en');
    fixture.componentRef.setInput('holiday', 'repentanceDay');
    fixture.detectChanges();
    expect(root().textContent).toContain('Today is a public holiday: Repentance and Prayer Day');
  });

  it('aktualisiert den Text bei Input-Wechsel', () => {
    fixture.componentRef.setInput('holiday', 'newYear');
    fixture.detectChanges();
    expect(root().textContent).toContain('Neujahr');
    expect(root().textContent).not.toContain('Einheit');
  });
});
