import { TestBed } from '@angular/core/testing';
import { Firestore } from '@angular/fire/firestore';
import { firstValueFrom, of } from 'rxjs';
import { SettingsService } from './settings';
import { AuthService } from '../auth/auth';
import { ApiClient } from './api-client';
import { WorkProfileService } from './work-profile';

let apiSaveSettings: ReturnType<typeof vi.fn>;

function setup(uid: string | null = null): SettingsService {
  apiSaveSettings = vi.fn();
  TestBed.resetTestingModule();
  TestBed.configureTestingModule({
    providers: [
      { provide: Firestore, useValue: {} },
      { provide: AuthService, useValue: { user$: of(null), uid } },
      { provide: ApiClient, useValue: { saveSettings: apiSaveSettings } },
      { provide: WorkProfileService, useValue: { activeProfileId$: of('default'), activeProfileIdForApi: undefined } },
    ],
  });
  return TestBed.inject(SettingsService);
}

describe('SettingsService (anonym) - vacationDaysPerYear', () => {
  beforeEach(() => localStorage.clear());
  afterEach(() => localStorage.clear());

  it('liefert ohne Eintrag den Default 30', async () => {
    expect((await firstValueFrom(setup().getSettings())).vacationDaysPerYear).toBe(30);
  });

  it('liest einen gespeicherten Wert', async () => {
    localStorage.setItem('user_settings', JSON.stringify({ vacationDaysPerYear: 25 }));
    expect((await firstValueFrom(setup().getSettings())).vacationDaysPerYear).toBe(25);
  });

  it.each(['"x"', 'null', '400'])('normalisiert ungültigen Wert %s auf 30', async raw => {
    localStorage.setItem('user_settings', `{"vacationDaysPerYear":${raw}}`);
    expect((await firstValueFrom(setup().getSettings())).vacationDaysPerYear).toBe(30);
  });

  it('schreibt das Feld beim anonymen Speichern in localStorage', async () => {
    const svc = setup();
    const current = await firstValueFrom(svc.getSettings());
    await svc.saveSettings({ ...current, vacationDaysPerYear: 20 });
    expect(JSON.parse(localStorage.getItem('user_settings')!).vacationDaysPerYear).toBe(20);
  });
});

describe('SettingsService (anonym) - workdays', () => {
  beforeEach(() => localStorage.clear());
  afterEach(() => localStorage.clear());

  it('heilt gespeicherte Duplikate und sortiert (Fehler im Arbeitstage-Dialog)', async () => {
    localStorage.setItem('user_settings', JSON.stringify({ workdays: [1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6] }));
    expect((await firstValueFrom(setup().getSettings())).workdays).toEqual([1, 2, 3, 4, 5, 6]);
  });

  it('lässt eine gültige Liste unverändert', async () => {
    localStorage.setItem('user_settings', JSON.stringify({ workdays: [2, 4] }));
    expect((await firstValueFrom(setup().getSettings())).workdays).toEqual([2, 4]);
  });
});

describe('SettingsService - bundesland', () => {
  beforeEach(() => localStorage.clear());
  afterEach(() => localStorage.clear());

  it('liest ein gespeichertes Bundesland', async () => {
    localStorage.setItem('user_settings', JSON.stringify({ bundesland: 'bayern' }));
    expect((await firstValueFrom(setup().getSettings())).bundesland).toBe('bayern');
  });

  it.each(['""', '"xyz"', '123', 'null'])('normalisiert Rohwert %s zu null', async raw => {
    localStorage.setItem('user_settings', `{"bundesland":${raw}}`);
    expect((await firstValueFrom(setup().getSettings())).bundesland).toBeNull();
  });

  it('liefert ohne Feld null', async () => {
    localStorage.setItem('user_settings', '{}');
    expect((await firstValueFrom(setup().getSettings())).bundesland).toBeNull();
  });

  it('speichert anonym lokal und löscht per null, ohne API-Aufruf', async () => {
    const svc = setup();
    const current = await firstValueFrom(svc.getSettings());
    await svc.saveSettings({ ...current, bundesland: 'hessen' });
    expect(JSON.parse(localStorage.getItem('user_settings')!).bundesland).toBe('hessen');
    await svc.saveSettings({ ...current, bundesland: null }, { clearBundesland: true });
    expect(JSON.parse(localStorage.getItem('user_settings')!).bundesland).toBeNull();
    expect(apiSaveSettings).not.toHaveBeenCalled();
  });

  it('eingeloggt: ruft die API ohne opts auf', async () => {
    const svc = setup('u1');
    const s = { ...(await firstValueFrom(svc.getSettings())), bundesland: 'berlin' as const };
    await svc.saveSettings(s);
    expect(apiSaveSettings).toHaveBeenCalledWith(s, undefined, undefined);
  });

  it('eingeloggt: reicht clearBundesland durch', async () => {
    const svc = setup('u1');
    const s = await firstValueFrom(svc.getSettings());
    await svc.saveSettings(s, { clearBundesland: true });
    expect(apiSaveSettings).toHaveBeenCalledWith(s, undefined, { clearBundesland: true });
  });
});

