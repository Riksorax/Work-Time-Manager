import {
  ChangeDetectionStrategy,
  Component,
  inject,
  signal,
  computed,
  input,
  effect,
} from '@angular/core';
import { DatePipe } from '@angular/common';
import { Router } from '@angular/router';
import { FormBuilder, ReactiveFormsModule } from '@angular/forms';
import { MatButtonModule } from '@angular/material/button';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatSelectModule } from '@angular/material/select';
import { MatIconModule } from '@angular/material/icon';
import { MatProgressSpinnerModule } from '@angular/material/progress-spinner';
import { MatDividerModule } from '@angular/material/divider';
import { MatDialog } from '@angular/material/dialog';
import { TranslateModule } from '@ngx-translate/core';
import { WorkSessionService } from '../../services/work-session.service';
import { ToastService } from '../../../../shared/components/toast/toast.service';
import { WorkSession, SessionBreak, WorkSessionType } from '../../../../shared/models';
import { DurationPipe } from '../../../../shared/pipes/duration.pipe';
import { calculateNetMinutes } from '../../utils/time-calculations.util';
import { EditTimeDialogComponent, EditTimeDialogData, EditTimeDialogResult } from '../edit-time-dialog/edit-time-dialog.component';
import { EditBreakDialogComponent, EditBreakDialogData } from '../edit-break-dialog/edit-break-dialog.component';
import { ConfirmDialogComponent } from '../../../../shared/components/confirm-dialog/confirm-dialog.component';

const SESSION_TYPE_ICONS: Record<WorkSessionType, string> = {
  work: 'work',
  vacation: 'beach_access',
  sick: 'sick',
  holiday: 'celebration',
};

