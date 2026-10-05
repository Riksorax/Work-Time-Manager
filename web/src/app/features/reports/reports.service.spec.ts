import { TestBed } from '@angular/core/testing';
import { signal } from '@angular/core';
import { Router } from '@angular/router';
import { Observable, of, throwError } from 'rxjs';
import { ReportsService } from './reports.service';
import { AuthService } from '../../core/auth/auth';
import { ProfileService } from '../../core/services/profile';
import { SettingsService } from '../../core/services/settings';
import { WorkEntryService } from '../../core/services/work-entry';
import { WorkProfileService } from '../../core/services/work-profile';
import { ApiClient } from '../../core/services/api-client';
import { LeaveBalanceService } from '../../core/services/leave-balance';
import { DEFAULT_SETTINGS, UserSettings, WorkEntry, WorkEntryType } from '../../shared/models/index';

describe('ReportsService - bundesland', () => {
  function create(settings$: Observable<UserSettings>): ReportsService {
    TestBed.configureTestingModule({
      providers: [
        { provide: AuthService, useValue: { user$: of(null), user: signal(null) } },
        { provide: WorkProfileService, useValue: { activeProfileId$: of('default'), activeProfileIdForApi: undefined } },
        { provide: WorkEntryService, useValue: { getEntriesForMonth: () => of([]) } },
        { provide: SettingsService, useValue: { getSettings: () => settings$ } },
        { provide: ProfileService, useValue: { isPremium: signal(false) } },
        { provide: ApiClient, useValue: {} },
        { provide: Router, useValue: { navigate: vi.fn() } },
        { provide: LeaveBalanceService, useValue: { refresh: vi.fn() } },
      ],
    });
    return TestBed.inject(ReportsService);
  }

  it('liefert das gewählte Bundesland aus den Einstellungen', () => {
    const svc = create(of({ ...DEFAULT_SETTINGS, bundesland: 'bayern' }));
    expect(svc.bundesland()).toBe('bayern');
  });

  it('liefert null ohne Bundesland', () => {
    const svc = create(of(DEFAULT_SETTINGS));
    expect(svc.bundesland()).toBeNull();
  });

  it('liefert null bei Fehler beim Laden der Einstellungen', () => {
    const svc = create(throwError(() => new Error('x')));
    expect(svc.bundesland()).toBeNull();
  });
});

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

describe('ReportsService - Tageswechsel (#382)', () => {
  afterEach(() => vi.useRealTimers());

  function create(): ReportsService {
    TestBed.configureTestingModule({
      providers: [
        { provide: AuthService, useValue: { user$: of(null), user: signal(null) } },
        { provide: WorkProfileService, useValue: { activeProfileId$: of('default'), activeProfileIdForApi: undefined } },
        { provide: WorkEntryService, useValue: { getEntriesForMonth: () => of([]) } },
        { provide: SettingsService, useValue: { getSettings: () => of(DEFAULT_SETTINGS) } },
        { provide: ProfileService, useValue: { isPremium: signal(false) } },
        { provide: ApiClient, useValue: {} },
        { provide: Router, useValue: { navigate: vi.fn() } },
        { provide: LeaveBalanceService, useValue: { refresh: vi.fn() } },
      ],
    });
    return TestBed.inject(ReportsService);
  }

  it('Vorauswahl folgt dem neuen Tag um Mitternacht', () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date(2026, 9, 31, 23, 59, 30));
    const svc = create();
    TestBed.tick();
    expect(svc.selectedDate().getDate()).toBe(31);

    vi.advanceTimersByTime(60_000);
    TestBed.tick();
    expect(svc.selectedDate().getMonth()).toBe(10);
    expect(svc.selectedDate().getDate()).toBe(1);
  });

  it('eine manuell gewählte Auswahl bleibt erhalten', () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date(2026, 9, 31, 23, 59, 30));
    const svc = create();
    TestBed.tick();
    svc.selectDate(new Date(2026, 9, 5));
    vi.advanceTimersByTime(60_000);
    TestBed.tick();
    expect(svc.selectedDate().getDate()).toBe(5);
  });
});

