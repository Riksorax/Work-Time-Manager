import { ComponentFixture, TestBed } from '@angular/core/testing';
import { TranslateService, provideTranslateService } from '@ngx-translate/core';
import { YearlyLeaveReport } from '../../../../domain/models/leave.models';
import { LeaveReportPrintComponent } from './leave-report-print';
import { LeaveReportPrintData } from './leave-report-print.service';
import de from '../../../../../../public/i18n/de.json';
import en from '../../../../../../public/i18n/en.json';

/** Druckansicht der Urlaubs- und Krankheitsauswertung (#284): reine Darstellung der Backend-Antwort. */
describe('LeaveReportPrintComponent', () => {
  let fixture: ComponentFixture<LeaveReportPrintComponent>;

  const months = (vac: Record<number, number> = {}, sick: Record<number, number> = {}) =>
    Array.from({ length: 12 }, (_, i) => ({ month: i + 1, vacationDays: vac[i + 1] ?? 0, sickDays: sick[i + 1] ?? 0 }));

  const report = (over: Partial<YearlyLeaveReport> = {}): YearlyLeaveReport => ({
    year: 2026, vacationDaysPerYear: 30, vacationDaysTaken: 13, vacationDaysRemaining: 17, sickDays: 3,
    months: months({ 8: 12, 12: 1 }, { 2: 3 }),
    vacationPeriods: [
      { start: '2026-08-03', end: '2026-08-14', days: 12 },
      { start: '2026-12-23', end: '2026-12-23', days: 1 },
    ],
    sickPeriods: [{ start: '2026-02-10', end: '2026-02-12', days: 3 }],
    ...over,
  });

  function mount(data: Partial<LeaveReportPrintData> = {}, lang: 'de' | 'en' = 'de'): HTMLElement {
    TestBed.configureTestingModule({
      imports: [LeaveReportPrintComponent],
      providers: [provideTranslateService({ fallbackLang: 'de' })],
    });
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('de', de);
    translate.setTranslation('en', en);
    translate.use(lang);
    fixture = TestBed.createComponent(LeaveReportPrintComponent);
    fixture.componentRef.setInput('data', {
      report: report(), isCurrentYear: true, profileName: null, createdAt: new Date(2026, 10, 15, 9, 30), ...data,
    });
    fixture.detectChanges();
    return fixture.nativeElement as HTMLElement;
  }

  const text = (el: HTMLElement, sel: string) => el.querySelector(sel)?.textContent?.replace(/\s+/g, ' ').trim() ?? '';
  const texts = (el: HTMLElement, sel: string) =>
    [...el.querySelectorAll(sel)].map(n => n.textContent?.replace(/\s+/g, ' ').trim());

  it('ist nur für den Druck markiert (Host-Klassen)', () => {
    const el = mount();
    expect(el.classList).toContain('print-only');
    expect(el.classList).toContain('leave-print');
  });

  it('Titel mit Jahr und Erstellungsdatum, ohne Profilname beim Standard-Profil', () => {
    const el = mount();
    expect(text(el, 'h2')).toBe('Urlaubs- und Krankheitsauswertung 2026');
    expect(text(el, '.lr-meta')).toBe('Erstellt am 15.11.2026');
    expect(text(el, '.lr-meta')).not.toContain('Profil');
  });

  it('nennt bei einem Zusatzprofil den Profilnamen', () => {
    const el = mount({ profileName: 'Nebenjob' });
    expect(text(el, '.lr-meta')).toContain('Profil: Nebenjob');
  });

  it('laufendes Jahr: Summen mit Anspruch und Resturlaub, kein Hinweis', () => {
    const el = mount();
    expect(texts(el, '.lr-summary dt')).toEqual(['Urlaubstage genommen', 'Krankheitstage', 'Urlaubsanspruch', 'Resturlaub']);
    expect(texts(el, '.lr-summary dd')).toEqual(['13', '3', '30', '17']);
    expect(el.querySelector('.lr-note')).toBeNull();
  });

  it('vergangenes Jahr: ohne Anspruch und Resturlaub, mit Hinweis', () => {
    const el = mount({ isCurrentYear: false, report: report({ year: 2025 }) });
    expect(texts(el, '.lr-summary dt')).toEqual(['Urlaubstage genommen', 'Krankheitstage']);
    expect(text(el, '.lr-note')).toBe('Anspruch und Resturlaub werden nur für das laufende Jahr ausgewiesen.');
  });

  it('Monatstabelle: 12 Monate in der App-Sprache plus Summenzeile aus den Backend-Werten', () => {
    const el = mount();
    const rows = el.querySelectorAll('tbody tr');
    expect(rows.length).toBe(12);
    expect(texts(el, 'tbody th')[0]).toBe('Januar');
    expect(texts(el, 'tbody tr:nth-child(8) > *')).toEqual(['August', '12', '0']);
    expect(texts(el, 'tbody tr:nth-child(2) > *')).toEqual(['Februar', '0', '3']);
    expect(texts(el, 'tfoot tr > *')).toEqual(['Summe', '13', '3']);
    expect(el.querySelector('caption')?.textContent).toContain('je Monat');
  });

  it('Zeiträume getrennt nach Urlaub und Krank, ein Tag ohne Bereich', () => {
    const el = mount();
    expect(texts(el, '.lr-vacation li')).toEqual(['03.08.–14.08. (12 Tage)', '23.12. (1 Tag)']);
    expect(texts(el, '.lr-sick li')).toEqual(['10.02.–12.02. (3 Tage)']);
  });

  it('nur Urlaub: Krankheitszeiträume sagen „Keine“', () => {
    const el = mount({ report: report({ sickDays: 0, sickPeriods: [], months: months({ 8: 12, 12: 1 }) }) });
    expect(texts(el, '.lr-sick li')).toEqual(['Keine']);
    expect(el.querySelector('.lr-empty')).toBeNull();
  });

  it('Jahr ohne Urlaub und Krankheit: Auswertung mit Hinweis, Tabelle mit Nullen, keine Zeitraumlisten', () => {
    const el = mount({ report: report({
      vacationDaysTaken: 0, vacationDaysRemaining: 30, sickDays: 0, months: months(), vacationPeriods: [], sickPeriods: [],
    }) });
    expect(text(el, 'h2')).toBe('Urlaubs- und Krankheitsauswertung 2026');
    expect(text(el, '.lr-empty')).toBe('In 2026 wurden keine Urlaubs- oder Krankheitstage erfasst.');
    expect(el.querySelectorAll('tbody tr').length).toBe(12);
    expect(texts(el, 'tfoot tr > *')).toEqual(['Summe', '0', '0']);
    expect(el.querySelector('.lr-periods')).toBeNull();
  });

  it('Fußnote mit der Zählregel', () => {
    const el = mount();
    expect(text(el, '.lr-footnote')).toContain('ein Tag, auch am Wochenende');
    expect(text(el, '.lr-footnote')).toContain('Feiertage zählen nicht');
  });

  it('älteres Backend ohne Aufschlüsselung: keine Tabelle, Summen bleiben', () => {
    const el = mount({ report: report({ months: undefined, vacationPeriods: undefined, sickPeriods: undefined }) });
    expect(el.querySelector('table')).toBeNull();
    expect(texts(el, '.lr-summary dd')).toEqual(['13', '3', '30', '17']);
    expect(texts(el, '.lr-vacation li')).toEqual(['Keine']);
  });

  it('Englisch: Texte, Monatsnamen und Datumsformat der App-Sprache', () => {
    const el = mount({ profileName: 'Side job' }, 'en');
    expect(text(el, 'h2')).toBe('Vacation and sick-day report 2026');
    expect(text(el, '.lr-meta')).toContain('Profile: Side job');
    expect(text(el, '.lr-meta')).toContain('Created on Nov 15, 2026');
    expect(texts(el, 'tbody th')[7]).toBe('August');
    expect(texts(el, '.lr-vacation li')).toEqual(['08/03–08/14 (12 days)', '12/23 (1 day)']);
  });
});
