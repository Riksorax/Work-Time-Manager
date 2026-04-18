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
import { toSignal } from '@angular/core/rxjs-interop';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatProgressSpinnerModule } from '@angular/material/progress-spinner';
import { MatSelectModule } from '@angular/material/select';
import { MatTooltipModule } from '@angular/material/tooltip';
import { TranslateModule } from '@ngx-translate/core';
import { WorkSessionService } from '../../services/work-session.service';
import { BreakCalculatorService } from '../../services/break-calculator.service';
import { ToastService } from '../../../../shared/components/toast/toast.service';
import { WorkSessionType } from '../../../../shared/models';
import { formatTimer, getElapsedSeconds } from '../../utils/time-calculations.util';

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
    MatButtonModule,
    MatIconModule,
    MatProgressSpinnerModule,
    MatSelectModule,
    MatTooltipModule,
    TranslateModule,
  ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  styles: [`
    :host { display: block; }

    .timer-card {
      background: var(--mat-sys-primary-container);
      border-radius: 12px;
      padding: 20px;
      text-align: center;
    }

    .timer-display {
      font-size: 3rem;
      font-weight: 700;
      font-variant-numeric: tabular-nums;
      color: var(--mat-sys-on-primary-container);
      letter-spacing: 2px;
      margin: 0 0 4px;

      &.vacation { color: #1565c0; }
      &.sick { color: #c62828; }
      &.holiday { color: #2e7d32; }
    }

    .timer-status {
      font-size: 0.875rem;
      color: var(--mat-sys-on-primary-container);
      opacity: 0.75;
      margin: 0 0 4px;
    }

    .timer-meta {
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 16px;
      font-size: 0.8rem;
      color: var(--mat-sys-on-primary-container);
      opacity: 0.7;
      margin-bottom: 16px;

      .meta-item { display: flex; align-items: center; gap: 4px; }
      mat-icon { font-size: 14px; width: 14px; height: 14px; }
    }

    .break-warning {
      display: flex;
      align-items: center;
      gap: 6px;
      justify-content: center;
      background: #FFF3E0;
      border: 1px solid #FFCC80;
      border-radius: 8px;
      padding: 6px 12px;
      margin-bottom: 12px;
      font-size: 0.8rem;
      color: #E65100;
      mat-icon { font-size: 16px; width: 16px; height: 16px; }
    }

    .timer-actions {
      display: flex;
      gap: 12px;
      justify-content: center;
      flex-wrap: wrap;
    }

    .idle-card {
      border: 2px dashed var(--mat-sys-outline-variant);
      border-radius: 12px;
      padding: 20px;
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
  `],
  template: `
    @if (activeSession()) {
      <div class="timer-card">
        <p class="timer-display" [class]="activeSession()!.type">{{ display() }}</p>

        <p class="timer-status">
          <mat-icon style="font-size:14px;width:14px;height:14px;vertical-align:middle">
            {{ typeIcon(activeSession()!.type) }}
          </mat-icon>
          {{ typeLabel(activeSession()!.type) }} ·
          {{ activeSession()!.isPaused ? ('timer.paused' | translate) : ('timer.running' | translate) }}
        </p>

        @if (expectedEnd()) {
          <div class="timer-meta">
            <span class="meta-item">
              <mat-icon>schedule</mat-icon>
              Feierabend ca. {{ expectedEnd() | date:'HH:mm' }}
            </span>
            @if (activeSession()!.pauseDuration > 0) {
              <span class="meta-item">
                <mat-icon>coffee</mat-icon>
                {{ activeSession()!.pauseDuration }}min Pause
              </span>
            }
          </div>
        }

        @if (breakSuggestion()?.isRequired) {
          <div class="break-warning">
            <mat-icon>warning</mat-icon>
            Gesetzliche Pause: noch {{ breakSuggestion()!.missingMinutes }}min fällig
          </div>
        }

        <div class="timer-actions">
          @if (activeSession()!.isPaused) {
            <button mat-flat-button (click)="resume()" [disabled]="busy()">
              <mat-icon>play_arrow</mat-icon>
              {{ 'timer.resume' | translate }}
            </button>
          } @else {
            <button mat-stroked-button (click)="pause()" [disabled]="busy()">
              <mat-icon>pause</mat-icon>
              {{ 'timer.pause' | translate }}
            </button>
          }
          <button mat-flat-button color="warn" (click)="stop()" [disabled]="busy()">
            @if (busy()) { <mat-spinner diameter="18" /> } @else { <mat-icon>stop</mat-icon> }
            {{ 'timer.stop' | translate }}
          </button>
        </div>
      </div>
    } @else {
      <div class="idle-card">
        <mat-icon style="font-size:40px;width:40px;height:40px;color:var(--mat-sys-primary)">timer</mat-icon>
        <p>{{ 'timer.noActiveSession' | translate }}</p>

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

        <button mat-flat-button (click)="start()" [disabled]="busy()">
          @if (busy()) { <mat-spinner diameter="18" /> } @else { <mat-icon>play_arrow</mat-icon> }
          {{ 'timer.start' | translate }}
        </button>
      </div>
    }
  `,
})
export class LiveTimerComponent implements OnInit, OnDestroy {
  private sessionService = inject(WorkSessionService);
  private breakCalc = inject(BreakCalculatorService);
  private toast = inject(ToastService);

  readonly activeSession = toSignal(this.sessionService.activeSession$, { initialValue: null });
  readonly busy = signal(false);
  readonly display = signal('00:00:00');
  readonly selectedType = signal<WorkSessionType>('work');

  readonly sessionTypes: WorkSessionType[] = ['work', 'vacation', 'sick', 'holiday'];

  readonly breakSuggestion = computed(() => {
    const s = this.activeSession();
    if (!s || s.isPaused) return null;
    const workedMinutes = Math.floor(getElapsedSeconds(s) / 60) + s.pauseDuration;
    return this.breakCalc.getSuggestion(workedMinutes, s.pauseDuration);
  });

  readonly expectedEnd = computed(() => {
    const s = this.activeSession();
    if (!s || s.type !== 'work') return null;
    // Feierabend basierend auf 8h Tagesziel (grobe Schätzung, verfeinert durch Profil)
    return this.breakCalc.expectedEndTime(s.startTime.toDate(), 8 * 60, s.pauseDuration);
  });

  private tickInterval: ReturnType<typeof setInterval> | null = null;

  ngOnInit(): void {
    this.tickInterval = setInterval(() => {
      const s = this.activeSession();
      if (s && !s.isPaused) {
        this.display.set(formatTimer(getElapsedSeconds(s)));
      }
    }, 1000);
  }

  ngOnDestroy(): void {
    if (this.tickInterval) clearInterval(this.tickInterval);
  }

  typeIcon(type: WorkSessionType): string { return SESSION_TYPE_ICONS[type]; }
  typeLabel(type: WorkSessionType): string { return SESSION_TYPE_LABELS[type]; }

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
    try { await this.sessionService.stopSession(s.id); this.display.set('00:00:00'); }
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
}
