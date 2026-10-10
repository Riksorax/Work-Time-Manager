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

/**
 * Zonenunabhängig (#407, Block B): Kalenderpunkt und Tagesliste richten sich nach dem Kalendertag aus der `id`.
 * Fixture: `id` Montag 05.10.2026, `date` Sonntag 04.10. (wie nach einer Lesegrenze, die den Vortag geliefert hat).
 * Uhr: Montag 05.10.2026, 12:00 lokal.
 */
describe('ReportsService: Tag aus der id (#407)', () => {
  let svc: ReportsService;

  const inconsistent: WorkEntry = {
    id: '2026-10-05', date: new Date(2026, 9, 4), breaks: [], isManuallyEntered: false, type: WorkEntryType.Work,
    workStart: new Date(2026, 9, 5, 8, 0), workEnd: new Date(2026, 9, 5, 16, 0),
  };

  beforeEach(() => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date(2026, 9, 5, 12, 0));
    TestBed.configureTestingModule({
      providers: [
        { provide: AuthService, useValue: { user$: of(null), user: signal(null) } },
        { provide: WorkProfileService, useValue: { activeProfileId$: of('default'), activeProfileIdForApi: undefined } },
        { provide: WorkEntryService, useValue: { getEntriesForMonth: () => of([inconsistent]) } },
        { provide: SettingsService, useValue: { getSettings: () => of(DEFAULT_SETTINGS) } },
        { provide: ProfileService, useValue: { isPremium: signal(false) } },
        { provide: ApiClient, useValue: {} },
        { provide: Router, useValue: { navigate: vi.fn() } },
        { provide: LeaveBalanceService, useValue: { refresh: vi.fn() } },
      ],
    });
    svc = TestBed.inject(ReportsService);
    TestBed.tick();
  });

  afterEach(() => {
    TestBed.resetTestingModule();
    vi.useRealTimers();
  });

  it('daysWithEntries: der Kalenderpunkt liegt am 5. (nicht am 4.)', () => {
    expect(svc.daysWithEntries()).toEqual([5]);
  });

  it('selectedDayEntries: Auswahl 05.10. enthält den Eintrag', () => {
    svc.selectDate(new Date(2026, 9, 5));
    expect(svc.selectedDayEntries().map(e => e.id)).toEqual(['2026-10-05']);
  });

  it('selectedDayEntries: Auswahl 04.10. enthält ihn nicht', () => {
    svc.selectDate(new Date(2026, 9, 4));
    expect(svc.selectedDayEntries()).toEqual([]);
  });
});
