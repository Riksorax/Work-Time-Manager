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
  ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <h2 mat-dialog-title>Schnelleintrag — {{ data.date | date:'d. MMMM yyyy' }}</h2>

    <mat-dialog-content>
      <form [formGroup]="form" id="quick-entry-form">
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
              color="primary"
              [disabled]="form.invalid"
              (click)="submit()">
        Speichern
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
