import {
  ChangeDetectionStrategy,
  Component,
  inject,
  signal,
  computed,
} from '@angular/core';
import { DatePipe } from '@angular/common';
import { RouterLink } from '@angular/router';
import { toSignal } from '@angular/core/rxjs-interop';
import { MatCardModule } from '@angular/material/card';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatDividerModule } from '@angular/material/divider';
import { TranslateModule } from '@ngx-translate/core';
import { ReportService } from '../../services/report.service';
import { PremiumService } from '../../../premium/services/premium.service';
import { DurationPipe } from '../../../../shared/pipes/duration.pipe';
import { OvertimePipe } from '../../../../shared/pipes/overtime.pipe';
import { PremiumGateComponent } from '../../../../shared/components/premium-gate/premium-gate.component';

@Component({
  selector: 'wtm-reports-overview',
  standalone: true,
  imports: [
    DatePipe,
    RouterLink,
    MatCardModule,
    MatButtonModule,
    MatIconModule,
    MatDividerModule,
    TranslateModule,
    DurationPipe,
    OvertimePipe,
    PremiumGateComponent,
  ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  styles: [`
    :host { display: block; padding: 16px; max-width: 800px; margin: 0 auto; }

    h1 { margin: 0 0 20px; font-size: 1.5rem; font-weight: 700; }

    .week-nav {
      display: flex;
      align-items: center;
      gap: 8px;
      margin-bottom: 20px;

      span {
        flex: 1;
        text-align: center;
        font-weight: 600;
        font-size: 0.95rem;
      }
    }

    .summary-row {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
      gap: 12px;
      margin-bottom: 20px;
    }

    .stat-card {
      text-align: center;
      .stat-value { font-size: 1.4rem; font-weight: 700; color: var(--mat-sys-primary); }
      .stat-label { font-size: 0.8rem; color: var(--mat-sys-on-surface-variant); margin-top: 4px; }
      &.overtime .stat-value { color: #c62828; }
      &.overtime.positive .stat-value { color: #2e7d32; }
    }

    .day-row {
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 10px 0;

      .day-label {
        width: 80px;
        font-size: 0.875rem;
        color: var(--mat-sys-on-surface-variant);
        &.today { font-weight: 700; color: var(--mat-sys-primary); }
      }

      .day-bar-wrap {
        flex: 1;
        margin: 0 12px;
        height: 8px;
        background: var(--mat-sys-surface-container-high);
        border-radius: 4px;
        overflow: hidden;
      }

      .day-bar {
        height: 100%;
        border-radius: 4px;
        background: var(--mat-sys-primary);
        transition: width 0.3s ease;
        &.over { background: #2e7d32; }
        &.under { background: var(--mat-sys-primary); }
      }

      .day-value {
        width: 80px;
        text-align: right;
        font-size: 0.875rem;
        font-weight: 600;
      }
    }

    .premium-links {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 12px;
      margin-top: 20px;

      a {
        display: flex;
        align-items: center;
        gap: 8px;
        justify-content: center;
      }
    }
  `],
  template: `
    <h1>{{ 'reports.title' | translate }}</h1>

    <div class="week-nav">
      <button mat-icon-button (click)="prevWeek()">
        <mat-icon>chevron_left</mat-icon>
      </button>
      <span>
        {{ report()?.weekStart | date:'d. MMM' }} –
        {{ report()?.weekEnd | date:'d. MMM yyyy' }}
      </span>
      <button mat-icon-button (click)="nextWeek()" [disabled]="isCurrentWeek()">
        <mat-icon>chevron_right</mat-icon>
      </button>
    </div>

    @if (report(); as r) {
      <div class="summary-row">
        <mat-card appearance="outlined" class="stat-card">
          <mat-card-content>
            <div class="stat-value">{{ r.totalMinutes | duration }}</div>
            <div class="stat-label">Gearbeitet</div>
          </mat-card-content>
        </mat-card>

        <mat-card appearance="outlined" class="stat-card">
          <mat-card-content>
            <div class="stat-value">{{ r.targetMinutes | duration }}</div>
            <div class="stat-label">{{ 'dashboard.weekTarget' | translate }}</div>
          </mat-card-content>
        </mat-card>

        <mat-card
          appearance="outlined"
          class="stat-card overtime"
          [class.positive]="r.overtimeMinutes >= 0"
        >
          <mat-card-content>
            <div class="stat-value">{{ r.overtimeMinutes | overtime }}</div>
            <div class="stat-label">
              {{ r.overtimeMinutes >= 0
                  ? ('common.overtime' | translate)
                  : ('common.undertime' | translate) }}
            </div>
          </mat-card-content>
        </mat-card>
      </div>

      <mat-card appearance="outlined">
        <mat-card-content>
          @for (day of r.dailyReports; track day.date.getTime()) {
            <div class="day-row">
              <span class="day-label" [class.today]="isToday(day.date)">
                {{ day.date | date:'EEE' }}
              </span>
              <div class="day-bar-wrap">
                <div
                  class="day-bar"
                  [class.over]="day.totalMinutes >= day.targetMinutes"
                  [style.width.%]="barWidth(day.totalMinutes, day.targetMinutes)"
                ></div>
              </div>
              <span class="day-value">{{ day.totalMinutes | duration }}</span>
            </div>
            <mat-divider />
          }
        </mat-card-content>
      </mat-card>

      @if (isPremium()) {
        <div class="premium-links">
          <a mat-stroked-button routerLink="/reports/monthly">
            <mat-icon>calendar_month</mat-icon>
            {{ 'reports.monthly' | translate }}
          </a>
          <a mat-stroked-button routerLink="/reports/yearly">
            <mat-icon>bar_chart</mat-icon>
            {{ 'reports.yearly' | translate }}
          </a>
        </div>
      } @else {
        <wtm-premium-gate message="Monats- und Jahresberichte sind ein Premium-Feature." />
      }
    }
  `,
})
export class ReportsOverviewComponent {
  private reportService = inject(ReportService);
  private premiumService = inject(PremiumService);

  readonly selectedWeek = signal(new Date());
  readonly isPremium = this.premiumService.isPremium;

  readonly report = toSignal(
    this.reportService.getWeeklyReport(new Date()),
    { initialValue: null }
  );

  isCurrentWeek(): boolean {
    const now = new Date();
    const start = new Date(this.selectedWeek());
    const day = start.getDay();
    const diff = day === 0 ? -6 : 1 - day;
    start.setDate(start.getDate() + diff);
    start.setHours(0, 0, 0, 0);
    const nowStart = new Date(now);
    const nowDay = nowStart.getDay();
    const nowDiff = nowDay === 0 ? -6 : 1 - nowDay;
    nowStart.setDate(nowStart.getDate() + nowDiff);
    nowStart.setHours(0, 0, 0, 0);
    return start.getTime() === nowStart.getTime();
  }

  isToday(date: Date): boolean {
    const now = new Date();
    return date.getFullYear() === now.getFullYear() &&
      date.getMonth() === now.getMonth() &&
      date.getDate() === now.getDate();
  }

  prevWeek(): void {
    const d = new Date(this.selectedWeek());
    d.setDate(d.getDate() - 7);
    this.selectedWeek.set(d);
  }

  nextWeek(): void {
    const d = new Date(this.selectedWeek());
    d.setDate(d.getDate() + 7);
    this.selectedWeek.set(d);
  }

  barWidth(worked: number, target: number): number {
    if (target === 0) return 0;
    return Math.min(100, Math.round((worked / target) * 100));
  }
}
