import { Component, inject, signal, computed, OnInit } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { MatButtonModule } from '@angular/material/button';
import { MatDialogModule, MatDialogRef, MAT_DIALOG_DATA } from '@angular/material/dialog';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { WorkSessionService } from '../../services/work-session.service';
import { ToastService } from '../../../../shared/components/toast/toast.service';

export interface EditBreakDialogData {
  sessionId: string;
  mode: 'add' | 'edit';
  breakId?: string;
  initialName?: string;
  initialStartTime?: Date;
  initialEndTime?: Date;
}

@Component({
  selector: 'wtm-edit-break-dialog',
  standalone: true,
  imports: [FormsModule, MatButtonModule, MatDialogModule, MatFormFieldModule, MatInputModule],
  styles: [`
    .form-grid { display: flex; flex-direction: column; gap: 16px; min-width: 280px; }
    .time-row { display: flex; gap: 12px; }
    .time-row mat-form-field { flex: 1; }
    .error-text { color: var(--mat-sys-error); font-size: 0.75rem; margin-top: -12px; }
  `],
  template: `
    <h2 mat-dialog-title>{{ data.mode === 'add' ? 'Pause hinzufügen' : 'Pause bearbeiten' }}</h2>
    <mat-dialog-content>
      <div class="form-grid">
        <mat-form-field appearance="outline">
          <mat-label>Name (optional)</mat-label>
          <input matInput [(ngModel)]="name" placeholder="z.B. Mittagspause" />
        </mat-form-field>

        <div class="time-row">
          <mat-form-field appearance="outline">
            <mat-label>Startzeit</mat-label>
            <input matInput type="time" [(ngModel)]="startTimeStr" (ngModelChange)="validate()" />
          </mat-form-field>
          <mat-form-field appearance="outline">
            <mat-label>Endzeit</mat-label>
            <input matInput type="time" [(ngModel)]="endTimeStr" (ngModelChange)="validate()" />
          </mat-form-field>
        </div>

        @if (validationError()) {
          <p class="error-text">{{ validationError() }}</p>
        }
      </div>
    </mat-dialog-content>
    <mat-dialog-actions align="end">
      <button mat-button mat-dialog-close>Abbrechen</button>
      <button mat-flat-button color="primary" [disabled]="!isValid() || busy()" (click)="save()">
        {{ data.mode === 'add' ? 'Hinzufügen' : 'Speichern' }}
      </button>
    </mat-dialog-actions>
  `,
})
export class EditBreakDialogComponent implements OnInit {
  readonly data = inject<EditBreakDialogData>(MAT_DIALOG_DATA);
  private dialogRef = inject(MatDialogRef<EditBreakDialogComponent>);
  private sessionService = inject(WorkSessionService);
  private toast = inject(ToastService);

  name = '';
  startTimeStr = '';
  endTimeStr = '';

  readonly busy = signal(false);
  readonly validationError = signal<string | null>(null);
  readonly isValid = signal(false);

  ngOnInit(): void {
    const now = new Date();
    const pad = (n: number) => n.toString().padStart(2, '0');
    const fmt = (d: Date) => `${pad(d.getHours())}:${pad(d.getMinutes())}`;

    this.name = this.data.initialName ?? '';
    this.startTimeStr = this.data.initialStartTime ? fmt(this.data.initialStartTime) : fmt(new Date(now.getTime() - 30 * 60_000));
    this.endTimeStr = this.data.initialEndTime ? fmt(this.data.initialEndTime) : fmt(now);
    this.validate();
  }

  validate(): void {
    if (!this.startTimeStr || !this.endTimeStr) {
      this.validationError.set('Bitte Start- und Endzeit angeben.');
      this.isValid.set(false);
      return;
    }
    const [sh, sm] = this.startTimeStr.split(':').map(Number);
    const [eh, em] = this.endTimeStr.split(':').map(Number);
    const startMins = sh * 60 + sm;
    const endMins = eh * 60 + em;
    if (endMins <= startMins) {
      this.validationError.set('Endzeit muss nach der Startzeit liegen.');
      this.isValid.set(false);
      return;
    }
    this.validationError.set(null);
    this.isValid.set(true);
  }

  async save(): Promise<void> {
    if (!this.isValid()) return;
    this.busy.set(true);

    const today = new Date();
    const [sh, sm] = this.startTimeStr.split(':').map(Number);
    const [eh, em] = this.endTimeStr.split(':').map(Number);
    const startTime = new Date(today.getFullYear(), today.getMonth(), today.getDate(), sh, sm, 0);
    const endTime = new Date(today.getFullYear(), today.getMonth(), today.getDate(), eh, em, 0);
    const name = this.name.trim() || `Pause ${this.startTimeStr}–${this.endTimeStr}`;

    try {
      if (this.data.mode === 'add') {
        await this.sessionService.addManualBreak(this.data.sessionId, { name, startTime, endTime });
      } else if (this.data.breakId) {
        await this.sessionService.updateBreak(this.data.sessionId, this.data.breakId, { name, startTime, endTime });
      }
      this.dialogRef.close(true);
    } catch {
      this.toast.error('common.error');
    } finally {
      this.busy.set(false);
    }
  }
}
