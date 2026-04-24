import { ChangeDetectionStrategy, Component, inject } from '@angular/core';
import { ReactiveFormsModule, FormBuilder, Validators } from '@angular/forms';
import { MAT_DIALOG_DATA, MatDialogModule, MatDialogRef } from '@angular/material/dialog';
import { MatButtonModule } from '@angular/material/button';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatSelectModule } from '@angular/material/select';

export interface EditWorkdaysDialogData   { currentDays: number; }
export interface EditWorkdaysDialogResult { days: number; }

@Component({
  selector: 'app-edit-workdays-dialog',
  imports: [ReactiveFormsModule, MatDialogModule, MatButtonModule, MatFormFieldModule, MatSelectModule],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <h2 mat-dialog-title>Arbeitstage pro Woche</h2>
    <mat-dialog-content>
      <form [formGroup]="form">
        <mat-form-field appearance="outline" class="full-width">
          <mat-label>Tage</mat-label>
          <mat-select formControlName="days" aria-label="Arbeitstage pro Woche">
            @for (d of dayOptions; track d) {
              <mat-option [value]="d">{{ d }} {{ d === 1 ? 'Tag' : 'Tage' }}</mat-option>
            }
          </mat-select>
        </mat-form-field>
      </form>
    </mat-dialog-content>
    <mat-dialog-actions align="end">
      <button mat-button mat-dialog-close>Abbrechen</button>
      <button mat-flat-button [disabled]="form.invalid" (click)="submit()">
        Speichern
      </button>
    </mat-dialog-actions>
  `,
  styles: [`.full-width { width: 100%; min-width: 240px; } mat-dialog-content { padding-top: 8px; }`],
})
export class EditWorkdaysDialogComponent {
  protected readonly data      = inject<EditWorkdaysDialogData>(MAT_DIALOG_DATA);
  private  readonly dialogRef  = inject(MatDialogRef<EditWorkdaysDialogComponent>);
  private  readonly fb         = inject(FormBuilder);

  protected readonly dayOptions = [1, 2, 3, 4, 5, 6, 7];

  protected readonly form = this.fb.group({
    days: [this.data.currentDays, [Validators.required, Validators.min(1), Validators.max(7)]],
  });

  submit(): void {
    if (this.form.invalid) return;
    this.dialogRef.close({ days: this.form.getRawValue().days! } satisfies EditWorkdaysDialogResult);
  }
}
