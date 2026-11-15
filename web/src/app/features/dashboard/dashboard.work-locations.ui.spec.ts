import { TestBed, ComponentFixture } from '@angular/core/testing';
import { Component, input, output, signal } from '@angular/core';
import { MatDialog } from '@angular/material/dialog';
import { MatSnackBar } from '@angular/material/snack-bar';
import { provideTranslateService, TranslateService } from '@ngx-translate/core';
import { Router } from '@angular/router';
import { of } from 'rxjs';
import { DashboardComponent } from './dashboard';
import { DashboardService } from './dashboard.service';
import { OpenEntryService } from './open-entry';
import { createFakeOpenEntry } from '../../shared/testing/open-entry-fake';
import { TimeInputComponent } from '../../shared/components/time-input/time-input';
import { WorkEntry, WorkEntryType } from '../../shared/models/index';

@Component({ selector: 'app-time-input', template: '' })
class TimeInputStub {
  readonly label = input<string>();
  readonly value = input<unknown>();
  readonly disabled = input<boolean>();
  readonly showClear = input<boolean>();
  readonly settle = input<boolean>(false);
  readonly timeSelected = output<Date>();
}

/** Button/Zeile für Arbeitsorte und Sichtbarkeit des Home-Office-Schalters im Dashboard (#526). */
describe('DashboardComponent Arbeitsorte (#526)', () => {
  const base: WorkEntry = { id: 'x', date: new Date(2026, 5, 5), breaks: [], isManuallyEntered: false, type: WorkEntryType.Work };
  const workEntry = signal<WorkEntry>(base);
  const showWorkLocation = signal(true);
  const showHomeOffice = signal(true);
  const isSaving = signal(false);
  let setWorkLocations: ReturnType<typeof vi.fn>;
  let dialogResult: { locations: string[] } | undefined;
  let dialogOpen: ReturnType<typeof vi.fn>;
  let fixture: ComponentFixture<DashboardComponent>;

  beforeEach(() => {
    workEntry.set(base);
    showWorkLocation.set(true);
    showHomeOffice.set(true);
    isSaving.set(false);
    dialogResult = undefined;
    setWorkLocations = vi.fn().mockResolvedValue(undefined);
    dialogOpen = vi.fn(() => ({ afterClosed: () => of(dialogResult) }));
    TestBed.overrideComponent(DashboardComponent, {
      remove: { imports: [TimeInputComponent] },
      add: { imports: [TimeInputStub] },
    });
    TestBed.configureTestingModule({
      providers: [
        provideTranslateService(),
        { provide: DashboardService, useValue: {
          isLoading: signal(false), holidayToday: signal(null), isLoggedIn: signal(false), isSaving,
          netDuration: signal(0), grossDuration: signal(0), dailyOvertime: signal(0), totalOvertime: signal(0),
          isTimerRunning: signal(false), isBreakRunning: signal(false), expectedEndTime: signal(null),
          expectedEndTotalZero: signal(null), breaks: signal([]), workEntry, setWorkLocations,
          showWorkLocation, showHomeOffice, setHomeOffice: vi.fn(),
        } },
        { provide: OpenEntryService, useValue: createFakeOpenEntry() },
        { provide: Router, useValue: { navigate: vi.fn() } },
        { provide: MatDialog, useValue: { open: dialogOpen } },
        { provide: MatSnackBar, useValue: {} },
      ],
    });
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('de', {
      shared: {
        workLocationAddButton: 'Arbeitsort hinzufügen',
        workLocationEditAria: 'Arbeitsorte bearbeiten: {{names}}',
        homeOfficeLabel: 'Von zu Hause gearbeitet',
      },
    });
    translate.use('de');
    fixture = TestBed.createComponent(DashboardComponent);
  });

  const el = (): HTMLElement => fixture.nativeElement;
  const addButton = (): HTMLButtonElement | null => el().querySelector('.work-locations-add');
  const summary = (): HTMLButtonElement | null => el().querySelector('.work-locations-summary');
  const homeOffice = (): HTMLElement | null => el().querySelector('mat-slide-toggle');

  it('Einstellung an, keine Orte: Button statt Feld, keine Zeile', () => {
    fixture.detectChanges();
    expect(addButton()?.textContent).toContain('Arbeitsort hinzufügen');
    expect(summary()).toBeNull();
  });

  it('Einstellung aus: weder Button noch Zeile (kein leerer Platz)', () => {
    showWorkLocation.set(false);
    workEntry.set({ ...base, workLocations: ['Büro'] });
    fixture.detectChanges();
    expect(addButton()).toBeNull();
    expect(summary()).toBeNull();
  });

  it('mit Orten: kompakte Zeile mit Chips statt Button, aria-label nennt die Orte', () => {
    workEntry.set({ ...base, workLocations: ['Büro', 'Kunde'] });
    fixture.detectChanges();
    expect(addButton()).toBeNull();
    const chips = Array.from(el().querySelectorAll('.work-location-chip')).map(c => c.textContent?.trim());
    expect(chips).toEqual(['Büro', 'Kunde']);
    expect(summary()?.getAttribute('aria-label')).toBe('Arbeitsorte bearbeiten: Büro, Kunde');
  });

  it.each([WorkEntryType.Vacation, WorkEntryType.Sick, WorkEntryType.Holiday])('bei Typ %s ausgeblendet', type => {
    workEntry.set({ ...base, type, workLocations: ['Büro'] });
    fixture.detectChanges();
    expect(addButton()).toBeNull();
    expect(summary()).toBeNull();
  });

  it('Button und Zeile öffnen denselben Dialog mit den aktuellen Orten', () => {
    fixture.detectChanges();
    addButton()!.click();
    expect(dialogOpen.mock.calls[0][1].data).toEqual({ locations: [] });

    workEntry.set({ ...base, workLocations: ['Büro'] });
    fixture.detectChanges();
    summary()!.click();
    expect(dialogOpen.mock.calls[1][0]).toBe(dialogOpen.mock.calls[0][0]);
    expect(dialogOpen.mock.calls[1][1].data).toEqual({ locations: ['Büro'] });
  });

  it('Speichern im Dialog ruft svc.setWorkLocations', async () => {
    dialogResult = { locations: ['Büro', 'Kunde'] };
    fixture.detectChanges();
    addButton()!.click();
    await fixture.whenStable();
    expect(setWorkLocations).toHaveBeenCalledWith(['Büro', 'Kunde']);
  });

  it('Entfernen aller Orte im Dialog sendet []', async () => {
    workEntry.set({ ...base, workLocations: ['Büro'] });
    dialogResult = { locations: [] };
    fixture.detectChanges();
    summary()!.click();
    await fixture.whenStable();
    expect(setWorkLocations).toHaveBeenCalledWith([]);
  });

  it('Abbrechen ändert nichts', async () => {
    dialogResult = undefined;
    fixture.detectChanges();
    addButton()!.click();
    await fixture.whenStable();
    expect(setWorkLocations).not.toHaveBeenCalled();
  });

  it('Button ist während isSaving deaktiviert', () => {
    isSaving.set(true);
    fixture.detectChanges();
    expect(addButton()!.disabled).toBe(true);
  });

  it('Home-Office-Schalter nur bei eingeschalteter Einstellung', () => {
    fixture.detectChanges();
    expect(homeOffice()).toBeTruthy();
    showHomeOffice.set(false);
    fixture.detectChanges();
    expect(homeOffice()).toBeNull();
  });

  it('Home-Office aus, Ort an: Button bleibt, Schalter fehlt', () => {
    showHomeOffice.set(false);
    fixture.detectChanges();
    expect(addButton()).toBeTruthy();
    expect(homeOffice()).toBeNull();
  });
});
