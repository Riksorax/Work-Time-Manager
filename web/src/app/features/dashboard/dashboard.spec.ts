import { TestBed } from '@angular/core/testing';
import { Component, ErrorHandler, computed, input, output, signal } from '@angular/core';
import { By } from '@angular/platform-browser';
import { ComponentFixture } from '@angular/core/testing';
import { MatDialog } from '@angular/material/dialog';
import { MatSnackBar } from '@angular/material/snack-bar';
import { TranslateService, provideTranslateService } from '@ngx-translate/core';
import { Router } from '@angular/router';
import { DashboardComponent } from './dashboard';
import { DashboardService } from './dashboard.service';
import { DashboardSaveError } from './dashboard-save-error';
import { OpenEntryService } from './open-entry';
import { createFakeOpenEntry, FakeOpenEntry } from '../../shared/testing/open-entry-fake';
import { LiveAnnouncer } from '@angular/cdk/a11y';
import { Subject, of } from 'rxjs';
import de from '../../../../public/i18n/de.json';
import en from '../../../../public/i18n/en.json';
import { GermanHoliday } from '../../shared/utils/german-holidays.util';
import { HolidayBannerComponent } from '../../shared/components/holiday-banner/holiday-banner';
import { TimeInputComponent } from '../../shared/components/time-input/time-input';
import { WorkEntry, WorkEntryType } from '../../shared/models/index';

