import { TestBed } from '@angular/core/testing';
import { Component, input, output, signal } from '@angular/core';
import { ComponentFixture } from '@angular/core/testing';
import { MatDialog } from '@angular/material/dialog';
import { MatSnackBar } from '@angular/material/snack-bar';
import { TranslateService, provideTranslateService } from '@ngx-translate/core';
import { Router } from '@angular/router';
import { DashboardComponent } from './dashboard';
import { DashboardService } from './dashboard.service';
import { OpenEntryService } from './open-entry';
import { createFakeOpenEntry, FakeOpenEntry } from '../../shared/testing/open-entry-fake';
import { LiveAnnouncer } from '@angular/cdk/a11y';
import { Subject, of } from 'rxjs';
import de from '../../../../public/i18n/de.json';
import en from '../../../../public/i18n/en.json';
import { LeaveBalanceService } from '../../core/services/leave-balance';
import { GermanHoliday } from '../../shared/utils/german-holidays.util';
import { HolidayBannerComponent } from '../../shared/components/holiday-banner/holiday-banner';
import { LeaveBalanceCardComponent } from '../../shared/components/leave-balance-card/leave-balance-card';
import { TimeInputComponent } from '../../shared/components/time-input/time-input';
import { WorkEntryType } from '../../shared/models/index';

describe('DashboardComponent.goToSettings', () => {
  it('navigiert zu /settings', () => {
    const navigate = vi.fn();
    TestBed.overrideComponent(DashboardComponent, { set: { template: '', imports: [] } });
    TestBed.configureTestingModule({
      providers: [
        { provide: DashboardService, useValue: {} },
        { provide: OpenEntryService, useValue: createFakeOpenEntry() },
        { provide: LeaveBalanceService, useValue: {} },
        { provide: Router, useValue: { navigate } },
        { provide: MatDialog, useValue: {} },
        { provide: MatSnackBar, useValue: {} },
        { provide: TranslateService, useValue: {} },
      ],
    });
    TestBed.createComponent(DashboardComponent).componentInstance.goToSettings();
    expect(navigate).toHaveBeenCalledWith(['/settings']);
  });
});

@Component({ selector: 'app-holiday-banner', template: '<div class="stub-banner">{{ holiday() }}</div>' })
class HolidayBannerStub { readonly holiday = input.required<GermanHoliday>(); }
@Component({ selector: 'app-leave-balance-card', template: '' })
class LeaveCardStub {
  readonly report = input<unknown>();
  readonly state = input<unknown>();
  readonly editable = input<boolean>();
  readonly localOnly = input<boolean>();
  readonly retry = output<void>();
  readonly editEntitlement = output<void>();
}
@Component({ selector: 'app-time-input', template: '' })
class TimeInputStub {
  readonly label = input<string>();
  readonly value = input<unknown>();
  readonly disabled = input<boolean>();
  readonly showClear = input<boolean>();
  readonly timeSelected = output<Date>();
}

describe('DashboardComponent Feiertags-Banner', () => {
  const holiday = signal<GermanHoliday | null>(null);
  const isLoading = signal(false);
  let fixture: ComponentFixture<DashboardComponent>;

  beforeEach(() => {
    holiday.set(null);
    isLoading.set(false);
    TestBed.overrideComponent(DashboardComponent, {
      remove: { imports: [HolidayBannerComponent, LeaveBalanceCardComponent, TimeInputComponent] },
      add: { imports: [HolidayBannerStub, LeaveCardStub, TimeInputStub] },
    });
    TestBed.configureTestingModule({
      providers: [
        provideTranslateService(),
        { provide: DashboardService, useValue: {
          isLoading, holidayToday: holiday, isLoggedIn: signal(false),
          netDuration: signal(0), grossDuration: signal(0), dailyOvertime: signal(0), totalOvertime: signal(0),
          isTimerRunning: signal(false), isBreakRunning: signal(false), expectedEndTime: signal(null),
          expectedEndTotalZero: signal(null), breaks: signal([]),
          workEntry: signal({ id: 'x', date: new Date(2026, 9, 3), breaks: [], isManuallyEntered: false, type: WorkEntryType.Work }),
        } },
        { provide: OpenEntryService, useValue: createFakeOpenEntry() },
        { provide: LeaveBalanceService, useValue: {
          currentYearReport: signal(null), currentYearState: signal('loading'), refresh: vi.fn() } },
        { provide: Router, useValue: { navigate: vi.fn() } },
        { provide: MatDialog, useValue: {} },
        { provide: MatSnackBar, useValue: {} },
      ],
    });
    fixture = TestBed.createComponent(DashboardComponent);
  });

  const banner = (): HTMLElement | null => fixture.nativeElement.querySelector('app-holiday-banner');

  it('rendert das Banner oberhalb des Inhalts, wenn heute Feiertag ist', () => {
    holiday.set('germanUnityDay');
    fixture.detectChanges();
    const el = banner()!;
    expect(el).toBeTruthy();
    expect(el.textContent).toContain('germanUnityDay');
    const content = fixture.nativeElement.querySelector('.dashboard-content') as HTMLElement;
    expect(el.compareDocumentPosition(content) & Node.DOCUMENT_POSITION_FOLLOWING).toBeTruthy();
  });

  it('rendert kein Banner ohne Feiertag', () => {
    fixture.detectChanges();
    expect(banner()).toBeNull();
    expect(fixture.nativeElement.querySelector('.dashboard-content')).toBeTruthy();
  });

  it('rendert kein Banner während des Ladens', () => {
    holiday.set('germanUnityDay');
    isLoading.set(true);
    fixture.detectChanges();
    expect(banner()).toBeNull();
  });
});


