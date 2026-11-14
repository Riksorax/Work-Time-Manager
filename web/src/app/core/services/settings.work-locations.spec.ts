import { TestBed } from '@angular/core/testing';
import { Firestore } from '@angular/fire/firestore';
import { firstValueFrom, of } from 'rxjs';
import { SettingsService } from './settings';
import { AuthService } from '../auth/auth';
import { ApiClient } from './api-client';
import { WorkProfileService } from './work-profile';
import { createFakeWorkProfile } from '../../shared/testing/work-profile-fake';
import { DEFAULT_SETTINGS } from '../../shared/models';

/** Dashboard-Anzeige-Einstellungen im SettingsService (#526), Gastmodus (localStorage) und API. */
describe('SettingsService: Dashboard-Anzeige (#526)', () => {
  let api: { saveSettings: ReturnType<typeof vi.fn>; getSettings: ReturnType<typeof vi.fn> };

  function setup(uid: string | null): SettingsService {
    api = { saveSettings: vi.fn().mockResolvedValue(undefined), getSettings: vi.fn() };
    TestBed.resetTestingModule();
    TestBed.configureTestingModule({
      providers: [
        { provide: Firestore, useValue: {} },
        { provide: AuthService, useValue: { uid, user$: of(uid ? { uid } : null) } },
        { provide: ApiClient, useValue: api },
        { provide: WorkProfileService, useValue: createFakeWorkProfile('default') },
      ],
    });
    return TestBed.inject(SettingsService);
  }

  beforeEach(() => localStorage.clear());
  afterEach(() => { TestBed.resetTestingModule(); localStorage.clear(); });

  it('Standardwerte: Ort aus, Home-Office an', () => {
    expect(DEFAULT_SETTINGS.showWorkLocationOnDashboard).toBe(false);
    expect(DEFAULT_SETTINGS.showHomeOfficeOnDashboard).toBe(true);
  });

  it('Gast ohne gespeicherte Einstellungen: Standardwerte', async () => {
    const s = await firstValueFrom(setup(null).getSettings());
    expect(s.showWorkLocationOnDashboard).toBe(false);
    expect(s.showHomeOfficeOnDashboard).toBe(true);
  });

  it('Gast mit Altdaten ohne die Felder: Standardwerte', async () => {
    localStorage.setItem('user_settings', JSON.stringify({ weeklyTargetHours: 30 }));
    const s = await firstValueFrom(setup(null).getSettings());
    expect(s.weeklyTargetHours).toBe(30);
    expect(s.showWorkLocationOnDashboard).toBe(false);
    expect(s.showHomeOfficeOnDashboard).toBe(true);
  });

  it('Gast: Umschalten wird lokal gespeichert und gelesen', async () => {
    const svc = setup(null);
    await svc.saveSettings({ ...DEFAULT_SETTINGS, showWorkLocationOnDashboard: true, showHomeOfficeOnDashboard: false });
    const s = await firstValueFrom(svc.getSettings());
    expect(s.showWorkLocationOnDashboard).toBe(true);
    expect(s.showHomeOfficeOnDashboard).toBe(false);
    expect(JSON.parse(localStorage.getItem('user_settings')!)).toEqual(expect.objectContaining({
      showWorkLocationOnDashboard: true, showHomeOfficeOnDashboard: false,
    }));
  });

  it('ungültige gespeicherte Werte fallen auf den Standard zurück', async () => {
    localStorage.setItem('user_settings', JSON.stringify({ showWorkLocationOnDashboard: 'ja', showHomeOfficeOnDashboard: null }));
    const s = await firstValueFrom(setup(null).getSettings());
    expect(s.showWorkLocationOnDashboard).toBe(false);
    expect(s.showHomeOfficeOnDashboard).toBe(true);
  });

  it('eingeloggt: saveSettings reicht beide Felder an die API', async () => {
    const svc = setup('u1');
    await svc.saveSettings({ ...DEFAULT_SETTINGS, showWorkLocationOnDashboard: true });
    expect(api.saveSettings).toHaveBeenCalledWith(
      expect.objectContaining({ showWorkLocationOnDashboard: true, showHomeOfficeOnDashboard: true }),
      undefined, undefined,
    );
  });

  it('eingeloggt: getSettingsOnce übernimmt die API-Werte', async () => {
    const svc = setup('u1');
    api.getSettings.mockResolvedValue({ ...DEFAULT_SETTINGS, showWorkLocationOnDashboard: true, showHomeOfficeOnDashboard: false });
    const s = await svc.getSettingsOnce();
    expect(s.showWorkLocationOnDashboard).toBe(true);
    expect(s.showHomeOfficeOnDashboard).toBe(false);
  });
});
