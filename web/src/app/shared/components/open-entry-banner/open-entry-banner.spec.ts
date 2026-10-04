import { ComponentFixture, TestBed } from '@angular/core/testing';
import { TranslateService, provideTranslateService } from '@ngx-translate/core';
import { OpenEntryBannerComponent } from './open-entry-banner';
import de from '../../../../../public/i18n/de.json';
import en from '../../../../../public/i18n/en.json';

describe('OpenEntryBannerComponent (#385)', () => {
  let fixture: ComponentFixture<OpenEntryBannerComponent>;
  let translate: TranslateService;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [OpenEntryBannerComponent],
      providers: [provideTranslateService({ fallbackLang: 'de' })],
    }).compileComponents();
    translate = TestBed.inject(TranslateService);
    translate.setTranslation('de', de);
    translate.setTranslation('en', en);
    translate.use('de');
    fixture = TestBed.createComponent(OpenEntryBannerComponent);
    fixture.componentRef.setInput('dateText', 'Fr., 2.10.');
    fixture.componentRef.setInput('time', '22:00');
    fixture.componentRef.setInput('moreCount', 0);
    fixture.componentRef.setInput('busy', false);
    fixture.detectChanges();
  });

  afterEach(() => TestBed.resetTestingModule());

  const el = (): HTMLElement => fixture.nativeElement;
  const buttons = (): HTMLButtonElement[] => Array.from(el().querySelectorAll('button'));
  const button = (text: string): HTMLButtonElement => buttons().find(b => b.textContent!.includes(text))!;

  it('zeigt Datum und Startzeit auf Deutsch', () => {
    expect(el().textContent).toContain('Dein Eintrag vom Fr., 2.10. läuft noch seit 22:00.');
    expect(button('Später')).toBeTruthy();
    expect(button('Beenden')).toBeTruthy();
  });

  it('zeigt die englische Variante', () => {
    translate.use('en');
    fixture.detectChanges();
    expect(el().textContent).toContain('Your entry from Fr., 2.10. has been running since 22:00.');
    expect(button('Later')).toBeTruthy();
    expect(button('End')).toBeTruthy();
  });

  it('„Noch n weitere" nur bei n > 0, Plural 1 / n', () => {
    expect(el().textContent).not.toContain('weiter');
    fixture.componentRef.setInput('moreCount', 1);
    fixture.detectChanges();
    expect(el().textContent).toContain('Noch 1 weiterer offener Eintrag');
    fixture.componentRef.setInput('moreCount', 3);
    fixture.detectChanges();
    expect(el().textContent).toContain('Noch 3 weitere offene Einträge');
    expect(el().textContent).not.toContain('weiterer');
  });

  it('englischer Plural', () => {
    translate.use('en');
    fixture.componentRef.setInput('moreCount', 1);
    fixture.detectChanges();
    expect(el().textContent).toContain('1 more open entry');
    fixture.componentRef.setInput('moreCount', 2);
    fixture.detectChanges();
    expect(el().textContent).toContain('2 more open entries');
  });

  it('Klicks lösen end bzw. later aus', () => {
    const end = vi.fn();
    const later = vi.fn();
    fixture.componentInstance.end.subscribe(end);
    fixture.componentInstance.later.subscribe(later);
    button('Beenden').click();
    expect(end).toHaveBeenCalledTimes(1);
    expect(later).not.toHaveBeenCalled();
    button('Später').click();
    expect(later).toHaveBeenCalledTimes(1);
  });

  it('busy deaktiviert beide Buttons und blockiert die Ausgaben', () => {
    const end = vi.fn();
    fixture.componentInstance.end.subscribe(end);
    fixture.componentRef.setInput('busy', true);
    fixture.detectChanges();
    expect(buttons().length).toBe(2);
    expect(buttons().every(b => b.disabled)).toBe(true);
    button('Beenden').click();
    expect(end).not.toHaveBeenCalled();
  });

  it('Icon ist aria-hidden, role="status" hängt nur am Textblock (nicht an den Buttons)', () => {
    expect(el().querySelector('mat-icon')!.getAttribute('aria-hidden')).toBe('true');
    const statusEls = el().querySelectorAll('[role="status"]');
    expect(statusEls.length).toBe(1);
    expect(statusEls[0].querySelector('button')).toBeNull();
    expect(statusEls[0].textContent).toContain('Dein Eintrag vom');
  });

  it('die Buttons verweisen per aria-describedby auf den existierenden Titeltext', () => {
    for (const b of buttons()) {
      const id = b.getAttribute('aria-describedby')!;
      expect(id).toBeTruthy();
      const target = el().querySelector(`#${id}`)!;
      expect(target.textContent).toContain('Dein Eintrag vom Fr., 2.10.');
    }
  });

  it('zwei Banner haben verschiedene Titel-IDs', () => {
    const other = TestBed.createComponent(OpenEntryBannerComponent);
    other.componentRef.setInput('dateText', 'x');
    other.componentRef.setInput('time', 'y');
    other.componentRef.setInput('moreCount', 0);
    other.componentRef.setInput('busy', false);
    other.detectChanges();
    const idOf = (f: ComponentFixture<OpenEntryBannerComponent>): string =>
      (f.nativeElement as HTMLElement).querySelector('button')!.getAttribute('aria-describedby')!;
    expect(idOf(other)).not.toBe(idOf(fixture));
  });

  it('focus() setzt den Fokus auf den ersten Button', () => {
    document.body.appendChild(el());
    fixture.componentInstance.focus();
    expect(document.activeElement).toBe(buttons()[0]);
    el().remove();
  });
});
