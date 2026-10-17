import { TestBed } from '@angular/core/testing';
import { signal } from '@angular/core';
import { Router } from '@angular/router';
import { of } from 'rxjs';
import { ReportsService } from './reports.service';
import { AuthService } from '../../core/auth/auth';
import { ProfileService } from '../../core/services/profile';
import { SettingsService } from '../../core/services/settings';
import { WorkEntryService } from '../../core/services/work-entry';
import { WorkProfileService } from '../../core/services/work-profile';
import { ApiClient } from '../../core/services/api-client';
import { LeaveBalanceService } from '../../core/services/leave-balance';
import { DEFAULT_SETTINGS, WorkEntry, WorkEntryType } from '../../shared/models/index';

// Home-Office-Tage im ReportsService (#277). Feste Kalendertage im Juni 2026, keine Abhängigkeit von Datum/Zone.
describe('ReportsService - Home-Office (#277)', () => {
  const day = (d: number, over: Partial<WorkEntry> = {}): WorkEntry => ({
    id: `2026-06-${String(d).padStart(2, '0')}`, date: new Date(2026, 5, d), breaks: [], isManuallyEntered: false,
    type: WorkEntryType.Work, ...over,
  });

  let saveEntry: ReturnType<typeof vi.fn>;

  function create(entries: WorkEntry[]): ReportsService {
    saveEntry = vi.fn().mockResolvedValue(undefined);
    TestBed.configureTestingModule({
      providers: [
        { provide: AuthService, useValue: { user$: of(null), user: signal(null) } },
        { provide: WorkProfileService, useValue: { activeProfileId$: of('default'), activeProfileIdForApi: undefined } },
        { provide: WorkEntryService, useValue: { getEntriesForMonth: () => of(entries), saveEntry } },
        { provide: SettingsService, useValue: { getSettings: () => of(DEFAULT_SETTINGS) } },
        { provide: ProfileService, useValue: { isPremium: signal(false) } },
        { provide: ApiClient, useValue: {} },
        { provide: Router, useValue: { navigate: vi.fn() } },
        { provide: LeaveBalanceService, useValue: { refresh: vi.fn() } },
      ],
    });
    const svc = TestBed.inject(ReportsService);
    TestBed.tick(); // toObservable(_viewMonth) feuert erst im Effect-Flush
    return svc;
  }

  afterEach(() => TestBed.resetTestingModule());

  it('enthält nur Tage mit Typ Arbeit und Flag', () => {
    const svc = create([
      day(1, { isHomeOffice: true }),
      day(2, { isHomeOffice: false }),
      day(3),
      day(4, { isHomeOffice: true, type: WorkEntryType.Vacation }),
      day(5, { isHomeOffice: true, type: WorkEntryType.Sick }),
      day(8, { isHomeOffice: true, type: WorkEntryType.Holiday }),
      day(9, { isHomeOffice: true }),
    ]);
    expect([...svc.homeOfficeDays()].sort((a, b) => a - b)).toEqual([1, 9]);
  });

  it('ist ohne Einträge leer', () => {
    expect(create([]).homeOfficeDays()).toEqual([]);
  });

  it('Batch-Einträge (Mehrfachauswahl) lassen das Flag unangetastet (undefined)', async () => {
    const svc = create([]);
    await svc.saveBatchEntries([new Date(2026, 5, 1), new Date(2026, 5, 2)], WorkEntryType.Vacation);
    expect(saveEntry).toHaveBeenCalledTimes(2);
    for (const [entry] of saveEntry.mock.calls as [WorkEntry][]) {
      expect(entry.isHomeOffice).toBeUndefined();
    }
  });
});
