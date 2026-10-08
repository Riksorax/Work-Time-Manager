import { TestBed } from '@angular/core/testing';
import { signal } from '@angular/core';
import { of } from 'rxjs';
import { MatDialog } from '@angular/material/dialog';
import { MatSnackBar } from '@angular/material/snack-bar';
import { provideTranslateService } from '@ngx-translate/core';
import { NoopAnimationsModule } from '@angular/platform-browser/animations';
import { WorkProfileSwitcherComponent } from './work-profile-switcher';
import { AuthService } from '../../../core/auth/auth';
import { ProfileService } from '../../../core/services/profile';
import { WorkProfileService } from '../../../core/services/work-profile';

describe('WorkProfileSwitcherComponent (#380)', () => {
  const workProfile = {
    profiles: signal([{ id: 'default', name: 'Standard' }]),
    activeProfileId: signal('default'),
    maxProfileCount: signal(2),
    requestSwitch: vi.fn(async () => true),
    setActiveProfile: vi.fn(),
    addProfile: vi.fn<(n: string) => Promise<{ id: string; name: string } | null>>(),
  };
  const dialog = { open: vi.fn(() => ({ afterClosed: () => of({ name: 'Neu' }) })) };
  const snackBar = { open: vi.fn() };

  function create(): WorkProfileSwitcherComponent {
    vi.clearAllMocks();
    TestBed.resetTestingModule();
    TestBed.configureTestingModule({
      imports: [NoopAnimationsModule],
      providers: [
        provideTranslateService({ fallbackLang: 'de' }),
        { provide: AuthService, useValue: { user: signal({ uid: 'u1' }) } },
        { provide: ProfileService, useValue: { isPremium: signal(true) } },
        { provide: WorkProfileService, useValue: workProfile },
        { provide: MatDialog, useValue: dialog },
        { provide: MatSnackBar, useValue: snackBar },
      ],
    });
    return TestBed.createComponent(WorkProfileSwitcherComponent).componentInstance;
  }

  afterEach(() => TestBed.resetTestingModule());

  it('select() geht über requestSwitch, nicht über setActiveProfile', () => {
    const c = create();
    c.select('B');
    expect(workProfile.requestSwitch).toHaveBeenCalledWith('B');
    expect(workProfile.setActiveProfile).not.toHaveBeenCalled();
  });

  it('handleAdd: wurde der Wechsel abgelehnt (null), gibt es weder Erfolgs- noch Fehlermeldung', async () => {
    const c = create();
    workProfile.addProfile.mockResolvedValue(null);
    c.handleAdd();
    await Promise.resolve();
    await Promise.resolve();
    expect(workProfile.addProfile).toHaveBeenCalledWith('Neu');
    expect(snackBar.open).not.toHaveBeenCalled();
  });

  it('handleAdd: bei Erfolg erscheint die „Profil angelegt"-Meldung', async () => {
    const c = create();
    workProfile.addProfile.mockResolvedValue({ id: 'B', name: 'Neu' });
    c.handleAdd();
    await Promise.resolve();
    await Promise.resolve();
    expect(snackBar.open).toHaveBeenCalledTimes(1);
  });
});