describe('SettingsService.getSettingsOnce (#385)', () => {
  let apiGetSettings: ReturnType<typeof vi.fn>;
  let activeForApi: string | undefined;

  function setupOnce(uid: string | null): SettingsService {
    apiGetSettings = vi.fn();
    activeForApi = 'B';
    TestBed.resetTestingModule();
    TestBed.configureTestingModule({
      providers: [
        { provide: Firestore, useValue: {} },
        { provide: AuthService, useValue: { user$: of(null), uid } },
        { provide: ApiClient, useValue: { getSettings: apiGetSettings, saveSettings: vi.fn() } },
        {
          provide: WorkProfileService,
          useValue: { activeProfileId$: of('B'), get activeProfileIdForApi() { return activeForApi; } },
        },
      ],
    });
    return TestBed.inject(SettingsService);
  }

  beforeEach(() => localStorage.clear());
  afterEach(() => { TestBed.resetTestingModule(); localStorage.clear(); });

  it('eingeloggt: liest über die API mit explizitem Profil und merged mit den Defaults', async () => {
    const svc = setupOnce('u1');
    apiGetSettings.mockResolvedValue({ weeklyTargetHours: 20 });
    const s = await svc.getSettingsOnce('A');
    expect(apiGetSettings).toHaveBeenCalledWith('A');
    expect(s.weeklyTargetHours).toBe(20);
    expect(s.workdays).toEqual([1, 2, 3, 4, 5]); // Default greift
    expect(s.vacationDaysPerYear).toBe(30);
  });

  it('eingeloggt: "default" -> undefined, ohne Argument das aktive Profil', async () => {
    const svc = setupOnce('u1');
    apiGetSettings.mockResolvedValue({});
    await svc.getSettingsOnce('default');
    expect(apiGetSettings).toHaveBeenLastCalledWith(undefined);
    await svc.getSettingsOnce();
    expect(apiGetSettings).toHaveBeenLastCalledWith('B');
  });

  it('eingeloggt: migriert workdaysPerWeek in workdays', async () => {
    const svc = setupOnce('u1');
    apiGetSettings.mockResolvedValue({ workdaysPerWeek: 3 });
    expect((await svc.getSettingsOnce('A')).workdays).toEqual([1, 2, 3]);
  });

  it('ausgeloggt: liest localStorage, Profil und API unbeteiligt', async () => {
    localStorage.setItem('user_settings', JSON.stringify({ weeklyTargetHours: 30 }));
    const svc = setupOnce(null);
    expect((await svc.getSettingsOnce('A')).weeklyTargetHours).toBe(30);
    expect(apiGetSettings).not.toHaveBeenCalled();
  });

  it('ein Lesefehler wird geworfen', async () => {
    const svc = setupOnce('u1');
    apiGetSettings.mockRejectedValue(new Error('offline'));
    await expect(svc.getSettingsOnce('A')).rejects.toThrow('offline');
  });

  it('getSettings() bleibt unverändert (Observable)', async () => {
    const svc = setupOnce(null);
    expect((await firstValueFrom(svc.getSettings())).weeklyTargetHours).toBe(40);
  });
});
