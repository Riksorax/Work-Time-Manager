import { TestBed } from '@angular/core/testing';
import { signal } from '@angular/core';
import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { TranslateService, provideTranslateService } from '@ngx-translate/core';
import { BehaviorSubject } from 'rxjs';
import { InsightsViewService } from './insights-view.service';
import { InsightsViewComponent } from './insights-view';
import { AuthService } from '../../../../core/auth/auth';
import { ProfileService } from '../../../../core/services/profile';
import { BROWSER_TIME_ZONE } from '../../../../core/services/time-zone';
import { TodayService } from '../../../../core/services/today';
import { WorkProfileService } from '../../../../core/services/work-profile';
import { createFakeWorkProfile } from '../../../../shared/testing/work-profile-fake';
import de from '../../../../../../public/i18n/de.json';

/**
 * Zonen-Regressionstest (#537, Muster #407): Bezugstag und Zeitraum sind Kalendertage. Westlich (Los Angeles) und östlich
 * (Auckland) von UTC darf sich kein Tag verschieben: der Pfad trägt den lokalen Tag, `from`/`to` werden zerlegt, nicht
 * über `new Date(iso)` gelesen. Läuft in CI zusätzlich unter `TZ=America/Los_Angeles` und `TZ=Pacific/Auckland`.
 */
describe('Insights: Kalendertage zonenfest (#537)', () => {
  afterEach(() => TestBed.resetTestingModule());

  it('Bezugstag im Pfad und Zeitraum-Beschriftung ohne Tagesverschiebung', () => {
    TestBed.configureTestingModule({
      imports: [InsightsViewComponent],
      providers: [
        provideHttpClient(), provideHttpClientTesting(), provideTranslateService({ fallbackLang: 'de' }),
        InsightsViewService,
        { provide: AuthService, useValue: { user$: new BehaviorSubject({ uid: 'u1' }) } },
        { provide: ProfileService, useValue: { isPremium: signal(true) } },
        // Monatserster: liest jemand den Tag über UTC, landet er westlich von UTC im Vormonat.
        { provide: TodayService, useValue: { today: signal('2026-11-01') } },
        { provide: BROWSER_TIME_ZONE, useValue: () => 'Europe/Berlin' },
        { provide: WorkProfileService, useValue: createFakeWorkProfile() },
      ],
    });
    TestBed.overrideComponent(InsightsViewComponent, { set: { providers: [] } });
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('de', de);
    translate.use('de');
    const http = TestBed.inject(HttpTestingController);

    const fixture = TestBed.createComponent(InsightsViewComponent);
    fixture.detectChanges();
    TestBed.tick();

    const req = http.expectOne(r => r.url.includes('/reports/insights/'));
    expect(req.request.url.endsWith('/reports/insights/2026/11/1')).toBe(true);
    req.flush({
      from: '2026-09-01', to: '2026-11-30', timeZone: 'Europe/Berlin', dailyTargetMs: 0, weekdayAverages: [],
      overtimeStreak: { currentStreak: 0, longestStreak: 0, isWarning: false, warningThresholdDays: 5 }, startTimeHeatmap: [],
    });
    fixture.detectChanges();
    const period = (fixture.nativeElement as HTMLElement).querySelector('.ins-period span')?.textContent ?? '';
    expect(period).toMatch(/1\.\sSept?\.?\s–\s30\.\sNov\.?\s2026/);
    http.verify();
  });
});
