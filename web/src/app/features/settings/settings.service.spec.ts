import { TestBed } from '@angular/core/testing';
import { Router } from '@angular/router';
import { signal } from '@angular/core';
import { of } from 'rxjs';
import { SettingsPageService } from './settings.service';
import { AuthService } from '../../core/auth/auth';
import { ProfileService } from '../../core/services/profile';
import { SettingsService } from '../../core/services/settings';
import { OvertimeService } from '../../core/services/overtime';
import { ThemeService } from '../../core/services/theme';
import { LanguageService } from '../../core/services/language';
import { DataSyncService } from '../../core/services/data-sync';
import { WebPremiumService } from '../../core/services/web-premium';
import { LeaveBalanceService } from '../../core/services/leave-balance';
import { WorkProfileService } from '../../core/services/work-profile';
import { createFakeWorkProfile, FakeWorkProfile } from '../../shared/testing/work-profile-fake';
import { DashboardService } from '../dashboard/dashboard.service';
import { DEFAULT_SETTINGS, UserSettings } from '../../shared/models/index';

describe('SettingsPageService.setVacationDays', () => {
  let saveSettings: ReturnType<typeof vi.fn>;
  let refresh: ReturnType<typeof vi.fn>;
  let svc: SettingsPageService;

  beforeEach(() => {
    saveSettings = vi.fn().mockResolvedValue(undefined);
    refresh = vi.fn();
    TestBed.configureTestingModule({
      providers: [
        { provide: SettingsService, useValue: { getSettings: () => of(DEFAULT_SETTINGS), saveSettings } },
        { provide: LeaveBalanceService, useValue: { refresh } },
        { provide: AuthService, useValue: { user: signal(null) } },
        { provide: ProfileService, useValue: { isPremium: signal(false) } },
        { provide: OvertimeService, useValue: {
          getOvertime: vi.fn().mockResolvedValue(0), getLastUpdateDate: vi.fn().mockResolvedValue(null) } },
        { provide: ThemeService, useValue: { isDarkMode: signal(false) } },
        { provide: LanguageService, useValue: { locale: signal('de') } },
        { provide: DataSyncService, useValue: { isSyncing: signal(false) } },
        { provide: WebPremiumService, useValue: {
          isConfigured: signal(false), isRestoring: signal(false), isPurchasing: signal(false) } },
        { provide: WorkProfileService, useValue: createFakeWorkProfile() },
        { provide: DashboardService, useValue: {} },
        { provide: Router, useValue: { navigate: vi.fn() } },
      ],
    });
    svc = TestBed.inject(SettingsPageService);
  });

  it('speichert den Anspruch und lädt danach die Urlaubsübersicht neu', async () => {
    await svc.setVacationDays(25);
    expect(saveSettings).toHaveBeenCalledWith({ ...DEFAULT_SETTINGS, vacationDaysPerYear: 25 });
    expect(refresh).toHaveBeenCalledTimes(1);
  });

  it('reicht Speicherfehler weiter und lädt nicht neu', async () => {
    saveSettings.mockRejectedValue(new Error('fail'));
    await expect(svc.setVacationDays(25)).rejects.toThrow('fail');
    expect(refresh).not.toHaveBeenCalled();
  });
});