describe('ReportsService - Mehrfachauswahl', () => {
  let saveEntry: ReturnType<typeof vi.fn>;
  let svc: ReportsService;

  // Feste lokale Daten: 1.10.2026 = Do, 2. = Fr, 3. = Sa, 4. = So, 5. = Mo (nur über Konstruktoren).
  const d = (day: number) => new Date(2026, 9, day);
  const key = (day: number) => `2026-10-${String(day).padStart(2, '0')}`;

  function create(settings: UserSettings = DEFAULT_SETTINGS): void {
    saveEntry = vi.fn().mockResolvedValue(undefined);
    TestBed.configureTestingModule({
      providers: [
        { provide: AuthService, useValue: { user$: of(null), user: signal(null) } },
        { provide: WorkProfileService, useValue: { activeProfileId$: of('default'), activeProfileIdForApi: undefined } },
        { provide: WorkEntryService, useValue: { getEntriesForMonth: () => of([]), saveEntry } },
        { provide: SettingsService, useValue: { getSettings: () => of(settings) } },
        { provide: ProfileService, useValue: { isPremium: signal(false) } },
        { provide: ApiClient, useValue: {} },
        { provide: Router, useValue: { navigate: vi.fn() } },
        { provide: LeaveBalanceService, useValue: { refresh: vi.fn() } },
      ],
    });
    svc = TestBed.inject(ReportsService);
  }

  const sorted = (): string[] => [...svc.selectedDates()].sort();

  it('startet mit ausgeschaltetem Modus und leerer Auswahl', () => {
    create();
    expect(svc.isMultiSelectActive()).toBe(false);
    expect(svc.selectedDates().size).toBe(0);
  });

  it('toggleMultiSelect schaltet an (leere Menge) und beim Ausschalten wird die Auswahl geleert', () => {
    create();
    svc.toggleMultiSelect();
    expect(svc.isMultiSelectActive()).toBe(true);
    expect(svc.selectedDates().size).toBe(0);
    svc.toggleDateSelection(d(1));
    svc.toggleMultiSelect();
    expect(svc.isMultiSelectActive()).toBe(false);
    expect(svc.selectedDates().size).toBe(0);
  });

  it('toggleDateSelection fügt hinzu, der zweite Aufruf entfernt; Sa/So werden nicht gefiltert', () => {
    create();
    svc.toggleDateSelection(d(3));
    expect(sorted()).toEqual([key(3)]);
    svc.toggleDateSelection(d(3));
    expect(svc.selectedDates().size).toBe(0);
  });

  describe('addDateRangeSelection', () => {
    it('schaltet den Modus ein, filtert Sa/So (Default Mo-Fr) und ist additiv', () => {
      create();
      svc.toggleDateSelection(d(8));
      svc.addDateRangeSelection([d(1), d(2), d(3), d(4), d(5)]);
      expect(svc.isMultiSelectActive()).toBe(true);
      expect(sorted()).toEqual([key(1), key(2), key(5), key(8)]);
    });

    it('enthält mit allen Arbeitstagen auch Sa/So', () => {
      create({ ...DEFAULT_SETTINGS, workdays: [1, 2, 3, 4, 5, 6, 7] });
      svc.addDateRangeSelection([d(1), d(2), d(3), d(4), d(5)]);
      expect(sorted()).toEqual([key(1), key(2), key(3), key(4), key(5)]);
    });

    it('lässt die Menge bei reinem Wochenende unverändert, der Modus bleibt an', () => {
      create();
      svc.addDateRangeSelection([d(3), d(4)]);
      expect(svc.selectedDates().size).toBe(0);
      expect(svc.isMultiSelectActive()).toBe(true);
    });
  });

  describe('removeDatesFromSelection', () => {
    beforeEach(() => create());

    it('entfernt nur die genannten Keys', () => {
      svc.addDateRangeSelection([d(1), d(2), d(5), d(6)]);
      svc.removeDatesFromSelection([d(2), d(6)]);
      expect(sorted()).toEqual([key(1), key(5)]);
    });

    it('ist ein No-op für nicht vorhandene Keys und für ein leeres Array', () => {
      svc.addDateRangeSelection([d(1), d(2)]);
      svc.removeDatesFromSelection([d(20)]);
      svc.removeDatesFromSelection([]);
      expect(sorted()).toEqual([key(1), key(2)]);
    });

    it('filtert beim Entfernen nicht nach Arbeitstagen (Sa per Toggle wird entfernt)', () => {
      svc.toggleDateSelection(d(3));
      svc.toggleDateSelection(d(1));
      svc.removeDatesFromSelection([d(3)]);
      expect(sorted()).toEqual([key(1)]);
    });

    it('lässt den Modus aktiv, auch bei leerer Menge', () => {
      svc.addDateRangeSelection([d(1)]);
      svc.removeDatesFromSelection([d(1)]);
      expect(svc.selectedDates().size).toBe(0);
      expect(svc.isMultiSelectActive()).toBe(true);
    });
  });

  describe('endMultiSelect', () => {
    beforeEach(() => create());

    it('schaltet den Modus aus und leert die Auswahl', () => {
      svc.addDateRangeSelection([d(1), d(2)]);
      svc.endMultiSelect();
      expect(svc.isMultiSelectActive()).toBe(false);
      expect(svc.selectedDates().size).toBe(0);
    });

    it('ist idempotent und schaltet nie wieder ein', () => {
      svc.addDateRangeSelection([d(1)]);
      svc.endMultiSelect();
      svc.endMultiSelect();
      expect(svc.isMultiSelectActive()).toBe(false);
    });

    it('bleibt im Ruhezustand aus', () => {
      svc.endMultiSelect();
      expect(svc.isMultiSelectActive()).toBe(false);
      expect(svc.selectedDates().size).toBe(0);
    });
  });

  describe('saveBatchEntries', () => {
    beforeEach(() => create());

    it('beendet nach Erfolg den Modus und leert die Auswahl', async () => {
      svc.addDateRangeSelection([d(1), d(2)]);
      await svc.saveBatchEntries([d(1), d(2)], WorkEntryType.Vacation);
      expect(saveEntry).toHaveBeenCalledTimes(2);
      expect(svc.isMultiSelectActive()).toBe(false);
      expect(svc.selectedDates().size).toBe(0);
    });

    it('behält bei Schreibfehler Modus und Auswahl', async () => {
      svc.addDateRangeSelection([d(1), d(2)]);
      saveEntry.mockRejectedValue(new Error('x'));
      await expect(svc.saveBatchEntries([d(1), d(2)], WorkEntryType.Sick)).rejects.toThrow();
      expect(svc.isMultiSelectActive()).toBe(true);
      expect(sorted()).toEqual([key(1), key(2)]);
    });
  });
});
