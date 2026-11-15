import { TestBed } from '@angular/core/testing';
import { TranslateService, provideTranslateService } from '@ngx-translate/core';
import { LeaveReportPrintComponent } from './leave-report-print';
import de from '../../../../../../public/i18n/de.json';

/**
 * Zonen-Regressionstest (#284): Die Zeiträume kommen als Kalendertage `yyyy-MM-dd`. Als `new Date(iso)` geparst wären
 * sie UTC-Mitternacht und westlich von UTC (Los Angeles) der Vortag. CI fährt diese Datei zusätzlich unter
 * `TZ=America/Los_Angeles` und `TZ=Pacific/Auckland`.
 */
describe('LeaveReportPrintComponent: Kalendertage unabhängig von der Zeitzone', () => {
  it('Jahresanfang, Monatsgrenze und Jahresende bleiben ihr Kalendertag', () => {
    TestBed.configureTestingModule({
      imports: [LeaveReportPrintComponent],
      providers: [provideTranslateService({ fallbackLang: 'de' })],
    });
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('de', de);
    translate.use('de');
    const fixture = TestBed.createComponent(LeaveReportPrintComponent);
    fixture.componentRef.setInput('data', {
      report: {
        year: 2026, vacationDaysPerYear: 30, vacationDaysTaken: 3, vacationDaysRemaining: 27, sickDays: 2,
        months: [],
        vacationPeriods: [
          { start: '2026-01-01', end: '2026-01-01', days: 1 },
          { start: '2026-12-30', end: '2026-12-31', days: 2 },
        ],
        sickPeriods: [{ start: '2026-02-28', end: '2026-03-01', days: 2 }],
      },
      isCurrentYear: true, profileName: null, createdAt: new Date(2026, 0, 1),
    });
    fixture.detectChanges();
    const el = fixture.nativeElement as HTMLElement;
    const items = (sel: string) => [...el.querySelectorAll(sel)].map(n => n.textContent?.replace(/\s+/g, ' ').trim());
    expect(items('.lr-vacation li')).toEqual(['01.01. (1 Tag)', '30.12.–31.12. (2 Tage)']);
    expect(items('.lr-sick li')).toEqual(['28.02.–01.03. (2 Tage)']);
    expect(el.querySelector('.lr-meta')?.textContent).toContain('01.01.2026');
  });
});
