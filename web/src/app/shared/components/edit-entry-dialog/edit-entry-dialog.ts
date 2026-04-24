import { ChangeDetectionStrategy, Component, inject } from '@angular/core';
import { ReactiveFormsModule, FormBuilder, FormGroup, Validators, FormArray } from '@angular/forms';
import { MAT_DIALOG_DATA, MatDialogModule, MatDialogRef } from '@angular/material/dialog';
import { MatButtonModule } from '@angular/material/button';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatIconModule } from '@angular/material/icon';
import { MatInputModule } from '@angular/material/input';
import { MatSelectModule } from '@angular/material/select';
import { WorkEntry, WorkEntryType, Break } from '../../models/index';

interface BreakFormValue {
  id: string;
  name: string;
  start: string;
  end: string;
}

@Component({
  selector: 'app-edit-entry-dialog',
  imports: [
    ReactiveFormsModule,
    MatDialogModule,
    MatButtonModule,
    MatFormFieldModule,
    MatIconModule,
    MatInputModule,
    MatSelectModule,
  ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <h2 mat-dialog-title>{{ data.entry ? 'Eintrag bearbeiten' : 'Neuer Eintrag' }}</h2>
    <mat-dialog-content>
      <form [formGroup]="form" class="edit-form">
        <mat-form-field appearance="outline">
          <mat-label>Typ</mat-label>
          <mat-select formControlName="type">
            <mat-option [value]="WorkEntryType.Work">Arbeit</mat-option>
            <mat-option [value]="WorkEntryType.Vacation">Urlaub</mat-option>
            <mat-option [value]="WorkEntryType.Sick">Krankheit</mat-option>
            <mat-option [value]="WorkEntryType.Holiday">Feiertag</mat-option>
          </mat-select>
        </mat-form-field>

        <div class="time-row">
          <mat-form-field appearance="outline">
            <mat-label>Arbeitsbeginn</mat-label>
            <input matInput type="time" formControlName="startTime" />
          </mat-form-field>
          <mat-form-field appearance="outline">
            <mat-label>Arbeitsende</mat-label>
            <input matInput type="time" formControlName="endTime" />
          </mat-form-field>
        </div>

        <div class="section-header">
          <h3>Pausen</h3>
          <button mat-stroked-button type="button" (click)="addBreak()" aria-label="Pause hinzufügen">
            <mat-icon>add</mat-icon> Pause
          </button>
        </div>

        <div formArrayName="breaks" class="breaks-list">
          @for (b of breaks.controls; track $index; let i = $index) {
            <div [formGroupName]="i" class="break-row">
              <mat-form-field appearance="outline" class="flex-2">
                <mat-label>Name</mat-label>
                <input matInput formControlName="name" />
              </mat-form-field>
              <mat-form-field appearance="outline" class="flex-1">
                <mat-label>Start</mat-label>
                <input matInput type="time" formControlName="start" />
              </mat-form-field>
              <mat-form-field appearance="outline" class="flex-1">
                <mat-label>Ende</mat-label>
                <input matInput type="time" formControlName="end" />
              </mat-form-field>
              <button mat-icon-button (click)="removeBreak(i)" aria-label="Pause entfernen">
                <mat-icon>delete</mat-icon>
              </button>
            </div>
          }
        </div>
      </form>
    </mat-dialog-content>
    <mat-dialog-actions align="end">
      <button mat-button (click)="onCancel()">Abbrechen</button>
      <button mat-flat-button [disabled]="form.invalid" (click)="onSave()">Speichern</button>
    </mat-dialog-actions>
  `,
  styles: [`
    .edit-form { display: flex; flex-direction: column; gap: 8px; min-width: 400px; padding-top: 8px; }
    .time-row { display: flex; gap: 16px; }
    .section-header {
      display: flex; justify-content: space-between; align-items: center; margin: 16px 0 8px;
      h3 { margin: 0; font-size: 1rem; }
    }
    .break-row { display: flex; gap: 8px; align-items: center; }
    .flex-2 { flex: 2; }
    .flex-1 { flex: 1; }
  `],
})
export class EditEntryDialogComponent {
  private readonly fb        = inject(FormBuilder);
  private readonly dialogRef = inject(MatDialogRef<EditEntryDialogComponent>);
  readonly data              = inject(MAT_DIALOG_DATA) as { entry?: WorkEntry; date: Date };

  protected readonly WorkEntryType = WorkEntryType;
  readonly form: FormGroup;

  constructor() {
    const entry = this.data.entry;
    this.form = this.fb.group({
      type:      [entry?.type ?? WorkEntryType.Work, Validators.required],
      startTime: [this._formatTime(entry?.workStart)],
      endTime:   [this._formatTime(entry?.workEnd)],
      breaks: this.fb.array(
        (entry?.breaks ?? []).map(b => this.fb.group({
          id:    [b.id],
          name:  [b.name,                   Validators.required],
          start: [this._formatTime(b.start), Validators.required],
          end:   [this._formatTime(b.end),   Validators.required],
        }))
      ),
    });
  }

  get breaks(): FormArray { return this.form.get('breaks') as FormArray; }

  addBreak(): void {
    this.breaks.push(this.fb.group({
      id:    [crypto.randomUUID()],
      name:  [`Pause ${this.breaks.length + 1}`, Validators.required],
      start: ['', Validators.required],
      end:   ['', Validators.required],
    }));
  }

  removeBreak(index: number): void { this.breaks.removeAt(index); }

  onCancel(): void { this.dialogRef.close(); }

  onSave(): void {
    if (this.form.invalid) return;
    const val  = this.form.value as { type: WorkEntryType; startTime: string; endTime: string; breaks: BreakFormValue[] };
    const date = this.data.date;

    const result: Partial<WorkEntry> = {
      id:               this.data.entry?.id ?? date.toISOString().split('T')[0],
      date,
      type:             val.type,
      workStart:        this._parseTime(date, val.startTime),
      workEnd:          this._parseTime(date, val.endTime),
      isManuallyEntered: true,
      breaks: val.breaks.map((b): Break => ({
        id:          b.id,
        name:        b.name,
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