describe('SettingsPageService.setBundesland', () => {
  let saveSettings: ReturnType<typeof vi.fn>;
  let svc: SettingsPageService;

  function create(current: UserSettings): void {
    saveSettings = vi.fn().mockResolvedValue(undefined);
    TestBed.configureTestingModule({
      providers: [
        { provide: SettingsService, useValue: { getSettings: () => of(current), saveSettings } },
        { provide: LeaveBalanceService, useValue: { refresh: vi.fn() } },
        { provide: AuthService, useValue: { user: signal(null) } },
        { provide: ProfileService, useValue: { isPremium: signal(false) } },
        { provide: OvertimeService, useValue: {
          getOvertime: vi.fn().mockResolvedValue(0), getLastUpdateDate: vi.fn().mockResolvedValue(null) } },
        { provide: ThemeService, useValue: { isDarkMode: signal(false) } },
        { provide: LanguageService, useValue: { locale: signal('de') } },
        { provide: DataSyncService, useValue: { isSyncing: signal(false) } },
        { provide: WebPremiumService, useValue: {
          isConfigured: signal(false), isRestoring: signal(false), isPurchasing: signal(false) } },
        { provide: WorkProfileService, useValue: createFakeWorkProfile() },
        { provide: DashboardService, useValue: {} },
        { provide: Router, useValue: { navigate: vi.fn() } },
      ],
    });
    svc = TestBed.inject(SettingsPageService);
  }

  const withBayern: UserSettings = { ...DEFAULT_SETTINGS, bundesland: 'bayern', weeklyTargetHours: 35 };

  it('speichert ein Bundesland ohne clearBundesland', async () => {
    create(withBayern);
    await svc.setBundesland('sachsen');
    expect(saveSettings).toHaveBeenCalledTimes(1);
    expect(saveSettings).toHaveBeenCalledWith({ ...withBayern, bundesland: 'sachsen' });
    expect(saveSettings.mock.calls[0][1]).toBeUndefined();
  });

  it('sendet bei Abwahl clearBundesland', async () => {
    create(withBayern);
    await svc.setBundesland(null);
    expect(saveSettings).toHaveBeenCalledWith({ ...withBayern, bundesland: null }, { clearBundesland: true });
  });

  it('reicht Speicherfehler weiter', async () => {
    create(withBayern);
    saveSettings.mockRejectedValue(new Error('fail'));
    await expect(svc.setBundesland('berlin')).rejects.toThrow('fail');
  });

  it.each([['bayern', withBayern], ['null', { ...DEFAULT_SETTINGS, bundesland: null }]] as const)(
    'andere Setter senden nie clearBundesland (Bundesland %s)',
    async (_l, current) => {
      create(current);
      await svc.setTargetHours(30);
      await svc.setVacationDays(20);
      await svc.setWorkdays([1, 2]);
      await svc.saveSettings({ ...current });
      expect(saveSettings).toHaveBeenCalledTimes(4);
      for (const [arg, opts] of saveSettings.mock.calls) {
        expect(arg.bundesland).toBe(current.bundesland);
        expect(opts).toBeUndefined();
      }
    },
  );
});

