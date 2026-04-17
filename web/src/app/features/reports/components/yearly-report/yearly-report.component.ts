import {
  ChangeDetectionStrategy,
  Component,
  inject,
  signal,
} from '@angular/core';
import { toSignal, toObservable } from '@angular/core/rxjs-interop';
import { switchMap } from 'rxjs';
import { MatCardModule } from '@angular/material/card';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatDividerModule } from '@angular/material/divider';
import { TranslateModule } from '@ngx-translate/core';
import { ReportService } from '../../services/report.service';
import { DurationPipe } from '../../../../shared/pipes/duration.pipe';
import { OvertimePipe } from '../../../../shared/pipes/overtime.pipe';

const MONTH_NAMES = [
  'Jan', 'Feb', 'Mär', 'Apr', 'Mai', 'Jun',
  'Jul', 'Aug', 'Sep', 'Okt', 'Nov', 'Dez',
];

@Component({
  selector: 'wtm-yearly-report',
  standalone: true,
  imports: [
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

    .year-nav {
      display: flex;
      align-items: center;
      gap: 8px;
      margin-bottom: 20px;
      span { flex: 1; text-align: center; font-weight: 700; font-size: 1.1rem; }
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

    .chart-grid {
      display: grid;
      grid-template-columns: repeat(2, 1fr);
      gap: 8px;
    }

    .month-bar-item {
      display: flex;
      align-items: center;
      gap: 8px;

      .month-name {
        width: 32px;
        font-size: 0.8rem;
        color: var(--mat-sys-on-surface-variant);
        flex-shrink: 0;
      }

      .bar-wrap {
        flex: 1;
        height: 20px;
        background: var(--mat-sys-surface-container-high);
        border-radius: 4px;
        overflow: hidden;
        position: relative;
      }

      .bar-fill {
        height: 100%;
        border-radius: 4px;
        background: var(--mat-sys-primary);
        transition: width 0.4s ease;
        &.over { background: #2e7d32; }
        &.empty { background: transparent; }
      }

      .bar-label {
        position: absolute;
        right: 4px;
        top: 50%;
        transform: translateY(-50%);
        font-size: 0.7rem;
        color: var(--mat-sys-on-surface-variant);
        white-space: nowrap;
      }

      .month-value {
        width: 64px;
        text-align: right;
        font-size: 0.8rem;
        font-weight: 600;
        flex-shrink: 0;
      }
    }

    .empty-state {
      text-align: center;
      padding: 40px;
      color: var(--mat-sys-on-surface-variant);
    }
  `],
  template: `
    <div class="page-header">
      <h1>{{ 'reports.yearly' | translate }}</h1>
    </div>

    <div class="year-nav">
      <button mat-icon-button (click)="prevYear()">
        <mat-icon>chevron_left</mat-icon>
      </button>
      <span>{{ selectedYear() }}</span>
      <button mat-icon-button (click)="nextYear()" [disabled]="selectedYear() >= currentYear">
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

      @if (maxMonthMinutes(r.monthlyReports) === 0) {
        <div class="empty-state">{{ 'reports.noData' | translate }}</div>
      } @else {
        <mat-card appearance="outlined">
          <mat-card-content>
            <div class="chart-grid">
              @for (month of r.monthlyReports; track month.month.getMonth()) {
                <div class="month-bar-item">
                  <span class="month-name">{{ monthName(month.month.getMonth()) }}</span>
                  <div class="bar-wrap">
                    <div
                      class="bar-fill"
                      [class.over]="month.totalMinutes >= month.targetMinutes"
                      [class.empty]="month.totalMinutes === 0"
                      [style.width.%]="barWidth(month.totalMinutes, maxMonthMinutes(r.monthlyReports))"
                    ></div>
                  </div>
                  <span class="month-value">{{ month.totalMinutes | duration }}</span>
                </div>
              }
            </div>
          </mat-card-content>
        </mat-card>
      }
    }
  `,
})
export class YearlyReportComponent {
  private reportService = inject(ReportService);

  readonly currentYear = new Date().getFullYear();
  readonly selectedYear = signal(this.currentYear);

  readonly report = toSignal(
    toObservable(this.selectedYear).pipe(
      switchMap(y => this.reportService.getYearlyReport(y))
    ),
    { initialValue: null }
  );

  prevYear(): void {
    this.selectedYear.update(y => y - 1);
  }

  nextYear(): void {
    if (this.selectedYear() >= this.currentYear) return;
    this.selectedYear.update(y => y + 1);
  }

  monthName(index: number): string {
    return MONTH_NAMES[index] ?? '';
  }

  maxMonthMinutes(months: { totalMinutes: number }[]): number {
    return Math.max(...months.map(m => m.totalMinutes), 0);
  }

  barWidth(worked: number, max: number): number {
    if (max === 0) return 0;
    return Math.min(100, Math.round((worked / max) * 100));
  }
}
