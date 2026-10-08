import { TestBed } from '@angular/core/testing';
import { OvertimeService } from './overtime';
import { AuthService } from '../auth/auth';
import { ApiClient } from './api-client';
import { WorkProfileService } from './work-profile';
import { createFakeWorkProfile, FakeWorkProfile } from '../../shared/testing/work-profile-fake';

describe('OvertimeService profileId (#380)', () => {
  let api: {
    getOvertimeMs: ReturnType<typeof vi.fn>;
    getOvertimeLastUpdate: ReturnType<typeof vi.fn>;
    saveOvertimeMs: ReturnType<typeof vi.fn>;
  };
  let profile: FakeWorkProfile;

  function setup(uid: string | null): OvertimeService {
    api = {
      getOvertimeMs: vi.fn().mockResolvedValue(60000),
      getOvertimeLastUpdate: vi.fn().mockResolvedValue(null),
      saveOvertimeMs: vi.fn().mockResolvedValue(undefined),
    };
    profile = createFakeWorkProfile('B'); // aktiv ist B
    TestBed.resetTestingModule();
    TestBed.configureTestingModule({
      providers: [
        { provide: AuthService, useValue: { uid } },
        { provide: ApiClient, useValue: api },
        { provide: WorkProfileService, useValue: profile },
      ],
    });
    return TestBed.inject(OvertimeService);
  }

  beforeEach(() => localStorage.clear());
  afterEach(() => { TestBed.resetTestingModule(); localStorage.clear(); });

  describe('eingeloggt', () => {
    it('saveOvertime(ms, "A") schreibt in Profil A, obwohl B aktiv ist', async () => {
      const svc = setup('u1');
      await svc.saveOvertime(5000, 'A');
      expect(api.saveOvertimeMs).toHaveBeenCalledWith(5000, 'A');
    });

    it('saveOvertime(ms, "default") -> undefined (Standard), aktiv ist B', async () => {
      const svc = setup('u1');
      await svc.saveOvertime(5000, 'default');
      expect(api.saveOvertimeMs).toHaveBeenCalledWith(5000, undefined);
    });

    it('getOvertime("A") / getLastUpdateDate("A") lesen Profil A', async () => {
      const svc = setup('u1');
      await svc.getOvertime('A');
      await svc.getLastUpdateDate('A');
      expect(api.getOvertimeMs).toHaveBeenCalledWith('A');
      expect(api.getOvertimeLastUpdate).toHaveBeenCalledWith('A');
    });

    it('getOvertime("default") / getLastUpdateDate("default") -> undefined', async () => {
      const svc = setup('u1');
      await svc.getOvertime('default');
      await svc.getLastUpdateDate('default');
      expect(api.getOvertimeMs).toHaveBeenCalledWith(undefined);
      expect(api.getOvertimeLastUpdate).toHaveBeenCalledWith(undefined);
    });

    it('ohne Argument: aktives Profil (Kompatibilität)', async () => {
      const svc = setup('u1');
      await svc.saveOvertime(5000);
      await svc.getOvertime();
      await svc.getLastUpdateDate();
      expect(api.saveOvertimeMs).toHaveBeenCalledWith(5000, 'B');
      expect(api.getOvertimeMs).toHaveBeenCalledWith('B');
      expect(api.getOvertimeLastUpdate).toHaveBeenCalledWith('B');
    });
  });

  describe('anonym', () => {
    it('ignoriert das Argument, localStorage-Pfad unverändert', async () => {
      const svc = setup(null);
      await svc.saveOvertime(120 * 60000, 'A');
      expect(localStorage.getItem('overtime_value')).toBe('120');
      expect(await svc.getOvertime('A')).toBe(120 * 60000);
      expect(await svc.getLastUpdateDate('A')).toBeNull();
      expect(api.saveOvertimeMs).not.toHaveBeenCalled();
      expect(api.getOvertimeMs).not.toHaveBeenCalled();
    });
  });
});

describe('OvertimeService keepLastUpdated (#385)', () => {
  let api: { saveOvertimeMs: ReturnType<typeof vi.fn> };

  function setup(uid: string | null): OvertimeService {
    api = { saveOvertimeMs: vi.fn().mockResolvedValue(undefined) };
    TestBed.resetTestingModule();
    TestBed.configureTestingModule({
      providers: [
        { provide: AuthService, useValue: { uid } },
        { provide: ApiClient, useValue: api },
        { provide: WorkProfileService, useValue: createFakeWorkProfile('B') },
      ],
    });
    return TestBed.inject(OvertimeService);
  }

  beforeEach(() => localStorage.clear());
  afterEach(() => { TestBed.resetTestingModule(); localStorage.clear(); });

  it('eingeloggt: reicht { keepLastUpdated: true } an den ApiClient durch (explizites Profil)', async () => {
    const svc = setup('u1');
    await svc.saveOvertime(5 * 60000, 'A', { keepLastUpdated: true });
    expect(api.saveOvertimeMs).toHaveBeenCalledWith(5 * 60000, 'A', { keepLastUpdated: true });
  });

  it('eingeloggt: Default-Aufruf bleibt unverändert (kein dritter Parameter)', async () => {
    const svc = setup('u1');
    await svc.saveOvertime(5 * 60000, 'A');
    expect(api.saveOvertimeMs.mock.calls[0]).toEqual([5 * 60000, 'A']);
  });

  it('ausgeloggt: schreibt nur overtime_value, overtime_last_update bleibt unberührt', async () => {
    const svc = setup(null);
    localStorage.setItem('overtime_last_update', '2026-10-01T10:00:00.000Z');
    await svc.saveOvertime(30 * 60000, 'A', { keepLastUpdated: true });
    expect(localStorage.getItem('overtime_value')).toBe('30');
    expect(localStorage.getItem('overtime_last_update')).toBe('2026-10-01T10:00:00.000Z');
    expect(api.saveOvertimeMs).not.toHaveBeenCalled();
  });
});
