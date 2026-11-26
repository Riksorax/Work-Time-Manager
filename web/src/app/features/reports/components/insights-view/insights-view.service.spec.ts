import { TestBed } from '@angular/core/testing';
import { signal } from '@angular/core';
import { BehaviorSubject, Observable, Subject, of, throwError } from 'rxjs';
import { InsightsViewService } from './insights-view.service';
import { AuthService } from '../../../../core/auth/auth';
import { ApiClient } from '../../../../core/services/api-client';
import { ProfileService } from '../../../../core/services/profile';
import { BROWSER_TIME_ZONE } from '../../../../core/services/time-zone';
import { TodayService } from '../../../../core/services/today';
import { WorkProfileService } from '../../../../core/services/work-profile';
import { InsightsReport } from '../../../../domain/models/insights.models';
import { FakeWorkProfile, createFakeWorkProfile } from '../../../../shared/testing/work-profile-fake';

const report = (over: Partial<InsightsReport> = {}): InsightsReport => ({
  from: '2026-09-01', to: '2026-11-30', timeZone: 'Asia/Kolkata', dailyTargetMs: 28_800_000,
  weekdayAverages: [], overtimeStreak: { currentStreak: 0, longestStreak: 0, isWarning: false, warningThresholdDays: 5 },
  startTimeHeatmap: [], ...over,
});

/**
 * Laden der Insights (#537). Bezugstag und Zone sind im Test festgesetzt (`TodayService.today`, `BROWSER_TIME_ZONE`):
 * nichts hängt vom Ausführungsdatum oder der Zone des Testprozesses ab.
 */
describe('InsightsViewService (#537)', () => {
  let user$: BehaviorSubject<{ uid: string } | null>;
  let premium: ReturnType<typeof signal<boolean>>;
  let today: ReturnType<typeof signal<string>>;
  let zone: string;
  let workProfile: FakeWorkProfile;
  let getInsightsReport: ReturnType<typeof vi.fn>;

  function create(respond: () => Observable<InsightsReport> = () => of(report())): InsightsViewService {
    user$ = new BehaviorSubject<{ uid: string } | null>({ uid: 'u1' });
    premium = signal(true);
    today = signal('2026-11-26');
    zone = 'Asia/Kolkata';
    workProfile = createFakeWorkProfile();
    getInsightsReport = vi.fn(respond);
    TestBed.configureTestingModule({
      providers: [
        InsightsViewService,
        { provide: AuthService, useValue: { user$ } },
        { provide: ProfileService, useValue: { isPremium: premium } },
        { provide: TodayService, useValue: { today } },
        { provide: BROWSER_TIME_ZONE, useValue: () => zone },
        { provide: WorkProfileService, useValue: workProfile },
        { provide: ApiClient, useValue: { getInsightsReport } },
      ],
    });
    return TestBed.inject(InsightsViewService);
  }

  afterEach(() => TestBed.resetTestingModule());

  const lastDate = () => getInsightsReport.mock.calls.at(-1)![0] as Date;

  it('lädt erst nach attach(), mit Bezugstag heute (lokal) und der Zone des Browsers', () => {
    const svc = create();
    TestBed.tick();
    expect(getInsightsReport).not.toHaveBeenCalled();
    expect(svc.state().status).toBe('idle');

    svc.attach();
    TestBed.tick();
    expect(getInsightsReport).toHaveBeenCalledTimes(1);
    const [date, tz, pid] = getInsightsReport.mock.calls[0];
    expect([date.getFullYear(), date.getMonth(), date.getDate()]).toEqual([2026, 10, 26]);
    expect(tz).toBe('Asia/Kolkata');
    expect(pid).toBeUndefined();
    expect(svc.state().status).toBe('data');
  });

  it('Profil- und Tageswechsel laden neu (mit profileId und neuem Bezugstag)', () => {
    const svc = create();
    svc.attach();
    TestBed.tick();
    workProfile.set('p2');
    TestBed.tick();
    expect(getInsightsReport.mock.calls.at(-1)![2]).toBe('p2');
    today.set('2026-12-01');
    zone = 'Pacific/Auckland';
    TestBed.tick();
    expect([lastDate().getFullYear(), lastDate().getMonth(), lastDate().getDate()]).toEqual([2026, 11, 1]);
    expect(getInsightsReport.mock.calls.at(-1)![1]).toBe('Pacific/Auckland');
    expect(getInsightsReport).toHaveBeenCalledTimes(3);
  });

  it('ohne Premium oder ohne Anmeldung: kein Aufruf', () => {
    const svc = create();
    premium.set(false);
    svc.attach();
    TestBed.tick();
    expect(getInsightsReport).not.toHaveBeenCalled();
    premium.set(true);
    user$.next(null);
    TestBed.tick();
    expect(getInsightsReport).not.toHaveBeenCalled();
    expect(svc.state().status).toBe('idle');
  });

  it('Laden, Fehler und Wiederholen', () => {
    const pending = new Subject<InsightsReport>();
    let fail = false;
    const svc = create(() => (fail ? throwError(() => new Error('x')) : pending));
    svc.attach();
    TestBed.tick();
    expect(svc.state().status).toBe('loading');
    fail = true;
    svc.retry();
    expect(svc.state().status).toBe('error');
    fail = false;
    svc.retry();
    pending.next(report());
    expect(svc.state().status).toBe('data');
  });

  it('leer = weder Wochentage noch Startstunden (wie Mobile)', () => {
    const svc = create();
    svc.attach();
    TestBed.tick();
    expect(svc.isEmpty()).toBe(true);
  });

  it('nicht leer, sobald Wochentage vorliegen', () => {
    const svc = create(() => of(report({ weekdayAverages: [{ weekday: 1, averageWorkedMs: 1, deviationMs: 0, sampleCount: 1 }] })));
    svc.attach();
    TestBed.tick();
    expect(svc.isEmpty()).toBe(false);
  });

  it('detach beendet das Laden (Ansicht weg = idle)', () => {
    const svc = create();
    const detach = svc.attach();
    TestBed.tick();
    detach();
    detach();
    TestBed.tick();
    expect(svc.state().status).toBe('idle');
  });
});
