import { TestBed } from '@angular/core/testing';
import { Firestore } from '@angular/fire/firestore';
import { BehaviorSubject, firstValueFrom, of } from 'rxjs';
import { WorkEntryService } from './work-entry';
import { AuthService } from '../auth/auth';
import { ApiClient } from './api-client';
import { WorkProfileService } from './work-profile';
import { createFakeWorkProfile, FakeWorkProfile } from '../../shared/testing/work-profile-fake';
import { WorkEntry, WorkEntryType } from '../../shared/models';

const ENTRY: WorkEntry = {
  id: '2026-10-05', date: new Date(2026, 9, 5), breaks: [], isManuallyEntered: false, type: WorkEntryType.Work,
  workStart: new Date(2026, 9, 5, 8, 0),
};

describe('WorkEntryService profileId (#380)', () => {
  let api: { saveWorkEntry: ReturnType<typeof vi.fn> };
  let profile: FakeWorkProfile;
  let user$: BehaviorSubject<{ uid: string } | null>;
  // `doc`/`onSnapshot` aus @angular/fire sind im gebündelten Test nicht mockbar: der Firestore-Zugriff wird über
  // `_firebaseToday(uid, profileId)` abgegriffen (die Pfadbildung selbst deckt `profileScopedPath` ab).
  let firebaseToday: ReturnType<typeof vi.fn>;

  function setup(uid: string | null): WorkEntryService {
    api = { saveWorkEntry: vi.fn().mockResolvedValue(undefined) };
    profile = createFakeWorkProfile('B'); // aktiv ist B
    user$ = new BehaviorSubject<{ uid: string } | null>(uid ? { uid } : null);
    TestBed.resetTestingModule();
    TestBed.configureTestingModule({
      providers: [
        { provide: Firestore, useValue: {} },
        { provide: AuthService, useValue: { uid, user$: user$.asObservable() } },
        { provide: ApiClient, useValue: api },
        { provide: WorkProfileService, useValue: profile },
      ],
    });
    const svc = TestBed.inject(WorkEntryService);
    firebaseToday = vi.fn().mockReturnValue(of(null));
    (svc as unknown as { _firebaseToday: unknown })._firebaseToday = firebaseToday;
    return svc;
  }

  beforeEach(() => {
    localStorage.clear();
    vi.useFakeTimers();
    vi.setSystemTime(new Date(2026, 9, 5, 12, 0));
  });
  afterEach(() => {
    TestBed.resetTestingModule();
    vi.useRealTimers();
    localStorage.clear();
  });

  describe('saveEntry', () => {
    it('saveEntry(e, "A") schreibt in Profil A bei aktivem B', async () => {
      const svc = setup('u1');
      await svc.saveEntry(ENTRY, 'A');
      expect(api.saveWorkEntry).toHaveBeenCalledWith(ENTRY, 'A');
    });

    it('"default" -> undefined', async () => {
      const svc = setup('u1');
      await svc.saveEntry(ENTRY, 'default');
      expect(api.saveWorkEntry).toHaveBeenCalledWith(ENTRY, undefined);
    });

    it('ohne Argument: aktives Profil', async () => {
      const svc = setup('u1');
      await svc.saveEntry(ENTRY);
      expect(api.saveWorkEntry).toHaveBeenCalledWith(ENTRY, 'B');
    });

    it('anonym: localStorage, Argument ignoriert', async () => {
      const svc = setup(null);
      await svc.saveEntry(ENTRY, 'A');
      expect(api.saveWorkEntry).not.toHaveBeenCalled();
      expect(localStorage.getItem('local_work_entries_2026_10')).toContain('"5"');
    });
  });

  describe('getTodayEntry', () => {
    it('getTodayEntry("A") liest den Pfad von Profil A, unabhängig vom activeProfileId$', async () => {
      const svc = setup('u1');
      profile.emitObservable('B');
      await firstValueFrom(svc.getTodayEntry('A'));
      expect(firebaseToday).toHaveBeenCalledTimes(1);
      expect(firebaseToday).toHaveBeenCalledWith('u1', 'A');
    });

    it('getTodayEntry("default") liest den Standard-Pfad', async () => {
      const svc = setup('u1');
      await firstValueFrom(svc.getTodayEntry('default'));
      expect(firebaseToday).toHaveBeenCalledWith('u1', 'default');
    });

    it('ohne Argument folgt dem activeProfileId$ (Kompatibilität)', async () => {
      const svc = setup('u1');
      await firstValueFrom(svc.getTodayEntry());
      expect(firebaseToday).toHaveBeenCalledWith('u1', 'B');
    });

    it('anonym: Argument ignoriert, kein Firestore-Zugriff', async () => {
      const svc = setup(null);
      expect(await firstValueFrom(svc.getTodayEntry('A'))).toBeNull();
      expect(firebaseToday).not.toHaveBeenCalled();
    });
  });
});
