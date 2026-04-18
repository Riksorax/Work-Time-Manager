import { Component, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormBuilder, FormGroup, ReactiveFormsModule, Validators, FormArray } from '@angular/forms';
import { MatDialogModule, MatDialogRef, MAT_DIALOG_DATA } from '@angular/material/dialog';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatSelectModule } from '@angular/material/select';
import { WorkEntry, WorkEntryType, Break } from '../../../shared/models';

@Component({
  selector: 'app-edit-entry-dialog',
  standalone: true,
  imports: [
    CommonModule,
    ReactiveFormsModule,
    MatDialogModule,
    MatFormFieldModule,
    MatInputModule,
    MatButtonModule,
    MatIconModule,
    MatSelectModule
  ],
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
            <input matInput type="time" formControlName="startTime">
          </mat-form-field>

          <mat-form-field appearance="outline">
            <mat-label>Arbeitsende</mat-label>
            <input matInput type="time" formControlName="endTime">
          </mat-form-field>
        </div>

        <div class="section-header">
          <h3>Pausen</h3>
          <button mat-stroked-button type="button" (click)="addBreak()">
            <mat-icon>add</mat-icon> Pause
          </button>
        </div>

        <div formArrayName="breaks" class="breaks-list">
          @for (b of breaks.controls; track $index; let i = $index) {
            <div [formGroupName]="i" class="break-row">
              <mat-form-field appearance="outline" class="flex-2">
                <mat-label>Name</mat-label>
                <input matInput formControlName="name">
              </mat-form-field>
              
              <mat-form-field appearance="outline" class="flex-1">
                <mat-label>Start</mat-label>
                <input matInput type="time" formControlName="start">
              </mat-form-field>
              
              <mat-form-field appearance="outline" class="flex-1">
                <mat-label>Ende</mat-label>
                <input matInput type="time" formControlName="end">
              </mat-form-field>

              <button mat-icon-button color="warn" (click)="removeBreak(i)">
                <mat-icon>delete</mat-icon>
              </button>
            </div>
          }
        </div>
      </form>
    </mat-dialog-content>
    <mat-dialog-actions align="end">
      <button mat-button (click)="onCancel()">Abbrechen</button>
      <button mat-flat-button color="primary" [disabled]="form.invalid" (click)="onSave()">Speichern</button>
    </mat-dialog-actions>
  `,
  styles: [`
    .edit-form {
      display: flex;
      flex-direction: column;
      gap: 8px;
      min-width: 400px;
      padding-top: 8px;
    }
    .time-row {
      display: flex;
      gap: 16px;
    }
    .section-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin: 16px 0 8px 0;
      h3 { margin: 0; font-size: 1rem; }
    }
    .break-row {
      display: flex;
      gap: 8px;
      align-items: center;
    }
    .flex-2 { flex: 2; }
    .flex-1 { flex: 1; }
  `]
})
export class EditEntryDialogComponent {
  private fb = inject(FormBuilder);
  private dialogRef = inject(MatDialogRef<EditEntryDialogComponent>);
  data = inject(MAT_DIALOG_DATA) as { entry?: WorkEntry, date: Date };

  WorkEntryType = WorkEntryType;
  form: FormGroup;

  constructor() {
    const entry = this.data.entry;
    this.form = this.fb.group({
      type: [entry?.type || WorkEntryType.Work, Validators.required],
      startTime: [this.formatTime(entry?.workStart)],
      endTime: [this.formatTime(entry?.workEnd)],
      breaks: this.fb.array(
        (entry?.breaks || []).map(b => this.fb.group({
          id: [b.id],
          name: [b.name, Validators.required],
          start: [this.formatTime(b.start), Validators.required],
          end: [this.formatTime(b.end), Validators.required]
        }))
      )
    });
  }

  get breaks() {
    return this.form.get('breaks') as FormArray;
  }

  addBreak() {
    this.breaks.push(this.fb.group({
      id: [crypto.randomUUID()],
      name: ['Pause ' + (this.breaks.length + 1), Validators.required],
      start: ['', Validators.required],
      end: ['', Validators.required]
    }));
  }

  removeBreak(index: number) {
    this.breaks.removeAt(index);
  }

  onCancel() {
    this.dialogRef.close();
  }

  onSave() {
    if (this.form.invalid) return;

    const val = this.form.value;
    const date = this.data.date;

    const result: Partial<WorkEntry> = {
      id: this.data.entry?.id || date.toISOString().split('T')[0],
      date: date,
      type: val.type,
      workStart: this.parseTime(date, val.startTime),
      workEnd: this.parseTime(date, val.endTime),
      isManuallyEntered: true,
      breaks: val.breaks.map((b: any) => ({
        id: b.id,
        name: b.name,
        start: this.parseTime(date, b.start)!,
        end: this.parseTime(date, b.end),
        isAutomatic: false
      }))
    };

    this.dialogRef.close(result);
  }

  private formatTime(date?: Date): string {
    if (!date) return '';
    return date.toTimeString().slice(0, 5);
  }

  private parseTime(baseDate: Date, timeStr: string): Date | undefined {
    if (!timeStr) return undefined;
    const [h, m] = timeStr.split(':').map(Number);
    const d = new Date(baseDate);
    d.setHours(h, m, 0, 0);
    return d;
  }
}
