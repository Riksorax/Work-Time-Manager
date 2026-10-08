import { ComponentFixture, TestBed } from '@angular/core/testing';
import { MAT_DIALOG_DATA, MatDialogRef } from '@angular/material/dialog';
import { provideTranslateService } from '@ngx-translate/core';
import { EditBundeslandDialogComponent, EditBundeslandDialogData } from './edit-bundesland-dialog';
import { BUNDESLAND_VALUES } from '../../../../shared/models/index';

describe('EditBundeslandDialogComponent', () => {
  let fixture: ComponentFixture<EditBundeslandDialogComponent>;
  let close: ReturnType<typeof vi.fn>;

  async function create(data: EditBundeslandDialogData): Promise<void> {
    close = vi.fn();
    await TestBed.configureTestingModule({
      imports: [EditBundeslandDialogComponent],
      providers: [
        provideTranslateService(),
        { provide: MAT_DIALOG_DATA, useValue: data },
        { provide: MatDialogRef, useValue: { close } },
      ],
    }).compileComponents();
    fixture = TestBed.createComponent(EditBundeslandDialogComponent);
    fixture.detectChanges();
    await fixture.whenStable();
    fixture.detectChanges();
  }

  const radios = (): HTMLElement[] => Array.from(fixture.nativeElement.querySelectorAll('mat-radio-button'));
  const saveButton = (): HTMLButtonElement => fixture.nativeElement.querySelector('button[mat-flat-button]');
  const focusInitial = (): HTMLElement[] => Array.from(fixture.nativeElement.querySelectorAll('[cdkFocusInitial]'));

  it('zeigt 17 Optionen, "Nicht ausgewählt" zuerst', async () => {
    await create({ current: null });
    expect(radios()).toHaveLength(1 + BUNDESLAND_VALUES.length);
    expect(radios()[0].textContent).toContain('settings.bundesland.notSelected');
    expect(radios()[1].textContent).toContain('settings.bundesland.state.badenWuerttemberg');
  });

  it('übernimmt die aktuelle Auswahl und speichert sie', async () => {
    await create({ current: 'bayern' });
    expect((radios()[2].querySelector('input') as HTMLInputElement).checked).toBe(true);
    saveButton().click();
    expect(close).toHaveBeenCalledWith({ bundesland: 'bayern' });
  });

  it('Auswahl "Nicht ausgewählt" liefert null', async () => {
    await create({ current: 'bayern' });
    (radios()[0].querySelector('input') as HTMLInputElement).click();
    fixture.detectChanges();
    saveButton().click();
    expect(close).toHaveBeenCalledWith({ bundesland: null });
  });

  it('Abbrechen schließt über mat-dialog-close ohne Ergebnis', async () => {
    await create({ current: null });
    const cancel = fixture.nativeElement.querySelector('button[mat-dialog-close]') as HTMLButtonElement;
    expect(cancel).toBeTruthy();
    expect(close).not.toHaveBeenCalled();
  });

  it('cdkFocusInitial steht bei current=null nur auf "Nicht ausgewählt"', async () => {
    await create({ current: null });
    expect(focusInitial()).toEqual([radios()[0]]);
  });

  it('cdkFocusInitial steht bei current=bayern nur auf der Option bayern', async () => {
    await create({ current: 'bayern' });
    expect(focusInitial()).toEqual([radios()[2]]);
  });
});