@Component({ selector: 'app-holiday-banner', template: '<div class="stub-banner">{{ holiday() }}</div>' })
class HolidayBannerStub { readonly holiday = input.required<GermanHoliday>(); }
@Component({ selector: 'app-time-input', template: '' })
class TimeInputStub {
  readonly label = input<string>();
  readonly value = input<unknown>();
  readonly disabled = input<boolean>();
  readonly showClear = input<boolean>();
  readonly settle = input<boolean>(false);
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
      remove: { imports: [HolidayBannerComponent, TimeInputComponent] },
      add: { imports: [HolidayBannerStub, TimeInputStub] },
    });
    TestBed.configureTestingModule({
      providers: [
        provideTranslateService(),
        { provide: DashboardService, useValue: {
          isLoading, holidayToday: holiday, isLoggedIn: signal(false), isSaving: signal(false),
          netDuration: signal(0), grossDuration: signal(0), dailyOvertime: signal(0), totalOvertime: signal(0),
          isTimerRunning: signal(false), isBreakRunning: signal(false), expectedEndTime: signal(null),
          expectedEndTotalZero: signal(null), breaks: signal([]),
          workEntry: signal({ id: 'x', date: new Date(2026, 9, 3), breaks: [], isManuallyEntered: false, type: WorkEntryType.Work }),
        } },
        { provide: OpenEntryService, useValue: createFakeOpenEntry() },
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
      remove: { imports: [HolidayBannerComponent, TimeInputComponent] },
      add: { imports: [HolidayBannerStub, TimeInputStub] },
    });
    TestBed.configureTestingModule({
      providers: [
        provideTranslateService({ fallbackLang: 'de' }),
        { provide: DashboardService, useValue: {
          isLoading, holidayToday: holiday, isLoggedIn: signal(false), isSaving: signal(false), startOrStopTimer: startOrStop,
          netDuration: signal(0), grossDuration: signal(0), dailyOvertime: signal(0), totalOvertime: signal(0),
          isTimerRunning: signal(false), isBreakRunning: signal(false), expectedEndTime: signal(null),
          expectedEndTotalZero: signal(null), breaks: signal([]),
          workEntry: signal({ id: 'x', date: new Date(2026, 9, 3), breaks: [], isManuallyEntered: false, type: WorkEntryType.Work }),
        } },
        { provide: OpenEntryService, useValue: fake },
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

  describe('Fortsetzen', () => {
    const resumeBtn = (): HTMLButtonElement | undefined =>
      Array.from(openBanner()?.querySelectorAll('button') ?? []).find(b => b.textContent!.includes('Fortsetzen'));

    it('canResume aus dem Service steuert den Button', async () => {
      fake.current.set(FRI);
      await flush();
      expect(resumeBtn()).toBeUndefined();
      fake.canResume.set(true);
      await flush();
      expect(resumeBtn()).toBeTruthy();
      fake.canResume.set(false);
      await flush();
      expect(resumeBtn()).toBeUndefined();
    });

    it('Klick ruft resume mit dem Kandidaten genau einmal auf, ohne Dialog, Snackbar oder zusätzliche Ansage', async () => {
      fake.current.set(FRI);
      fake.canResume.set(true);
      await flush();
      expect(announce).toHaveBeenCalledTimes(1); // nur die einmalige Banner-Ansage
      resumeBtn()!.click();
      await flush();
      expect(fake.resumeCalls).toEqual([FRI]);
      expect(dialogOpen).not.toHaveBeenCalled();
      expect(snackOpen).not.toHaveBeenCalled();
      expect(announce).toHaveBeenCalledTimes(1);
    });

    it('während busy sind alle drei Buttons deaktiviert', async () => {
      fake.current.set(FRI);
      fake.canResume.set(true);
      fake.resumeResult = new Promise<boolean>(() => { /* hängt */ });
      await flush();
      resumeBtn()!.click();
      fake.busy.set(true);
      await flush();
      expect(Array.from(openBanner()!.querySelectorAll('button')).every(b => b.disabled)).toBe(true);
    });

    it('Fokus nach Erfolg: Spinner beim Pin, danach der stabile Anker', async () => {
      fake.current.set(FRI);
      fake.canResume.set(true);
      await flush();
      resumeBtn()!.focus();
      isLoading.set(true); // Dashboard pinnt: Spinner
      await flush();
      expect(el().querySelector('.timer-label')).toBeNull();
      fake.current.set(null);
      isLoading.set(false);
      fake.closedCount.set(1);
      await flush();
      expect(document.activeElement).toBe(el().querySelector('.timer-label'));
    });

    it('Fokus nach Erfolg: gibt es einen nächsten Banner, bekommt er den Fokus', async () => {
      fake.current.set(FRI);
      fake.canResume.set(true);
      await flush();
      fake.current.set(SAT_EARLIER);
      fake.canResume.set(false);
      fake.closedCount.set(1);
      await flush();
      expect(document.activeElement).toBe(openBanner()!.querySelector('button'));
    });

    it('nicht modal: der Timer-Start bleibt neben dem Fortsetzen-Button bedienbar', async () => {
      fake.current.set(FRI);
      fake.canResume.set(true);
      await flush();
      el().querySelector<HTMLButtonElement>('.main-action-btn')!.click();
      await flush();
      expect(startOrStop).toHaveBeenCalledTimes(1);
    });
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

describe('DashboardComponent Sperre während einer Schreibaktion (#426, W19)', () => {
  const isSaving = signal(false);
  const runningEntry = (): WorkEntry => ({
    id: '2026-10-05', date: new Date(2026, 9, 5), workStart: new Date(2026, 9, 5, 8, 0), breaks: [
      { id: 'b1', name: 'Pause 1', start: new Date(2026, 9, 5, 9, 0), end: new Date(2026, 9, 5, 9, 15), isAutomatic: false },
    ], isManuallyEntered: false, type: WorkEntryType.Work,
  });
  const workEntry = signal<WorkEntry>(runningEntry());
  let fixture: ComponentFixture<DashboardComponent>;
  let startOrStop: ReturnType<typeof vi.fn>;
  let breakAction: ReturnType<typeof vi.fn>;
  let dialogOpen: ReturnType<typeof vi.fn>;

  const el = (): HTMLElement => fixture.nativeElement;
  const mainBtn = (): HTMLButtonElement => el().querySelector<HTMLButtonElement>('.main-action-btn')!;
  const breakBtn = (): HTMLButtonElement => el().querySelector<HTMLButtonElement>('.section-header button')!;
  const editBtn = (): HTMLButtonElement => el().querySelector<HTMLButtonElement>('.break-actions button:not(.delete-btn)')!;
  const deleteBtn = (): HTMLButtonElement => el().querySelector<HTMLButtonElement>('.break-actions .delete-btn')!;
  const adjustBtn = (): HTMLButtonElement => el().querySelector<HTMLButtonElement>('.adjust-btn')!;
  const timeInputs = (): TimeInputStub[] =>
    fixture.debugElement.queryAll(By.directive(TimeInputStub)).map(d => d.componentInstance as TimeInputStub);
  /** Interaktiv deaktiviert: `aria-disabled="true"`, aber kein `disabled`-Attribut (Fokus bleibt). */
  const interactivelyDisabled = (b: HTMLElement): boolean => b.getAttribute('aria-disabled') === 'true' && !b.hasAttribute('disabled');
  const inactive = (b: HTMLElement): boolean => b.getAttribute('aria-disabled') !== 'true' && !b.hasAttribute('disabled');

  beforeEach(() => {
    isSaving.set(false);
    workEntry.set(runningEntry());
    startOrStop = vi.fn().mockResolvedValue(undefined);
    breakAction = vi.fn().mockResolvedValue(undefined);
    dialogOpen = vi.fn(() => ({ afterClosed: () => of(undefined) }));
    TestBed.overrideComponent(DashboardComponent, {
      remove: { imports: [HolidayBannerComponent, TimeInputComponent] },
      add: { imports: [HolidayBannerStub, TimeInputStub] },
    });
    TestBed.configureTestingModule({
      providers: [
        provideTranslateService({ fallbackLang: 'de' }),
        { provide: DashboardService, useValue: {
          isLoading: signal(false), holidayToday: signal(null), isLoggedIn: signal(false), isSaving,
          startOrStopTimer: startOrStop, startOrStopBreak: breakAction,
          netDuration: signal(0), grossDuration: signal(0), dailyOvertime: signal(0), totalOvertime: signal(0),
          isTimerRunning: signal(true), isBreakRunning: signal(false), expectedEndTime: signal(null),
          expectedEndTotalZero: signal(null), breaks: computed(() => workEntry().breaks), workEntry,
        } },
        { provide: OpenEntryService, useValue: createFakeOpenEntry() },
        { provide: Router, useValue: { navigate: vi.fn() } },
        { provide: MatDialog, useValue: { open: dialogOpen } },
        { provide: MatSnackBar, useValue: { open: vi.fn() } },
      ],
    });
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('de', de);
    translate.use('de');
    fixture = TestBed.createComponent(DashboardComponent);
    document.body.appendChild(fixture.nativeElement);
    fixture.detectChanges();
  });

  afterEach(() => {
    fixture.nativeElement.remove();
    TestBed.resetTestingModule();
  });

  it('ohne laufende Aktion ist alles aktiv', () => {
    expect(inactive(mainBtn())).toBe(true);
    expect(inactive(breakBtn())).toBe(true);
    expect(editBtn().disabled).toBe(false);
    expect(deleteBtn().disabled).toBe(false);
    expect(adjustBtn().disabled).toBe(false);
    expect(timeInputs().map(t => t.disabled())).toEqual([false, false]);
  });

  it('während einer Aktion sind Haupt- und Pausen-Button interaktiv deaktiviert, die übrigen Elemente echt deaktiviert', () => {
    isSaving.set(true);
    fixture.detectChanges();
    expect(interactivelyDisabled(mainBtn())).toBe(true);
    expect(interactivelyDisabled(breakBtn())).toBe(true);
    expect(editBtn().disabled).toBe(true);
    expect(deleteBtn().disabled).toBe(true);
    expect(adjustBtn().disabled).toBe(true);
    expect(timeInputs().map(t => t.disabled())).toEqual([true, true]);
  });

  it('beide Zeitfelder (Start, Ende) aktivieren das Entprellen (settle, Review-Fund zu #426)', () => {
    expect(timeInputs().map(t => t.settle())).toEqual([true, true]);
  });

  it('das Ende-Zeitfeld bleibt ohne Startzeit auch ohne Aktion deaktiviert', () => {
    workEntry.update(e => ({ ...e, workStart: undefined }));
    fixture.detectChanges();
    expect(timeInputs().map(t => t.disabled())).toEqual([false, true]);
  });

  it('aria-label und Text der Buttons ändern sich nicht (kein Spinner, keine neue Optik)', () => {
    const snap = (): string[] => [mainBtn(), breakBtn(), editBtn(), deleteBtn(), adjustBtn()]
      .map(b => `${b.getAttribute('aria-label')}|${b.textContent!.trim()}`);
    const before = snap();
    isSaving.set(true);
    fixture.detectChanges();
    expect(snap()).toEqual(before);
  });

  it('der Fokus bleibt auf dem Haupt-Button, wenn er interaktiv deaktiviert wird', () => {
    mainBtn().focus();
    expect(document.activeElement).toBe(mainBtn());
    isSaving.set(true);
    fixture.detectChanges();
    expect(document.activeElement).toBe(mainBtn());
  });

  it('Klick auf den interaktiv deaktivierten Haupt-Button feuert den Handler (Material fängt Klicks bei <button> nicht ab); der Service verwirft', () => {
    isSaving.set(true);
    fixture.detectChanges();
    mainBtn().click();
    expect(startOrStop).toHaveBeenCalledTimes(1);
    expect(dialogOpen).not.toHaveBeenCalled(); // verworfener Tap liefert undefined, kein Restart-Dialog
  });

  it('Klick auf das deaktivierte Bearbeiten-Icon öffnet keinen Dialog', () => {
    isSaving.set(true);
    fixture.detectChanges();
    editBtn().click();
    adjustBtn().click();
    expect(dialogOpen).not.toHaveBeenCalled();
  });

  it('nach Ende der Aktion ist alles wieder aktiv', () => {
    isSaving.set(true);
    fixture.detectChanges();
    isSaving.set(false);
    fixture.detectChanges();
    expect(inactive(mainBtn())).toBe(true);
    expect(inactive(breakBtn())).toBe(true);
    expect(editBtn().disabled).toBe(false);
    expect(deleteBtn().disabled).toBe(false);
    expect(adjustBtn().disabled).toBe(false);
    expect(timeInputs().map(t => t.disabled())).toEqual([false, false]);
    editBtn().click();
    expect(dialogOpen).toHaveBeenCalledTimes(1);
  });
});

describe('DashboardComponent Fehler beim Speichern (#426 B, S1-S5)', () => {
  const workEntry = signal<WorkEntry>({
    id: '2026-10-05', date: new Date(2026, 9, 5), workStart: new Date(2026, 9, 5, 8, 0), breaks: [
      { id: 'b1', name: 'Pause 1', start: new Date(2026, 9, 5, 9, 0), end: new Date(2026, 9, 5, 9, 15), isAutomatic: false },
    ], isManuallyEntered: false, type: WorkEntryType.Work,
  });
  type Mock = ReturnType<typeof vi.fn>;
  let fixture: ComponentFixture<DashboardComponent>;
  let component: DashboardComponent;
  let translate: TranslateService;
  let svc: Record<string, Mock>;
  let snackOpen: Mock;
  let handleError: Mock;
  let dialogOpen: Mock;
  let dialogResult: unknown;

  const cause = new Error('Saldo kaputt');
  const saveError = (): DashboardSaveError => new DashboardSaveError(cause);
  // Nur Microtasks, kein `setTimeout` (fremder Fake-Timer im Vollauf, #392).
  const flush = async (): Promise<void> => { for (let i = 0; i < 20; i++) await Promise.resolve(); };
  const el = (): HTMLElement => fixture.nativeElement;
  const mainBtn = (): HTMLButtonElement => el().querySelector<HTMLButtonElement>('.main-action-btn')!;
  const breakBtn = (): HTMLButtonElement => el().querySelector<HTMLButtonElement>('.section-header button')!;
  const editBtn = (): HTMLButtonElement => el().querySelector<HTMLButtonElement>('.break-actions button:not(.delete-btn)')!;
  const deleteBtn = (): HTMLButtonElement => el().querySelector<HTMLButtonElement>('.break-actions .delete-btn')!;

  beforeEach(() => {
    dialogResult = undefined;
    svc = {
      startOrStopTimer: vi.fn().mockResolvedValue(undefined),
      startNewSession: vi.fn().mockResolvedValue(undefined),
      startOrStopBreak: vi.fn().mockResolvedValue(undefined),
      setManualStartTime: vi.fn().mockResolvedValue(undefined),
      setManualEndTime: vi.fn().mockResolvedValue(undefined),
      clearEndTime: vi.fn().mockResolvedValue(undefined),
      updateBreak: vi.fn().mockResolvedValue(undefined),
      deleteBreak: vi.fn().mockResolvedValue(undefined),
      stopRunningTimerForSwitch: vi.fn().mockResolvedValue(false),
    };
    snackOpen = vi.fn();
    handleError = vi.fn();
    dialogOpen = vi.fn(() => ({ afterClosed: () => of(dialogResult) }));
    TestBed.overrideComponent(DashboardComponent, {
      remove: { imports: [HolidayBannerComponent, TimeInputComponent] },
      add: { imports: [HolidayBannerStub, TimeInputStub] },
    });
    TestBed.configureTestingModule({
      providers: [
        provideTranslateService({ fallbackLang: 'de' }),
        { provide: DashboardService, useValue: {
          ...svc,
          isLoading: signal(false), holidayToday: signal(null), isLoggedIn: signal(false), isSaving: signal(false),
          netDuration: signal(0), grossDuration: signal(0), dailyOvertime: signal(0), totalOvertime: signal(0),
          isTimerRunning: signal(true), isBreakRunning: signal(false), expectedEndTime: signal(null),
          expectedEndTotalZero: signal(null), breaks: computed(() => workEntry().breaks), workEntry,
        } },
        { provide: OpenEntryService, useValue: createFakeOpenEntry() },
        { provide: Router, useValue: { navigate: vi.fn() } },
        { provide: MatDialog, useValue: { open: dialogOpen } },
        { provide: MatSnackBar, useValue: { open: snackOpen } },
        { provide: ErrorHandler, useValue: { handleError } },
      ],
    });
    translate = TestBed.inject(TranslateService);
    translate.setTranslation('de', de);
    translate.setTranslation('en', en);
    translate.use('de');
    fixture = TestBed.createComponent(DashboardComponent);
    component = fixture.componentInstance;
    document.body.appendChild(fixture.nativeElement);
    fixture.detectChanges();
  });

  afterEach(() => {
    fixture.nativeElement.remove();
    TestBed.resetTestingModule();
  });

  it('S1 Snackbar bei DashboardSaveError: übersetzter Text (de/en), OK, 5 s; die Ursache geht an den ErrorHandler; der Handler rejected nicht', async () => {
    svc['startOrStopTimer'].mockRejectedValue(saveError());
    await expect(component.onMainAction()).resolves.toBeUndefined();
    expect(snackOpen).toHaveBeenCalledTimes(1);
    expect(snackOpen).toHaveBeenCalledWith(de.dashboard.saveError, 'OK', { duration: 5000 });
    expect(handleError).toHaveBeenCalledTimes(1);
    expect(handleError).toHaveBeenCalledWith(cause);

    translate.use('en');
    snackOpen.mockClear();
    await component.onMainAction();
    expect(snackOpen).toHaveBeenCalledWith(en.dashboard.saveError, 'OK', { duration: 5000 });
  });

  describe('S2 Keine Snackbar bei verworfenem Tap', () => {
    it('undefined (verworfen): weder Snackbar noch ErrorHandler', async () => {
      await component.onMainAction();
      expect(snackOpen).not.toHaveBeenCalled();
      expect(handleError).not.toHaveBeenCalled();
      expect(dialogOpen).not.toHaveBeenCalled();
    });

    it("'restart-dialog': der Dialog öffnet wie bisher, keine Snackbar", async () => {
      svc['startOrStopTimer'].mockResolvedValue('restart-dialog');
      dialogResult = 'keep-breaks';
      await component.onMainAction();
      await flush();
      expect(dialogOpen).toHaveBeenCalledTimes(1);
      expect(svc['startNewSession']).toHaveBeenCalledWith(true);
      expect(snackOpen).not.toHaveBeenCalled();
    });
  });

  it('S3 Andere Fehler bleiben unverändert: keine Snackbar, der Handler rejected weiter, der ErrorHandler wird nicht zusätzlich gerufen', async () => {
    const plain = new Error('Netz weg');
    svc['startOrStopTimer'].mockRejectedValue(plain);
    await expect(component.onMainAction()).rejects.toBe(plain);
    svc['startOrStopBreak'].mockRejectedValue(plain);
    await expect(component.onBreakAction()).rejects.toBe(plain);
    expect(snackOpen).not.toHaveBeenCalled();
    expect(handleError).not.toHaveBeenCalled();
  });

  describe('S4 Alle Handler melden einen DashboardSaveError genau einmal', () => {
    const rows: Array<[string, string, (c: DashboardComponent, f: () => HTMLElement) => Promise<void> | void]> = [
      ['Haupt-Button', 'startOrStopTimer', async (_c, f) => { f().querySelector<HTMLButtonElement>('.main-action-btn')!.click(); }],
      ['Pausen-Button', 'startOrStopBreak', async (_c, f) => { f().querySelector<HTMLButtonElement>('.section-header button')!.click(); }],
      ['Startzeit', 'setManualStartTime', c => c.onStartTimeSelected('07:30')],
      ['Endzeit', 'setManualEndTime', c => c.onEndTimeSelected('17:00')],
      ['Endzeit löschen', 'clearEndTime', c => c.onClearEndTime()],
      ['Pause löschen', 'deleteBreak', async (_c, f) => { f().querySelector<HTMLButtonElement>('.break-actions .delete-btn')!.click(); }],
      ['Pause bearbeiten (nach Dialog-Ergebnis)', 'updateBreak', async (_c, f) => {
        dialogResult = { updated: { id: 'b1', name: 'x', start: new Date(2026, 9, 5, 9, 0), end: new Date(2026, 9, 5, 9, 20), isAutomatic: false } };
        f().querySelector<HTMLButtonElement>('.break-actions button:not(.delete-btn)')!.click();
      }],
    ];

    it.each(rows)('%s', async (_name, method, run) => {
      svc[method].mockRejectedValue(saveError());
      await run(component, el);
      await flush();
      expect(svc[method]).toHaveBeenCalledTimes(1);
      expect(snackOpen).toHaveBeenCalledTimes(1);
      expect(handleError).toHaveBeenCalledWith(cause);
    });

    it.each([['keep-breaks', true], ['discard-breaks', false]] as const)('Neue Session nach Restart-Dialog (%s)', async (choice, keep) => {
      svc['startOrStopTimer'].mockResolvedValue('restart-dialog');
      svc['startNewSession'].mockRejectedValue(saveError());
      dialogResult = choice;
      mainBtn().click();
      await flush();
      expect(svc['startNewSession']).toHaveBeenCalledWith(keep);
      expect(snackOpen).toHaveBeenCalledTimes(1);
      expect(handleError).toHaveBeenCalledWith(cause);
    });
  });

  it('S5 Keine Doppelmeldung am Profilwechsel: ohne Rejection des Services zeigt die Komponente nichts', async () => {
    // Guard-Pfad: stopRunningTimerForSwitch liefert false (Meldung kommt vom Wechsel-Dialog) und läuft nie über die Komponente.
    const stopForSwitch = svc['stopRunningTimerForSwitch'] as unknown as (id: string) => Promise<boolean>;
    expect(await stopForSwitch('default')).toBe(false);
    await component.onMainAction();
    await component.onBreakAction();
    await component.onStartTimeSelected('07:30');
    await component.onEndTimeSelected('17:00');
    await component.onClearEndTime();
    await component.onDeleteBreak('b1');
    expect(snackOpen).not.toHaveBeenCalled();
    expect(handleError).not.toHaveBeenCalled();
    expect(breakBtn()).toBeTruthy();
    expect(editBtn()).toBeTruthy();
    expect(deleteBtn()).toBeTruthy();
  });
});
