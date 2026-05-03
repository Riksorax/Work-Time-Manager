import { ChangeDetectionStrategy, Component, inject, signal } from '@angular/core';
import { MatButtonModule } from '@angular/material/button';
import { MatDialogModule, MatDialogRef, MAT_DIALOG_DATA } from '@angular/material/dialog';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { Break } from '../../../../shared/models/index';
import { TimeInputComponent } from '../../../../shared/components/time-input/time-input.component';

export interface EditBreakDialogData {
  break: Break;
  entryDate: Date;
}

export interface EditBreakDialogResult {
  updated: Break;
}

@Component({
  selector: 'app-edit-break-dialog',
  imports: [
    MatButtonModule,
    MatDialogModule,
    MatFormFieldModule,
    MatInputModule,
    TimeInputComponent,
  ],
  templateUrl: './edit-break-dialog.component.html',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class EditBreakDialogComponent {
  private readonly dialogRef = inject(MatDialogRef<EditBreakDialogComponent, EditBreakDialogResult>);
  private readonly data: EditBreakDialogData = inject(MAT_DIALOG_DATA);

  readonly name  = signal(this.data.break.name);
  startTime      = signal<Date | null>(this.data.break.start);
  endTime        = signal<Date | null>(this.data.break.end ?? null);
  validationError = signal<string | null>(null);

  onNameInput(event: Event): void {
    this.name.set((event.target as HTMLInputElement).value);
  }

  onStartTimeSelected(timeStr: string): void {
    this.startTime.set(this._parseTime(timeStr));
    this.validationError.set(null);
  }

  onEndTimeSelected(timeStr: string): void {
    this.endTime.set(this._parseTime(timeStr));
    this.validationError.set(null);
  }

  save(): void {
    const start = this.startTime();
    if (!start) {
      this.validationError.set('Startzeit ist erforderlich.');
      return;
    }
    const end = this.endTime();
    if (end && end <= start) {
      this.validationError.set('Endzeit muss nach der Startzeit liegen.');
      return;
    }
    this.dialogRef.close({
      updated: {
        ...this.data.break,
        name: this.name,
        start,
        end: end ?? undefined,
      },
    });
  }

  private _parseTime(timeStr: string): Date {
    const [h, m] = timeStr.split(':').map(Number);
    const d = new Date(this.data.entryDate);
    d.setHours(h, m, 0, 0);
    return d;
  }
}
