import { Component, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { MatDialogModule, MAT_DIALOG_DATA, MatDialogRef } from '@angular/material/dialog';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatButtonModule } from '@angular/material/button';
import { MatRadioModule } from '@angular/material/radio';

@Component({
  selector: 'app-adjustment-dialog',
  standalone: true,
  imports: [
    CommonModule, 
    ReactiveFormsModule, 
    MatDialogModule, 
    MatFormFieldModule, 
    MatInputModule, 
    MatButtonModule,
    MatRadioModule
  ],
  template: `
    <h2 mat-dialog-title>Überstunden-Saldo anpassen</h2>
    <mat-dialog-content>
      <form [formGroup]="adjustmentForm">
        <mat-radio-group formControlName="type" class="type-group">
          <mat-radio-button value="positive">Überstunden (+)</mat-radio-button>
          <mat-radio-button value="negative">Minusstunden (-)</mat-radio-button>
        </mat-radio-group>

        <div class="time-row">
          <mat-form-field appearance="outline">
            <mat-label>Stunden</mat-label>
            <input matInput type="number" formControlName="hours" min="0">
          </mat-form-field>
          <mat-form-field appearance="outline">
            <mat-label>Minuten</mat-label>
            <input matInput type="number" formControlName="minutes" min="0" max="59">
          </mat-form-field>
        </div>
        
        <p class="hint">Der Saldo wird auf den eingegebenen Wert gesetzt.</p>
      </form>
    </mat-dialog-content>
    <mat-dialog-actions align="end">
      <button mat-button (click)="onReset()">Auf 0 zurücksetzen</button>
      <button mat-button [mat-dialog-close]="undefined">Abbrechen</button>
      <button mat-raised-button color="primary" (click)="onSave()" [disabled]="adjustmentForm.invalid">
        Speichern
      </button>
    </mat-dialog-actions>
  `,
  styles: `
    .type-group { display: flex; flex-direction: column; gap: 0.5rem; margin-bottom: 1.5rem; }
    .time-row { display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; }
    .hint { font-size: 0.8rem; color: rgba(0,0,0,0.5); }
  `
})
export class AdjustmentDialogComponent {
  private fb = inject(FormBuilder);
  private dialogRef = inject(MatDialogRef<AdjustmentDialogComponent>);
  private data = inject(MAT_DIALOG_DATA);

  adjustmentForm = this.fb.group({
    type: ['positive'],
    hours: [0, [Validators.required, Validators.min(0)]],
    minutes: [0, [Validators.required, Validators.min(0), Validators.max(59)]]
  });

  constructor() {
    const current = Math.abs(this.data.currentBalance);
    this.adjustmentForm.patchValue({
      type: this.data.currentBalance >= 0 ? 'positive' : 'negative',
      hours: Math.floor(current / 60),
      minutes: current % 60
    });
  }

  onReset() {
    this.dialogRef.close(0);
  }

  onSave() {
    if (this.adjustmentForm.invalid) return;
    const { type, hours, minutes } = this.adjustmentForm.value;
    let totalMinutes = (hours || 0) * 60 + (minutes || 0);
    if (type === 'negative') totalMinutes *= -1;
    this.dialogRef.close(totalMinutes);
  }
}
