import { Component, inject, signal, OnInit } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { MatButtonModule } from '@angular/material/button';
import { MatDialogModule, MatDialogRef, MAT_DIALOG_DATA } from '@angular/material/dialog';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';

export interface EditTimeDialogData {
  label: string;
  currentTime: Date;
}

export interface EditTimeDialogResult {
  hours: number;
  minutes: number;
}

@Component({
  selector: 'wtm-edit-time-dialog',
  standalone: true,
  imports: [FormsModule, MatButtonModule, MatDialogModule, MatFormFieldModule, MatInputModule],
  styles: [`
    .content { display: flex; flex-direction: column; gap: 16px; min-width: 240px; }
    .time-field { width: 100%; }
  `],
  template: `
    <h2 mat-dialog-title>{{ data.label }} ändern</h2>
    <mat-dialog-content>
      <div class="content">
        <mat-form-field class="time-field" appearance="outline">
          <mat-label>{{ data.label }}</mat-label>
          <input matInput type="time" [(ngModel)]="timeStr" />
        </mat-form-field>
      </div>
    </mat-dialog-content>
    <mat-dialog-actions align="end">
      <button mat-button mat-dialog-close>Abbrechen</button>
      <button mat-flat-button color="primary" (click)="save()">Übernehmen</button>
    </mat-dialog-actions>
  `,
})
export class EditTimeDialogComponent implements OnInit {
  readonly data = inject<EditTimeDialogData>(MAT_DIALOG_DATA);
  private dialogRef = inject(MatDialogRef<EditTimeDialogComponent, EditTimeDialogResult>);

  timeStr = '';

  ngOnInit(): void {
    const d = this.data.currentTime;
    const pad = (n: number) => n.toString().padStart(2, '0');
    this.timeStr = `${pad(d.getHours())}:${pad(d.getMinutes())}`;
  }

  save(): void {
    const [h, m] = this.timeStr.split(':').map(Number);
    if (isNaN(h) || isNaN(m)) return;
    this.dialogRef.close({ hours: h, minutes: m });
  }
}
