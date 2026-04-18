import {
  ChangeDetectionStrategy,
  Component,
  inject,
  signal,
  computed,
  OnInit,
  OnDestroy,
} from '@angular/core';
import { DatePipe } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { toSignal } from '@angular/core/rxjs-interop';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatProgressSpinnerModule } from '@angular/material/progress-spinner';
import { MatSelectModule } from '@angular/material/select';
import { MatTooltipModule } from '@angular/material/tooltip';
import { MatDividerModule } from '@angular/material/divider';
import { MatDialog } from '@angular/material/dialog';
import { TranslateModule } from '@ngx-translate/core';
import { WorkSessionService } from '../../services/work-session.service';
import { BreakCalculatorService } from '../../services/break-calculator.service';
import { ToastService } from '../../../../shared/components/toast/toast.service';
import { WorkSessionType, SessionBreak } from '../../../../shared/models';
import { formatTimer, getElapsedSeconds, getGrossSeconds } from '../../utils/time-calculations.util';
import { EditBreakDialogComponent, EditBreakDialogData } from '../edit-break-dialog/edit-break-dialog.component';
import { EditTimeDialogComponent, EditTimeDialogData, EditTimeDialogResult } from '../edit-time-dialog/edit-time-dialog.component';

const SESSION_TYPE_ICONS: Record<WorkSessionType, string> = {
  work: 'work',
  vacation: 'beach_access',
  sick: 'sick',
  holiday: 'celebration',
};

const SESSION_TYPE_LABELS: Record<WorkSessionType, string> = {
  work: 'Arbeit',
  vacation: 'Urlaub',
  sick: 'Krank',
  holiday: 'Feiertag',
};

