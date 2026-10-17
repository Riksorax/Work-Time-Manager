import { TestBed } from '@angular/core/testing';
import { signal } from '@angular/core';
import { DashboardService } from './dashboard.service';
import { WorkProfileService } from '../../core/services/work-profile';
import { ProfileSwitchConfirmService } from '../../shared/components/work-profile-switcher/profile-switch-confirm';
import { createFakeWorkProfile } from '../../shared/testing/work-profile-fake';
import { DashboardWorld, WORLD_A as A, dashboardWorldProviders, worldEntry } from '../../shared/testing/dashboard-world-fake';
import { WorkEntry } from '../../shared/models/index';

// Home-Office-Toggle im DashboardService (#277). Feste lokale Daten (Montag 2026-10-05) + vi.setSystemTime.

const MON = (h = 12, m = 0): Date => new Date(2026, 9, 5, h, m, 0);

const running = (isHomeOffice?: boolean): WorkEntry => worldEntry(MON(), { workStart: MON(8, 0), isHomeOffice });
const done = (isHomeOffice?: boolean): WorkEntry =>
  worldEntry(MON(), { workStart: MON(8, 0), workEnd: MON(16, 0), isHomeOffice });

function setup(aEntry: WorkEntry | null): { svc: DashboardService; world: DashboardWorld } {
  const world = new DashboardWorld({ aEntry });
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

describe('DashboardService.setHomeOffice (#277)', () => {
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

  it('setzt den Zustand und schreibt das Flag, wenn workStart gesetzt ist; der Timer läuft weiter', async () => {
    const { svc, world } = setup(running());
    await settle();
    const timers = vi.getTimerCount();
    await svc.setHomeOffice(true);
    expect(svc.workEntry().isHomeOffice).toBe(true);
    const writes = world.entryWrites();
    expect(writes).toHaveLength(1);
    expect(writes[0].entry?.isHomeOffice).toBe(true);
    expect(svc.isTimerRunning()).toBe(true);
    expect(vi.getTimerCount()).toBe(timers);
  });

  it('schreibt ins geladene Profil (festgehaltenes Argument, nie undefined)', async () => {
    const { svc, world } = setup(running());
    await settle();
    await svc.setHomeOffice(true);
    expect(world.entryWrites()[0].rawPid).toBe(A);
  });

  it('ausschalten schreibt explizit false', async () => {
    const { svc, world } = setup(running(true));
    await settle();
    await svc.setHomeOffice(false);
    expect(svc.workEntry().isHomeOffice).toBe(false);
    expect(world.entryWrites()[0].entry?.isHomeOffice).toBe(false);
  });

  it('ohne workStart: nur Zustand, kein Write; der spätere Start schreibt das Flag mit', async () => {
    const { svc, world } = setup(null);
    await settle();
    await svc.setHomeOffice(true);
    expect(svc.workEntry().isHomeOffice).toBe(true);
    expect(world.entryWrites()).toHaveLength(0);

    await svc.startOrStopTimer();
    const writes = world.entryWrites();
    expect(writes).toHaveLength(1);
    expect(writes[0].entry?.workStart).toBeDefined();
    expect(writes[0].entry?.isHomeOffice).toBe(true);
  });

  it('auf einem beendeten Eintrag wird das Flag geschrieben', async () => {
    const { svc, world } = setup(done(false));
    await settle();
    await svc.setHomeOffice(true);
    expect(world.entryWrites().at(-1)?.entry?.isHomeOffice).toBe(true);
    expect(svc.workEntry().workEnd).toEqual(MON(16, 0));
  });

  describe('bestehende Aktionen erhalten das Flag', () => {
    it('Pause starten', async () => {
      const { svc, world } = setup(running(true));
      await settle();
      await svc.startOrStopBreak();
      expect(world.entryWrites().at(-1)?.entry?.isHomeOffice).toBe(true);
    });

    it('Stop', async () => {
      const { svc, world } = setup(running(true));
      await settle();
      await svc.startOrStopTimer();
      expect(world.entryWrites().at(-1)?.entry?.workEnd).toBeDefined();
      expect(world.entryWrites().at(-1)?.entry?.isHomeOffice).toBe(true);
    });

    it('manuelle Endzeit', async () => {
      const { svc, world } = setup(running(true));
      await settle();
      await svc.setManualEndTime('16:00');
      expect(world.entryWrites().at(-1)?.entry?.isHomeOffice).toBe(true);
    });

    it('neue Session', async () => {
      const { svc, world } = setup(done(true));
      await settle();
      await svc.startNewSession(false);
      expect(world.entryWrites().at(-1)?.entry?.isHomeOffice).toBe(true);
    });
  });
});
