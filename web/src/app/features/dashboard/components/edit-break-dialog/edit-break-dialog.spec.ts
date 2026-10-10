import { TestBed } from '@angular/core/testing';
import { By } from '@angular/platform-browser';
import { MAT_DIALOG_DATA, MatDialogRef } from '@angular/material/dialog';
import { provideTranslateService } from '@ngx-translate/core';
import { EditBreakDialogComponent } from './edit-break-dialog';
import { TimeInputComponent } from '../../../../shared/components/time-input/time-input';

// Der Pausen-Dialog hat keinen Schreib-Block, der die Felder sperrt: er bleibt beim sofortigen Emit (kein Opt-in `settle`).
describe('EditBreakDialogComponent Zeitfelder', () => {
  it('nutzt TimeInputComponent ohne Entprellen (settle aus)', () => {
    TestBed.configureTestingModule({
      providers: [
        provideTranslateService(),
        { provide: MatDialogRef, useValue: { close: vi.fn() } },
        { provide: MAT_DIALOG_DATA, useValue: {
          break: { id: 'b1', name: 'Pause 1', start: new Date(2026, 9, 5, 9, 0), end: new Date(2026, 9, 5, 9, 15), isAutomatic: false },
          entryDate: new Date(2026, 9, 5),
        } },
      ],
    });
    const fixture = TestBed.createComponent(EditBreakDialogComponent);
    fixture.detectChanges();
    const inputs = fixture.debugElement.queryAll(By.directive(TimeInputComponent)).map(d => d.componentInstance as TimeInputComponent);
    expect(inputs.length).toBe(2);
    expect(inputs.map(i => i.settle())).toEqual([false, false]);
  });
});