describe('SettingsPageService Profilbindung des Saldos (#380)', () => {
  const A = 'default';
  const B = 'B';
  const T_A = new Date(2026, 9, 1, 10, 0);
  const T_B = new Date(2026, 9, 2, 10, 0);
  let profile: FakeWorkProfile;
  let getOvertime: ReturnType<typeof vi.fn>;
  let getLastUpdateDate: ReturnType<typeof vi.fn>;
  let updateInitialOvertime: ReturnType<typeof vi.fn>;
  let gates: Record<string, Promise<void>>;
  let svc: SettingsPageService;

  const data: Record<string, { ms: number; last: Date }> = {
    [A]: { ms: 120 * 60000, last: T_A },
    [B]: { ms: 30 * 60000, last: T_B },
  };

  /**
   * Effekte ausführen und die Promise-Ketten (Mocks lösen in Microtasks auf) abwarten, ohne Timer. Kein `setTimeout`:
   * im Vollauf steht dort teils ein fremder Fake-Timer (`setTimeout.clock` gesetzt, `vi.isFakeTimers()` false), Ursache offen.
   */
  async function flush(): Promise<void> {
    TestBed.tick();
    for (let i = 0; i < 20; i++) await Promise.resolve();
  }

  function create(): void {
    profile = createFakeWorkProfile(A);
    gates = {};
    getOvertime = vi.fn(async (pid?: string) => { await gates[pid ?? '']; return data[pid ?? A].ms; });
    getLastUpdateDate = vi.fn(async (pid?: string) => { await gates[pid ?? '']; return data[pid ?? A].last; });
    updateInitialOvertime = vi.fn().mockResolvedValue(undefined);
    TestBed.resetTestingModule();
    TestBed.configureTestingModule({
      providers: [
        { provide: SettingsService, useValue: { getSettings: () => of(DEFAULT_SETTINGS), saveSettings: vi.fn() } },
        { provide: LeaveBalanceService, useValue: { refresh: vi.fn() } },
        { provide: AuthService, useValue: { user: signal(null) } },
        { provide: ProfileService, useValue: { isPremium: signal(false) } },
        { provide: OvertimeService, useValue: { getOvertime, getLastUpdateDate } },
        { provide: ThemeService, useValue: { isDarkMode: signal(false) } },
        { provide: LanguageService, useValue: { locale: signal('de') } },
        { provide: DataSyncService, useValue: { isSyncing: signal(false) } },
        { provide: WebPremiumService, useValue: {
          isConfigured: signal(false), isRestoring: signal(false), isPurchasing: signal(false) } },
        { provide: WorkProfileService, useValue: profile },
        { provide: DashboardService, useValue: { updateInitialOvertime } },
        { provide: Router, useValue: { navigate: vi.fn() } },
      ],
    });
    svc = TestBed.inject(SettingsPageService);
  }

  afterEach(() => TestBed.resetTestingModule());

  it('lädt den Saldo mit explizitem Profil', async () => {
    create();
    await flush();
    expect(getOvertime).toHaveBeenCalledWith(A);
    expect(getLastUpdateDate).toHaveBeenCalledWith(A);
    expect(svc.overtimeMs()).toBe(data[A].ms);
    expect(svc.lastOvertimeUpdate()).toEqual(T_A);
  });

  it('nach dem Wechsel A -> B zeigt die Seite Saldo und Datum von B', async () => {
    create();
    await flush();
    profile.set(B);
    await flush();
    expect(getOvertime).toHaveBeenLastCalledWith(B);
    expect(getLastUpdateDate).toHaveBeenLastCalledWith(B);
    expect(svc.overtimeMs()).toBe(data[B].ms);
    expect(svc.lastOvertimeUpdate()).toEqual(T_B);
  });

  it('eine überholte A-Antwort überschreibt die Anzeige von B nicht', async () => {
    create();
    await flush();
    let release!: () => void;
    gates[A] = new Promise<void>(r => { release = r; });
    profile.set(B); // Lauf für B (schnell) ...
    await flush();
    profile.set(A); // ... dann A (hängt) ...
    await flush();
    profile.set(B); // ... und wieder B, A-Antwort kommt zuletzt
    await flush();
    release();
    await flush();
    expect(svc.overtimeMs()).toBe(data[B].ms);
    expect(svc.lastOvertimeUpdate()).toEqual(T_B);
  });

  it('der Lade-Effect hängt nur an Auth und Profil: ein im Service gelesenes fremdes Signal löst kein Neuladen aus', async () => {
    create();
    const foreign = signal(0);
    getOvertime.mockImplementation(async (pid?: string) => { foreign(); return data[pid ?? A].ms; });
    await flush();
    const calls = getOvertime.mock.calls.length;
    foreign.set(1);
    await flush();
    expect(getOvertime.mock.calls.length).toBe(calls);
  });

  it('setOvertime reicht das angezeigte Profil an das Dashboard durch', async () => {
    create();
    await flush();
    profile.set(B);
    await flush();
    await svc.setOvertime(5 * 60000);
    expect(updateInitialOvertime).toHaveBeenCalledWith(5 * 60000, B);
    expect(svc.overtimeMs()).toBe(5 * 60000);
  });

  it('setOvertime im Lag-Fenster (Signal gewechselt, Anzeige noch A) schreibt in das angezeigte Profil A', async () => {
    create();
    await flush();
    profile.setSignalOnly(B); // Effekt noch nicht gelaufen: Anzeige zeigt weiter A
    await svc.setOvertime(7 * 60000);
    expect(updateInitialOvertime).toHaveBeenCalledWith(7 * 60000, A);
  });

  it('setOvertime überschreibt nach einem Wechsel während des Speicherns nicht die Anzeige des neuen Profils', async () => {
    create();
    await flush();
    let release!: () => void;
    updateInitialOvertime.mockReturnValue(new Promise<void>(r => { release = r; }));
    const p = svc.setOvertime(9 * 60000);
    profile.set(B);
    await flush();
    expect(svc.overtimeMs()).toBe(data[B].ms);
    release();
    await p;
    expect(updateInitialOvertime).toHaveBeenCalledWith(9 * 60000, A);
    expect(svc.overtimeMs()).toBe(data[B].ms);
  });
});
