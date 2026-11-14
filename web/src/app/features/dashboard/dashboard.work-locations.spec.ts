import { TestBed } from '@angular/core/testing';
import { signal } from '@angular/core';
import { DashboardService } from './dashboard.service';
import { WorkProfileService } from '../../core/services/work-profile';
import { ProfileSwitchConfirmService } from '../../shared/components/work-profile-switcher/profile-switch-confirm';
import { createFakeWorkProfile } from '../../shared/testing/work-profile-fake';
import { DashboardWorld, WORLD_A as A, dashboardWorldProviders, worldEntry } from '../../shared/testing/dashboard-world-fake';
import { DEFAULT_SETTINGS, WorkEntry } from '../../shared/models/index';

// Arbeitsorte im DashboardService (#526), Muster `dashboard.home-office.spec.ts`. Feste lokale Daten (Montag 2026-10-05).

const MON = (h = 12, m = 0): Date => new Date(2026, 9, 5, h, m, 0);

const running = (workLocations?: string[]): WorkEntry => worldEntry(MON(), { workStart: MON(8, 0), workLocations });

function setup(
  aEntry: WorkEntry | null, settings: Partial<typeof DEFAULT_SETTINGS> = {},
): { svc: DashboardService; world: DashboardWorld } {
  const world = new DashboardWorld({ aEntry });
  world.data[A].settings = { ...DEFAULT_SETTINGS, ...settings };
  const profile = createFakeWorkProfile(A);
  const user = signal<{ uid: string } | null>({ uid: 'u1' });
  TestBed.resetTestingModule();
  TestBed.configureTestingModule({
    providers: [
      ...dashboardWorldProviders(world, () => profile, user),
      { provide: WorkProfileService, useValue: profile },
      { provide: ProfileSwitchConfirmService, useValue: { confirmStopAndSwitch: vi.fn(() => Promise.resolve(true)), notifySaveFailed: vi.fn() } },
    ],
  });
  return { svc: TestBed.inject(DashboardService), world };
}

const settle = async (): Promise<void> => { await vi.advanceTimersByTimeAsync(0); };

describe('DashboardService.setWorkLocations (#526)', () => {
  beforeEach(() => {
    localStorage.clear();
    vi.useFakeTimers();
    vi.setSystemTime(MON());
  });
  afterEach(() => {
    TestBed.resetTestingModule();
    vi.useRealTimers();
    vi.restoreAllMocks();
    localStorage.clear();
  });

  it('schreibt die Liste bei laufendem Eintrag, der Timer läuft weiter, andere Felder bleiben', async () => {
    const { svc, world } = setup(worldEntry(MON(), { workStart: MON(8, 0), isHomeOffice: true }));
    await settle();
    const timers = vi.getTimerCount();
    await svc.setWorkLocations(['Büro', 'Kunde']);
    expect(svc.workEntry().workLocations).toEqual(['Büro', 'Kunde']);
    const writes = world.entryWrites();
    expect(writes).toHaveLength(1);
    expect(writes[0].entry?.workLocations).toEqual(['Büro', 'Kunde']);
    expect(writes[0].entry?.isHomeOffice).toBe(true);
    expect(writes[0].entry?.workStart).toEqual(MON(8, 0));
    expect(svc.isTimerRunning()).toBe(true);
    expect(vi.getTimerCount()).toBe(timers);
  });

  it('schreibt ins geladene Profil', async () => {
    const { svc, world } = setup(running());
    await settle();
    await svc.setWorkLocations(['Büro']);
    expect(world.entryWrites()[0].rawPid).toBe(A);
  });

  it('bereinigt wie das Backend (trimmen, Duplikate, leere)', async () => {
    const { svc, world } = setup(running());
    await settle();
    await svc.setWorkLocations([' Büro ', 'büro', '', 'Kunde']);
    expect(world.entryWrites()[0].entry?.workLocations).toEqual(['Büro', 'Kunde']);
  });

  it('[] schreibt explizit eine leere Liste (Backend entfernt das Feld)', async () => {
    const { svc, world } = setup(running(['Büro']));
    await settle();
    await svc.setWorkLocations([]);
    expect(svc.workEntry().workLocations).toEqual([]);
    expect(world.entryWrites()[0].entry?.workLocations).toEqual([]);
  });

  it('ohne workStart: nur Zustand, kein Write; der spätere Start schreibt die Orte mit', async () => {
    const { svc, world } = setup(null);
    await settle();
    await svc.setWorkLocations(['Büro']);
    expect(svc.workEntry().workLocations).toEqual(['Büro']);
    expect(world.entryWrites()).toHaveLength(0);

    await svc.startOrStopTimer();
    const writes = world.entryWrites();
    expect(writes).toHaveLength(1);
    expect(writes[0].entry?.workStart).toBeDefined();
    expect(writes[0].entry?.workLocations).toEqual(['Büro']);
  });

  it('bestehende Aktionen erhalten die Orte (Pause, Stop)', async () => {
    const { svc, world } = setup(running(['Büro']));
    await settle();
    await svc.startOrStopBreak();
    expect(world.entryWrites().at(-1)?.entry?.workLocations).toEqual(['Büro']);
    await svc.startOrStopBreak();
    await svc.startOrStopTimer();
    expect(world.entryWrites().at(-1)?.entry?.workEnd).toBeDefined();
    expect(world.entryWrites().at(-1)?.entry?.workLocations).toEqual(['Büro']);
  });
});

describe('DashboardService: Anzeige-Einstellungen (#526)', () => {
  beforeEach(() => { localStorage.clear(); vi.useFakeTimers(); vi.setSystemTime(MON()); });
  afterEach(() => { TestBed.resetTestingModule(); vi.useRealTimers(); localStorage.clear(); });

  it('Standard: Ort aus, Home-Office an (heutiger Zustand)', async () => {
    const { svc } = setup(null);
    await settle();
    expect(svc.showWorkLocation()).toBe(false);
    expect(svc.showHomeOffice()).toBe(true);
  });

  it('Einstellung an/aus wird übernommen', async () => {
    const { svc } = setup(null, { showWorkLocationOnDashboard: true, showHomeOfficeOnDashboard: false });
    await settle();
    expect(svc.showWorkLocation()).toBe(true);
    expect(svc.showHomeOffice()).toBe(false);
  });

  it('Ausschalten löscht keine Daten: der Eintrag behält seine Orte', async () => {
    const { svc } = setup(running(['Büro']), { showWorkLocationOnDashboard: false });
    await settle();
    expect(svc.workEntry().workLocations).toEqual(['Büro']);
  });
});
