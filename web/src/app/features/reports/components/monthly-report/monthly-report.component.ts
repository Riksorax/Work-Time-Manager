import {
  ChangeDetectionStrategy,
  Component,
  inject,
  signal,
} from '@angular/core';
import { DatePipe } from '@angular/common';
import { toSignal } from '@angular/core/rxjs-interop';
import { switchMap } from 'rxjs';
import { toObservable } from '@angular/core/rxjs-interop';
import { MatCardModule } from '@angular/material/card';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatDividerModule } from '@angular/material/divider';
import { TranslateModule } from '@ngx-translate/core';
import { ReportService } from '../../services/report.service';
import { DurationPipe } from '../../../../shared/pipes/duration.pipe';
import { OvertimePipe } from '../../../../shared/pipes/overtime.pipe';

@Component({
  selector: 'wtm-monthly-report',
  standalone: true,
  imports: [
    DatePipe,
    MatCardModule,
    MatButtonModule,
    MatIconModule,
    MatDividerModule,
    TranslateModule,
    DurationPipe,
    OvertimePipe,
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

    .month-nav {
      display: flex;
      align-items: center;
      gap: 8px;
      margin-bottom: 20px;
      span { flex: 1; text-align: center; font-weight: 600; font-size: 0.95rem; }
    }

    .summary-row {
      display: grid;
      grid-template-columns: repeat(3, 1fr);
      gap: 12px;
      margin-bottom: 20px;
    }

    .stat-card {
      text-align: center;
      .stat-value { font-size: 1.25rem; font-weight: 700; color: var(--mat-sys-primary); }
      .stat-label { font-size: 0.75rem; color: var(--mat-sys-on-surface-variant); margin-top: 4px; }
      &.overtime .stat-value { color: #c62828; }
      &.overtime.positive .stat-value { color: #2e7d32; }
    }

    .week-row {
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 12px 0;

      .week-label { font-size: 0.85rem; color: var(--mat-sys-on-surface-variant); }
      .week-bar-wrap {
        flex: 1;
        margin: 0 12px;
        height: 8px;
        background: var(--mat-sys-surface-container-high);
        border-radius: 4px;
        overflow: hidden;
      }
      .week-bar {
        height: 100%;
        border-radius: 4px;
        background: var(--mat-sys-primary);
        transition: width 0.3s ease;
        &.over { background: #2e7d32; }
      }
      .week-value { width: 80px; text-align: right; font-size: 0.875rem; font-weight: 600; }
    }

    .empty-state {
      text-align: center;
      padding: 40px;
      color: var(--mat-sys-on-surface-variant);
    }
  `],
  template: `
    <div class="page-header">
      <h1>{{ 'reports.monthly' | translate }}</h1>
    </div>

    <div class="month-nav">
      <button mat-icon-button (click)="prevMonth()">
        <mat-icon>chevron_left</mat-icon>
      </button>
      <span>{{ selectedMonth() | date:'MMMM yyyy' }}</span>
      <button mat-icon-button (click)="nextMonth()" [disabled]="isCurrentMonth()">
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
            <div class="stat-label">Soll</div>
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
              {{ r.overtimeMinutes >= 0 ? ('common.overtime' | translate) : ('common.undertime' | translate) }}
            </div>
          </mat-card-content>
        </mat-card>
      </div>

      @if (r.weeklyReports.length === 0) {
        <div class="empty-state">{{ 'reports.noData' | translate }}</div>
      } @else {
        <mat-card appearance="outlined">
          <mat-card-content>
            @for (week of r.weeklyReports; track week.weekStart.getTime(); let last = $last) {
              <div class="week-row">
                <span class="week-label">
                  {{ week.weekStart | date:'d. MMM' }} – {{ week.weekEnd | date:'d. MMM' }}
                </span>
                <div class="week-bar-wrap">
                  <div
                    class="week-bar"
                    [class.over]="week.totalMinutes >= week.targetMinutes"
                    [style.width.%]="barWidth(week.totalMinutes, week.targetMinutes)"
                  ></div>
                </div>
                <span class="week-value">{{ week.totalMinutes | duration }}</span>
              </div>
              @if (!last) { <mat-divider /> }
            }
          </mat-card-content>
        </mat-card>
      }
    }
  `,
})
export class MonthlyReportComponent {
  private reportService = inject(ReportService);

  readonly selectedMonth = signal(new Date());

  readonly report = toSignal(
    toObservable(this.selectedMonth).pipe(
      switchMap(d => this.reportService.getMonthlyReport(d))
    ),
    { initialValue: null }
  );

  isCurrentMonth(): boolean {
    const now = new Date();
    const sel = this.selectedMonth();
    return sel.getFullYear() === now.getFullYear() && sel.getMonth() === now.getMonth();
  }

  prevMonth(): void {
    const d = new Date(this.selectedMonth());
    d.setMonth(d.getMonth() - 1);
    this.selectedMonth.set(d);
  }

  nextMonth(): void {
    if (this.isCurrentMonth()) return;
    const d = new Date(this.selectedMonth());
    d.setMonth(d.getMonth() + 1);
    this.selectedMonth.set(d);
  }

  barWidth(worked: number, target: number): number {
    if (target === 0) return 0;
    return Math.min(100, Math.round((worked / target) * 100));
  }
}
