import { TestBed } from '@angular/core/testing';
import { MAT_DIALOG_DATA, MatDialogRef } from '@angular/material/dialog';
import { provideTranslateService } from '@ngx-translate/core';
import { EditEntryDialogComponent } from './edit-entry-dialog';
import { WorkEntry, WorkEntryType } from '../../models/index';

/** Home-Office-Toggle im Edit-Dialog (#277). Ohne Template-Rendering (Vite-SSR-Falle, siehe entry-day.spec). */
describe('EditEntryDialogComponent: Home-Office (#277)', () => {
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

  afterEach(() => TestBed.resetTestingModule());

  it('Initialwert aus dem Eintrag', () => {
    expect(open({ entry: entry({ isHomeOffice: true }), date: DAY }).form.value.isHomeOffice).toBe(true);
    expect(open({ entry: entry({ isHomeOffice: false }), date: DAY }).form.value.isHomeOffice).toBe(false);
    expect(open({ entry: entry(), date: DAY }).form.value.isHomeOffice).toBe(false);
  });

  it('Toggle nur bei Typ Arbeit sichtbar', () => {
    const c = open({ entry: entry({ isHomeOffice: true }), date: DAY });
    expect(c.showHomeOffice()).toBe(true);
    c.form.patchValue({ type: WorkEntryType.Vacation });
    expect(c.showHomeOffice()).toBe(false);
    c.form.patchValue({ type: WorkEntryType.Work });
    expect(c.showHomeOffice()).toBe(true);
  });

  it.each([[true], [false]])('Speichern liefert isHomeOffice %s', v => {
    const c = open({ entry: entry({ isHomeOffice: !v }), date: DAY });
    c.form.patchValue({ isHomeOffice: v });
    c.onSave();
    expect(saved().isHomeOffice).toBe(v);
  });

  it('bei Typ Urlaub bleibt der Originalwert im Ergebnis', () => {
    const c = open({ entry: entry({ isHomeOffice: true }), date: DAY });
    c.form.patchValue({ type: WorkEntryType.Vacation, isHomeOffice: false });
    c.onSave();
    expect(saved().isHomeOffice).toBe(true);
  });

  it('ohne Original-Eintrag false', () => {
    open({ date: DAY }).onSave();
    expect(saved().isHomeOffice).toBe(false);
  });

  it('neuer Eintrag mit eingeschaltetem Toggle', () => {
    const c = open({ date: DAY });
    c.form.patchValue({ isHomeOffice: true });
    c.onSave();
    expect(saved().isHomeOffice).toBe(true);
  });
});
