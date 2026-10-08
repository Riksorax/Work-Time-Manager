import { ChangeDetectionStrategy, Component, inject, signal } from '@angular/core';
import { MAT_DIALOG_DATA, MatDialogModule, MatDialogRef } from '@angular/material/dialog';
import { MatButtonModule } from '@angular/material/button';
import { MatChipsModule } from '@angular/material/chips';
import { TranslatePipe, TranslateService } from '@ngx-translate/core';
import { normalizeWorkdays } from '../../../../shared/utils/workdays.util';

export interface EditWorkdaysDialogData   { currentDays: number[]; }
export interface EditWorkdaysDialogResult { days: number[]; }

@Component({
  selector: 'app-edit-workdays-dialog',
  imports: [MatDialogModule, MatButtonModule, MatChipsModule, TranslatePipe],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <h2 mat-dialog-title>{{ 'settings.workdaysLabel' | translate }}</h2>
    <mat-dialog-content>
      <mat-chip-listbox multiple [attr.aria-label]="'settings.selectWorkdaysAria' | translate">
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
        <p class="error-text">{{ 'settings.workdaysRequired' | translate }}</p>
      }
    </mat-dialog-content>
    <mat-dialog-actions align="end">
      <button mat-button mat-dialog-close>{{ 'common.cancel' | translate }}</button>
      <button mat-flat-button [disabled]="selectedDays().length === 0" (click)="submit()">
        {{ 'common.save' | translate }}
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
  private  readonly translate  = inject(TranslateService);

  protected readonly weekdayLabels: string[] = this.translate.instant('common.weekdaysShort');
  protected readonly selectedDays = signal<number[]>(normalizeWorkdays(this.data.currentDays));

  isSelected(day: number): boolean {
    return this.selectedDays().includes(day);
  }

  /**
   * Idempotent: `mat-chip-option` meldet `selectionChange` auch für die per `[selected]` vorbelegten Chips. Ein
   * reines Anhängen verdoppelte so beim Speichern alle bisherigen Tage ([1,1,2,2,…]) und ließ das tägliche Soll schrumpfen.
   */
  toggle(day: number, selected: boolean): void {
    this.selectedDays.update(days => normalizeWorkdays(selected ? [...days, day] : days.filter(d => d !== day)));
  }

  submit(): void {
    if (this.selectedDays().length === 0) return;
    const days = normalizeWorkdays(this.selectedDays());
    this.dialogRef.close({ days } satisfies EditWorkdaysDialogResult);
  }
}
