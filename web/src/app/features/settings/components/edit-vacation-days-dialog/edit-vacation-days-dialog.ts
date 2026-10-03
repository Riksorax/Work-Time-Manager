import { ChangeDetectionStrategy, Component, inject } from '@angular/core';
import { ReactiveFormsModule, FormBuilder, Validators } from '@angular/forms';
import { MAT_DIALOG_DATA, MatDialogModule, MatDialogRef } from '@angular/material/dialog';
import { MatButtonModule } from '@angular/material/button';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { TranslatePipe } from '@ngx-translate/core';

export interface EditVacationDaysDialogData   { currentDays: number; }
export interface EditVacationDaysDialogResult { days: number; }

@Component({
  selector: 'app-edit-vacation-days-dialog',
  imports: [ReactiveFormsModule, MatDialogModule, MatButtonModule, MatFormFieldModule, MatInputModule, TranslatePipe],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <h2 mat-dialog-title>{{ 'settings.vacationDaysLabel' | translate }}</h2>
    <mat-dialog-content>
      <form [formGroup]="form" (ngSubmit)="submit()">
        <mat-form-field appearance="outline" class="full-width">
          <mat-label>{{ 'settings.vacationDaysFieldLabel' | translate }}</mat-label>
          <input matInput type="number" inputmode="numeric" formControlName="days"
                 min="0" max="366" step="1" cdkFocusInitial
                 [attr.aria-label]="'settings.editVacationDaysAria' | translate" />
          <mat-hint>{{ 'settings.vacationDaysHint' | translate }}</mat-hint>
          @if (form.controls.days.invalid) {
            <mat-error>{{ 'settings.vacationDaysInvalid' | translate }}</mat-error>
          }
        </mat-form-field>
      </form>
    </mat-dialog-content>
    <mat-dialog-actions align="end">
      <button mat-button mat-dialog-close>{{ 'common.cancel' | translate }}</button>
      <button mat-flat-button [disabled]="form.invalid" (click)="submit()">{{ 'common.save' | translate }}</button>
    </mat-dialog-actions>
  `,
  styles: [`
    .full-width { width: 100%; min-width: 260px; }
    mat-dialog-content { padding-top: 8px; }
  `],
})
export class EditVacationDaysDialogComponent {
  protected readonly data     = inject<EditVacationDaysDialogData>(MAT_DIALOG_DATA);
  private  readonly dialogRef = inject(MatDialogRef<EditVacationDaysDialogComponent>);
  private  readonly fb        = inject(FormBuilder);

  protected readonly form = this.fb.group({
    // Ganze Tage 0–366 (Backend: 400 außerhalb); Dezimalzahlen nicht still runden.
    days: [this.data.currentDays as number | null,
           [Validators.required, Validators.min(0), Validators.max(366), Validators.pattern(/^\d+$/)]],
  });

  submit(): void {
    if (this.form.invalid) return;
    this.dialogRef.close({ days: this.form.getRawValue().days! } satisfies EditVacationDaysDialogResult);
  }
}
