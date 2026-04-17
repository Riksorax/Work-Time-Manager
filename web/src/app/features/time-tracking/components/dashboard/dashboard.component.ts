import { ChangeDetectionStrategy, Component, inject, computed } from '@angular/core';
import { DatePipe } from '@angular/common';
import { RouterLink } from '@angular/router';
import { toSignal } from '@angular/core/rxjs-interop';
import { MatCardModule } from '@angular/material/card';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatDividerModule } from '@angular/material/divider';
import { TranslateModule } from '@ngx-translate/core';
import { WorkSessionService } from '../../services/work-session.service';
import { UserProfileService } from '../../../settings/services/user-profile.service';
import { LiveTimerComponent } from '../live-timer/live-timer.component';
import { DurationPipe } from '../../../../shared/pipes/duration.pipe';
import { OvertimePipe } from '../../../../shared/pipes/overtime.pipe';
import { WorkSession } from '../../../../shared/models';
import {
  calculateDailyTotal,
  calculateNetMinutes,
  calculateOvertimeMinutes,
} from '../../utils/time-calculations.util';

@Component({
  selector: 'wtm-dashboard',
  standalone: true,
  imports: [
    DatePipe,
    RouterLink,
    MatCardModule,
    MatButtonModule,
    MatIconModule,
    MatDividerModule,
    TranslateModule,
    LiveTimerComponent,
    DurationPipe,
    OvertimePipe,
  ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  styles: [`
    :host { display: block; padding: 16px; max-width: 800px; margin: 0 auto; }

    h1 { margin: 0 0 20px; font-size: 1.5rem; font-weight: 700; }

    .stats-row {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(160px, 1fr));
      gap: 12px;
      margin: 20px 0;
    }

    .stat-card {
      text-align: center;

      .stat-value { font-size: 1.5rem; font-weight: 700; color: var(--mat-sys-primary); }
      .stat-label { font-size: 0.8rem; color: var(--mat-sys-on-surface-variant); margin-top: 4px; }

      &.overtime .stat-value { color: #c62828; }
      &.overtime.positive .stat-value { color: #2e7d32; }
    }

    .section-header {
      display: flex;
      align-items: center;
      justify-content: space-between;
      margin: 24px 0 12px;
      h2 { margin: 0; font-size: 1rem; font-weight: 600; }
    }

    .session-item {
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 12px 0;

      .session-meta { display: flex; flex-direction: column; gap: 2px; }
      .session-time { font-size: 0.8rem; color: var(--mat-sys-on-surface-variant); }
      .session-note { font-size: 0.85rem; color: var(--mat-sys-on-surface-variant); }
      .session-duration { font-weight: 600; color: var(--mat-sys-primary); }
    }

    .empty-state {
      text-align: center;
      padding: 24px;
      color: var(--mat-sys-on-surface-variant);
      font-size: 0.875rem;
    }
  `],
  template: `
    <h1>{{ 'dashboard.title' | translate }}</h1>

    <wtm-live-timer />

    <div class="stats-row">
      <mat-card appearance="outlined" class="stat-card">
        <mat-card-content>
          <div class="stat-value">{{ todayMinutes() | duration }}</div>
          <div class="stat-label">{{ 'dashboard.todayTotal' | translate }}</div>
        </mat-card-content>
      </mat-card>

      <mat-card appearance="outlined" class="stat-card">
        <mat-card-content>
          <div class="stat-value">{{ weekMinutes() | duration }}</div>
          <div class="stat-label">{{ 'dashboard.weekTotal' | translate }}</div>
        </mat-card-content>
      </mat-card>

      <mat-card
        appearance="outlined"
        class="stat-card overtime"
        [class.positive]="weekOvertime() >= 0"
      >
        <mat-card-content>
          <div class="stat-value">{{ weekOvertime() | overtime }}</div>
          <div class="stat-label">
            {{ weekOvertime() >= 0
                ? ('common.overtime' | translate)
                : ('common.undertime' | translate) }}
          </div>
        </mat-card-content>
      </mat-card>
    </div>

    <div class="section-header">
      <h2>{{ 'dashboard.recentSessions' | translate }}</h2>
      <a mat-button routerLink="/time-tracking">
        <mat-icon>arrow_forward</mat-icon>
        Alle anzeigen
      </a>
    </div>

    <mat-card appearance="outlined">
      <mat-card-content>
        @if (todaySessions().length === 0) {
          <div class="empty-state">{{ 'sessions.noSessions' | translate }}</div>
        } @else {
          @for (session of todaySessions(); track session.id; let last = $last) {
            <div class="session-item">
              <div class="session-meta">
                <span class="session-time">
                  {{ session.startTime.toDate() | date:'HH:mm' }}
                  @if (session.endTime) {
                    – {{ session.endTime.toDate() | date:'HH:mm' }}
                  } @else {
                    <span style="color:var(--mat-sys-primary)"> ● läuft</span>
                  }
                </span>
                @if (session.note) {
                  <span class="session-note">{{ session.note }}</span>
                }
              </div>
              <span class="session-duration">{{ netMinutes(session) | duration }}</span>
            </div>
            @if (!last) { <mat-divider /> }
          }
        }
      </mat-card-content>
    </mat-card>
  `,
})
export class DashboardComponent {
  private sessionService = inject(WorkSessionService);
  private profileService = inject(UserProfileService);

  readonly todaySessions = toSignal(
    this.sessionService.getSessionsForDay(new Date()),
    { initialValue: [] }
  );

  readonly weekSessions = toSignal(
    this.sessionService.getSessionsForWeek(new Date()),
    { initialValue: [] }
  );

  readonly todayMinutes = computed(() => calculateDailyTotal(this.todaySessions()));
  readonly weekMinutes = computed(() => calculateDailyTotal(this.weekSessions()));

  readonly weekOvertime = computed(() => {
    const targetMinutes = (this.profileService.profile()?.weeklyTargetHours ?? 40) * 60;
    return calculateOvertimeMinutes(this.weekMinutes(), targetMinutes);
  });

  netMinutes(session: WorkSession): number {
    return calculateNetMinutes(session);
  }
}
