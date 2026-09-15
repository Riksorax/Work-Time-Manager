import { ChangeDetectionStrategy, Component, inject, signal } from '@angular/core';
import { MAT_DIALOG_DATA, MatDialogModule, MatDialogRef } from '@angular/material/dialog';
import { MatButtonModule } from '@angular/material/button';
import { MatChipsModule } from '@angular/material/chips';
import { GERMAN_WEEKDAY_SHORT_LABELS } from '../../../../shared/utils/weekday-labels.util';

export interface EditWorkdaysDialogData   { currentDays: number[]; }
export interface EditWorkdaysDialogResult { days: number[]; }

@Component({
  selector: 'app-edit-workdays-dialog',
  imports: [MatDialogModule, MatButtonModule, MatChipsModule],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <h2 mat-dialog-title>Arbeitstage</h2>
    <mat-dialog-content>
      <mat-chip-listbox multiple aria-label="Arbeitstage auswählen">
        @for (label of weekdayLabels; track $index) {
          <mat-chip-option
            [selected]="isSelected($index + 1)"
            (selectionChange)="toggle($index + 1, $event.selected)"
          >
            {{ label }}
          </mat-chip-option>
        }
      </mat-chip-listbox>
      @if (selectedDays().length === 0) {
        <p class="error-text">Mindestens ein Arbeitstag muss ausgewählt sein.</p>
      }
    </mat-dialog-content>
    <mat-dialog-actions align="end">
      <button mat-button mat-dialog-close>Abbrechen</button>
      <button mat-flat-button [disabled]="selectedDays().length === 0" (click)="submit()">
        Speichern
      </button>
    </mat-dialog-actions>
  `,
  styles: [`
    mat-dialog-content { padding-top: 8px; }
    .error-text { color: var(--mat-sys-error); font-size: 0.85rem; margin-top: 8px; }
  `],
})
export class EditWorkdaysDialogComponent {
  protected readonly data      = inject<EditWorkdaysDialogData>(MAT_DIALOG_DATA);
  private  readonly dialogRef  = inject(MatDialogRef<EditWorkdaysDialogComponent>);

  protected readonly weekdayLabels = GERMAN_WEEKDAY_SHORT_LABELS;
  protected readonly selectedDays = signal<number[]>([...this.data.currentDays]);

  isSelected(day: number): boolean {
    return this.selectedDays().includes(day);
  }

  toggle(day: number, selected: boolean): void {
    this.selectedDays.update(days =>
      selected ? [...days, day] : days.filter(d => d !== day)
    );
  }

  submit(): void {
    if (this.selectedDays().length === 0) return;
    const days = [...this.selectedDays()].sort((a, b) => a - b);
    this.dialogRef.close({ days } satisfies EditWorkdaysDialogResult);
  }
}