@Component({
  selector: 'wtm-live-timer',
  standalone: true,
  imports: [
    DatePipe,
    FormsModule,
    MatButtonModule,
    MatIconModule,
    MatProgressSpinnerModule,
    MatSelectModule,
    MatTooltipModule,
    MatDividerModule,
    TranslateModule,
  ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  styles: [`
    :host { display: block; }

    /* ── Aktiver Timer ─────────────────────────────────── */

    .timer-card {
      background: var(--mat-sys-primary-container);
      border-radius: 12px;
      padding: 20px;
      text-align: center;
    }

    .timer-net {
      font-size: 3.5rem;
      font-weight: 700;
      font-variant-numeric: tabular-nums;
      color: var(--mat-sys-on-primary-container);
      letter-spacing: 2px;
      margin: 0 0 2px;
      line-height: 1;

      &.vacation { color: #1565c0; }
      &.sick     { color: #c62828; }
      &.holiday  { color: #2e7d32; }
    }

    .timer-gross {
      font-size: 0.8rem;
      color: var(--mat-sys-on-primary-container);
      opacity: 0.65;
      margin: 0 0 16px;
      font-variant-numeric: tabular-nums;
    }

    /* ── START / ENDE ──────────────────────────────────── */

    .start-end-row {
      display: flex;
      justify-content: center;
      gap: 48px;
      margin-bottom: 12px;

      .time-col {
        display: flex;
        flex-direction: column;
        align-items: center;
        gap: 4px;
      }

      .time-label {
        font-size: 0.65rem;
        font-weight: 700;
        letter-spacing: 0.08em;
        text-transform: uppercase;
        color: var(--mat-sys-on-primary-container);
        opacity: 0.6;
      }

      .time-value {
        font-size: 1.1rem;
        font-weight: 700;
        font-variant-numeric: tabular-nums;
        color: var(--mat-sys-on-primary-container);
      }
    }

    /* ── Feierabend-Prognose ───────────────────────────── */

    .timer-meta {
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 16px;
      font-size: 0.8rem;
      color: var(--mat-sys-on-primary-container);
      opacity: 0.7;
      margin-bottom: 12px;

      .meta-item { display: flex; align-items: center; gap: 4px; }
      mat-icon { font-size: 14px; width: 14px; height: 14px; }
    }

    /* ── Pausen-Warnung ────────────────────────────────── */

    .break-warning {
      display: flex;
      align-items: flex-start;
      gap: 8px;
      background: #FFF3E0;
      border: 1px solid #FFCC80;
      border-radius: 8px;
      padding: 10px 12px;
      margin-bottom: 12px;
      font-size: 0.8rem;
      color: #E65100;
      text-align: left;
      mat-icon { font-size: 18px; width: 18px; height: 18px; flex-shrink: 0; margin-top: 1px; }
    }

    /* ── Pausen-Sektion ────────────────────────────────── */

    .pause-section {
      background: var(--mat-sys-surface);
      border-radius: 8px;
      padding: 12px 16px;
      margin-bottom: 12px;
      text-align: left;
    }

    .pause-header {
      display: flex;
      align-items: center;
      justify-content: space-between;
      margin-bottom: 8px;

      .pause-title {
        font-size: 0.85rem;
        font-weight: 600;
        color: var(--mat-sys-on-surface);
      }
      .pause-total {
        font-size: 0.85rem;
        font-weight: 600;
        color: var(--mat-sys-primary);
      }
    }

    .pause-status {
      font-size: 0.75rem;
      color: var(--mat-sys-on-surface-variant);
      display: flex;
      align-items: center;
      gap: 4px;
      mat-icon { font-size: 14px; width: 14px; height: 14px; }
    }

    /* ── Einzelne Pause ────────────────────────────────── */

    .break-list { display: flex; flex-direction: column; gap: 4px; margin-bottom: 8px; }

    .break-item {
      display: flex;
      align-items: center;
      gap: 8px;
      padding: 6px 8px;
      border-radius: 6px;
      background: var(--mat-sys-surface-variant);

      .break-icon {
        font-size: 16px; width: 16px; height: 16px;
        color: var(--mat-sys-on-surface-variant);
        flex-shrink: 0;
      }

      .break-info {
        flex: 1;
        min-width: 0;

        .break-name {
          font-size: 0.78rem;
          font-weight: 500;
          color: var(--mat-sys-on-surface);
          white-space: nowrap;
          overflow: hidden;
          text-overflow: ellipsis;
        }
        .break-time {
          font-size: 0.7rem;
          color: var(--mat-sys-on-surface-variant);
          font-variant-numeric: tabular-nums;
        }
      }

      .break-duration {
        font-size: 0.75rem;
        font-weight: 600;
        color: var(--mat-sys-primary);
        flex-shrink: 0;
      }

      }

    /* ── Aktions-Buttons ───────────────────────────────── */

    .timer-actions {
      display: flex;
      flex-direction: column;
      gap: 8px;
    }

    .btn-stop {
      width: 100%;
      height: 48px;
      font-size: 1rem;
      font-weight: 600;
      background: #E65100 !important;
      color: #fff !important;
    }

    .btn-pause {
      width: 100%;
      height: 44px;
      font-size: 0.9rem;
    }

    /* ── Idle Card ─────────────────────────────────────── */

    .idle-card {
      border: 2px dashed var(--mat-sys-outline-variant);
      border-radius: 12px;
      padding: 24px 20px;
      text-align: center;
      display: flex;
      flex-direction: column;
      align-items: center;
      gap: 12px;

      p { margin: 0; color: var(--mat-sys-on-surface-variant); font-size: 0.9rem; }
    }

    .type-select {
      width: 100%;
      max-width: 200px;
      ::ng-deep .mat-mdc-form-field-subscript-wrapper { display: none; }
    }

    .type-row {
      display: flex;
      align-items: center;
      gap: 6px;
      font-size: 0.9rem;
    }

    .btn-start {
      width: 100%;
      max-width: 280px;
      height: 48px;
      font-size: 1rem;
      font-weight: 600;
      background: #2e7d32 !important;
      color: #fff !important;
    }
  `],
  template: `
    @if (activeSession()) {
      <div class="timer-card">

        <!-- Netto-Timer -->
        <p class="timer-net" [class]="activeSession()!.type">{{ netDisplay() }}</p>
        <p class="timer-gross">Anwesenheit (Brutto): {{ grossDisplay() }}</p>

        <!-- START / ENDE (read-only, wie in Flutter) -->
        <div class="start-end-row">
          <div class="time-col">
            <span class="time-label">Start</span>
            <span class="time-value">{{ startTimeStr() }}</span>
          </div>
          <div class="time-col">
            <span class="time-label">Ende</span>
            <span class="time-value">{{ endTimeStr() || '--:--' }}</span>
          </div>
        </div>

        <!-- Feierabend-Prognose -->
        @if (expectedEnd() && !activeSession()!.isPaused) {
          <div class="timer-meta">
            <span class="meta-item">
              <mat-icon>schedule</mat-icon>
              Feierabend ca. {{ expectedEnd() | date:'HH:mm' }}
            </span>
          </div>
        }

        <!-- Pause-Warnung (ArbZG) -->
        @if (breakSuggestion()?.isRequired) {
          <div class="break-warning">
            <mat-icon>info_outline</mat-icon>
            Laut Arbeitszeitgesetz sind noch mind. {{ breakSuggestion()!.missingMinutes }} Min. Pause vorgeschrieben.
          </div>
        }

        <!-- Pausen-Sektion -->
        <div class="pause-section">
          <div class="pause-header">
            <span class="pause-title">Pausen</span>
            <span class="pause-total">{{ totalPauseDisplay() }}</span>
          </div>

          <!-- Pausen-Liste (read-only während aktiver Session) -->
          @if (completedBreaks().length > 0) {
            <div class="break-list">
              @for (b of completedBreaks(); track b.id) {
                <div class="break-item">
                  <mat-icon class="break-icon">coffee</mat-icon>
                  <div class="break-info">
                    <div class="break-name">{{ b.name }}</div>
                    <div class="break-time">{{ b.startTime.toDate() | date:'HH:mm' }} – {{ b.endTime!.toDate() | date:'HH:mm' }}</div>
                  </div>
                  <span class="break-duration">{{ breakDuration(b) }} Min.</span>
                </div>
              }
            </div>
          }

          <!-- Status -->
          @if (activeSession()!.isPaused) {
            <div class="pause-status">
              <mat-icon style="color:var(--mat-sys-primary)">timer</mat-icon>
              Pause läuft gerade…
            </div>
          } @else if (completedBreaks().length === 0) {
            <div class="pause-status">Noch keine Pausen erfasst</div>
          }
        </div>

        <!-- Aktions-Buttons -->
        <div class="timer-actions">
          @if (activeSession()!.isPaused) {
            <button class="btn-pause" mat-stroked-button (click)="resume()" [disabled]="busy()">
              @if (busy()) { <mat-spinner diameter="18" /> } @else { <mat-icon>play_circle_outline</mat-icon> }
              Pause beenden
            </button>
          } @else {
            <button class="btn-pause" mat-stroked-button (click)="pause()" [disabled]="busy()">
              @if (busy()) { <mat-spinner diameter="18" /> } @else { <mat-icon>stop_circle</mat-icon> }
              Pause starten
            </button>
          }

          <button class="btn-stop" mat-flat-button (click)="stop()" [disabled]="busy()">
            @if (busy()) { <mat-spinner diameter="18" /> } @else { <mat-icon>stop</mat-icon> }
            Zeiterfassung beenden
          </button>
        </div>

      </div>
    } @else {
      <div class="idle-card">
        <mat-icon style="font-size:40px;width:40px;height:40px;color:var(--mat-sys-primary)">timer</mat-icon>
        <p>Kein aktiver Timer</p>

        <mat-select class="type-select" [value]="selectedType()" (valueChange)="selectedType.set($event)">
          <mat-select-trigger>
            <span class="type-row">
              <mat-icon style="font-size:16px;width:16px;height:16px">{{ typeIcon(selectedType()) }}</mat-icon>
              {{ typeLabel(selectedType()) }}
            </span>
          </mat-select-trigger>
          @for (t of sessionTypes; track t) {
            <mat-option [value]="t">
              <span class="type-row">
                <mat-icon style="font-size:16px;width:16px;height:16px">{{ typeIcon(t) }}</mat-icon>
                {{ typeLabel(t) }}
              </span>
            </mat-option>
          }
        </mat-select>

        <button class="btn-start" mat-flat-button (click)="start()" [disabled]="busy()">
          @if (busy()) { <mat-spinner diameter="18" /> } @else { <mat-icon>play_circle_filled</mat-icon> }
          Zeiterfassung starten
        </button>
      </div>
    }
  `,
})
export class LiveTimerComponent implements OnInit, OnDestroy {
  private sessionService = inject(WorkSessionService);
  private breakCalc = inject(BreakCalculatorService);
  private toast = inject(ToastService);
  private dialog = inject(MatDialog);

  readonly activeSession = toSignal(this.sessionService.activeSession$, { initialValue: null });
  readonly busy = signal(false);
  readonly netDisplay = signal('00:00:00');
  readonly grossDisplay = signal('00:00:00');
  readonly selectedType = signal<WorkSessionType>('work');

  readonly sessionTypes: WorkSessionType[] = ['work', 'vacation', 'sick', 'holiday'];

  readonly completedBreaks = computed(() =>
    (this.activeSession()?.breaks ?? []).filter(b => !!b.endTime)
  );

  readonly totalPauseDisplay = computed(() => {
    const s = this.activeSession();
    if (!s) return '0 min';
    return `${s.pauseDuration} min`;
  });

  readonly startTimeStr = computed(() => {
    const s = this.activeSession();
    if (!s) return '';
    const d = s.startTime.toDate();
    return `${d.getHours().toString().padStart(2, '0')}:${d.getMinutes().toString().padStart(2, '0')}`;
  });

  readonly endTimeStr = computed(() => {
    const s = this.activeSession();
    if (!s?.endTime) return '';
    const d = s.endTime.toDate();
    return `${d.getHours().toString().padStart(2, '0')}:${d.getMinutes().toString().padStart(2, '0')}`;
  });

  readonly breakSuggestion = computed(() => {
    const s = this.activeSession();
    if (!s || s.isPaused) return null;
    const workedMinutes = Math.floor(getElapsedSeconds(s) / 60) + s.pauseDuration;
    return this.breakCalc.getSuggestion(workedMinutes, s.pauseDuration);
  });

  readonly expectedEnd = computed(() => {
    const s = this.activeSession();
    if (!s || s.type !== 'work') return null;
    return this.breakCalc.expectedEndTime(s.startTime.toDate(), 8 * 60, s.pauseDuration);
  });

  private tickInterval: ReturnType<typeof setInterval> | null = null;

  ngOnInit(): void {
    this.tickInterval = setInterval(() => {
      const s = this.activeSession();
      if (s && !s.isPaused) {
        this.netDisplay.set(formatTimer(getElapsedSeconds(s)));
        this.grossDisplay.set(formatTimer(getGrossSeconds(s)));
      }
    }, 1000);
  }

  ngOnDestroy(): void {
    if (this.tickInterval) clearInterval(this.tickInterval);
  }

  typeIcon(type: WorkSessionType): string { return SESSION_TYPE_ICONS[type]; }
  typeLabel(type: WorkSessionType): string { return SESSION_TYPE_LABELS[type]; }

  breakDuration(b: SessionBreak): number {
    if (!b.endTime) return 0;
    return Math.floor((b.endTime.toMillis() - b.startTime.toMillis()) / 60_000);
  }

  openStartTimePicker(): void {
    const s = this.activeSession();
    if (!s) return;
    const data: EditTimeDialogData = { label: 'Startzeit', currentTime: s.startTime.toDate() };
    this.dialog.open<EditTimeDialogComponent, EditTimeDialogData, EditTimeDialogResult>(
      EditTimeDialogComponent, { data, width: '280px' }
    ).afterClosed().subscribe(async result => {
      if (!result) return;
      const newStart = new Date(s.startTime.toDate());
      newStart.setHours(result.hours, result.minutes, 0, 0);
      try { await this.sessionService.updateSessionTimes(s.id, newStart); }
      catch { this.toast.error('common.error'); }
    });
  }

  openEndTimePicker(): void {
    const s = this.activeSession();
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

  async start(): Promise<void> {
    this.busy.set(true);
    try { await this.sessionService.startSession({ type: this.selectedType() }); }
    catch { this.toast.error('common.error'); }
    finally { this.busy.set(false); }
  }

  async stop(): Promise<void> {
    const s = this.activeSession();
    if (!s) return;
    this.busy.set(true);
    try {
      await this.sessionService.stopSessionWithAutoBreaks(s);
      this.netDisplay.set('00:00:00');
      this.grossDisplay.set('00:00:00');
    }
    catch { this.toast.error('common.error'); }
    finally { this.busy.set(false); }
  }

  async pause(): Promise<void> {
    const s = this.activeSession();
    if (!s) return;
    this.busy.set(true);
    try { await this.sessionService.pauseSession(s.id); }
    catch { this.toast.error('common.error'); }
    finally { this.busy.set(false); }
  }

  async resume(): Promise<void> {
    const s = this.activeSession();
    if (!s?.pauseStartTime) return;
    this.busy.set(true);
    try { await this.sessionService.resumeSession(s.id, s.pauseStartTime); }
    catch { this.toast.error('common.error'); }
    finally { this.busy.set(false); }
  }

  addManualBreak(): void {
    const s = this.activeSession();
    if (!s) return;
    const data: EditBreakDialogData = { sessionId: s.id, mode: 'add' };
    this.dialog.open(EditBreakDialogComponent, { data, width: '320px' });
  }

  editBreak(b: SessionBreak): void {
    const s = this.activeSession();
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

  async deleteBreak(breakId: string): Promise<void> {
    const s = this.activeSession();
    if (!s) return;
    try {
      await this.sessionService.deleteBreak(s.id, breakId);
    } catch {
      this.toast.error('common.error');
    }
  }
}
