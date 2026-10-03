import { ComponentFixture, TestBed } from '@angular/core/testing';
import { MAT_DIALOG_DATA, MatDialogRef } from '@angular/material/dialog';
import { provideTranslateService } from '@ngx-translate/core';
import { EditVacationDaysDialogComponent } from './edit-vacation-days-dialog';

describe('EditVacationDaysDialogComponent', () => {
  let fixture: ComponentFixture<EditVacationDaysDialogComponent>;
  let close: ReturnType<typeof vi.fn>;

  beforeEach(async () => {
    close = vi.fn();
    await TestBed.configureTestingModule({
      imports: [EditVacationDaysDialogComponent],
      providers: [
        provideTranslateService(),
        { provide: MAT_DIALOG_DATA, useValue: { currentDays: 30 } },
        { provide: MatDialogRef, useValue: { close } },
      ],
    }).compileComponents();
    fixture = TestBed.createComponent(EditVacationDaysDialogComponent);
    fixture.detectChanges();
  });

  function enter(value: string): void {
    const input = fixture.nativeElement.querySelector('input') as HTMLInputElement;
    input.value = value;
    input.dispatchEvent(new Event('input'));
    fixture.detectChanges();
  }
  function saveButton(): HTMLButtonElement {
    return fixture.nativeElement.querySelector('button[mat-flat-button]') as HTMLButtonElement;
  }

  it.each(['0', '30', '366'])('erlaubt Speichern bei gültigem Wert %s', value => {
    enter(value);
    expect(saveButton().disabled).toBe(false);
    saveButton().click();
    expect(close).toHaveBeenCalledWith({ days: Number(value) });
  });

  it.each(['', '-1', '367', '2.5'])('sperrt Speichern bei ungültigem Wert "%s"', value => {
    enter(value);
    expect(saveButton().disabled).toBe(true);
    saveButton().click();
    expect(close).not.toHaveBeenCalled();
  });
});
