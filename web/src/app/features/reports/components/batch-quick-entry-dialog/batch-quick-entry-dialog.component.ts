import { ChangeDetectionStrategy, Component, inject } from '@angular/core';
import { ReactiveFormsModule, FormBuilder, Validators } from '@angular/forms';
import { DatePipe } from '@angular/common';
import {
  MAT_DIALOG_DATA,
  MatDialogModule,
  MatDialogRef,
} from '@angular/material/dialog';
import { MatButtonModule } from '@angular/material/button';
import { MatChipsModule } from '@angular/material/chips';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatSelectModule } from '@angular/material/select';
import { WorkEntryType } from '../../../../shared/models/index';

export interface BatchQuickEntryDialogData {
  dates: Date[];
}

export interface BatchQuickEntryDialogResult {
  type: WorkEntryType;
  startTime?: string;
  endTime?: string;
}

@Component({
  selector: 'app-batch-quick-entry-dialog',
  imports: [
    DatePipe,
    ReactiveFormsModule,
    MatDialogModule,
    MatButtonModule,
    MatChipsModule,
    MatFormFieldModule,
    MatInputModule,
    MatSelectModule,
  ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <h2 mat-dialog-title>Stapeleintrag — {{ data.dates.length }} Tage</h2>

    <mat-dialog-content>
      <mat-chip-set aria-label="Ausgewählte Tage">
        @for (date of data.dates; track date.getTime()) {
          <mat-chip>{{ date | date:'d. MMM' }}</mat-chip>
        }
      </mat-chip-set>

      <form [formGroup]="form" class="form-fields">
        <mat-form-field appearance="outline" class="full-width">
          <mat-label>Typ</mat-label>
          <mat-select formControlName="type" required>
            <mat-option [value]="WorkEntryType.Vacation">Urlaub</mat-option>
            <mat-option [value]="WorkEntryType.Sick">Krank</mat-option>
            <mat-option [value]="WorkEntryType.Holiday">Feiertag</mat-option>
            <mat-option [value]="WorkEntryType.Work">Arbeit</mat-option>
          </mat-select>
        </mat-form-field>

        @if (form.value['type'] === WorkEntryType.Work) {
          <mat-form-field appearance="outline" class="full-width">
            <mat-label>Beginn</mat-label>
            <input matInput type="time" formControlName="startTime" aria-label="Arbeitsbeginn" />
          </mat-form-field>

          <mat-form-field appearance="outline" class="full-width">
            <mat-label>Ende</mat-label>
            <input matInput type="time" formControlName="endTime" aria-label="Arbeitsende" />
          </mat-form-field>
        }
      </form>
    </mat-dialog-content>

    <mat-dialog-actions align="end">
      <button mat-button mat-dialog-close>Abbrechen</button>
      <button mat-flat-button
              [disabled]="form.invalid"
              (click)="submit()">
        Alle speichern
      </button>
    </mat-dialog-actions>
  `,
  styles: [`
    .full-width { width: 100%; }
    mat-chip-set { margin-bottom: 16px; display: flex; flex-wrap: wrap; gap: 4px; }
    mat-dialog-content { display: flex; flex-direction: column; min-width: 300px; max-width: 480px; }
    .form-fields { display: flex; flex-direction: column; gap: 4px; margin-top: 8px; }
  `],
})
export class BatchQuickEntryDialogComponent {
  protected readonly data      = inject<BatchQuickEntryDialogData>(MAT_DIALOG_DATA);
  private  readonly dialogRef  = inject(MatDialogRef<BatchQuickEntryDialogComponent>);
  private  readonly fb         = inject(FormBuilder);

  protected readonly WorkEntryType = WorkEntryType;

  protected readonly form = this.fb.group({
    type:      [WorkEntryType.Vacation, Validators.required],
    startTime: [''],
    endTime:   [''],
  });

  submit(): void {
    if (this.form.invalid) return;
    const v = this.form.getRawValue();
    const result: BatchQuickEntryDialogResult = {
      type: v.type!,
      ...(v.type === WorkEntryType.Work && v.startTime ? { startTime: v.startTime } : {}),
      ...(v.type === WorkEntryType.Work && v.endTime   ? { endTime:   v.endTime   } : {}),
    };
    this.dialogRef.close(result);
  }
}
