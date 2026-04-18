import { Component, inject, signal, computed, OnDestroy } from '@angular/core';
import { CommonModule } from '@angular/common';
import { MatCardModule } from '@angular/material/card';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatDividerModule } from '@angular/material/divider';
import { WorkEntryService } from '../../services/work-entry.service';
import { OvertimeService } from '../../services/overtime.service';
import { toSignal } from '@angular/core/rxjs-interop';
import { WorkEntry, Break } from '@shared/models';
import { 
  calculateNetDuration, 
  calculateGrossDuration, 
  calculateOvertime, 
  calculateExpectedEnd,
  formatDurationSeconds
} from '@shared/utils/time-calculations.util';
import { DurationPipe } from '@shared/pipes/duration.pipe';
import { OvertimePipe } from '@shared/pipes/overtime.pipe';
import { interval, Subscription } from 'rxjs';
import { BreakListComponent } from '../break-list/break-list';
import { v4 as uuidv4 } from 'uuid';

@Component({
  selector: 'app-dashboard',
  standalone: true,
  imports: [
    CommonModule, 
    MatCardModule, 
    MatButtonModule, 
    MatIconModule, 
    MatDividerModule,
    DurationPipe,
    OvertimePipe,
    BreakListComponent
  ],
  template: `
    <div class="dashboard-grid">
      <!-- Left Column: Stats & Timer -->
      <div class="stats-column">
        <mat-card class="timer-card">
          <mat-card-header>
            <mat-card-title>Nettoarbeitszeit</mat-card-title>
          </mat-card-header>
          <mat-card-content>
            <div class="big-timer" [class.running]="isTimerRunning()">
              {{ displayTime() }}
            </div>
            <div class="gross-info">
              Anwesenheit (Brutto): {{ grossTime() | duration }}
            </div>
          </mat-card-content>
        </mat-card>

        <div class="stats-grid">
          <mat-card>
            <mat-card-header><mat-card-subtitle>Heutige Überstunden</mat-card-subtitle></mat-card-header>
            <mat-card-content>
              <div class="stat-value" [class.negative]="dailyOvertime() < 0">
                {{ dailyOvertime() | overtime }}
              </div>
            </mat-card-content>
          </mat-card>

          <mat-card>
            <mat-card-header><mat-card-subtitle>Gesamt-Bilanz</mat-card-subtitle></mat-card-header>
            <mat-card-content>
              <div class="stat-value" [class.negative]="totalBalanceMinutes() < 0">
                {{ totalBalanceMinutes() | overtime }}
              </div>
            </mat-card-content>
          </mat-card>
        </div>

        <mat-card class="expected-end-card">
          <mat-card-content>
            <div class="expected-item">
              <mat-icon>event_available</mat-icon>
              <span>Voraussichtlicher Feierabend (±0): <strong>{{ expectedEnd() | date:'HH:mm' }} Uhr</strong></span>
            </div>
          </mat-card-content>
        </mat-card>
      </div>

      <!-- Right Column: Controls & Breaks -->
      <div class="controls-column">
        <mat-card class="actions-card">
          <mat-card-header>
            <mat-card-title>Zeiterfassung</mat-card-title>
          </mat-card-header>
          <mat-card-content>
            <div class="main-actions">
              @if (!entry()?.workStart) {
                <button mat-raised-button color="primary" class="big-btn" (click)="startTimer()">
                  <mat-icon>play_arrow</mat-icon> Zeiterfassung starten
                </button>
              } @else if (!entry()?.workEnd) {
                <button mat-raised-button color="warn" class="big-btn" (click)="stopTimer()">
                  <mat-icon>stop</mat-icon> Zeiterfassung beenden
                </button>
              } @else {
                <button mat-stroked-button class="big-btn" (click)="startTimer()">
                  <mat-icon>refresh</mat-icon> Neue Session starten
                </button>
              }
            </div>
          </mat-card-content>
        </mat-card>

        <mat-card class="breaks-card">
          <mat-card-header>
            <mat-card-title>Pausen</mat-card-title>
            <span class="spacer"></span>
            <button mat-icon-button (click)="toggleBreak()" [disabled]="!isTimerRunning()">
              <mat-icon>{{ isBreakRunning() ? 'pause_circle_filled' : 'pause_circle_outline' }}</mat-icon>
            </button>
          </mat-card-header>
          <mat-card-content>
            <app-break-list [breaks]="entry()?.breaks || []" (delete)="onDeleteBreak($event)"></app-break-list>
          </mat-card-content>
        </mat-card>
      </div>
    </div>
  `,
  styles: `
    .dashboard-grid {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 1.5rem;
    }
    @media (max-width: 960px) {
      .dashboard-grid { grid-template-columns: 1fr; }
    }
    .timer-card { text-align: center; margin-bottom: 1rem; }
    .big-timer {
      font-size: 4rem;
      font-weight: 300;
      font-variant-numeric: tabular-nums;
      margin: 1.5rem 0;
      color: rgba(0, 0, 0, 0.3);
    }
    .big-timer.running { color: #3f51b5; }
    .gross-info { color: rgba(0, 0, 0, 0.5); font-size: 0.9rem; }
    .stats-grid {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 1rem;
      margin-bottom: 1rem;
    }
    .stat-value { font-size: 1.5rem; font-weight: 500; color: #4caf50; }
    .stat-value.negative { color: #f44336; }
    .expected-item { display: flex; align-items: center; gap: 0.5rem; }
    .main-actions { padding: 1rem 0; }
    .big-btn { width: 100%; height: 56px; font-size: 1.1rem; }
    .spacer { flex: 1; }
  `
})
export class DashboardComponent implements OnDestroy {
  private entryService = inject(WorkEntryService);
  private overtimeService = inject(OvertimeService);
  
