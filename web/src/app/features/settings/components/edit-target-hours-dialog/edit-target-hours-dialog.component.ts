import { ChangeDetectionStrategy, Component, inject } from '@angular/core';
import { ReactiveFormsModule, FormBuilder, Validators } from '@angular/forms';
import { MAT_DIALOG_DATA, MatDialogModule, MatDialogRef } from '@angular/material/dialog';
import { MatButtonModule } from '@angular/material/button';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';

export interface EditTargetHoursDialogData   { currentHours: number; }
export interface EditTargetHoursDialogResult { hours: number; }

@Component({
  selector: 'app-edit-target-hours-dialog',
  imports: [ReactiveFormsModule, MatDialogModule, MatButtonModule, MatFormFieldModule, MatInputModule],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <h2 mat-dialog-title>Soll-Arbeitsstunden</h2>
    <mat-dialog-content>
      <form [formGroup]="form">
        <mat-form-field appearance="outline" class="full-width">
          <mat-label>Stunden pro Woche</mat-label>
          <input matInput type="number" formControlName="hours"
                 min="1" max="168" step="0.5"
                 aria-label="Soll-Arbeitsstunden pro Woche" />
          <mat-hint>Zwischen 1 und 168 Stunden</mat-hint>
        </mat-form-field>
      </form>
    </mat-dialog-content>
    <mat-dialog-actions align="end">
      <button mat-button mat-dialog-close>Abbrechen</button>
      <button mat-flat-button color="primary" [disabled]="form.invalid" (click)="submit()">
        Speichern
      </button>
    </mat-dialog-actions>
  `,
  styles: [`.full-width { width: 100%; min-width: 260px; } mat-dialog-content { padding-top: 8px; }`],
})
export class EditTargetHoursDialogComponent {
  protected readonly data      = inject<EditTargetHoursDialogData>(MAT_DIALOG_DATA);
  private  readonly dialogRef  = inject(MatDialogRef<EditTargetHoursDialogComponent>);
  private  readonly fb         = inject(FormBuilder);

  protected readonly form = this.fb.group({
    hours: [this.data.currentHours, [Validators.required, Validators.min(1), Validators.max(168)]],
  });

  submit(): void {
    if (this.form.invalid) return;
    this.dialogRef.close({ hours: this.form.getRawValue().hours! } satisfies EditTargetHoursDialogResult);
  }
}
