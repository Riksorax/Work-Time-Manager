import {
  ChangeDetectionStrategy,
  Component,
  ElementRef,
  computed,
  effect,
  input,
  output,
  signal,
  untracked,
  viewChild,
} from '@angular/core';
import { DatePipe } from '@angular/common';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';

function toKey(d: Date): string {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

@Component({
  selector: 'app-calendar',
  imports: [DatePipe, MatButtonModule, MatIconModule],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <div class="calendar-card"
         #calendarCard
         (pointerdown)="onCardPointerDown($event)"
         (pointermove)="onCardPointerMove($event)"
         (pointerup)="onCardPointerUp($event)"
         (pointercancel)="onCardPointerUp($event)">

      <div class="calendar-header">
        <button mat-icon-button (click)="changeMonth(-1)" aria-label="Vorheriger Monat">
          <mat-icon>chevron_left</mat-icon>
        </button>
        <div class="current-month" aria-live="polite">
          {{ viewDate() | date:'MMMM yyyy' }}
        </div>
        <button mat-icon-button (click)="changeMonth(1)" aria-label="Nächster Monat">
          <mat-icon>chevron_right</mat-icon>
        </button>
      </div>

      <div class="calendar-grid" role="grid" [attr.aria-label]="viewDate() | date:'MMMM yyyy'">
        @for (day of weekDays; track day) {
          <div class="weekday-label" role="columnheader">{{ day }}</div>
        }

        @for (empty of emptyPrefix(); track $index) {
          <div class="calendar-day empty" role="gridcell" aria-hidden="true"></div>
        }

        @for (day of daysInMonth(); track day.date.getTime()) {
          <div
            class="calendar-day"
            role="gridcell"
            [attr.data-date]="dayKey(day.date)"
            [attr.aria-label]="day.date | date:'d. MMMM yyyy'"
            [attr.aria-selected]="isSameDay(day.date, selectedDate())"
            [attr.aria-pressed]="isMultiSelected(day.date)"
            [class.selected]="!hasMultiSelected() && isSameDay(day.date, selectedDate())"
            [class.today]="isToday(day.date)"
            [class.has-entry]="hasEntry(day.date)"
            [class.multi-selected]="isMultiSelected(day.date)"
          >
            <span class="day-number">{{ day.date.getDate() }}</span>
            @if (hasEntry(day.date)) {
              <div class="entry-dot" aria-hidden="true"></div>
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
      touch-action: none;
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

      &.today:not(.selected):not(.multi-selected) {
        color: var(--mat-sys-primary);
        font-weight: bold;
        border: 1px solid var(--mat-sys-primary);
      }

      &.multi-selected {
        background-color: var(--mat-sys-secondary-container);
        color: var(--mat-sys-on-secondary-container);
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
  readonly selectedDate       = input.required<Date>();
  readonly daysWithEntries    = input<number[]>([]);
  readonly multiSelectedDates = input<Set<string>>(new Set());

  readonly dateSelected = output<Date>();
  readonly monthChanged = output<{ year: number; month: number }>();
  readonly dragSelected = output<Date[]>();

  readonly viewDate = signal(new Date());
  readonly weekDays = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];

  private readonly _cardRef = viewChild<ElementRef<HTMLElement>>('calendarCard');

  private _dragStart: Date | null = null;
  private _isDragging = false;
  private _activePointerId: number | null = null;

  constructor() {
    effect(() => {
      const initial = this.selectedDate();
      untracked(() => {
        this.viewDate.set(new Date(initial.getFullYear(), initial.getMonth(), 1));
      });
    });
  }

  readonly emptyPrefix = computed(() => {
    const d = this.viewDate();
    const firstDay = new Date(d.getFullYear(), d.getMonth(), 1).getDay();
    const offset = firstDay === 0 ? 6 : firstDay - 1;
    return Array<number>(offset).fill(0);
  });

  readonly daysInMonth = computed(() => {
    const d = this.viewDate();
    const count = new Date(d.getFullYear(), d.getMonth() + 1, 0).getDate();
    return Array.from({ length: count }, (_, i) => ({
      date: new Date(d.getFullYear(), d.getMonth(), i + 1),
    }));
  });

  isSameDay(d1: Date, d2: Date): boolean {
    return d1.getFullYear() === d2.getFullYear()
      && d1.getMonth() === d2.getMonth()
      && d1.getDate() === d2.getDate();
  }

  isToday(date: Date): boolean {
    const today = new Date();
    return this.isSameDay(date, today);
  }

  hasEntry(date: Date): boolean {
    return this.daysWithEntries().includes(date.getDate());
  }

  isMultiSelected(date: Date): boolean {
    return this.multiSelectedDates().has(toKey(date));
  }

  hasMultiSelected(): boolean {
    return this.multiSelectedDates().size > 0;
  }

  dayKey(d: Date): string { return toKey(d); }

  // ── Pointer Events (Container-level) ────────────────────────────────────────

  onCardPointerDown(event: PointerEvent): void {
    const date = this._dateFromPoint(event.clientX, event.clientY);
    if (!date) return;

    this._dragStart       = date;
    this._isDragging      = false;
    this._activePointerId = event.pointerId;
    this._cardRef()?.nativeElement.setPointerCapture(event.pointerId);
    event.preventDefault();
  }

  onCardPointerMove(event: PointerEvent): void {
    if (this._activePointerId === null || this._dragStart === null) return;
    if (event.pointerId !== this._activePointerId) return;

    const date = this._dateFromPoint(event.clientX, event.clientY);
    if (!date) return;

    // Drag beginnt sobald der Finger einen anderen Tag berührt
    if (!this.isSameDay(date, this._dragStart) || this._isDragging) {
      this._isDragging = true;
      this.dragSelected.emit(this._dateRange(this._dragStart, date));
    }
    event.preventDefault();
  }

  onCardPointerUp(event: PointerEvent): void {
    const card = this._cardRef()?.nativeElement;
    if (card?.hasPointerCapture(event.pointerId)) {
      card.releasePointerCapture(event.pointerId);
    }

    if (!this._isDragging && this._dragStart) {
      // Einfacher Tap → Tag auswählen
      this.dateSelected.emit(this._dragStart);
    }

    this._dragStart       = null;
    this._activePointerId = null;
    setTimeout(() => { this._isDragging = false; });
  }

  changeMonth(delta: number): void {
    const d = this.viewDate();
    const next = new Date(d.getFullYear(), d.getMonth() + delta, 1);
    this.viewDate.set(next);
    this.monthChanged.emit({ year: next.getFullYear(), month: next.getMonth() + 1 });
  }

  // ── Private ─────────────────────────────────────────────────────────────────

  private _dateFromPoint(x: number, y: number): Date | null {
    const el      = document.elementFromPoint(x, y);
    const dayEl   = el?.closest('[data-date]') as HTMLElement | null;
    const dateStr = dayEl?.dataset['date'];
    if (!dateStr) return null;
    const [yr, mo, da] = dateStr.split('-').map(Number);
    return new Date(yr, mo - 1, da);
  }

  private _dateRange(a: Date, b: Date): Date[] {
    const start = a <= b ? a : b;
    const end   = a <= b ? b : a;
    const result: Date[] = [];
    const cur = new Date(start.getFullYear(), start.getMonth(), start.getDate());
    const fin = new Date(end.getFullYear(),   end.getMonth(),   end.getDate());
    while (cur <= fin) {
      result.push(new Date(cur));
      cur.setDate(cur.getDate() + 1);
    }
    return result;
  }
}
