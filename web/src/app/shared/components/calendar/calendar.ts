import {
  ChangeDetectionStrategy,
  Component,
  ElementRef,
  Injector,
  afterNextRender,
  computed,
  effect,
  inject,
  input,
  output,
  signal,
  untracked,
  viewChild,
} from '@angular/core';
import { DatePipe } from '@angular/common';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatTooltipModule } from '@angular/material/tooltip';
import { TranslatePipe, TranslateService } from '@ngx-translate/core';
import { Bundesland } from '../../models';
import { GermanHoliday, getGermanHolidayIds } from '../../utils/german-holidays.util';
import { TodayService } from '../../../core/services/today';
import { isCalendarNavKey, nextFocusDate } from '../../utils/calendar-keyboard.util';

const EMPTY_HOLIDAYS = new Map<string, GermanHoliday>();

function toKey(d: Date): string {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

@Component({
  selector: 'app-calendar',
  imports: [DatePipe, MatButtonModule, MatIconModule, MatTooltipModule, TranslatePipe],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <div class="calendar-card"
         #calendarCard
         (pointerdown)="onCardPointerDown($event)"
         (pointermove)="onCardPointerMove($event)"
         (pointerup)="onCardPointerUp($event)"
         (pointercancel)="onCardPointerUp($event)">

      <div class="calendar-header">
        <button mat-icon-button (click)="changeMonth(-1)" [attr.aria-label]="'shared.calendarPrevMonthAria' | translate">
          <mat-icon>chevron_left</mat-icon>
        </button>
        <div class="current-month" aria-live="polite">
          {{ viewDate() | date:'MMMM yyyy' }}
        </div>
        <button mat-icon-button (click)="changeMonth(1)" [attr.aria-label]="'shared.calendarNextMonthAria' | translate">
          <mat-icon>chevron_right</mat-icon>
        </button>
      </div>

      <div class="calendar-grid" role="grid" [attr.aria-label]="viewDate() | date:'MMMM yyyy'"
           (keydown)="onGridKeydown($event)">
        <div class="calendar-week weekday-row" role="row">
          @for (day of weekDays; track day) {
            <div class="weekday-label" role="columnheader">{{ day }}</div>
          }
        </div>

        @for (week of weeks(); track $index) {
          <div class="calendar-week" role="row">
            @for (day of week; track day ? day.date.getTime() : 'empty-' + $index) {
              @if (day) {
                @let holiday = holidayFor(day.date);
                @let holidayName = holiday ? ('holidays.' + holiday | translate) : '';
                @let ariaDate = day.date | date:'EEEE, d. MMMM yyyy';
                @let ariaDay = holiday ? ('shared.calendarHolidayAria' | translate: { date: ariaDate, name: holidayName }) : ariaDate;
                <div
                  class="calendar-day"
                  role="gridcell"
                  [attr.data-date]="dayKey(day.date)"
                  [attr.aria-label]="hasEntry(day.date) ? ('shared.calendarHasEntryAria' | translate: { label: ariaDay }) : ariaDay"
                  [matTooltip]="holidayName"
                  [matTooltipDisabled]="holiday === null"
                  [class.holiday]="holiday !== null"
                  [attr.tabindex]="dayKey(day.date) === focusableKey() ? 0 : -1"
                  [attr.aria-selected]="isSelected(day.date)"
                  [attr.aria-current]="isToday(day.date) ? 'date' : null"
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
              } @else {
                <div class="calendar-day empty" role="gridcell" aria-hidden="true"></div>
              }
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
      display: flex;
      flex-direction: column;
      gap: 4px;
    }
    .calendar-week {
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

      &:focus-visible {
        outline: 2px solid var(--mat-sys-primary);
        outline-offset: 2px;
      }

      &:focus:not(:focus-visible) {
        outline: none;
      }

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

      &.holiday {
        font-weight: 700;
        text-decoration: underline;
        text-decoration-thickness: 2px;
        text-underline-offset: 3px;
      }

      &.holiday:not(.selected):not(.multi-selected) {
        color: var(--mat-sys-error);
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
  /** Bundesland für die Feiertags-Markierung (null = keine Markierung). Siehe #371. */
  readonly bundesland         = input<Bundesland | null>(null);

  readonly dateSelected = output<Date>();
  readonly monthChanged = output<{ year: number; month: number }>();
  readonly dragSelected = output<Date[]>();

  private readonly translate = inject(TranslateService);
  private readonly todayService = inject(TodayService);
  private readonly injector = inject(Injector);

  readonly viewDate = signal(new Date());
  readonly weekDays: string[] = this.translate.instant('common.weekdaysShort');

  private readonly _cardRef = viewChild<ElementRef<HTMLElement>>('calendarCard');

  /** Roving-Fokus (Key yyyy-MM-dd), nur durch Tastatur/Tap gesetzt; `null` = Fallback über focusableKey. */
  private readonly _focusKey = signal<string | null>(null);

  private _dragStart: Date | null = null;
  private _isDragging = false;
  private _activePointerId: number | null = null;

  constructor() {
    effect(() => {
      const initial = this.selectedDate();
      untracked(() => {
        this.viewDate.set(new Date(initial.getFullYear(), initial.getMonth(), 1));
        this._focusKey.set(null);
      });
    });
  }

  readonly emptyPrefix = computed(() => {
    const d = this.viewDate();
    const firstDay = new Date(d.getFullYear(), d.getMonth(), 1).getDay();
    const offset = firstDay === 0 ? 6 : firstDay - 1;
    return Array<number>(offset).fill(0);
  });

  /** Wochenzeilen (Mo-So) für `role=row`; `null` = leere Zelle vor Monatsbeginn bzw. nach Monatsende. */
  readonly weeks = computed(() => {
    const cells: ({ date: Date } | null)[] = [
      ...this.emptyPrefix().map(() => null),
      ...this.daysInMonth(),
    ];
    while (cells.length % 7 !== 0) cells.push(null);
    const rows: ({ date: Date } | null)[][] = [];
    for (let i = 0; i < cells.length; i += 7) rows.push(cells.slice(i, i + 7));
    return rows;
  });

  readonly daysInMonth = computed(() => {
    const d = this.viewDate();
    const count = new Date(d.getFullYear(), d.getMonth() + 1, 0).getDate();
    return Array.from({ length: count }, (_, i) => ({
      date: new Date(d.getFullYear(), d.getMonth(), i + 1),
    }));
  });

  /** Einziger Tab-Stopp im Grid: Roving-Fokus, sonst selectedDate, sonst heute, sonst Tag 1 (nur im angezeigten Monat). */
  readonly focusableKey = computed(() => {
    const view = this.viewDate();
    const prefix = toKey(view).slice(0, 7);
    const inMonth = (key: string | null): key is string => key !== null && key.startsWith(prefix);
    const focus = this._focusKey();
    if (inMonth(focus)) return focus;
    const selected = toKey(this.selectedDate());
    if (inMonth(selected)) return selected;
    const today = this.todayService.today();
    if (inMonth(today)) return today;
    return `${prefix}-01`;
  });

  // Jahr aus dem angezeigten Monat (nicht aus selectedDate): Dez -> Jan beim Blättern.
  private readonly holidayMap = computed(() => {
    const b = this.bundesland();
    return b ? getGermanHolidayIds(this.viewDate().getFullYear(), b) : EMPTY_HOLIDAYS;
  });

  holidayFor(date: Date): GermanHoliday | null {
    return this.holidayMap().get(toKey(date)) ?? null;
  }

  isSameDay(d1: Date, d2: Date): boolean {
    return d1.getFullYear() === d2.getFullYear()
      && d1.getMonth() === d2.getMonth()
      && d1.getDate() === d2.getDate();
  }

  /** Visuelle Auswahl (Mehrfachauswahl hat Vorrang vor selectedDate), Basis für aria-selected. */
  isSelected(date: Date): boolean {
    return this.hasMultiSelected() ? this.isMultiSelected(date) : this.isSameDay(date, this.selectedDate());
  }

  isToday(date: Date): boolean {
    return toKey(date) === this.todayService.today();
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
      // Einfacher Tap → Tag auswählen; Fokus folgt dem Klick (pointerdown ruft preventDefault)
      const key = toKey(this._dragStart);
      this._focusKey.set(key);
      this._focusElement(key);
      this.dateSelected.emit(this._dragStart);
    }

    this._dragStart       = null;
    this._activePointerId = null;
    setTimeout(() => { this._isDragging = false; });
  }

  // ── Tastatur (#377): Roving tabindex, Fokus folgt nicht der Auswahl ─────────

  onGridKeydown(event: KeyboardEvent): void {
    if (event.altKey || event.metaKey || event.shiftKey) return;
    const from = this._dateFromElement(event.target);
    if (!from) return;

    const key = event.key;
    if (key === 'Enter' || key === ' ') {
      if (event.ctrlKey) return;
      event.preventDefault();
      if (!event.repeat) this.dateSelected.emit(from);
      return;
    }

    if (!isCalendarNavKey(key)) return;
    if (event.ctrlKey && key !== 'Home' && key !== 'End') return;
    event.preventDefault();
    this._focusCell(nextFocusDate(key, from, event.ctrlKey));
  }

  changeMonth(delta: number): void {
    const d = this.viewDate();
    this._showMonth(d.getFullYear(), d.getMonth() + delta);
  }

  // ── Private ─────────────────────────────────────────────────────────────────

  private _dateFromPoint(x: number, y: number): Date | null {
    return this._dateFromElement(document.elementFromPoint(x, y));
  }

  private _dateFromElement(target: EventTarget | null): Date | null {
    const dayEl   = (target as Element | null)?.closest?.('[data-date]') as HTMLElement | null;
    const dateStr = dayEl?.dataset['date'];
    if (!dateStr) return null;
    const [yr, mo, da] = dateStr.split('-').map(Number);
    return new Date(yr, mo - 1, da);
  }

  private _focusCell(date: Date): void {
    const view = this.viewDate();
    const key = toKey(date);
    this._focusKey.set(key);
    if (date.getFullYear() === view.getFullYear() && date.getMonth() === view.getMonth()) {
      this._focusElement(key);
      return;
    }
    // Monatswechsel: Zellen werden neu erzeugt, Fokus erst nach dem nächsten Render
    this._showMonth(date.getFullYear(), date.getMonth());
    afterNextRender(() => this._focusElement(key), { injector: this.injector });
  }

  private _focusElement(key: string): void {
    this._cardRef()?.nativeElement.querySelector<HTMLElement>(`[data-date="${key}"]`)?.focus();
  }

  private _showMonth(year: number, monthIndex: number): void {
    const next = new Date(year, monthIndex, 1);
    this.viewDate.set(next);
    this.monthChanged.emit({ year: next.getFullYear(), month: next.getMonth() + 1 });
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
