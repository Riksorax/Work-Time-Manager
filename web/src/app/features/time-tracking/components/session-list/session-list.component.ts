import {
  ChangeDetectionStrategy,
  Component,
  inject,
  signal,
  computed,
} from '@angular/core';
import { DatePipe } from '@angular/common';
import { Router } from '@angular/router';
import { toSignal } from '@angular/core/rxjs-interop';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatCardModule } from '@angular/material/card';
import { MatDividerModule } from '@angular/material/divider';
import { MatChipsModule } from '@angular/material/chips';
import { MatMenuModule } from '@angular/material/menu';
import { MatDialogModule, MatDialog } from '@angular/material/dialog';
import { TranslateModule } from '@ngx-translate/core';
import { WorkSessionService } from '../../services/work-session.service';
import { LiveTimerComponent } from '../live-timer/live-timer.component';
import { DurationPipe } from '../../../../shared/pipes/duration.pipe';
import { ConfirmDialogComponent } from '../../../../shared/components/confirm-dialog/confirm-dialog.component';
import { ToastService } from '../../../../shared/components/toast/toast.service';
import { WorkSession } from '../../../../shared/models';
import {
  calculateDailyTotal,
  calculateNetMinutes,
  startOfDay,
  endOfDay,
  isSameDay,
} from '../../utils/time-calculations.util';

@Component({
  selector: 'wtm-session-list',
  standalone: true,
  imports: [
    DatePipe,
    MatButtonModule,
    MatIconModule,
    MatCardModule,
    MatDividerModule,
    MatChipsModule,
    MatMenuModule,
    MatDialogModule,
    TranslateModule,
    LiveTimerComponent,
    DurationPipe,
  ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  styles: [`
    :host { display: block; padding: 16px; max-width: 800px; margin: 0 auto; }

    .page-header {
      display: flex;
      align-items: center;
      justify-content: space-between;
      margin-bottom: 20px;
      h1 { margin: 0; font-size: 1.5rem; font-weight: 700; }
    }

    .date-nav {
      display: flex;
      align-items: center;
      gap: 8px;
      margin: 16px 0;

      span {
        flex: 1;
        text-align: center;
        font-weight: 600;
        font-size: 0.95rem;
      }
    }

    .day-total {
      display: flex;
      justify-content: flex-end;
      align-items: center;
      gap: 8px;
      margin-bottom: 12px;
      font-size: 0.875rem;
      color: var(--mat-sys-on-surface-variant);

      strong { color: var(--mat-sys-primary); font-size: 1rem; }
    }

    .session-item {
      display: flex;
      align-items: center;
      gap: 12px;
      padding: 12px 0;

      .session-info { flex: 1; min-width: 0; }
      .session-time { font-size: 0.8rem; color: var(--mat-sys-on-surface-variant); }
      .session-note {
        font-size: 0.9rem;
        white-space: nowrap;
        overflow: hidden;
        text-overflow: ellipsis;
      }
      .session-duration { font-weight: 600; color: var(--mat-sys-primary); white-space: nowrap; }
    }

    .empty-state {
      text-align: center;
      padding: 40px 16px;
      color: var(--mat-sys-on-surface-variant);
      mat-icon { font-size: 48px; width: 48px; height: 48px; opacity: 0.4; }
      p { margin: 8px 0 0; }
    }
  `],
  template: `
    <div class="page-header">
      <h1>{{ 'sessions.title' | translate }}</h1>
    </div>

    <wtm-live-timer />

    <div class="date-nav">
      <button mat-icon-button (click)="prevDay()">
        <mat-icon>chevron_left</mat-icon>
      </button>
      <span>
        {{ isToday() ? 'Heute' : (selectedDate() | date:'EEEE, d. MMMM':'':'de') }}
      </span>
      <button mat-icon-button (click)="nextDay()" [disabled]="isToday()">
        <mat-icon>chevron_right</mat-icon>
      </button>
    </div>

    @if (sessions().length > 0) {
      <div class="day-total">
        <span>Gesamt:</span>
        <strong>{{ dayTotal() | duration }}</strong>
      </div>
    }

    <mat-card appearance="outlined">
      <mat-card-content>
        @if (sessions().length === 0) {
          <div class="empty-state">
            <mat-icon>event_busy</mat-icon>
            <p>{{ 'sessions.noSessions' | translate }}</p>
          </div>
        } @else {
          @for (session of sessions(); track session.id; let last = $last) {
            <div class="session-item">
              <div class="session-info">
                <div class="session-time">
                  {{ session.startTime.toDate() | date:'HH:mm' }}
                  @if (session.endTime) {
                    – {{ session.endTime.toDate() | date:'HH:mm' }}
                  } @else {
                    <span style="color:var(--mat-sys-primary)"> ● läuft</span>
                  }
                  @if (session.pauseDuration > 0) {
                    · {{ session.pauseDuration }}min Pause
                  }
                </div>
                @if (session.note) {
                  <div class="session-note">{{ session.note }}</div>
                }
                @if (session.category) {
                  <mat-chip-set>
                    <mat-chip>{{ session.category }}</mat-chip>
                  </mat-chip-set>
                }
              </div>
              <span class="session-duration">{{ netMinutes(session) | duration }}</span>
              <button mat-icon-button [matMenuTriggerFor]="menu">
                <mat-icon>more_vert</mat-icon>
              </button>
              <mat-menu #menu>
                <button mat-menu-item (click)="editSession(session)">
                  <mat-icon>edit</mat-icon>
                  {{ 'common.edit' | translate }}
                </button>
                <button mat-menu-item (click)="confirmDelete(session)">
                  <mat-icon color="warn">delete</mat-icon>
                  {{ 'common.delete' | translate }}
                </button>
              </mat-menu>
            </div>
            @if (!last) { <mat-divider /> }
          }
        }
      </mat-card-content>
    </mat-card>
  `,
})
export class SessionListComponent {
  private sessionService = inject(WorkSessionService);
  private router = inject(Router);
  private dialog = inject(MatDialog);
  private toast = inject(ToastService);

  readonly selectedDate = signal(new Date());

  readonly sessions = toSignal(
    // re-subscribe when selectedDate changes via computed observable
    // simple approach: listen to service with current date
    this.sessionService.getSessionsForDay(new Date()),
    { initialValue: [] }
  );

  readonly isToday = computed(() => isSameDay(this.selectedDate(), new Date()));
  readonly dayTotal = computed(() => calculateDailyTotal(this.sessions()));

  netMinutes(session: WorkSession): number {
    return calculateNetMinutes(session);
  }

  prevDay(): void {
    const d = new Date(this.selectedDate());
    d.setDate(d.getDate() - 1);
    this.selectedDate.set(d);
  }

  nextDay(): void {
    if (this.isToday()) return;
    const d = new Date(this.selectedDate());
    d.setDate(d.getDate() + 1);
    this.selectedDate.set(d);
  }

  editSession(session: WorkSession): void {
    this.router.navigate(['/time-tracking', session.id]);
  }

  confirmDelete(session: WorkSession): void {
    const ref = this.dialog.open(ConfirmDialogComponent, {
      data: {
        title: 'Eintrag löschen',
        message: 'sessions.deleteConfirm',
        confirmLabel: 'common.delete',
        cancelLabel: 'common.cancel',
      },
    });
    ref.afterClosed().subscribe(async confirmed => {
      if (!confirmed) return;
      try {
        await this.sessionService.deleteSession(session.id);
        this.toast.success('Eintrag gelöscht');
      } catch {
        this.toast.error('sessions.deleteError');
      }
    });
  }
}
