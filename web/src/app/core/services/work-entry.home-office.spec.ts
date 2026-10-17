import { TestBed } from '@angular/core/testing';
import { Firestore } from '@angular/fire/firestore';
import { of } from 'rxjs';
import { WorkEntryService } from './work-entry';
import { AuthService } from '../auth/auth';
import { ApiClient } from './api-client';
import { WorkProfileService } from './work-profile';
import { createFakeWorkProfile } from '../../shared/testing/work-profile-fake';
import { WorkEntry, WorkEntryType } from '../../shared/models';
import { DataSyncService } from './data-sync';
import { OvertimeService } from './overtime';
import { SettingsService } from './settings';
import { LeaveBalanceService } from './leave-balance';

const DAY = new Date(2026, 5, 5);
const KEY = 'local_work_entries_2026_06';

function entry(isHomeOffice?: boolean, over: Partial<WorkEntry> = {}): WorkEntry {
  return {
    id: '2026-06-05', date: DAY, breaks: [], isManuallyEntered: false, type: WorkEntryType.Work,
    workStart: new Date(2026, 5, 5, 8, 0), isHomeOffice, ...over,
  };
}

describe('WorkEntryService isHomeOffice (#277)', () => {
  let api: { saveWorkEntry: ReturnType<typeof vi.fn> };

  function setup(uid: string | null): WorkEntryService {
    api = { saveWorkEntry: vi.fn().mockResolvedValue(undefined) };
    TestBed.resetTestingModule();
    TestBed.configureTestingModule({
      providers: [
        { provide: Firestore, useValue: {} },
        { provide: AuthService, useValue: { uid, user$: of(uid ? { uid } : null) } },
        { provide: ApiClient, useValue: api },
        { provide: WorkProfileService, useValue: createFakeWorkProfile('default') },
      ],
    });
    return TestBed.inject(WorkEntryService);
  }

  beforeEach(() => localStorage.clear());
  afterEach(() => { TestBed.resetTestingModule(); localStorage.clear(); });

  describe('Firestore-Lesepfad', () => {
    const fromFs = (svc: WorkEntryService, data: Record<string, unknown>) =>
      (svc as unknown as { _fromFirestore: (d: Record<string, unknown>, id: string) => WorkEntry | null })
        ._fromFirestore({ type: 'work', breaks: [], ...data }, '2026-06-05');

    it('fehlendes Feld -> false', () => {
      expect(fromFs(setup('u1'), {})?.isHomeOffice).toBe(false);
    });

    it('vorhandenes Feld -> Wert', () => {
      expect(fromFs(setup('u1'), { isHomeOffice: true })?.isHomeOffice).toBe(true);
      expect(fromFs(setup('u1'), { isHomeOffice: false })?.isHomeOffice).toBe(false);
    });
  });

  describe('localStorage', () => {
    it.each([[true], [false]])('Roundtrip %s', async v => {
      const svc = setup(null);
      await svc.saveEntry(entry(v));
      const [e] = await svc.getEntriesForMonthOnce(2026, 6);
      expect(e.isHomeOffice).toBe(v);
    });

    it('Altdaten ohne Feld -> false', async () => {
      localStorage.setItem(KEY, JSON.stringify({ days: { '5': { workStart: null, workEnd: null, type: 'work', breaks: [] } } }));
      const [e] = await setup(null).getEntriesForMonthOnce(2026, 6);
      expect(e.isHomeOffice).toBe(false);
    });

    it('undefined über gespeichertem true lässt true stehen (Schnelleintrag)', async () => {
      const svc = setup(null);
      await svc.saveEntry(entry(true));
      await svc.saveEntry(entry(undefined, { workEnd: new Date(2026, 5, 5, 16, 0) }));
      const [e] = await svc.getEntriesForMonthOnce(2026, 6);
      expect(e.isHomeOffice).toBe(true);
      expect(e.workEnd).toEqual(new Date(2026, 5, 5, 16, 0));
    });

    it('false überschreibt true', async () => {
      const svc = setup(null);
      await svc.saveEntry(entry(true));
      await svc.saveEntry(entry(false));
      const [e] = await svc.getEntriesForMonthOnce(2026, 6);
      expect(e.isHomeOffice).toBe(false);
    });

    it('undefined ohne Vorwert -> false beim Lesen', async () => {
      const svc = setup(null);
      await svc.saveEntry(entry(undefined));
      const [e] = await svc.getEntriesForMonthOnce(2026, 6);
      expect(e.isHomeOffice).toBe(false);
    });

    it('getAllLocalEntries enthält das Flag', async () => {
      const svc = setup(null);
      await svc.saveEntry(entry(true));
      expect(svc.getAllLocalEntries().map(e => e.isHomeOffice)).toEqual([true]);
    });
  });

  it('eingeloggt reicht saveEntry das Flag an den ApiClient durch', async () => {
    const svc = setup('u1');
    const e = entry(true);
    await svc.saveEntry(e);
    expect(api.saveWorkEntry).toHaveBeenCalledWith(expect.objectContaining({ isHomeOffice: true }), undefined);
  });
});

describe('DataSyncService: Home-Office-Flag (#277)', () => {
  afterEach(() => { TestBed.resetTestingModule(); localStorage.clear(); });

  it('Login-Migration reicht das lokale Flag an saveEntry durch', async () => {
    localStorage.clear();
    const saveEntry = vi.fn().mockResolvedValue(undefined);
    const local = entry(true);
    TestBed.configureTestingModule({
      providers: [
        { provide: WorkEntryService, useValue: { getAllLocalEntries: () => [local], saveEntry } },
        { provide: OvertimeService, useValue: { saveOvertime: vi.fn() } },
        { provide: SettingsService, useValue: { getSettings: () => of({}), saveSettings: vi.fn() } },
        { provide: AuthService, useValue: { uid: 'u1' } },
        { provide: LeaveBalanceService, useValue: { refresh: vi.fn() } },
      ],
    });
    await TestBed.inject(DataSyncService).syncAll();
    expect(saveEntry).toHaveBeenCalledWith(expect.objectContaining({ isHomeOffice: true }));
  });
});
