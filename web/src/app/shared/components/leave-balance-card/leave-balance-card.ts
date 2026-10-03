import { ChangeDetectionStrategy, Component, computed, input, output } from '@angular/core';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatProgressBarModule } from '@angular/material/progress-bar';
import { MatProgressSpinnerModule } from '@angular/material/progress-spinner';
import { TranslatePipe } from '@ngx-translate/core';
import { YearlyLeaveReport } from '../../../domain/models/leave.models';

export type LeaveBalanceState = 'loading' | 'data' | 'error';

/**
 * Reine Darstellungskomponente (kein Premium-Gate, kein Service).
 * Zustand und Daten kommen vom LeaveBalanceService der Elternkomponente.
 */
@Component({
  selector: 'app-leave-balance-card',
  imports: [MatButtonModule, MatIconModule, MatProgressBarModule, MatProgressSpinnerModule, TranslatePipe],
  templateUrl: './leave-balance-card.html',
  styleUrl: './leave-balance-card.scss',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class LeaveBalanceCardComponent {
  readonly report = input<YearlyLeaveReport | null>(null);
  readonly state = input<LeaveBalanceState>('data');
  /** false für Vorjahre: Rest/Anspruch werden nicht gezeigt (Anspruch gilt nur fürs laufende Jahr). */
  readonly showRemaining = input(true);
  /** true = Link "Anspruch festlegen" bei Anspruch 0 anzeigen (nicht in den Einstellungen). */
  readonly editable = input(false);
  /** true = anonyme Nutzer, Werte nur lokal. */
  readonly localOnly = input(false);
  /** Zeigt zusätzlich den Leerhinweis (Reports-Tab). */
  readonly showEmptyHint = input(false);

  readonly retry = output<void>();
  readonly editEntitlement = output<void>();

  protected readonly isOver = computed(() => (this.report()?.vacationDaysRemaining ?? 0) < 0);
  protected readonly overBy = computed(() => Math.abs(this.report()?.vacationDaysRemaining ?? 0));
  protected readonly entitlementZero = computed(() => (this.report()?.vacationDaysPerYear ?? 0) === 0);
  /** Anteil genommen/Anspruch in Prozent (0–100); bei Anspruch 0 nicht definiert. */
  protected readonly percent = computed(() => {
    const r = this.report();
    if (!r || r.vacationDaysPerYear <= 0) return 0;
    return Math.min(100, Math.round((r.vacationDaysTaken / r.vacationDaysPerYear) * 100));
  });
  protected readonly isEmpty = computed(() => {
    const r = this.report();
    return !!r && r.vacationDaysTaken === 0 && r.sickDays === 0;
  });
}
