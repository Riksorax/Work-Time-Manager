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

describe('ReportsService - Urlaubsübersicht neu laden', () => {
  let saveEntry: ReturnType<typeof vi.fn>;
  let deleteEntry: ReturnType<typeof vi.fn>;
  let refresh: ReturnType<typeof vi.fn>;
  let svc: ReportsService;
  const entry: WorkEntry = {
    id: '2026-03-02', date: new Date(2026, 2, 2), breaks: [], isManuallyEntered: true, type: WorkEntryType.Vacation,
  };

  beforeEach(() => {
    saveEntry = vi.fn().mockResolvedValue(undefined);
    deleteEntry = vi.fn().mockResolvedValue(undefined);
    refresh = vi.fn();
    TestBed.configureTestingModule({
      providers: [
        { provide: AuthService, useValue: { user$: of(null), user: signal(null) } },
        { provide: WorkProfileService, useValue: { activeProfileId$: of('default'), activeProfileIdForApi: undefined } },
        { provide: WorkEntryService, useValue: { getEntriesForMonth: () => of([]), saveEntry, deleteEntry } },
        { provide: SettingsService, useValue: { getSettings: () => of(DEFAULT_SETTINGS) } },
        { provide: ProfileService, useValue: { isPremium: signal(false) } },
        { provide: ApiClient, useValue: {} },
        { provide: Router, useValue: { navigate: vi.fn() } },
        { provide: LeaveBalanceService, useValue: { refresh } },
      ],
    });
    svc = TestBed.inject(ReportsService);
  });

  it('saveEntry lädt nach erfolgreichem Schreiben genau einmal neu', async () => {
    await svc.saveEntry(entry);
    expect(refresh).toHaveBeenCalledTimes(1);
  });

  it('deleteEntry lädt nach erfolgreichem Löschen genau einmal neu', async () => {
    await svc.deleteEntry('2026-03-02');
    expect(refresh).toHaveBeenCalledTimes(1);
  });

  it('saveBatchEntries lädt nach erfolgreichem Schreiben genau einmal neu', async () => {
    await svc.saveBatchEntries([new Date(2026, 2, 2), new Date(2026, 2, 3)], WorkEntryType.Vacation);
    expect(saveEntry).toHaveBeenCalledTimes(2);
    expect(refresh).toHaveBeenCalledTimes(1);
  });

  it('lädt bei fehlschlagendem Schreiben nicht neu', async () => {
    saveEntry.mockRejectedValue(new Error('x'));
    deleteEntry.mockRejectedValue(new Error('x'));
    await expect(svc.saveEntry(entry)).rejects.toThrow();
    await expect(svc.deleteEntry('a')).rejects.toThrow();
    await expect(svc.saveBatchEntries([entry.date], WorkEntryType.Sick)).rejects.toThrow();
    expect(refresh).not.toHaveBeenCalled();
  });
});
