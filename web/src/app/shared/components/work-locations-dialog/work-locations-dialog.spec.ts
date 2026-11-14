import { TestBed, ComponentFixture } from '@angular/core/testing';
import { MAT_DIALOG_DATA, MatDialogRef } from '@angular/material/dialog';
import { provideTranslateService, TranslateService } from '@ngx-translate/core';
import { WorkEntryService } from '../../../core/services/work-entry';
import { WorkLocationsDialogComponent, WorkLocationsDialogData } from './work-locations-dialog';

/** Dialog und Eingabe der Arbeitsorte (#526): Grenzen, Duplikate, Entfernen, Speichern/Abbrechen. */
describe('WorkLocationsDialogComponent (#526)', () => {
  let close: ReturnType<typeof vi.fn>;
  let suggest: ReturnType<typeof vi.fn>;
  let fixture: ComponentFixture<WorkLocationsDialogComponent>;

  async function open(locations: string[] = [], suggestions: string[] = []): Promise<void> {
    close = vi.fn();
    suggest = vi.fn(() => suggestions);
    TestBed.resetTestingModule();
    TestBed.configureTestingModule({
      providers: [
        provideTranslateService(),
        { provide: MatDialogRef, useValue: { close } },
        { provide: MAT_DIALOG_DATA, useValue: { locations } satisfies WorkLocationsDialogData },
        { provide: WorkEntryService, useValue: { suggestWorkLocations: suggest } },
      ],
    });
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('de', {
      common: { cancel: 'Abbrechen' },
      shared: {
        workLocationInputLabel: 'Arbeitsort',
        workLocationHint: 'Hinweis',
        workLocationMaxReached: 'Höchstens {{max}} Orte pro Tag.',
        workLocationRemoveAria: '{{name}} entfernen',
        workLocationSave: 'Speichern',
        workLocationErrorDuplicate: 'Dieser Ort ist schon eingetragen.',
        workLocationErrorTooLong: 'Höchstens {{length}} Zeichen.',
        workLocationDialogTitle: 'Arbeitsorte',
      },
    });
    translate.use('de');
    fixture = TestBed.createComponent(WorkLocationsDialogComponent);
    fixture.detectChanges();
    await fixture.whenStable();
  }

  const el = (): HTMLElement => fixture.nativeElement;
  const field = (): HTMLInputElement => el().querySelector('input')!;
  const chips = (): string[] =>
    Array.from(el().querySelectorAll('mat-chip')).map(c => c.textContent!.replace('cancel', '').trim());
  const message = (): string => el().querySelector('.wl-message')!.textContent!.trim();

  async function type(text: string, key = 'Enter'): Promise<void> {
    field().value = text;
    field().dispatchEvent(new Event('input', { bubbles: true }));
    const ev = new KeyboardEvent('keydown', { key, bubbles: true, cancelable: true });
    field().dispatchEvent(ev);
    fixture.detectChanges();
    await fixture.whenStable();
    fixture.detectChanges();
  }

  const save = (): HTMLButtonElement =>
    Array.from(el().querySelectorAll('button')).find(b => b.textContent?.includes('Speichern')) as HTMLButtonElement;
  const cancel = (): HTMLButtonElement =>
    Array.from(el().querySelectorAll('button')).find(b => b.textContent?.includes('Abbrechen')) as HTMLButtonElement;

  afterEach(() => TestBed.resetTestingModule());

  it('startet mit den übergebenen Orten und hat ein beschriftetes Feld', async () => {
    await open(['Büro', 'Kunde']);
    expect(chips()).toEqual(['Büro', 'Kunde']);
    expect(el().querySelector('mat-label')?.textContent).toContain('Arbeitsort');
    expect(el().querySelector('h2')?.textContent).toContain('Arbeitsorte');
  });

  it('Enter fügt einen Ort hinzu, Speichern liefert die Liste', async () => {
    await open([]);
    await type('  Büro ');
    expect(chips()).toEqual(['Büro']);
    save().click();
    expect(close).toHaveBeenCalledWith({ locations: ['Büro'] });
  });

  it('Komma fügt ebenfalls hinzu', async () => {
    await open([]);
    await type('Kunde', ',');
    expect(chips()).toEqual(['Kunde']);
  });

  it('noch getippter Text wird beim Speichern übernommen', async () => {
    await open(['Büro']);
    field().value = 'Kunde';
    field().dispatchEvent(new Event('input', { bubbles: true }));
    save().click();
    expect(close).toHaveBeenCalledWith({ locations: ['Büro', 'Kunde'] });
  });

  it('leere Eingabe wird nicht übernommen', async () => {
    await open([]);
    await type('   ');
    expect(chips()).toEqual([]);
  });

  it('Duplikat (ohne Groß-/Kleinschreibung) wird nicht übernommen und erklärt', async () => {
    await open(['Büro']);
    await type('BÜRO');
    expect(chips()).toEqual(['Büro']);
    expect(message()).toBe('Dieser Ort ist schon eingetragen.');
  });

  it('61 Zeichen werden nicht übernommen, 60 schon', async () => {
    await open([]);
    await type('x'.repeat(61));
    expect(chips()).toEqual([]);
    expect(message()).toBe('Höchstens 60 Zeichen.');
    await type('x'.repeat(60));
    expect(chips()).toEqual(['x'.repeat(60)]);
  });

  it('ungültiger Text blockiert das Speichern (Dialog bleibt offen)', async () => {
    await open(['Büro']);
    field().value = 'büro';
    field().dispatchEvent(new Event('input', { bubbles: true }));
    save().click();
    expect(close).not.toHaveBeenCalled();
  });

  it('bei 5 Orten ist die Eingabe gesperrt und sagt warum', async () => {
    await open(['1', '2', '3', '4', '5']);
    expect(field().disabled).toBe(true);
    expect(message()).toBe('Höchstens 5 Orte pro Tag.');
  });

  it('Entfernen eines Orts gibt die Sperre wieder frei; aria-label je Ort', async () => {
    await open(['1', '2', '3', '4', '5']);
    const remove = el().querySelector('button[matChipRemove]') as HTMLButtonElement;
    expect(remove.getAttribute('aria-label')).toBe('1 entfernen');
    remove.click();
    fixture.detectChanges();
    await fixture.whenStable();
    fixture.detectChanges();
    expect(chips()).toEqual(['2', '3', '4', '5']);
    expect(field().disabled).toBe(false);
  });

  it('alle entfernen und speichern liefert []', async () => {
    await open(['Büro']);
    (el().querySelector('button[matChipRemove]') as HTMLButtonElement).click();
    fixture.detectChanges();
    save().click();
    expect(close).toHaveBeenCalledWith({ locations: [] });
  });

  it('Abbrechen schließt ohne Ergebnis (Button mit mat-dialog-close)', async () => {
    await open(['Büro']);
    expect(cancel().hasAttribute('mat-dialog-close')).toBe(true);
    expect(close).not.toHaveBeenCalled();
  });

  it('fragt Vorschläge ohne die gewählten Orte beim Dienst ab', async () => {
    await open(['Büro'], ['Kunde']);
    expect(suggest).toHaveBeenCalledWith(['Büro'], '');
  });
});
