import { TestBed } from '@angular/core/testing';
import { Firestore } from '@angular/fire/firestore';
import { of } from 'rxjs';
import { WorkEntryService } from './work-entry';
import { AuthService } from '../auth/auth';
import { ApiClient } from './api-client';
import { WorkProfileService } from './work-profile';
import { createFakeWorkProfile } from '../../shared/testing/work-profile-fake';
import { WorkEntry, WorkEntryType } from '../../shared/models';

const DAY = new Date(2026, 5, 5);
const KEY = 'local_work_entries_2026_06';

function entry(workLocations?: string[], over: Partial<WorkEntry> = {}): WorkEntry {
  return {
    id: '2026-06-05', date: DAY, breaks: [], isManuallyEntered: false, type: WorkEntryType.Work,
    workStart: new Date(2026, 5, 5, 8, 0), workLocations, ...over,
  };
}

describe('WorkEntryService workLocations (#526)', () => {
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

    it('fehlendes Feld -> []', () => {
      expect(fromFs(setup('u1'), {})?.workLocations).toEqual([]);
    });

    it('Array -> Liste in Reihenfolge', () => {
      expect(fromFs(setup('u1'), { workLocations: ['Büro', 'Kunde'] })?.workLocations).toEqual(['Büro', 'Kunde']);
    });

    it('kein Array / Nicht-Texte -> []', () => {
      expect(fromFs(setup('u1'), { workLocations: 'Büro' })?.workLocations).toEqual([]);
      expect(fromFs(setup('u1'), { workLocations: ['Büro', 3, null] })?.workLocations).toEqual(['Büro']);
    });
  });

  describe('localStorage', () => {
    it('Roundtrip mit Liste', async () => {
      const svc = setup(null);
      await svc.saveEntry(entry(['Büro', 'Kunde']));
      const [e] = await svc.getEntriesForMonthOnce(2026, 6);
      expect(e.workLocations).toEqual(['Büro', 'Kunde']);
    });

    it('speichert bereinigt (trimmen, Duplikate, leere)', async () => {
      const svc = setup(null);
      await svc.saveEntry(entry(['  Büro ', 'BÜRO', '', 'Kunde']));
      const [e] = await svc.getEntriesForMonthOnce(2026, 6);
      expect(e.workLocations).toEqual(['Büro', 'Kunde']);
    });

    it('Altdaten ohne Feld -> []', async () => {
      localStorage.setItem(KEY, JSON.stringify({ days: { '5': { workStart: null, workEnd: null, type: 'work', breaks: [] } } }));
      const [e] = await setup(null).getEntriesForMonthOnce(2026, 6);
      expect(e.workLocations).toEqual([]);
    });

    it('undefined über gespeicherten Orten lässt sie stehen (Schnelleintrag/Batch)', async () => {
      const svc = setup(null);
      await svc.saveEntry(entry(['Büro']));
      await svc.saveEntry(entry(undefined, { workEnd: new Date(2026, 5, 5, 16, 0) }));
      const [e] = await svc.getEntriesForMonthOnce(2026, 6);
      expect(e.workLocations).toEqual(['Büro']);
      expect(e.workEnd).toEqual(new Date(2026, 5, 5, 16, 0));
    });

    it('[] löscht die gespeicherten Orte (Feld fehlt im Speicher)', async () => {
      const svc = setup(null);
      await svc.saveEntry(entry(['Büro']));
      await svc.saveEntry(entry([]));
      const [e] = await svc.getEntriesForMonthOnce(2026, 6);
      expect(e.workLocations).toEqual([]);
      const stored = JSON.parse(localStorage.getItem(KEY)!) as { days: Record<string, Record<string, unknown>> };
      expect('workLocations' in stored.days['5']).toBe(false);
    });

    it('eine Liste ersetzt die gespeicherte', async () => {
      const svc = setup(null);
      await svc.saveEntry(entry(['Büro', 'Kunde']));
      await svc.saveEntry(entry(['Zuhause']));
      const [e] = await svc.getEntriesForMonthOnce(2026, 6);
      expect(e.workLocations).toEqual(['Zuhause']);
    });

    it('getAllLocalEntries (DataSync) enthält die Orte', async () => {
      const svc = setup(null);
      await svc.saveEntry(entry(['Büro']));
      expect(svc.getAllLocalEntries().map(e => e.workLocations)).toEqual([['Büro']]);
    });
  });

  it('eingeloggt reicht saveEntry die Orte an den ApiClient durch', async () => {
    const svc = setup('u1');
    await svc.saveEntry(entry(['Büro']));
    expect(api.saveWorkEntry).toHaveBeenCalledWith(expect.objectContaining({ workLocations: ['Büro'] }), undefined);
  });

  describe('Vorschläge', () => {
    it('gespeicherte Orte erscheinen als Vorschlag, schon gewählte nicht', async () => {
      const svc = setup(null);
      await svc.saveEntry(entry(['Büro', 'Kunde']));
      expect(svc.suggestWorkLocations([])).toEqual(['Büro', 'Kunde']);
      expect(svc.suggestWorkLocations(['büro'])).toEqual(['Kunde']);
    });

    it('eingeloggt: geladene Orte werden gemerkt, ohne API-Lesezugriff', async () => {
      const svc = setup('u1');
      await svc.saveEntry(entry(['Büro']));
      expect(svc.suggestWorkLocations([])).toEqual(['Büro']);
      expect(api.saveWorkEntry).toHaveBeenCalledTimes(1);
    });

    it('ohne gesetzte Orte (undefined) wird nichts gemerkt', async () => {
      const svc = setup('u1');
      await svc.saveEntry(entry(undefined));
      expect(svc.suggestWorkLocations([])).toEqual([]);
    });
  });
});
