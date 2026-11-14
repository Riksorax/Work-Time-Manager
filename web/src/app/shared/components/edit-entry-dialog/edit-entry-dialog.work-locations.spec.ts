import { TestBed } from '@angular/core/testing';
import { MAT_DIALOG_DATA, MatDialogRef } from '@angular/material/dialog';
import { provideTranslateService } from '@ngx-translate/core';
import { EditEntryDialogComponent } from './edit-entry-dialog';
import { WorkEntry, WorkEntryType } from '../../models/index';

/** Arbeitsorte im Edit-Dialog (#526). Ohne Template-Rendering (Vite-SSR-Falle, siehe entry-day.spec). */
describe('EditEntryDialogComponent: Arbeitsorte (#526)', () => {
  let close: ReturnType<typeof vi.fn>;
  const DAY = new Date(2026, 5, 5);

  const entry = (over: Partial<WorkEntry> = {}): WorkEntry => ({
    id: '2026-06-05', date: DAY, breaks: [], isManuallyEntered: false, type: WorkEntryType.Work, ...over,
  });

  function open(data: { entry?: WorkEntry; date: Date }): EditEntryDialogComponent {
    close = vi.fn();
    TestBed.resetTestingModule();
    TestBed.configureTestingModule({
      providers: [
        provideTranslateService(),
        { provide: MatDialogRef, useValue: { close } },
        { provide: MAT_DIALOG_DATA, useValue: data },
      ],
    });
    return TestBed.runInInjectionContext(() => new EditEntryDialogComponent());
  }

  const saved = () => close.mock.calls[0][0] as Partial<WorkEntry>;
  const locations = (c: EditEntryDialogComponent) =>
    (c as unknown as { workLocations: { set: (v: string[]) => void } }).workLocations;

  afterEach(() => TestBed.resetTestingModule());

  it('Speichern ohne Änderung behält die Orte (Feld geht nicht verloren)', () => {
    open({ entry: entry({ workLocations: ['Büro', 'Kunde'] }), date: DAY }).onSave();
    expect(saved().workLocations).toEqual(['Büro', 'Kunde']);
  });

  it('bearbeitete Liste kommt im Ergebnis an, bereinigt', () => {
    const c = open({ entry: entry({ workLocations: ['Büro'] }), date: DAY });
    locations(c).set([' Zuhause ', 'zuhause', 'Kunde']);
    c.onSave();
    expect(saved().workLocations).toEqual(['Zuhause', 'Kunde']);
  });

  it('alle Orte entfernt -> [] (löscht)', () => {
    const c = open({ entry: entry({ workLocations: ['Büro'] }), date: DAY });
    locations(c).set([]);
    c.onSave();
    expect(saved().workLocations).toEqual([]);
  });

  it('neuer Eintrag ohne Orte -> []', () => {
    open({ date: DAY }).onSave();
    expect(saved().workLocations).toEqual([]);
  });

  it('bei Typ Urlaub bleibt das Original erhalten, auch wenn die Liste geändert wurde', () => {
    const c = open({ entry: entry({ workLocations: ['Büro'] }), date: DAY });
    locations(c).set(['Anders']);
    c.form.patchValue({ type: WorkEntryType.Vacation });
    c.onSave();
    expect(saved().workLocations).toEqual(['Büro']);
  });

  it('bei Typ Urlaub ohne Original bleibt es undefined (unangetastet)', () => {
    const c = open({ entry: entry(), date: DAY });
    // entry() hat kein Feld -> kein Original
    c.form.patchValue({ type: WorkEntryType.Sick });
    c.onSave();
    expect(saved().workLocations).toBeUndefined();
  });

  it('Typ Arbeit sichtbar, andere Typen nicht (gleiche Regel wie Home-Office)', () => {
    const c = open({ entry: entry(), date: DAY });
    expect(c.showHomeOffice()).toBe(true);
    c.form.patchValue({ type: WorkEntryType.Holiday });
    expect(c.showHomeOffice()).toBe(false);
  });
});
