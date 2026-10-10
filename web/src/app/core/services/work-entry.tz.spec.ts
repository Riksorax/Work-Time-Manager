import { TestBed } from '@angular/core/testing';
import { Firestore } from '@angular/fire/firestore';
import { of } from 'rxjs';
import { WorkEntryService } from './work-entry';
import { AuthService } from '../auth/auth';
import { ApiClient } from './api-client';
import { WorkProfileService } from './work-profile';
import { createFakeWorkProfile } from '../../shared/testing/work-profile-fake';
import { toDateKey } from '../../shared/utils/german-holidays.util';
import { WorkEntry } from '../../shared/models';

/**
 * Zonen-Regressionstests (#407) für die Firestore-Lesegrenze `_fromFirestore`. Das Dokument speichert `date` als
 * UTC-Mitternacht (Firestore-`Timestamp`); westlich von UTC ergibt `toDate()` lokal den Vortag. `doc`/`onSnapshot`
 * sind im Bundle nicht mockbar, deshalb wird der Mapper direkt über den Klammerzugriff aufgerufen (wie `work-entry.spec.ts`).
 */
describe('WorkEntryService._fromFirestore: Kalendertag (#407)', () => {
  type Mapper = (data: Record<string, unknown>, id: string) => WorkEntry | null;

  function create(uid: string | null = 'u1'): WorkEntryService {
    TestBed.resetTestingModule();
    TestBed.configureTestingModule({
      providers: [
        { provide: Firestore, useValue: {} },
        { provide: AuthService, useValue: { uid, user$: of(uid ? { uid } : null) } },
        { provide: ApiClient, useValue: {} },
        { provide: WorkProfileService, useValue: createFakeWorkProfile() },
      ],
    });
    return TestBed.inject(WorkEntryService);
  }

  const ts = (d: Date) => ({ toDate: () => d });
  const utc = (y: number, m: number, d: number, h = 0, min = 0) => new Date(Date.UTC(y, m - 1, d, h, min));

  function map(data: Record<string, unknown>, id: string): WorkEntry | null {
    const svc = create();
    const fn = (svc as unknown as { _fromFirestore: Mapper })['_fromFirestore'].bind(svc);
    return fn(data, id);
  }

  afterEach(() => {
    TestBed.resetTestingModule();
    localStorage.clear();
  });

  it('W1: id 2026-10-05 mit UTC-Mitternacht -> lokaler 05.10., Montag, Mitternacht', () => {
    const e = map({ date: ts(utc(2026, 10, 5)), type: 'work' }, '2026-10-05')!;
    expect(toDateKey(e.date)).toBe('2026-10-05');
    expect(e.date.getDay()).toBe(1);
    expect(e.date.getTime()).toBe(new Date(2026, 9, 5).getTime());
    expect(e.date.getHours()).toBe(0);
    expect(e.id).toBe('2026-10-05');
  });

  it.each([
    ['2026-11-01', utc(2026, 11, 1)],
    ['2026-01-01', utc(2026, 1, 1)],
  ])('W1 Randfall %s: Monats-/Jahresgrenze bleibt erhalten', (id, stamp) => {
    const e = map({ date: ts(stamp) }, id)!;
    const [y, m, d] = id.split('-').map(Number);
    expect(e.date.getTime()).toBe(new Date(y, m - 1, d).getTime());
  });

  it('W2: die id gewinnt über ein abweichendes gespeichertes date (Altdaten 22:00Z am Vortag)', () => {
    const e = map({ date: ts(utc(2026, 10, 4, 22)) }, '2026-10-05')!;
    expect(toDateKey(e.date)).toBe('2026-10-05');
  });

  it('W2: die id gewinnt auch über date auf dem Vortag um 00:00Z', () => {
    const e = map({ date: ts(utc(2026, 10, 4)) }, '2026-10-05')!;
    expect(toDateKey(e.date)).toBe('2026-10-05');
  });

  it('W3: ungültige id (nichtnumerischer Tages-Key) -> Fallback auf die UTC-Felder von date', () => {
    const e = map({ date: ts(utc(2026, 10, 5)) }, '2026-10-NaN')!;
    expect(toDateKey(e.date)).toBe('2026-10-05');
  });

  it('W3: ungültige id und kein date -> null statt Eintrag mit date undefined', () => {
    expect(map({ type: 'work' }, '2026-10-NaN')).toBeNull();
    expect(map({}, '')).toBeNull();
  });

  it('W4: workStart, workEnd und Pausen bleiben echte Instants (minutengenau)', () => {
    const e = map({
      date: ts(utc(2026, 10, 5)),
      workStart: ts(utc(2026, 10, 5, 6, 0)),
      workEnd: ts(utc(2026, 10, 5, 14, 0)),
      breaks: [{ id: 'b1', name: 'Pause', start: ts(utc(2026, 10, 5, 9, 0)), end: ts(utc(2026, 10, 5, 9, 30)) }],
    }, '2026-10-05')!;
    expect(e.workStart!.getTime()).toBe(utc(2026, 10, 5, 6, 0).getTime());
    expect(e.workEnd!.getTime()).toBe(utc(2026, 10, 5, 14, 0).getTime());
    expect(e.breaks[0].start.getTime()).toBe(utc(2026, 10, 5, 9, 0).getTime());
    expect(e.breaks[0].end!.getTime()).toBe(utc(2026, 10, 5, 9, 30).getTime());
  });

  it('W5 (Regression, anonym): localStorage-Monat liefert date = lokale Mitternacht des Tages-Keys, id passend', async () => {
    localStorage.setItem('local_work_entries_2026_10', JSON.stringify({
      days: { '5': { workStart: new Date(2026, 9, 5, 8, 0).toISOString(), workEnd: null, type: 'work', breaks: [] } },
    }));
    const svc = create(null);
    const [e] = await svc.getEntriesForMonthOnce(2026, 10);
    expect(e.id).toBe('2026-10-05');
    expect(e.date.getTime()).toBe(new Date(2026, 9, 5).getTime());
  });
});