@Component({
  selector: 'wtm-session-detail',
  standalone: true,
  imports: [
    DatePipe,
    ReactiveFormsModule,
    MatButtonModule,
    MatFormFieldModule,
    MatInputModule,
    MatSelectModule,
    MatIconModule,
    MatProgressSpinnerModule,
    MatDividerModule,
    TranslateModule,
    DurationPipe,
  ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  styles: [`
    :host { display: block; padding: 16px; max-width: 600px; margin: 0 auto; }

    .page-header {
      display: flex;
      align-items: center;
      gap: 8px;
      margin-bottom: 24px;
      h1 { margin: 0; font-size: 1.25rem; font-weight: 700; }
    }

    /* ── Zeiten ───────────────────────────────────────── */

    .section-title {
      font-size: 1rem;
      font-weight: 600;
      color: var(--mat-sys-on-surface);
      margin: 0 0 12px;
    }

    .time-row {
      display: flex;
      gap: 12px;
      margin-bottom: 24px;
    }

    .time-field {
      flex: 1;
      border: 1px solid var(--mat-sys-outline);
      border-radius: 8px;
      padding: 12px 14px;
      cursor: pointer;
      transition: border-color 0.15s, background 0.15s;

      &:hover { border-color: var(--mat-sys-primary); background: var(--mat-sys-primary-container); }

      .tf-label {
        font-size: 0.7rem;
        font-weight: 600;
        letter-spacing: 0.06em;
        text-transform: uppercase;
        color: var(--mat-sys-on-surface-variant);
        margin-bottom: 4px;
      }

      .tf-value {
        font-size: 1.1rem;
        font-weight: 700;
        font-variant-numeric: tabular-nums;
        color: var(--mat-sys-on-surface);
        display: flex;
        align-items: center;
        gap: 6px;
        mat-icon { font-size: 16px; width: 16px; height: 16px; opacity: 0.5; }
      }
    }

    /* ── Pausen ───────────────────────────────────────── */

    .breaks-section { margin-bottom: 24px; }

    .breaks-header {
      display: flex;
      align-items: center;
      justify-content: space-between;
      margin-bottom: 10px;
    }

    .break-list { display: flex; flex-direction: column; gap: 6px; margin-bottom: 10px; }

    .break-item {
      display: flex;
      align-items: center;
      gap: 10px;
      padding: 10px 12px;
      border: 1px solid var(--mat-sys-outline-variant);
      border-radius: 8px;

      .break-icon { font-size: 18px; width: 18px; height: 18px; color: var(--mat-sys-on-surface-variant); }

      .break-info {
        flex: 1;
        min-width: 0;
        .break-name { font-size: 0.85rem; font-weight: 500; }
        .break-time { font-size: 0.75rem; color: var(--mat-sys-on-surface-variant); font-variant-numeric: tabular-nums; }
      }

      .break-duration { font-size: 0.8rem; font-weight: 600; color: var(--mat-sys-primary); white-space: nowrap; }
      .break-actions { display: flex; gap: 2px; }
    }

    .empty-breaks {
      padding: 12px;
      text-align: center;
      font-size: 0.85rem;
      color: var(--mat-sys-on-surface-variant);
      border: 1px dashed var(--mat-sys-outline-variant);
      border-radius: 8px;
      margin-bottom: 10px;
    }

    /* ── Formular ─────────────────────────────────────── */

    .details-section { margin-bottom: 24px; }

    form { display: flex; flex-direction: column; gap: 12px; }
    mat-form-field { width: 100%; }

    .type-row { display: flex; align-items: center; gap: 6px; font-size: 0.9rem; }

    .form-actions {
      display: flex;
      gap: 8px;
      justify-content: flex-end;
    }

    /* ── Info-Zeile ───────────────────────────────────── */

    .info-chip {
      display: inline-flex;
      align-items: center;
      gap: 4px;
      background: var(--mat-sys-surface-variant);
      border-radius: 16px;
      padding: 4px 12px;
      font-size: 0.8rem;
      color: var(--mat-sys-on-surface-variant);
      margin-bottom: 20px;
      mat-icon { font-size: 14px; width: 14px; height: 14px; }
    }
  `],
  template: `
    <div class="page-header">
      <button mat-icon-button (click)="back()">
        <mat-icon>arrow_back</mat-icon>
      </button>
      <h1>Eintrag bearbeiten</h1>
    </div>

    @if (session()) {

      <!-- Info-Chip: Nettodauer -->
      <div class="info-chip">
        <mat-icon>schedule</mat-icon>
        Netto: {{ netMinutes() | duration }}
        &nbsp;·&nbsp;
        <mat-icon>coffee</mat-icon>
        Pause: {{ session()!.pauseDuration }} min
      </div>

      <!-- ── Arbeitszeiten ── -->
      <p class="section-title">Arbeitszeit</p>
      <div class="time-row">
        <div class="time-field" (click)="openStartTimePicker()" role="button">
          <div class="tf-label">Startzeit</div>
          <div class="tf-value">
            {{ session()!.startTime.toDate() | date:'HH:mm' }}
            <mat-icon>edit</mat-icon>
          </div>
        </div>
        <div class="time-field" (click)="openEndTimePicker()" role="button">
          <div class="tf-label">Endzeit</div>
          <div class="tf-value">
            @if (session()!.endTime) {
              {{ session()!.endTime!.toDate() | date:'HH:mm' }}
            } @else {
              läuft noch
            }
            <mat-icon>edit</mat-icon>
          </div>
        </div>
      </div>

      <!-- ── Pausen ── -->
      <div class="breaks-section">
        <div class="breaks-header">
          <p class="section-title" style="margin:0">Pausen</p>
          <button mat-stroked-button (click)="addBreak()">
            <mat-icon>add</mat-icon>
            Pause hinzufügen
          </button>
        </div>

        @if (completedBreaks().length === 0) {
          <div class="empty-breaks">Keine Pausen erfasst</div>
        } @else {
          <div class="break-list">
            @for (b of completedBreaks(); track b.id) {
              <div class="break-item">
                <mat-icon class="break-icon">{{ b.isAutomatic ? 'auto_mode' : 'coffee' }}</mat-icon>
                <div class="break-info">
                  <div class="break-name">{{ b.name }}</div>
                  <div class="break-time">
                    {{ b.startTime.toDate() | date:'HH:mm' }} – {{ b.endTime!.toDate() | date:'HH:mm' }}
                  </div>
                </div>
                <span class="break-duration">{{ breakDuration(b) }} Min.</span>
                <div class="break-actions">
                  <button mat-icon-button (click)="editBreak(b)" matTooltip="Bearbeiten">
                    <mat-icon>edit</mat-icon>
                  </button>
                  <button mat-icon-button (click)="confirmDeleteBreak(b)" matTooltip="Löschen">
                    <mat-icon color="warn">delete</mat-icon>
                  </button>
                </div>
              </div>
            }
          </div>
        }
      </div>

      <mat-divider style="margin-bottom:24px" />

      <!-- ── Details ── -->
      <div class="details-section">
        <p class="section-title">Details</p>
        <form [formGroup]="form" (ngSubmit)="save()">
          <mat-form-field appearance="outline">
            <mat-label>Typ</mat-label>
            <mat-select formControlName="type">
              @for (t of sessionTypes; track t) {
                <mat-option [value]="t">
                  <span class="type-row">
                    <mat-icon style="font-size:16px;width:16px;height:16px">{{ typeIcon(t) }}</mat-icon>
                    {{ typeLabel(t) }}
                  </span>
                </mat-option>
              }
            </mat-select>
          </mat-form-field>

          <mat-form-field appearance="outline">
            <mat-label>Notiz</mat-label>
            <textarea matInput formControlName="note" rows="3"></textarea>
          </mat-form-field>

          <mat-form-field appearance="outline">
            <mat-label>Kategorie</mat-label>
            <input matInput formControlName="category" />
            <mat-icon matSuffix>label</mat-icon>
          </mat-form-field>

          <div class="form-actions">
            <button mat-button type="button" (click)="back()">Abbrechen</button>
            <button mat-flat-button color="primary" type="submit" [disabled]="saving()">
              @if (saving()) { <mat-spinner diameter="18" /> } @else { Speichern }
            </button>
          </div>
        </form>
      </div>

    } @else {
      <div style="text-align:center;padding:40px">
        <mat-spinner />
      </div>
    }
  `,
})
export class SessionDetailComponent {
  readonly id = input.required<string>();

  private sessionService = inject(WorkSessionService);
  private router = inject(Router);
  private toast = inject(ToastService);
  private dialog = inject(MatDialog);
  private fb = inject(FormBuilder);

  readonly saving = signal(false);
  readonly session = signal<WorkSession | null>(null);
  readonly sessionTypes: WorkSessionType[] = ['work', 'vacation', 'sick', 'holiday'];

  readonly completedBreaks = computed(() =>
    (this.session()?.breaks ?? []).filter(b => !!b.endTime)
  );

  readonly form = this.fb.nonNullable.group({
    type: ['work' as WorkSessionType],
    note: [''],
    category: [''],
  });

  constructor() {
    effect(() => {
      const id = this.id();
      if (!id) return;
      this.sessionService.getSession$(id).subscribe(s => {
        this.session.set(s);
        if (s) {
          this.form.patchValue({
            type: s.type ?? 'work',
            note: s.note ?? '',
            category: s.category ?? '',
          });
        }
      });
    });
  }

  typeIcon(type: WorkSessionType): string { return SESSION_TYPE_ICONS[type]; }

  typeLabel(type: WorkSessionType): string {
    const labels: Record<WorkSessionType, string> = {
      work: 'Arbeit', vacation: 'Urlaub', sick: 'Krank', holiday: 'Feiertag',
    };
    return labels[type];
  }

  netMinutes(): number {
    const s = this.session();
    return s ? calculateNetMinutes(s) : 0;
  }

  breakDuration(b: SessionBreak): number {
    if (!b.endTime) return 0;
    return Math.floor((b.endTime.toMillis() - b.startTime.toMillis()) / 60_000);
  }

  openStartTimePicker(): void {
    const s = this.session();
    if (!s) return;
    const data: EditTimeDialogData = { label: 'Startzeit', currentTime: s.startTime.toDate() };
    this.dialog.open<EditTimeDialogComponent, EditTimeDialogData, EditTimeDialogResult>(
      EditTimeDialogComponent, { data, width: '280px' }
    ).afterClosed().subscribe(async result => {
      if (!result) return;
      const newStart = new Date(s.startTime.toDate());
      newStart.setHours(result.hours, result.minutes, 0, 0);
      try { await this.sessionService.updateSessionTimes(s.id, newStart, s.endTime?.toDate()); }
      catch { this.toast.error('common.error'); }
    });
  }

  openEndTimePicker(): void {
    const s = this.session();
    if (!s) return;
    const current = s.endTime?.toDate() ?? new Date();
    const data: EditTimeDialogData = { label: 'Endzeit', currentTime: current };
    this.dialog.open<EditTimeDialogComponent, EditTimeDialogData, EditTimeDialogResult>(
      EditTimeDialogComponent, { data, width: '280px' }
    ).afterClosed().subscribe(async result => {
      if (!result) return;
      const newEnd = new Date(s.startTime.toDate());
      newEnd.setHours(result.hours, result.minutes, 0, 0);
      try { await this.sessionService.updateSessionTimes(s.id, s.startTime.toDate(), newEnd); }
      catch { this.toast.error('common.error'); }
    });
  }

  addBreak(): void {
    const s = this.session();
    if (!s) return;
    const data: EditBreakDialogData = { sessionId: s.id, mode: 'add' };
    this.dialog.open(EditBreakDialogComponent, { data, width: '320px' });
  }

  editBreak(b: SessionBreak): void {
    const s = this.session();
    if (!s) return;
    const data: EditBreakDialogData = {
      sessionId: s.id,
      mode: 'edit',
      breakId: b.id,
      initialName: b.name,
      initialStartTime: b.startTime.toDate(),
      initialEndTime: b.endTime?.toDate(),
    };
    this.dialog.open(EditBreakDialogComponent, { data, width: '320px' });
  }

  confirmDeleteBreak(b: SessionBreak): void {
    const s = this.session();
    if (!s) return;
    this.dialog.open(ConfirmDialogComponent, {
      data: {
        title: 'Pause löschen',
        message: `"${b.name}" wirklich löschen?`,
        confirmLabel: 'common.delete',
        cancelLabel: 'common.cancel',
      },
    }).afterClosed().subscribe(async confirmed => {
      if (!confirmed) return;
      try { await this.sessionService.deleteBreak(s.id, b.id); }
      catch { this.toast.error('common.error'); }
    });
  }

  async save(): Promise<void> {
    const s = this.session();
    if (!s) return;
    this.saving.set(true);
    try {
      const { type, note, category } = this.form.getRawValue();
      await this.sessionService.updateSession(s.id, {
        type,
        note: note || undefined,
        category: category || undefined,
      });
      this.toast.success('Gespeichert');
      this.back();
    } catch {
      this.toast.error('common.error');
    } finally {
      this.saving.set(false);
    }
  }

  back(): void {
    this.router.navigate(['/time-tracking']);
  }
}
