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

describe('WorkEntryService.getEntriesForMonthOnce (#385)', () => {
  let api: { getWorkEntriesForMonth: ReturnType<typeof vi.fn> };
  let profile: FakeWorkProfile;

  function setup(uid: string | null): WorkEntryService {
    api = { getWorkEntriesForMonth: vi.fn().mockResolvedValue([ENTRY]) };
    profile = createFakeWorkProfile('B'); // aktiv ist B
    TestBed.resetTestingModule();
    TestBed.configureTestingModule({
      providers: [
        { provide: Firestore, useValue: {} },
        { provide: AuthService, useValue: { uid, user$: of(uid ? { uid } : null) } },
        { provide: ApiClient, useValue: api },
        { provide: WorkProfileService, useValue: profile },
      ],
    });
    return TestBed.inject(WorkEntryService);
  }

  beforeEach(() => localStorage.clear());
  afterEach(() => { TestBed.resetTestingModule(); localStorage.clear(); });

  describe('eingeloggt', () => {
    it('liest über die API mit explizitem Profil, unabhängig vom aktiven (B)', async () => {
      const svc = setup('u1');
      expect(await svc.getEntriesForMonthOnce(2026, 10, 'A')).toEqual([ENTRY]);
      expect(api.getWorkEntriesForMonth).toHaveBeenCalledWith(2026, 10, 'A');
    });

    it('"default" -> undefined (kein Query-Parameter)', async () => {
      const svc = setup('u1');
      await svc.getEntriesForMonthOnce(2026, 10, 'default');
      expect(api.getWorkEntriesForMonth).toHaveBeenCalledWith(2026, 10, undefined);
    });

    it('ohne Profil-Argument gilt das aktive Profil', async () => {
      const svc = setup('u1');
      await svc.getEntriesForMonthOnce(2026, 10);
      expect(api.getWorkEntriesForMonth).toHaveBeenCalledWith(2026, 10, 'B');
    });

    it('ein Lesefehler wird geworfen, nie als leerer Monat getarnt', async () => {
      const svc = setup('u1');
      api.getWorkEntriesForMonth.mockRejectedValue(new Error('offline'));
      await expect(svc.getEntriesForMonthOnce(2026, 10, 'A')).rejects.toThrow('offline');
    });
  });

  describe('ausgeloggt', () => {
    it('liest den Monat aus localStorage (Flutter-Keys), Profil wird ignoriert, id aus dem Tag', async () => {
      localStorage.setItem('local_work_entries_2026_10', JSON.stringify({
        days: {
          '9': { workStart: new Date(2026, 9, 9, 8, 0).toISOString(), workEnd: null, type: 'work', breaks: [] },
          '2': { workStart: new Date(2026, 9, 2, 22, 0).toISOString(), workEnd: null, type: 'work', breaks: [] },
        },
      }));
      const svc = setup(null);
      const entries = await svc.getEntriesForMonthOnce(2026, 10, 'A');
      expect(entries.map(e => e.id)).toEqual(['2026-10-02', '2026-10-09']);
      expect(entries[0].workStart).toEqual(new Date(2026, 9, 2, 22, 0));
      expect(api.getWorkEntriesForMonth).not.toHaveBeenCalled();
    });

    it('leerer Monat -> []', async () => {
      const svc = setup(null);
      expect(await svc.getEntriesForMonthOnce(2026, 9)).toEqual([]);
    });
  });
});
