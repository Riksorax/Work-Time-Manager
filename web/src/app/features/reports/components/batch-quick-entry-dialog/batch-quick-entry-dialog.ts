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
import { TranslatePipe } from '@ngx-translate/core';
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
    TranslatePipe,
  ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <h2 mat-dialog-title>{{ 'reports.batchDialogTitle' | translate: { count: data.dates.length } }}</h2>

    <mat-dialog-content>
      <mat-chip-set [attr.aria-label]="'reports.selectedDaysAria' | translate">
        @for (date of data.dates; track date.getTime()) {
          <mat-chip>{{ date | date:'d. MMM' }}</mat-chip>
        }
      </mat-chip-set>

      <form [formGroup]="form" class="form-fields">
        <mat-form-field appearance="outline" class="full-width">
          <mat-label>{{ 'reports.entryTypeFieldLabel' | translate }}</mat-label>
          <mat-select formControlName="type" required>
            <mat-option [value]="WorkEntryType.Vacation">{{ 'reports.entryTypeVacation' | translate }}</mat-option>
            <mat-option [value]="WorkEntryType.Sick">{{ 'reports.entryTypeSick' | translate }}</mat-option>
            <mat-option [value]="WorkEntryType.Holiday">{{ 'reports.entryTypeHoliday' | translate }}</mat-option>
            <mat-option [value]="WorkEntryType.Work">{{ 'reports.entryTypeWork' | translate }}</mat-option>
          </mat-select>
        </mat-form-field>

        @if (form.value['type'] === WorkEntryType.Work) {
          <mat-form-field appearance="outline" class="full-width">
            <mat-label>{{ 'reports.beginLabel' | translate }}</mat-label>
            <input matInput type="time" formControlName="startTime" [attr.aria-label]="'reports.workStartAria' | translate" />
          </mat-form-field>

          <mat-form-field appearance="outline" class="full-width">
            <mat-label>{{ 'reports.timeEnd' | translate }}</mat-label>
            <input matInput type="time" formControlName="endTime" [attr.aria-label]="'reports.workEndAria' | translate" />
          </mat-form-field>
        }
      </form>
    </mat-dialog-content>

    <mat-dialog-actions align="end">
      <button mat-button mat-dialog-close>{{ 'common.cancel' | translate }}</button>
      <button mat-flat-button
              [disabled]="form.invalid"
              (click)="submit()">
        {{ 'reports.saveAllButton' | translate }}
      </button>
    </mat-dialog-actions>
  `,
  styles: [`
    .full-width { width: 100%; }
    mat-chip-set { margin-bottom: 16px; display: flex; flex-wrap: wrap; gap: 4px; }
    mat-dialog-content { display: flex; flex-direction: column; min-width: min(300px, calc(95vw - 48px)); max-width: 480px; }
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
