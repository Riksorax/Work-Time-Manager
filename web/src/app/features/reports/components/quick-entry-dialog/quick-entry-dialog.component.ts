import { ChangeDetectionStrategy, Component, inject } from '@angular/core';
import { ReactiveFormsModule, FormBuilder, Validators } from '@angular/forms';
import { DatePipe } from '@angular/common';
import {
  MAT_DIALOG_DATA,
  MatDialogModule,
  MatDialogRef,
} from '@angular/material/dialog';
import { MatButtonModule } from '@angular/material/button';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatSelectModule } from '@angular/material/select';
import { TranslatePipe } from '@ngx-translate/core';
import { WorkEntryType } from '../../../../shared/models/index';

export interface QuickEntryDialogData {
  date: Date;
}

export interface QuickEntryDialogResult {
  type: WorkEntryType;
  startTime?: string;
  endTime?: string;
}

@Component({
  selector: 'app-quick-entry-dialog',
  imports: [
    DatePipe,
    ReactiveFormsModule,
    MatDialogModule,
    MatButtonModule,
    MatFormFieldModule,
    MatInputModule,
    MatSelectModule,
    TranslatePipe,
  ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <h2 mat-dialog-title>{{ 'reports.quickEntryDialogTitle' | translate: { date: (data.date | date:'d. MMMM yyyy') } }}</h2>

    <mat-dialog-content>
      <form [formGroup]="form" id="quick-entry-form">
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
        {{ 'common.save' | translate }}
      </button>
    </mat-dialog-actions>
  `,
  styles: [`
    .full-width { width: 100%; }
    mat-dialog-content { display: flex; flex-direction: column; gap: 8px; min-width: 280px; }
  `],
})
export class QuickEntryDialogComponent {
  protected readonly data       = inject<QuickEntryDialogData>(MAT_DIALOG_DATA);
  private  readonly dialogRef   = inject(MatDialogRef<QuickEntryDialogComponent>);
  private  readonly fb          = inject(FormBuilder);

  protected readonly WorkEntryType = WorkEntryType;

  protected readonly form = this.fb.group({
    type:      [WorkEntryType.Vacation, Validators.required],
    startTime: [''],
    endTime:   [''],
  });

  submit(): void {
    if (this.form.invalid) return;
    const v = this.form.getRawValue();
    const result: QuickEntryDialogResult = {
      type: v.type!,
      ...(v.type === WorkEntryType.Work && v.startTime ? { startTime: v.startTime } : {}),
      ...(v.type === WorkEntryType.Work && v.endTime   ? { endTime:   v.endTime   } : {}),
    };
    this.dialogRef.close(result);
  }
}
