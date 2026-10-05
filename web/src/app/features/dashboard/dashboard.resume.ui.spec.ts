import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Component, input, output, signal } from '@angular/core';
import { LiveAnnouncer } from '@angular/cdk/a11y';
import { MatDialog } from '@angular/material/dialog';
import { MatSnackBar } from '@angular/material/snack-bar';
import { TranslateService, provideTranslateService } from '@ngx-translate/core';
import { Router } from '@angular/router';
import { Observable, defer, of } from 'rxjs';
import { DashboardComponent } from './dashboard';
import { DashboardService } from './dashboard.service';
import { OpenEntryService } from './open-entry';
import { OpenEntryCloseService } from './open-entry-close';
import { WorkEntryService } from '../../core/services/work-entry';
import { OvertimeService } from '../../core/services/overtime';
import { SettingsService } from '../../core/services/settings';
import { AuthService } from '../../core/auth/auth';
import { LeaveBalanceService } from '../../core/services/leave-balance';
import { WorkProfileService } from '../../core/services/work-profile';
import { createFakeWorkProfile } from '../../shared/testing/work-profile-fake';
import { LeaveBalanceCardComponent } from '../../shared/components/leave-balance-card/leave-balance-card';
import { TimeInputComponent } from '../../shared/components/time-input/time-input';
import { toDateKey } from '../../shared/utils/german-holidays.util';
import { DEFAULT_SETTINGS, WorkEntry, WorkEntryType } from '../../shared/models/index';
import de from '../../../../public/i18n/de.json';
import en from '../../../../public/i18n/en.json';

// Ende-zu-Ende im Dashboard (#385): echter DashboardService + echter OpenEntryService + echte Component, nur Repos gefakt.
// Feste lokale Daten: Sa 2026-10-03 09:00, Fr 2026-10-02 22:00 offen. Flush nur über Microtasks/Timer-Advance, nie setTimeout.

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

const A = 'default';
const at = (d: number, h = 0, m = 0): Date => new Date(2026, 9, d, h, m);
function mk(id: string, d: number, extra: Partial<WorkEntry> = {}): WorkEntry {
  return { id, date: new Date(Date.UTC(2026, 9, d)), breaks: [], isManuallyEntered: false, type: WorkEntryType.Work, ...extra };
}

