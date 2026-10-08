import { ComponentFixture, TestBed } from '@angular/core/testing';
import { MAT_DIALOG_DATA, MatDialogRef } from '@angular/material/dialog';
import { TranslateService, provideTranslateService } from '@ngx-translate/core';
import { EditWorkdaysDialogComponent } from './edit-workdays-dialog';

describe('EditWorkdaysDialogComponent', () => {
  let fixture: ComponentFixture<EditWorkdaysDialogComponent>;
  let close: ReturnType<typeof vi.fn>;

  async function setup(currentDays: number[]): Promise<void> {
    close = vi.fn();
    await TestBed.configureTestingModule({
      imports: [EditWorkdaysDialogComponent],
      providers: [
        provideTranslateService({ lang: 'de' }),
        { provide: MAT_DIALOG_DATA, useValue: { currentDays } },
        { provide: MatDialogRef, useValue: { close } },
      ],
    }).compileComponents();
    TestBed.inject(TranslateService).setTranslation('de', {
      common: { weekdaysShort: ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'] },
    });
    fixture = TestBed.createComponent(EditWorkdaysDialogComponent);
    fixture.detectChanges();
    await fixture.whenStable();
    fixture.detectChanges();
  }

  /** Der Klick muss die innere Aktion des Chips treffen (`role="option"`), nicht das Host-Element. */
  const chip = (label: string): HTMLElement =>
    Array.from(fixture.nativeElement.querySelectorAll('mat-chip-option') as NodeListOf<HTMLElement>)
      .find(c => c.textContent?.trim() === label)!
      .querySelector('[role="option"]') as HTMLElement;
  const save = (): HTMLButtonElement => fixture.nativeElement.querySelector('button[mat-flat-button]') as HTMLButtonElement;

  it('speichert einen weiteren Tag ohne die bereits gewählten zu verdoppeln', async () => {
    await setup([1, 2, 3, 4, 5]);
    chip('Sa').click();
    fixture.detectChanges();
    save().click();
    expect(close).toHaveBeenCalledWith({ days: [1, 2, 3, 4, 5, 6] });
  });

  it('speichert die unveränderte Auswahl ohne Duplikate', async () => {
    await setup([1, 2, 3, 4, 5]);
    save().click();
    expect(close).toHaveBeenCalledWith({ days: [1, 2, 3, 4, 5] });
  });

  it('entfernt einen abgewählten Tag', async () => {
    await setup([1, 2, 3, 4, 5]);
    chip('Fr').click();
    fixture.detectChanges();
    save().click();
    expect(close).toHaveBeenCalledWith({ days: [1, 2, 3, 4] });
  });

  it('bereinigt bereits verfälschte Daten mit Duplikaten beim Öffnen', async () => {
    await setup([1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6]);
    save().click();
    expect(close).toHaveBeenCalledWith({ days: [1, 2, 3, 4, 5, 6] });
  });
});
