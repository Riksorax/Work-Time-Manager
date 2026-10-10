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
import { entryDto, mapWorkEntryDtos } from '../../shared/testing/mapped-entries';
import { DEFAULT_SETTINGS, WorkEntry } from '../../shared/models/index';

/**
 * Zonen-Regressionstests (#407), Komposition Mapper -> ReportsService (anonym, Uhr Mo 05.10.2026): der Eintrag aus
 * einem Backend-DTO mit UTC-Mitternacht muss am Montag erscheinen (Kalenderpunkt, Tagesliste, Soll), nicht am Sonntag.
 */
describe('ReportsService mit gemapptem Eintrag (#407)', () => {
  let svc: ReportsService;

  async function create(entries: WorkEntry[]): Promise<void> {
    TestBed.resetTestingModule();
    TestBed.configureTestingModule({
      providers: [
        { provide: AuthService, useValue: { user$: of(null), user: signal(null) } },
        { provide: WorkProfileService, useValue: { activeProfileId$: of('default'), activeProfileIdForApi: undefined } },
        { provide: WorkEntryService, useValue: { getEntriesForMonth: () => of(entries) } },
        { provide: SettingsService, useValue: { getSettings: () => of(DEFAULT_SETTINGS) } },
        { provide: ProfileService, useValue: { isPremium: signal(false) } },
        { provide: ApiClient, useValue: {} },
        { provide: Router, useValue: { navigate: vi.fn() } },
        { provide: LeaveBalanceService, useValue: { refresh: vi.fn() } },
      ],
    });
    svc = TestBed.inject(ReportsService);
    TestBed.tick();
  }

  beforeEach(() => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date(2026, 9, 5, 12, 0));
  });
  afterEach(() => {
    TestBed.resetTestingModule();
    vi.useRealTimers();
  });

  it('S1: Kalenderpunkt, Tagesliste und Tagessoll liegen am Montag 05.10.', async () => {
    const entries = await mapWorkEntryDtos([entryDto('2026-10-05', '2026-10-05T00:00:00Z', {
      workStart: new Date(2026, 9, 5, 8, 0).toISOString(),
      workEnd: new Date(2026, 9, 5, 16, 0).toISOString(),
    })]);
    await create(entries);

    expect(svc.daysWithEntries()).toEqual([5]);
    expect(svc.selectedDate().getDate()).toBe(5);
    expect(svc.selectedDayEntries().map(e => e.id)).toEqual(['2026-10-05']);
    expect(svc.dailyStat().target).toBe(8 * 3_600_000);
    expect(svc.dailyStat().worked).toBe(8 * 3_600_000);
  });

  it('S1: der Sonntag 04.10. enthält den Eintrag des 05.10. nicht', async () => {
    const entries = await mapWorkEntryDtos([entryDto('2026-10-05')]);
    await create(entries);
    svc.selectDate(new Date(2026, 9, 4));
    expect(svc.selectedDayEntries()).toEqual([]);
  });
});
