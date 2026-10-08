import { ChangeDetectionStrategy, Component, inject } from '@angular/core';
import { ReactiveFormsModule, FormBuilder, FormGroup, Validators, FormArray } from '@angular/forms';
import { MAT_DIALOG_DATA, MatDialogModule, MatDialogRef } from '@angular/material/dialog';
import { MatButtonModule } from '@angular/material/button';
import { MatDividerModule } from '@angular/material/divider';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatIconModule } from '@angular/material/icon';
import { MatInputModule } from '@angular/material/input';
import { MatSelectModule } from '@angular/material/select';
import { TranslatePipe, TranslateService } from '@ngx-translate/core';
import { WorkEntry, WorkEntryType, Break } from '../../models/index';
import { breakNameToStore, localizedBreakName } from '../../utils/break-name.util';

interface BreakFormValue {
  id: string;
  name: string;
  start: string;
  end: string;
}

interface EntryFormValue {
  type: WorkEntryType;
  startTime: string;
  endTime: string;
  manualOvertimeMinutes: number | null;
  breaks: BreakFormValue[];
}

@Component({
  selector: 'app-edit-entry-dialog',
  imports: [
    ReactiveFormsModule,
    MatDialogModule,
    MatButtonModule,
    MatDividerModule,
    MatFormFieldModule,
    MatIconModule,
    MatInputModule,
    MatSelectModule,
    TranslatePipe,
  ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <h2 mat-dialog-title>{{ (data.entry ? 'shared.editEntryTitleEdit' : 'shared.editEntryTitleNew') | translate }}</h2>
    <mat-dialog-content>
      <form [formGroup]="form" class="edit-form">
        <mat-form-field appearance="outline">
          <mat-label>{{ 'shared.editEntryTypeLabel' | translate }}</mat-label>
          <mat-select formControlName="type">
            <mat-option [value]="WorkEntryType.Work">{{ 'shared.entryTypeWork' | translate }}</mat-option>
            <mat-option [value]="WorkEntryType.Vacation">{{ 'shared.entryTypeVacation' | translate }}</mat-option>
            <mat-option [value]="WorkEntryType.Sick">{{ 'shared.entryTypeSick' | translate }}</mat-option>
            <mat-option [value]="WorkEntryType.Holiday">{{ 'shared.entryTypeHoliday' | translate }}</mat-option>
          </mat-select>
        </mat-form-field>

        <div class="time-row">
          <mat-form-field appearance="outline">
            <mat-label>{{ 'shared.workStartLabel' | translate }}</mat-label>
            <input matInput type="time" formControlName="startTime" />
          </mat-form-field>
          <mat-form-field appearance="outline">
            <mat-label>{{ 'shared.workEndLabel' | translate }}</mat-label>
            <input matInput type="time" formControlName="endTime" />
          </mat-form-field>
        </div>

        <div class="section-header">
          <h3>{{ 'dashboard.breaksTitle' | translate }}</h3>
          <button mat-stroked-button type="button" (click)="addBreak()" [attr.aria-label]="'shared.addBreakAria' | translate">
            <mat-icon>add</mat-icon> {{ 'shared.breakLabel' | translate }}
          </button>
        </div>

        <div formArrayName="breaks" class="breaks-list">
          @for (b of breaks.controls; track $index; let i = $index) {
            <div [formGroupName]="i" class="break-row">
              <mat-form-field appearance="outline" class="flex-2">
                <mat-label>{{ 'shared.nameLabel' | translate }}</mat-label>
                <input matInput formControlName="name" />
              </mat-form-field>
              <mat-form-field appearance="outline" class="flex-1">
                <mat-label>{{ 'reports.timeStart' | translate }}</mat-label>
                <input matInput type="time" formControlName="start" />
              </mat-form-field>
              <mat-form-field appearance="outline" class="flex-1">
                <mat-label>{{ 'reports.timeEnd' | translate }}</mat-label>
                <input matInput type="time" formControlName="end" />
              </mat-form-field>
              <button mat-icon-button (click)="removeBreak(i)" [attr.aria-label]="'shared.removeBreakAria' | translate">
                <mat-icon>delete</mat-icon>
              </button>
            </div>
          }
        </div>

        <mat-divider class="section-divider" />

        <div class="section-header">
          <h3>{{ 'shared.manualCorrectionTitle' | translate }}</h3>
        </div>
        <mat-form-field appearance="outline">
          <mat-label>{{ 'shared.manualCorrectionLabel' | translate }}</mat-label>
          <input matInput type="number" formControlName="manualOvertimeMinutes"
                 [attr.aria-label]="'shared.manualCorrectionAria' | translate" />
          <mat-hint>{{ 'shared.manualCorrectionHint' | translate }}</mat-hint>
        </mat-form-field>
      </form>
    </mat-dialog-content>
    <mat-dialog-actions align="end">
      <button mat-button (click)="onCancel()">{{ 'common.cancel' | translate }}</button>
      <button mat-flat-button [disabled]="form.invalid" (click)="onSave()">{{ 'common.save' | translate }}</button>
    </mat-dialog-actions>
  `,
  styles: [`
    .edit-form { display: flex; flex-direction: column; gap: 8px; min-width: min(400px, calc(95vw - 48px)); padding-top: 8px; }
    .time-row { display: flex; flex-wrap: wrap; gap: 0 16px; }
    .time-row mat-form-field { flex: 1 1 120px; }
    .section-header {
      display: flex; justify-content: space-between; align-items: center; margin: 16px 0 4px;
      h3 { margin: 0; font-size: 1rem; }
    }
    .section-divider { margin: 8px 0; }
    .break-row { display: flex; flex-wrap: wrap; gap: 0 8px; align-items: center; }
    .flex-2 { flex: 2 1 100%; }
    .flex-1 { flex: 1 1 100px; }
  `],
})
export class EditEntryDialogComponent {
  private readonly fb        = inject(FormBuilder);
  private readonly dialogRef = inject(MatDialogRef<EditEntryDialogComponent>);
  private readonly translate = inject(TranslateService);
  readonly data              = inject(MAT_DIALOG_DATA) as { entry?: WorkEntry; date: Date };

  protected readonly WorkEntryType = WorkEntryType;
  readonly form: FormGroup;

  private readonly translateKey = (key: string, params?: Record<string, unknown>): string =>
    this.translate.instant(key, params);

  constructor() {
    const entry = this.data.entry;
    this.form = this.fb.group({
      type:                  [entry?.type ?? WorkEntryType.Work, Validators.required],
      startTime:             [this._formatTime(entry?.workStart)],
      endTime:               [this._formatTime(entry?.workEnd)],
      manualOvertimeMinutes: [entry?.manualOvertimeMinutes ?? null],
      breaks: this.fb.array(
        (entry?.breaks ?? []).map(b => this.fb.group({
          id:    [b.id],
          // Standardnamen werden in der App-Sprache angezeigt (siehe #346)
          name:  [localizedBreakName(b.name, this.translateKey), Validators.required],
          start: [this._formatTime(b.start),  Validators.required],
          end:   [this._formatTime(b.end),    Validators.required],
        }))
      ),
    });
  }

  get breaks(): FormArray { return this.form.get('breaks') as FormArray; }

  addBreak(): void {
    this.breaks.push(this.fb.group({
      id:    [crypto.randomUUID()],
      name:  [this.translate.instant('shared.breakDefaultName', { number: this.breaks.length + 1 }), Validators.required],
      start: ['', Validators.required],
      end:   ['', Validators.required],
    }));
  }

  removeBreak(index: number): void { this.breaks.removeAt(index); }

  onCancel(): void { this.dialogRef.close(); }

  onSave(): void {
    if (this.form.invalid) return;
    const val  = this.form.value as EntryFormValue;
    const date = this.data.date;
    const originalNames = new Map((this.data.entry?.breaks ?? []).map(b => [b.id, b.name]));

    const result: Partial<WorkEntry> = {
      id:                    this.data.entry?.id ?? date.toISOString().split('T')[0],
      date,
      type:                  val.type,
      workStart:             this._parseTime(date, val.startTime),
      workEnd:               this._parseTime(date, val.endTime),
      manualOvertimeMinutes: val.manualOvertimeMinutes ?? undefined,
      isManuallyEntered:     true,
      breaks: val.breaks.map((b): Break => ({
        id:          b.id,
        // Unverändert gelassene Standardnamen nicht als übersetzten Freitext speichern
        name:        breakNameToStore(b.name, originalNames.get(b.id) ?? b.name, this.translateKey),
        start:       this._parseTime(date, b.start)!,
        end:         this._parseTime(date, b.end),
        isAutomatic: false,
      })),
    };

    this.dialogRef.close(result);
  }

  private _formatTime(date?: Date): string {
    if (!date) return '';
    return date.toTimeString().slice(0, 5);
  }

  private _parseTime(baseDate: Date, timeStr: string): Date | undefined {
    if (!timeStr) return undefined;
    const [h, m] = timeStr.split(':').map(Number);
    const d = new Date(baseDate);
    d.setHours(h, m, 0, 0);
    return d;
  }
}
