import {
  ChangeDetectionStrategy,
  Component,
  inject,
  signal,
  OnInit,
  OnDestroy,
} from '@angular/core';
import { toSignal } from '@angular/core/rxjs-interop';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatProgressSpinnerModule } from '@angular/material/progress-spinner';
import { TranslateModule } from '@ngx-translate/core';
import { WorkSessionService } from '../../services/work-session.service';
import { ToastService } from '../../../../shared/components/toast/toast.service';
import { formatTimer, getElapsedSeconds } from '../../utils/time-calculations.util';

@Component({
  selector: 'wtm-live-timer',
  standalone: true,
  imports: [MatButtonModule, MatIconModule, MatProgressSpinnerModule, TranslateModule],
  changeDetection: ChangeDetectionStrategy.OnPush,
  styles: [`
    :host { display: block; }

    .timer-card {
      background: var(--mat-sys-primary-container);
      border-radius: 16px;
      padding: 24px;
      text-align: center;
    }

    .timer-display {
      font-size: 3rem;
      font-weight: 700;
      font-variant-numeric: tabular-nums;
      color: var(--mat-sys-on-primary-container);
      letter-spacing: 2px;
      margin: 0 0 8px;
    }

    .timer-status {
      font-size: 0.875rem;
      color: var(--mat-sys-on-primary-container);
      opacity: 0.7;
      margin: 0 0 20px;
    }

    .timer-actions {
      display: flex;
      gap: 12px;
      justify-content: center;
      flex-wrap: wrap;
    }

    .idle-card {
      border: 2px dashed var(--mat-sys-outline-variant);
      border-radius: 16px;
      padding: 24px;
      text-align: center;
      display: flex;
      flex-direction: column;
      align-items: center;
      gap: 16px;

      p {
        margin: 0;
        color: var(--mat-sys-on-surface-variant);
        font-size: 0.9rem;
      }
    }
  `],
  template: `
    @if (activeSession()) {
      <div class="timer-card">
        <p class="timer-display">{{ display() }}</p>
        <p class="timer-status">
          {{ activeSession()!.isPaused
              ? ('timer.paused' | translate)
              : ('timer.running' | translate) }}
        </p>
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
            @if (busy()) {
              <mat-spinner diameter="18" />
            } @else {
              <ng-container>
                <mat-icon>stop</mat-icon>
                {{ 'timer.stop' | translate }}
              </ng-container>
            }
          </button>
        </div>
      </div>
    } @else {
      <div class="idle-card">
        <mat-icon style="font-size:40px;width:40px;height:40px;color:var(--mat-sys-primary)">timer</mat-icon>
        <p>{{ 'timer.noActiveSession' | translate }}</p>
        <button mat-flat-button (click)="start()" [disabled]="busy()">
          @if (busy()) {
            <mat-spinner diameter="18" />
          } @else {
            <ng-container>
              <mat-icon>play_arrow</mat-icon>
              {{ 'timer.start' | translate }}
            </ng-container>
          }
        </button>
      </div>
    }
  `,
})
export class LiveTimerComponent implements OnInit, OnDestroy {
  private sessionService = inject(WorkSessionService);
  private toast = inject(ToastService);

  readonly activeSession = toSignal(this.sessionService.activeSession$, { initialValue: null });
  readonly busy = signal(false);
  readonly display = signal('00:00:00');

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

  async start(): Promise<void> {
    this.busy.set(true);
    try {
      await this.sessionService.startSession();
    } catch {
      this.toast.error('common.error');
    } finally {
      this.busy.set(false);
    }
  }

  async stop(): Promise<void> {
    const s = this.activeSession();
    if (!s) return;
    this.busy.set(true);
    try {
      await this.sessionService.stopSession(s.id);
      this.display.set('00:00:00');
    } catch {
      this.toast.error('common.error');
    } finally {
      this.busy.set(false);
    }
  }

  async pause(): Promise<void> {
    const s = this.activeSession();
    if (!s) return;
    this.busy.set(true);
    try {
      await this.sessionService.pauseSession(s.id);
    } catch {
      this.toast.error('common.error');
    } finally {
      this.busy.set(false);
    }
  }

  async resume(): Promise<void> {
    const s = this.activeSession();
    if (!s?.pauseStartTime) return;
    this.busy.set(true);
    try {
      await this.sessionService.resumeSession(s.id, s.pauseStartTime);
    } catch {
      this.toast.error('common.error');
    } finally {
      this.busy.set(false);
    }
  }
}
