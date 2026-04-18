import { Component, input, output, computed, signal, effect, untracked } from '@angular/core';
import { CommonModule } from '@angular/common';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';

@Component({
  selector: 'app-calendar',
  standalone: true,
  imports: [CommonModule, MatButtonModule, MatIconModule],
  template: `
    <div class="calendar-card">
      <div class="calendar-header">
        <button mat-icon-button (click)="changeMonth(-1)">
          <mat-icon>chevron_left</mat-icon>
        </button>
        <div class="current-month">
          {{ viewDate() | date:'MMMM yyyy' }}
        </div>
        <button mat-icon-button (click)="changeMonth(1)">
          <mat-icon>chevron_right</mat-icon>
        </button>
      </div>

      <div class="calendar-grid">
        @for (day of weekDays; track day) {
          <div class="weekday-label">{{ day }}</div>
        }

        @for (empty of emptyPrefix(); track $index) {
          <div class="calendar-day empty"></div>
        }

        @for (day of daysInMonth(); track day.date.getTime()) {
          <div 
            class="calendar-day"
            [class.selected]="isSameDay(day.date, selectedDate())"
            [class.today]="isToday(day.date)"
            [class.has-entry]="hasEntry(day.date)"
            (click)="selectDate(day.date)"
          >
            <span class="day-number">{{ day.date.getDate() }}</span>
            @if (hasEntry(day.date)) {
              <div class="entry-dot"></div>
            }
          </div>
        }
      </div>
    </div>
  `,
  styles: [`
    .calendar-card {
      background: var(--mat-sys-surface-container-low);
      border-radius: 16px;
      padding: 16px;
      user-select: none;
    }
    .calendar-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 16px;
    }
    .current-month {
      font-weight: 500;
      font-size: 1.1rem;
    }
    .calendar-grid {
      display: grid;
      grid-template-columns: repeat(7, 1fr);
      gap: 4px;
    }
    .weekday-label {
      text-align: center;
      font-size: 0.8rem;
      font-weight: 500;
      opacity: 0.7;
      padding-bottom: 8px;
    }
    .calendar-day {
      aspect-ratio: 1;
      display: flex;
      flex-direction: column;
      justify-content: center;
      align-items: center;
      border-radius: 50%;
      cursor: pointer;
      position: relative;
      font-size: 0.9rem;
      transition: background-color 0.2s;

      &:hover:not(.empty) {
        background-color: var(--mat-sys-surface-container-high);
      }

      &.selected {
        background-color: var(--mat-sys-primary) !important;
        color: var(--mat-sys-on-primary);
      }

      &.today:not(.selected) {
        color: var(--mat-sys-primary);
        font-weight: bold;
        border: 1px solid var(--mat-sys-primary);
      }
    }
    .entry-dot {
      width: 4px;
      height: 4px;
      background-color: currentColor;
      border-radius: 50%;
      position: absolute;
      bottom: 6px;
      opacity: 0.6;
    }
    .calendar-day.selected .entry-dot {
      background-color: var(--mat-sys-on-primary);
    }
  `]
})
export class CalendarComponent {
  selectedDate = input.required<Date>();
  daysWithEntries = input<number[]>([]); 
  
  dateSelected = output<Date>();
  monthChanged = output<{ year: number, month: number }>();

  viewDate = signal(new Date());

  weekDays = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];

  constructor() {
    effect(() => {
      const initial = this.selectedDate();
      this.viewDate.set(new Date(initial.getFullYear(), initial.getMonth(), 1));
    }, { allowSignalWrites: true });
  }

  emptyPrefix = computed(() => {
    const d = this.viewDate();
    const firstDay = new Date(d.getFullYear(), d.getMonth(), 1).getDay();
    const offset = firstDay === 0 ? 6 : firstDay - 1;
    return Array(offset).fill(0);
  });

  daysInMonth = computed(() => {
    const d = this.viewDate();
    const days = new Date(d.getFullYear(), d.getMonth() + 1, 0).getDate();
    return Array.from({ length: days }, (_, i) => ({
      date: new Date(d.getFullYear(), d.getMonth(), i + 1)
    }));
  });

  isSameDay(d1: Date, d2: Date): boolean {
    return d1.getFullYear() === d2.getFullYear() &&
           d1.getMonth() === d2.getMonth() &&
           d1.getDate() === d2.getDate();
  }

  isToday(date: Date): boolean {
    const today = new Date();
    return this.isSameDay(date, today);
  }

  hasEntry(date: Date): boolean {
    return this.daysWithEntries().includes(date.getDate());
  }

  selectDate(date: Date) {
    this.dateSelected.emit(date);
  }

  changeMonth(delta: number) {
    const d = this.viewDate();
    const newDate = new Date(d.getFullYear(), d.getMonth() + delta, 1);
    this.viewDate.set(newDate);
    this.monthChanged.emit({ year: newDate.getFullYear(), month: newDate.getMonth() + 1 });
  }
}
