import { ChangeDetectionStrategy, Component, computed, inject, input } from '@angular/core';
import { TranslatePipe } from '@ngx-translate/core';
import { LanguageService } from '../../../../core/services/language';
import { LeavePeriod } from '../../../../domain/models/leave.models';
import { LeaveReportPrintData } from './leave-report-print.service';

interface MonthRow { month: number; name: string; vacationDays: string; sickDays: string }
interface PeriodRow { key: string; range: string; one: boolean; days: string }

/**
 * Druckansicht der Urlaubs- und Krankheitsauswertung (#284). Reine Darstellung der Backend-Antwort: Summen,
 * Monatstabelle und Zeiträume kommen fertig aus `GET /api/reports/yearly/{year}`, hier wird nur formatiert.
 * Auf dem Bildschirm unsichtbar (`.print-only`), im Druck nur im Druckmodus der Auswertung (`LEAVE_PRINT_CLASS`).
 */
@Component({
  selector: 'app-leave-report-print',
  imports: [TranslatePipe],
  templateUrl: './leave-report-print.html',
  styleUrl: './leave-report-print.scss',
  changeDetection: ChangeDetectionStrategy.OnPush,
  host: { class: 'print-only leave-print' },
})
export class LeaveReportPrintComponent {
  private readonly language = inject(LanguageService);

  readonly data = input.required<LeaveReportPrintData>();

  protected readonly report = computed(() => this.data().report);

  /** Weder Urlaub noch Krankheit im Jahr (Werte des Backends, nicht nachgerechnet). */
  protected readonly isEmpty = computed(() => this.report().vacationDaysTaken === 0 && this.report().sickDays === 0);

  protected readonly createdAt = computed(() =>
    new Intl.DateTimeFormat(this.language.locale(), { dateStyle: 'medium' }).format(this.data().createdAt));

  protected readonly months = computed((): MonthRow[] => {
    const monthFormat = new Intl.DateTimeFormat(this.language.locale(), { month: 'long' });
    return (this.report().months ?? []).map(m => ({
      month: m.month,
      name: monthFormat.format(new Date(2000, m.month - 1, 1)),
      vacationDays: this.count(m.vacationDays),
      sickDays: this.count(m.sickDays),
    }));
  });

  protected readonly vacationPeriods = computed(() => this.periods(this.report().vacationPeriods));
  protected readonly sickPeriods     = computed(() => this.periods(this.report().sickPeriods));

  protected count(n: number): string {
    return n.toLocaleString(this.language.locale());
  }

  /** „03.08.–14.08.“ bzw. ein Tag „10.02.“ (Datumsformat der App-Sprache), die Tageszahl setzt das Template dazu. */
  private periods(list: LeavePeriod[] | undefined): PeriodRow[] {
    const dayFormat = new Intl.DateTimeFormat(this.language.locale(), { day: '2-digit', month: '2-digit' });
    return (list ?? []).map(p => ({
      key: p.start,
      range: p.start === p.end
        ? this.day(p.start, dayFormat)
        : `${this.day(p.start, dayFormat)}–${this.day(p.end, dayFormat)}`,
      one: p.days === 1,
      days: this.count(p.days),
    }));
  }

  /** `yyyy-MM-dd` als lokaler Kalendertag zerlegt (kein `new Date(iso)`: das wäre UTC und westlich der Vortag). */
  private day(iso: string, format: Intl.DateTimeFormat): string {
    const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(iso);
    if (!match) return iso;
    return format.format(new Date(Number(match[1]), Number(match[2]) - 1, Number(match[3])));
  }
}
