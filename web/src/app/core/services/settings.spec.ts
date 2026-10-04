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