describe('Dashboard Fortsetzen Ende-zu-Ende (#385)', () => {
  let fixture: ComponentFixture<DashboardComponent>;
  let entries: Map<string, WorkEntry>;
  let writes: WorkEntry[];
  let monthGate: Promise<void> | null;
  let releaseMonth: () => void;
  let announce: ReturnType<typeof vi.fn>;
  let snackOpen: ReturnType<typeof vi.fn>;
  let dialogOpen: ReturnType<typeof vi.fn>;
  let translate: TranslateService;

  const el = (): HTMLElement => fixture.nativeElement;
  const settle = async (): Promise<void> => {
    await vi.advanceTimersByTimeAsync(0);
    fixture.detectChanges();
    await vi.advanceTimersByTimeAsync(0);
    fixture.detectChanges();
  };
  const banner = (): HTMLElement | null => el().querySelector('app-open-entry-banner');
  const resumeBtn = (): HTMLButtonElement | undefined =>
    Array.from(banner()?.querySelectorAll('button') ?? []).find(b => b.textContent!.includes('Fortsetzen'));
  const mainBtn = (): HTMLButtonElement => el().querySelector<HTMLButtonElement>('.main-action-btn')!;

  async function create(initial: WorkEntry[]): Promise<void> {
    entries = new Map(initial.map(e => [e.id, e]));
    writes = [];
    monthGate = null;
    announce = vi.fn().mockResolvedValue(undefined);
    snackOpen = vi.fn();
    dialogOpen = vi.fn();
    const profile = createFakeWorkProfile(A);
    const user = signal<{ uid: string } | null>({ uid: 'u1' });
    let stored = 0;
    TestBed.overrideComponent(DashboardComponent, {
      remove: { imports: [LeaveBalanceCardComponent, TimeInputComponent] },
      add: { imports: [LeaveCardStub, TimeInputStub] },
    });
    TestBed.configureTestingModule({
      providers: [
        provideTranslateService({ fallbackLang: 'de' }),
        { provide: WorkEntryService, useValue: {
          getTodayEntry: (): Observable<WorkEntry | null> => defer(() => of(entries.get(toDateKey(new Date())) ?? null)),
          getEntriesForMonthOnce: async (y: number, m: number): Promise<WorkEntry[]> => {
            if (monthGate) await monthGate;
            const prefix = `${y}-${String(m).padStart(2, '0')}-`;
            return [...entries.values()].filter(e => e.id.startsWith(prefix));
          },
          emptyEntry: (d: Date): WorkEntry => mk(toDateKey(d), d.getDate(), { date: d }),
          saveEntry: async (e: WorkEntry) => { writes.push(e); entries.set(e.id, e); },
        } },
        { provide: OvertimeService, useValue: {
          getOvertime: async () => stored, getLastUpdateDate: async () => null,
          saveOvertime: async (ms: number) => { stored = ms; }, saveLastUpdateDate: async () => undefined,
        } },
        { provide: SettingsService, useValue: {
          getSettings: () => of({ ...DEFAULT_SETTINGS }),
          getSettingsOnce: async () => ({ ...DEFAULT_SETTINGS }),
          saveSettings: () => undefined,
        } },
        { provide: AuthService, useValue: { user, get uid() { return user()?.uid ?? null; } } },
        { provide: WorkProfileService, useValue: profile },
        { provide: OpenEntryCloseService, useValue: { endEntry: async () => 'closed' } },
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
    TestBed.inject(OpenEntryService);
    fixture = TestBed.createComponent(DashboardComponent);
    document.body.appendChild(fixture.nativeElement);
    await settle();
  }

  beforeEach(() => {
    localStorage.clear();
    vi.useFakeTimers();
    vi.setSystemTime(at(3, 9, 0));
  });
  afterEach(() => {
    fixture.nativeElement.remove();
    TestBed.resetTestingModule();
    vi.useRealTimers();
    vi.restoreAllMocks();
  });

  it('Banner mit Fortsetzen: Klick, Spinner, laufender Timer am Starttag, Banner weg, Stop sichtbar, Anker fokussiert', async () => {
    await create([mk('2026-10-02', 2, { workStart: at(2, 22, 0) })]);
    expect(banner()).toBeTruthy();
    expect(resumeBtn()).toBeTruthy();
    expect(mainBtn().getAttribute('aria-label')).toBe((de.dashboard as Record<string, string>)['startTimeTracking']);

    let release!: () => void;
    monthGate = new Promise<void>(r => (release = r));
    resumeBtn()!.click();
    await settle();
    expect(el().querySelector('.loading-state')).toBeTruthy(); // Spinner beim Pin
    expect(banner()).toBeNull();
    expect(el().querySelector('.main-action-btn')).toBeNull(); // Start/Stop während des Pins nicht erreichbar

    monthGate = null;
    release();
    await settle();
    await settle();
    const svc = TestBed.inject(DashboardService);
    expect(el().querySelector('.loading-state')).toBeNull();
    expect(svc.workEntry().id).toBe('2026-10-02');
    expect(svc.workEntry().workStart).toEqual(at(2, 22, 0));
    expect(svc.isTimerRunning()).toBe(true);
    expect(banner()).toBeNull();
    expect(mainBtn().getAttribute('aria-label')).toBe((de.dashboard as Record<string, string>)['stopTimeTracking']);
    expect(writes).toEqual([]);
    expect(dialogOpen).not.toHaveBeenCalled();
    expect(snackOpen).not.toHaveBeenCalled();
    expect(announce).toHaveBeenCalledTimes(1); // nur die Banner-Ansage von vorher
    expect(document.activeElement).toBe(el().querySelector('.timer-label'));
  });

  it('ohne Fortsetzen, wenn heute schon ein Eintrag existiert; Beenden bleibt', async () => {
    await create([
      mk('2026-10-02', 2, { workStart: at(2, 22, 0) }),
      mk('2026-10-03', 3, { workStart: at(3, 8, 0), workEnd: at(3, 8, 30) }),
    ]);
    expect(banner()).toBeTruthy();
    expect(resumeBtn()).toBeUndefined();
    expect(Array.from(banner()!.querySelectorAll('button')).map(b => b.textContent!.trim())).toEqual(['Später', 'Beenden']);
  });

  it('älter als 24 h: nur Später und Beenden', async () => {
    vi.setSystemTime(at(3, 22, 1));
    await create([mk('2026-10-02', 2, { workStart: at(2, 22, 0) })]);
    expect(banner()).toBeTruthy();
    expect(resumeBtn()).toBeUndefined();
  });

  it('Stop nach Fortsetzen: Eintrag am Freitag gespeichert, Dashboard zeigt heute, Banner flackert nicht', async () => {
    await create([mk('2026-10-02', 2, { workStart: at(2, 22, 0) })]);
    resumeBtn()!.click();
    await settle();
    await settle();
    const seen: boolean[] = [];
    const svc = TestBed.inject(DashboardService);
    mainBtn().click();
    for (let i = 0; i < 6; i++) { await settle(); seen.push(!!banner()); }
    expect(seen.some(Boolean)).toBe(false);
    expect(writes[0].id).toBe('2026-10-02');
    expect(writes[0].workEnd).toBeDefined();
    expect(svc.workEntry().id).toBe('2026-10-03');
    expect(svc.isTimerRunning()).toBe(false);
    expect(banner()).toBeNull();
    expect(mainBtn().getAttribute('aria-label')).toBe((de.dashboard as Record<string, string>)['startTimeTracking']);
  });
});
