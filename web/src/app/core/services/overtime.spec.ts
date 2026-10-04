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