  today = new Date();
  entry = toSignal(this.entryService.getWorkEntry(this.today));
  balance = toSignal(this.overtimeService.getBalance());

  // Echtzeit-Ticker
  now = signal(new Date());
  private ticker: Subscription;

  constructor() {
    this.ticker = interval(1000).subscribe(() => this.now.set(new Date()));
  }

  ngOnDestroy() {
    this.ticker.unsubscribe();
  }

  // Abgeleitete Werte
  isTimerRunning = computed(() => !!this.entry()?.workStart && !this.entry()?.workEnd);
  
  isBreakRunning = computed(() => {
    const breaks = this.entry()?.breaks || [];
    return breaks.length > 0 && !breaks[breaks.length - 1].end;
  });

  displayTime = computed(() => {
    const e = this.entry();
    if (!e) return '00:00:00';
    this.now(); 
    return formatDurationSeconds(calculateNetDuration(e));
  });

  grossTime = computed(() => {
    const e = this.entry();
    if (!e) return 0;
    this.now();
    return calculateGrossDuration(e);
  });

  dailyOvertime = computed(() => {
    const e = this.entry();
    if (!e) return 0;
    this.now();
    return calculateOvertime(calculateNetDuration(e), 480);
  });

  totalBalanceMinutes = computed(() => {
    return (this.balance()?.minutes || 0) + this.dailyOvertime();
  });

  expectedEnd = computed(() => {
    const e = this.entry();
    if (!e) return new Date();
    return calculateExpectedEnd(e, 480);
  });

  // Aktionen
  async startTimer() {
    const newEntry: WorkEntry = {
      id: '',
      date: this.today,
      workStart: new Date(),
      type: 'work',
      isManuallyEntered: false,
      breaks: []
    };
    await this.entryService.saveWorkEntry(newEntry);
  }

  async stopTimer() {
    const e = this.entry();
    if (e) {
      await this.entryService.saveWorkEntry({
        ...e,
        workEnd: new Date()
      });
    }
  }

  async toggleBreak() {
    const e = this.entry();
    if (!e) return;

    const breaks = [...e.breaks];
    if (this.isBreakRunning()) {
      breaks[breaks.length - 1].end = new Date();
    } else {
      breaks.push({
        id: uuidv4(),
        name: `Pause ${breaks.length + 1}`,
        start: new Date(),
        isAutomatic: false
      });
    }

    await this.entryService.saveWorkEntry({ ...e, breaks });
  }

  async onDeleteBreak(breakId: string) {
    const e = this.entry();
    if (!e) return;
    const breaks = e.breaks.filter((b: Break) => b.id !== breakId);
    await this.entryService.saveWorkEntry({ ...e, breaks });
  }
}
