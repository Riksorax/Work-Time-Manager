import { ChangeDetectionStrategy, Component, inject } from '@angular/core';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { MatButtonModule } from '@angular/material/button';
import { MatDialogModule, MatDialogRef, MAT_DIALOG_DATA } from '@angular/material/dialog';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatIconModule } from '@angular/material/icon';

export interface OvertimeAdjustmentDialogData {
  currentMinutes: number;
}

@Component({
  selector: 'wtm-overtime-adjustment-dialog',
  standalone: true,
  imports: [
    ReactiveFormsModule,
    MatButtonModule,
    MatDialogModule,
    MatFormFieldModule,
    MatInputModule,
    MatIconModule,
  ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  styles: [`
    h2[mat-dialog-title] { display: flex; align-items: center; gap: 8px; }

    .hint {
      font-size: 0.8rem;
      color: var(--mat-sys-on-surface-variant);
      margin-bottom: 12px;
    }
  `],
  template: `
    <h2 mat-dialog-title>
      <mat-icon>tune</mat-icon>
      Überstunden anpassen
    </h2>
    <div mat-dialog-content>
      <p class="hint">
        Trage eine Korrektur in Minuten ein. Positiv = zusätzliche Überstunden, negativ = Abzug.
        Aktuell: {{ data.currentMinutes >= 0 ? '+' : '' }}{{ data.currentMinutes }} min
      </p>
      <form [formGroup]="form">
        <mat-form-field appearance="outline" style="width:100%">
          <mat-label>Korrektur (Minuten)</mat-label>
          <input matInput type="number" formControlName="minutes" />
          <span matSuffix>min</span>
        </mat-form-field>
      </form>
    </div>
    <div mat-dialog-actions align="end">
      <button mat-button mat-dialog-close>Abbrechen</button>
      <button mat-flat-button (click)="confirm()" [disabled]="form.invalid">
        Speichern
      </button>
    </div>
  `,
})
export class OvertimeAdjustmentDialogComponent {
  protected data: OvertimeAdjustmentDialogData = inject(MAT_DIALOG_DATA);
  private dialogRef = inject(MatDialogRef<OvertimeAdjustmentDialogComponent>);
  private fb = inject(FormBuilder);

  readonly form = this.fb.nonNullable.group({
    minutes: [this.data.currentMinutes, [Validators.required]],
  });

  confirm(): void {
    this.dialogRef.close(this.form.getRawValue().minutes);
  }
}
