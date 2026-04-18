import { Component, inject, signal, computed } from '@angular/core';
import { CommonModule } from '@angular/common';
import { MatCardModule } from '@angular/material/card';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatTableModule } from '@angular/material/table';
import { ReportService } from '../../services/report.service';
import { toSignal } from '@angular/core/rxjs-interop';
import { DurationPipe } from '../../../../shared/pipes/duration.pipe';
import { OvertimePipe } from '../../../../shared/pipes/overtime.pipe';
import { format, addWeeks, subWeeks, startOfWeek, endOfWeek } from 'date-fns';
import { BaseChartDirective } from 'ng2-charts';
import { ChartConfiguration } from 'chart.js';

@Component({
  selector: 'app-reports-overview',
  standalone: true,
  imports: [
    CommonModule, 
    MatCardModule, 
    MatButtonModule, 
    MatIconModule, 
    MatTableModule,
    DurationPipe,
    OvertimePipe,
    BaseChartDirective
  ],
  template: `
    <div class="reports-container">
      <mat-card class="header-card">
        <div class="week-selector">
          <button mat-icon-button (click)="previousWeek()">
            <mat-icon>chevron_left</mat-icon>
          </button>
          <h2>KW {{ currentWeekNumber() }}, {{ weekRange() }}</h2>
          <button mat-icon-button (click)="nextWeek()" [disabled]="isFutureWeek()">
            <mat-icon>chevron_right</mat-icon>
          </button>
        </div>
      </mat-card>

      @if (report(); as r) {
        <div class="stats-grid">
          <mat-card>
            <mat-card-header><mat-card-subtitle>Gesamt</mat-card-subtitle></mat-card-header>
            <mat-card-content>
              <div class="stat-value">{{ r.totalWorkedMinutes | duration }}</div>
            </mat-card-content>
          </mat-card>
          <mat-card>
            <mat-card-header><mat-card-subtitle>Soll</mat-card-subtitle></mat-card-header>
            <mat-card-content>
              <div class="stat-value">{{ r.totalTargetMinutes | duration }}</div>
            </mat-card-content>
          </mat-card>
          <mat-card>
            <mat-card-header><mat-card-subtitle>Überstunden</mat-card-subtitle></mat-card-header>
            <mat-card-content>
              <div class="stat-value" [class.negative]="r.overtimeMinutes < 0">
                {{ r.overtimeMinutes | overtime }}
              </div>
            </mat-card-content>
          </mat-card>
        </div>

        <mat-card class="chart-card">
          <mat-card-content>
            <div style="display: block; height: 300px;">
              <canvas baseChart
                [data]="barChartData()"
                [options]="barChartOptions"
                [type]="'bar'">
              </canvas>
            </div>
          </mat-card-content>
        </mat-card>

        <mat-card class="table-card">
          <table mat-table [dataSource]="r.dailyReports">
            <ng-container matColumnDef="date">
              <th mat-header-cell *mat-header-cellDef> Datum </th>
              <td mat-cell *mat-cellDef="let day"> {{ day.date | date:'EEE, dd.MM.' }} </td>
            </ng-container>
            <ng-container matColumnDef="worked">
              <th mat-header-cell *mat-header-cellDef> Ist </th>
              <td mat-cell *mat-cellDef="let day"> {{ day.workedMinutes | duration }} </td>
            </ng-container>
            <ng-container matColumnDef="overtime">
              <th mat-header-cell *mat-header-cellDef> +/- </th>
              <td mat-cell *mat-cellDef="let day" [class.negative]="day.overtimeMinutes < 0"> 
                {{ day.overtimeMinutes | overtime }} 
              </td>
            </ng-container>

            <tr mat-header-row *mat-header-rowDef="displayedColumns"></tr>
            <tr mat-row *mat-rowDef="let row; columns: displayedColumns;"></tr>
          </table>
        </mat-card>
      } @else {
        <div class="loading">Berichte werden geladen...</div>
      }
    </div>
  `,
  styles: `
    .reports-container { display: flex; flex-direction: column; gap: 1rem; }
    .header-card { padding: 0.5rem; }
    .week-selector { display: flex; align-items: center; justify-content: center; gap: 2rem; }
    .stats-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 1rem; }
    @media (max-width: 600px) { .stats-grid { grid-template-columns: 1fr; } }
    .stat-value { font-size: 1.5rem; font-weight: 500; }
    .stat-value.negative, .negative { color: #f44336; }
    .chart-card { padding: 1rem; }
    .table-card { overflow-x: auto; }
    table { width: 100%; }
    .loading { text-align: center; padding: 3rem; }
  `
})
export class ReportsOverviewComponent {
  private reportService = inject(ReportService);
  
  selectedDate = signal(new Date());
  
  report = computed(() => {
    return toSignal(this.reportService.getWeeklyReport(this.selectedDate()))();
  });

  displayedColumns: string[] = ['date', 'worked', 'overtime'];

  currentWeekNumber = computed(() => format(this.selectedDate(), 'w'));
  weekRange = computed(() => {
    const start = startOfWeek(this.selectedDate(), { weekStartsOn: 1 });
    const end = endOfWeek(this.selectedDate(), { weekStartsOn: 1 });
    return `${format(start, 'dd.MM.')} - ${format(end, 'dd.MM.yyyy')}`;
  });

  isFutureWeek = computed(() => {
    const next = addWeeks(this.selectedDate(), 1);
    return next > new Date();
  });

  barChartOptions: ChartConfiguration['options'] = {
    responsive: true,
    maintainAspectRatio: false,
    scales: {
      y: { beginAtZero: true, title: { display: true, text: 'Minuten' } }
    },
    plugins: {
      legend: { display: false }
    }
  };

  barChartData = computed<ChartConfiguration['data']>(() => {
    const r = this.report();
    if (!r) return { labels: [], datasets: [] };

    return {
      labels: r.dailyReports.map((d: any) => format(d.date, 'EEE')),
      datasets: [
        {
          data: r.dailyReports.map((d: any) => d.workedMinutes),
          backgroundColor: '#3f51b5',
          borderRadius: 4
        }
      ]
    };
  });

  previousWeek() {
    this.selectedDate.update(d => subWeeks(d, 1));
  }

  nextWeek() {
    this.selectedDate.update(d => addWeeks(d, 1));
  }
}
