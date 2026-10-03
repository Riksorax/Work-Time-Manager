import { TestBed } from '@angular/core/testing';
import { Firestore } from '@angular/fire/firestore';
import { firstValueFrom, of } from 'rxjs';
import { SettingsService } from './settings';
import { AuthService } from '../auth/auth';
import { ApiClient } from './api-client';
import { WorkProfileService } from './work-profile';

function setup(): SettingsService {
  TestBed.resetTestingModule();
  TestBed.configureTestingModule({
    providers: [
      { provide: Firestore, useValue: {} },
      { provide: AuthService, useValue: { user$: of(null), uid: null } },
      { provide: ApiClient, useValue: { saveSettings: vi.fn() } },
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