describe('DashboardComponent Banner für offene Einträge (#385)', () => {
  const holiday = signal<GermanHoliday | null>(null);
  const isLoading = signal(false);
  let fixture: ComponentFixture<DashboardComponent>;
  let fake: FakeOpenEntry;
  let dialogOpen: ReturnType<typeof vi.fn>;
  let dialogResult: Date | undefined;
  let snackOpen: ReturnType<typeof vi.fn>;
  let announce: ReturnType<typeof vi.fn>;
  let startOrStop: ReturnType<typeof vi.fn>;
  let translate: TranslateService;

  const FRI = { id: '2026-10-02', profileId: 'default' };
  const SAT_EARLIER = { id: '2026-10-01', profileId: 'default' };
  const friEntry = {
    id: '2026-10-02', date: new Date(2026, 9, 2), workStart: new Date(2026, 9, 2, 22, 0), breaks: [],
    isManuallyEntered: false, type: WorkEntryType.Work,
  };

  // Nur Microtasks, kein `setTimeout` (fremder Fake-Timer im Vollauf, #392).
  const flush = async (): Promise<void> => {
    for (let i = 0; i < 20; i++) { await Promise.resolve(); fixture.detectChanges(); }
  };
  const el = (): HTMLElement => fixture.nativeElement;
  const openBanner = (): HTMLElement | null => el().querySelector('app-open-entry-banner');
  const bannerButton = (text: string): HTMLButtonElement =>
    Array.from(openBanner()!.querySelectorAll('button')).find(b => b.textContent!.includes(text))!;

  beforeEach(() => {
    holiday.set(null);
    isLoading.set(false);
    dialogResult = undefined;
    dialogOpen = vi.fn(() => ({ afterClosed: () => of(dialogResult) }));
    snackOpen = vi.fn();
    announce = vi.fn().mockResolvedValue(undefined);
    startOrStop = vi.fn().mockResolvedValue(undefined);
    fake = createFakeOpenEntry();
    fake.entries.set({ '2026-10-02': friEntry, '2026-10-01': { ...friEntry, id: '2026-10-01' } });
    TestBed.overrideComponent(DashboardComponent, {
      remove: { imports: [HolidayBannerComponent, LeaveBalanceCardComponent, TimeInputComponent] },
      add: { imports: [HolidayBannerStub, LeaveCardStub, TimeInputStub] },
    });
    TestBed.configureTestingModule({
      providers: [
        provideTranslateService({ fallbackLang: 'de' }),
        { provide: DashboardService, useValue: {
          isLoading, holidayToday: holiday, isLoggedIn: signal(false), startOrStopTimer: startOrStop,
          netDuration: signal(0), grossDuration: signal(0), dailyOvertime: signal(0), totalOvertime: signal(0),
          isTimerRunning: signal(false), isBreakRunning: signal(false), expectedEndTime: signal(null),
          expectedEndTotalZero: signal(null), breaks: signal([]),
          workEntry: signal({ id: 'x', date: new Date(2026, 9, 3), breaks: [], isManuallyEntered: false, type: WorkEntryType.Work }),
        } },
        { provide: OpenEntryService, useValue: fake },
        { provide: LeaveBalanceService, useValue: {
          currentYearReport: signal(null), currentYearState: signal('loading'), refresh: vi.fn() } },
        { provide: Router, useValue: { navigate: vi.fn() } },
        { provide: MatDialog, useValue: { open: dialogOpen } },
        { provide: MatSnackBar, useValue: { open: snackOpen } },
        { provide: LiveAnnouncer, useValue: { announce } },
      ],
    });
    translate = TestBed.inject(TranslateService);
    translate.setTranslation('de', de);
    translate.setTranslation('en', en);
    translate.use('de');
    fixture = TestBed.createComponent(DashboardComponent);
    document.body.appendChild(fixture.nativeElement);
  });

  afterEach(() => {
    fixture.nativeElement.remove();
    TestBed.resetTestingModule();
  });

  it('rendert ohne offenen Eintrag keinen Banner', () => {
    fixture.detectChanges();
    expect(openBanner()).toBeNull();
  });

  it('rendert den Banner mit Datum und Startzeit, nicht beim Laden', () => {
    fake.current.set(FRI);
    isLoading.set(true);
    fixture.detectChanges();
    expect(openBanner()).toBeNull();
    isLoading.set(false);
    fixture.detectChanges();
    expect(openBanner()!.textContent).toMatch(/Dein Eintrag vom Fr\.?,? 2\.\s*10\.? läuft noch seit 22:00\./);
  });

  it('englische Oberfläche: Datum ohne deutsche Wochentage', () => {
    translate.use('en');
    fake.current.set(FRI);
    fixture.detectChanges();
    expect(openBanner()!.textContent).toContain('Fri');
    expect(openBanner()!.textContent).toContain('has been running since 22:00');
  });

  it('DOM-Reihenfolge: nach dem Feiertagsbanner, vor dem Inhalt', () => {
    holiday.set('germanUnityDay');
    fake.current.set(FRI);
    fixture.detectChanges();
    const holidayEl = el().querySelector('app-holiday-banner')!;
    const content = el().querySelector('.dashboard-content')!;
    expect(holidayEl.compareDocumentPosition(openBanner()!) & Node.DOCUMENT_POSITION_FOLLOWING).toBeTruthy();
    expect(openBanner()!.compareDocumentPosition(content) & Node.DOCUMENT_POSITION_FOLLOWING).toBeTruthy();
  });

  it('„Noch n weitere" kommt aus dem Service', () => {
    fake.current.set(FRI);
    fake.moreCount.set(2);
    fixture.detectChanges();
    expect(openBanner()!.textContent).toContain('Noch 2 weitere offene Einträge');
  });

  it('busy deaktiviert die Banner-Buttons', () => {
    fake.current.set(FRI);
    fake.busy.set(true);
    fixture.detectChanges();
    expect(bannerButton('Beenden').disabled).toBe(true);
    expect(bannerButton('Später').disabled).toBe(true);
  });

  describe('Beenden', () => {
    it('öffnet den Dialog mit den Daten des Services und ruft endEntry mit dem Ergebnis auf', async () => {
      fake.current.set(FRI);
      fixture.detectChanges();
      dialogResult = new Date(2026, 9, 2, 17, 0);
      bannerButton('Beenden').click();
      await flush();
      expect(dialogOpen).toHaveBeenCalledTimes(1);
      expect(dialogOpen.mock.calls[0][1].data.entry.id).toBe('2026-10-02');
      expect(fake.endCalls).toEqual([{ candidate: FRI, end: new Date(2026, 9, 2, 17, 0) }]);
    });

    it('Dialog-Abbruch: kein Service-Aufruf', async () => {
      fake.current.set(FRI);
      fixture.detectChanges();
      dialogResult = undefined;
      bannerButton('Beenden').click();
      await flush();
      expect(dialogOpen).toHaveBeenCalledTimes(1);
      expect(fake.endCalls).toEqual([]);
    });

    it('ohne Dialog-Daten (Eintrag nicht mehr verfügbar): kein Dialog', async () => {
      fake.current.set(FRI);
      fake.prepareResult = null;
      fixture.detectChanges();
      bannerButton('Beenden').click();
      await flush();
      expect(dialogOpen).not.toHaveBeenCalled();
    });

    it('Doppelklick öffnet nur einen Dialog', async () => {
      fake.current.set(FRI);
      fixture.detectChanges();
      const closed = new Subject<Date | undefined>(); // Dialog bleibt offen
      dialogOpen.mockReturnValue({ afterClosed: () => closed });
      bannerButton('Beenden').click();
      await flush();
      bannerButton('Beenden').click();
      await flush();
      expect(dialogOpen).toHaveBeenCalledTimes(1);
      // nach dem Schließen ist der nächste Versuch wieder möglich
      closed.next(undefined);
      closed.complete();
      await flush();
      dialogOpen.mockReturnValue({ afterClosed: () => of(undefined) });
      bannerButton('Beenden').click();
      await flush();
      expect(dialogOpen).toHaveBeenCalledTimes(2);
    });
  });

  it('Fehler: Snackbar mit übersetztem Text, Banner bleibt', async () => {
    fake.current.set(FRI);
    fixture.detectChanges();
    fake.saveError.set({ result: 'failed' });
    await flush();
    expect(snackOpen).toHaveBeenCalledWith('Eintrag konnte nicht beendet werden.', 'OK', { duration: 5000 });
    expect(openBanner()).not.toBeNull();
  });

  it('derselbe Fehler noch einmal (neues Objekt) zeigt die Snackbar erneut', async () => {
    fake.current.set(FRI);
    fixture.detectChanges();
    fake.saveError.set({ result: 'failed' });
    await flush();
    fake.saveError.set({ result: 'failed' });
    await flush();
    expect(snackOpen).toHaveBeenCalledTimes(2);
  });

  it('„Später" ruft later() am Service auf', () => {
    fake.current.set(FRI);
    fixture.detectChanges();
    bannerButton('Später').click();
    expect(fake.laterCalls).toBe(1);
  });

  it('nicht modal: der Timer-Start bleibt bedienbar', async () => {
    fake.current.set(FRI);
    fixture.detectChanges();
    const start = el().querySelector<HTMLButtonElement>('.main-action-btn')!;
    expect(start.disabled).toBe(false);
    start.click();
    await flush();
    expect(startOrStop).toHaveBeenCalledTimes(1);
  });

  describe('Fokus und Ansage', () => {
    it('nach dem Entfall des letzten Banners landet der Fokus auf dem stabilen Anker', async () => {
      fake.current.set(FRI);
      fixture.detectChanges();
      bannerButton('Beenden').focus();
      fake.current.set(null);
      fake.closedCount.set(1);
      await flush();
      const anchor = el().querySelector<HTMLElement>('.timer-label')!;
      expect(anchor.getAttribute('tabindex')).toBe('-1');
      expect(document.activeElement).toBe(anchor);
    });

    it('gibt es einen nächsten Eintrag, bekommt dessen Banner den Fokus', async () => {
      fake.current.set(FRI);
      fixture.detectChanges();
      fake.current.set(SAT_EARLIER);
      fake.closedCount.set(1);
      await flush();
      expect(document.activeElement).toBe(openBanner()!.querySelector('button'));
    });

    it('beim Erzeugen wird nicht fokussiert (frühere Abschlüsse der Sitzung)', async () => {
      fixture.nativeElement.remove();
      fake.closedCount.set(3);
      fixture = TestBed.createComponent(DashboardComponent);
      document.body.appendChild(fixture.nativeElement);
      (document.activeElement as HTMLElement | null)?.blur();
      await flush();
      expect(document.activeElement).toBe(document.body);
    });

    it('LiveAnnouncer sagt jeden Eintrag einmal höflich an', async () => {
      fake.current.set(FRI);
      await flush();
      expect(announce).toHaveBeenCalledTimes(1);
      expect(announce.mock.calls[0][0]).toContain('Dein Eintrag vom');
      expect(announce.mock.calls[0][1]).toBe('polite');
      fake.moreCount.set(1);
      await flush();
      expect(announce).toHaveBeenCalledTimes(1);
      fake.current.set(SAT_EARLIER);
      await flush();
      expect(announce).toHaveBeenCalledTimes(2);
      fake.current.set(FRI);
      await flush();
      expect(announce).toHaveBeenCalledTimes(2);
    });

    it('der Anker ist kein Tab-Stopp (tabindex=-1, kein sichtbarer Zusatztext)', async () => {
      await flush();
      const anchor = el().querySelector<HTMLElement>('.timer-label')!;
      expect(anchor.getAttribute('tabindex')).toBe('-1');
      expect(anchor.textContent!.trim()).toBe('Nettoarbeitszeit');
    });
  });
});

