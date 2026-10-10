import { TestBed } from '@angular/core/testing';
import { MAT_DIALOG_DATA, MatDialogRef } from '@angular/material/dialog';
import { provideTranslateService } from '@ngx-translate/core';
import { EditEntryDialogComponent } from './edit-entry-dialog';
import { WorkEntry, WorkEntryType } from '../../models/index';

/**
 * Die `id` eines neuen Eintrags ist der lokale Kalendertag (#407, Block B). `date.toISOString().split('T')[0]` ergab
 * östlich von UTC den Vortag (lokale Mitternacht = Vortag 22:00Z) und westlich für späte Uhrzeiten den Folgetag. Die Tests
 * laufen in jeder Zone und sind unter Berlin/Auckland/Los Angeles rot gegen die alte Fassung (in UTC bleibt der erste grün).
 */
describe('EditEntryDialogComponent: id aus dem lokalen Tag (#407)', () => {
  let close: ReturnType<typeof vi.fn>;

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
    // Ohne Template-Rendering: das Feld `WorkEntryType = WorkEntryType` der Component ist eine nackte importierte Referenz
    // (Vite-SSR-Falle, web/CLAUDE.md „Test-Falle“) und im Vollauf beim Rendern nicht deterministisch gesetzt.
    return TestBed.runInInjectionContext(() => new EditEntryDialogComponent());
  }

  afterEach(() => TestBed.resetTestingModule());

  it('neuer Eintrag, date = lokale Mitternacht 05.10.: id 2026-10-05', () => {
    open({ date: new Date(2026, 9, 5) }).onSave();
    expect(close).toHaveBeenCalledTimes(1);
    expect(close.mock.calls[0][0].id).toBe('2026-10-05');
  });

  it('neuer Eintrag, date = 05.10. 23:30 lokal: id 2026-10-05 (nicht der Folgetag)', () => {
    open({ date: new Date(2026, 9, 5, 23, 30) }).onSave();
    expect(close.mock.calls[0][0].id).toBe('2026-10-05');
  });

  it('neuer Eintrag am Monatserster und Jahresanfang', () => {
    open({ date: new Date(2026, 10, 1) }).onSave();
    expect(close.mock.calls[0][0].id).toBe('2026-11-01');
    open({ date: new Date(2026, 0, 1) }).onSave();
    expect(close.mock.calls[0][0].id).toBe('2026-01-01');
  });

  it('bestehender Eintrag behält seine id', () => {
    const entry: WorkEntry = {
      id: '2026-10-05', date: new Date(2026, 9, 5), breaks: [], isManuallyEntered: false, type: WorkEntryType.Work,
    };
    open({ entry, date: new Date(2026, 9, 5) }).onSave();
    expect(close.mock.calls[0][0].id).toBe('2026-10-05');
  });
});
