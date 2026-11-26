import { ChangeDetectionStrategy, Component, ElementRef, Injector, afterNextRender, inject, signal, viewChild } from '@angular/core';
import { DOCUMENT, DatePipe } from '@angular/common';
import { MatButtonModule } from '@angular/material/button';
import { MatDialog } from '@angular/material/dialog';
import { MatDividerModule } from '@angular/material/divider';
import { MatIconModule } from '@angular/material/icon';
import { MatProgressSpinnerModule } from '@angular/material/progress-spinner';
import { MatSnackBar } from '@angular/material/snack-bar';
import { MatTabsModule } from '@angular/material/tabs';
import { MatTooltipModule } from '@angular/material/tooltip';
import { TranslatePipe, TranslateService } from '@ngx-translate/core';
import { CalendarComponent } from '../../shared/components/calendar/calendar';
import { EditEntryDialogComponent } from '../../shared/components/edit-entry-dialog/edit-entry-dialog';
import {
  QuickEntryDialogComponent,
  QuickEntryDialogResult,
} from './components/quick-entry-dialog/quick-entry-dialog';
import {
  BatchQuickEntryDialogComponent,
  BatchQuickEntryDialogResult,
} from './components/batch-quick-entry-dialog/batch-quick-entry-dialog';
import { ReportsService } from './reports.service';
import { LanguageService } from '../../core/services/language';
import { WebPremiumService } from '../../core/services/web-premium';
import { WorkEntry, WorkEntryType } from '../../shared/models/index';
import { toDateKey } from '../../domain/services/report-calculator';
import { Router } from '@angular/router';
import { LeaveBalanceService } from '../../core/services/leave-balance';
import { LeaveBalanceCardComponent } from '../../shared/components/leave-balance-card/leave-balance-card';
import { HomeOfficeCardComponent } from '../../shared/components/home-office-card/home-office-card';
import { YearlyComparisonCardComponent } from '../../shared/components/yearly-comparison-card/yearly-comparison-card';
import { YearlyComparisonLockedComponent } from '../../shared/components/yearly-comparison-card/yearly-comparison-locked';
import { formatDurationHm, formatSignedDurationHm } from '../../shared/utils/duration-format.util';
import { TrendViewComponent } from './components/trend-view/trend-view';
import { TrendViewService } from './components/trend-view/trend-view.service';
import { InsightsViewComponent } from './components/insights-view/insights-view';
import { InsightsViewService } from './components/insights-view/insights-view.service';
import { LeaveReportPrintComponent } from './components/leave-report-print/leave-report-print';
import { LeaveReportPrintService } from './components/leave-report-print/leave-report-print.service';

@Component({
  selector: 'app-reports',
  imports: [
    DatePipe,
    MatButtonModule,
    MatDividerModule,
    MatIconModule,
    MatProgressSpinnerModule,
    MatTabsModule,
    MatTooltipModule,
    CalendarComponent,
    LeaveBalanceCardComponent,
    HomeOfficeCardComponent,
    YearlyComparisonCardComponent,
    YearlyComparisonLockedComponent,
    TrendViewComponent,
    InsightsViewComponent,
    LeaveReportPrintComponent,
    TranslatePipe,
  ],
  // Trend (#531): Zustand (Wochen/Monate) lebt mit der Berichtsseite, geladen wird nur im sichtbaren Tab.
  // Insights (#537): wie Trend, geladen wird nur im sichtbaren Tab.
  // Urlaubs-/Krankheitsauswertung (#284): Lade- und Druckzustand lebt mit der Berichtsseite.
  providers: [TrendViewService, InsightsViewService, LeaveReportPrintService],
  templateUrl: './reports.html',
  styleUrl: './reports.scss',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class ReportsComponent {
  protected readonly svc        = inject(ReportsService);
  protected readonly leave      = inject(LeaveBalanceService);
  protected readonly leavePrint = inject(LeaveReportPrintService);
  private  readonly router      = inject(Router);
  private  readonly premiumSvc  = inject(WebPremiumService);
  private  readonly dialog      = inject(MatDialog);
  private  readonly snackbar    = inject(MatSnackBar);
  private  readonly translate   = inject(TranslateService);
  private  readonly language    = inject(LanguageService);
  private  readonly injector    = inject(Injector);
  private  readonly document    = inject(DOCUMENT);
  private  readonly multiSelectToggle = viewChild('multiSelectToggle', { read: ElementRef<HTMLElement> });
  protected readonly activeTabIndex = signal(0);

  protected readonly isRestoring  = this.premiumSvc.isRestoring;
  protected readonly isPurchasing = this.premiumSvc.isPurchasing;
  protected readonly isRcConfigured = this.premiumSvc.isConfigured;

  goToSettings(): void {
    void this.router.navigate(['/settings']);
  }

  async onRestorePurchases(): Promise<void> {
    try {
      const restored = await this.premiumSvc.restorePurchases();
      this.snackbar.open(
        this.translate.instant(restored ? 'reports.restoreSuccess' : 'reports.restoreNotFound'),
        'OK',
        { duration: 4000 },
      );
    } catch {
      this.snackbar.open(this.translate.instant('reports.restoreError'), 'OK', { duration: 4000 });
    }
  }

  /**
   * Jahresauswertung als PDF (#483): Premium. Der Browser-Druckdialog (Als PDF speichern) druckt dank Print-CSS
   * (`styles.scss`, `.print-area`) nur die Jahresansicht; Nicht-Premium-Nutzer sehen stattdessen die Paywall.
   */
  async onPrintYear(): Promise<void> {
    if (!this.svc.isPremium()) {
      await this.onPresentPaywall();
      return;
    }
    // Eine vorher gedruckte Urlaubs-/Krankheitsauswertung darf hier nicht erscheinen (#284).
    this.leavePrint.endPrintMode();
    this.document.defaultView?.print();
  }

  /**
   * Urlaubs- und Krankheitsauswertung drucken (#284): Premium, sonst Paywall. Lädt Jahr und aktives Profil frisch vom
   * Backend und druckt erst danach; scheitert das Laden, gibt es eine Meldung und keinen Druckdialog.
   */
  async onPrintLeave(): Promise<void> {
    if (!this.svc.isPremium()) {
      await this.onPresentPaywall();
      return;
    }
    const result = await this.leavePrint.print(this.leave.year());
    if (result === 'error') {
      this.snackbar.open(this.translate.instant('leave.printLoadError'), 'OK', { duration: 4000 });
    }
  }

  async onPresentPaywall(): Promise<void> {
    try {
      const purchased = await this.premiumSvc.presentPaywall();
      if (purchased) {
        this.snackbar.open(this.translate.instant('reports.purchaseSuccess'), 'OK', { duration: 4000 });
      }
    } catch (e: unknown) {
      const msg = e instanceof Error ? e.message : this.translate.instant('reports.purchaseError');
      this.snackbar.open(msg, 'OK', { duration: 4000 });
    }
  }

  // ── Template helpers ────────────────────────────────────────────────────────

  /** Kurzer Wochentag und Tag der Berichtszeile in der App-Sprache („Mo. 2.“ / „Mon 2.“); `LOCALE_ID` bleibt fest Deutsch (#551). */
  dayLabel(date: Date): string {
    // Mit `day` formatiert, damit der Wochentag in Formatform erscheint („Mo.“ statt der Alleinstehend-Form „Mo“).
    const parts = new Intl.DateTimeFormat(this.language.locale(), { weekday: 'short', day: 'numeric' }).formatToParts(date);
    const part = (type: string): string => parts.find(p => p.type === type)?.value ?? '';
    return `${part('weekday')} ${part('day')}.`;
  }

  /** Ausgeschriebener Wochentag mit Datum für das `aria-label` der Berichtszeile in der App-Sprache. */
  dayAriaLabel(date: Date): string {
    return new Intl.DateTimeFormat(this.language.locale(), { weekday: 'long', day: 'numeric', month: 'long' }).format(date);
  }

  formatDuration(ms: number): string {
    return formatDurationHm(ms);
  }

  formatOvertime(ms: number): string {
    return formatSignedDurationHm(ms);
  }

  entryTypeLabel(type: WorkEntryType): string {
    switch (type) {
      case WorkEntryType.Work:     return this.translate.instant('reports.entryTypeWork');
      case WorkEntryType.Vacation: return this.translate.instant('reports.entryTypeVacation');
      case WorkEntryType.Sick:     return this.translate.instant('reports.entryTypeSick');
      case WorkEntryType.Holiday:  return this.translate.instant('reports.entryTypeHoliday');
    }
  }

  // ── Actions ─────────────────────────────────────────────────────────────────

  onTabChange(index: number): void {
    this.activeTabIndex.set(index);
  }

  onCalendarDayTap(date: Date): void {
    if (this.svc.isMultiSelectActive()) {
      this.svc.toggleDateSelection(date);
    } else {
      this.svc.selectDate(date);
    }
  }

  /** „Abbrechen“ im Day-Panel verschwindet beim Klick: Fokus nach dem nächsten Render auf den Toggle (#377). */
  onCancelMultiSelect(): void {
    this.svc.endMultiSelect();
    afterNextRender(() => this.multiSelectToggle()?.nativeElement.focus(), { injector: this.injector });
  }

  openEditDialog(entry?: WorkEntry): void {
    const ref = this.dialog.open(EditEntryDialogComponent, {
      width: '520px',
      data: { entry, date: this.svc.selectedDate() },
    });
    ref.afterClosed().subscribe(async (result: Partial<WorkEntry> | undefined) => {
      if (result) {
        await this.svc.saveEntry(result as WorkEntry);
      }
    });
  }

  openQuickEntryDialog(): void {
    const ref = this.dialog.open(QuickEntryDialogComponent, {
      data: { date: this.svc.selectedDate() },
    });
    ref.afterClosed().subscribe(async (result: QuickEntryDialogResult | undefined) => {
      if (!result) return;
      const date = this.svc.selectedDate();
      const entry: WorkEntry = {
        id: toDateKey(date),
        date,
        breaks: [],
        isManuallyEntered: true,
        type: result.type,
        workStart:  result.startTime ? this._parseTime(date, result.startTime) : undefined,
        workEnd:    result.endTime   ? this._parseTime(date, result.endTime)   : undefined,
      };
      await this.svc.saveEntry(entry);
    });
  }

  openBatchQuickEntryDialog(): void {
    const dateKeys = [...this.svc.selectedDates()];
    const dates    = dateKeys.map(k => {
      const [y, m, d] = k.split('-').map(Number);
      return new Date(y, m - 1, d);
    });
    if (!dates.length) return;

    const ref = this.dialog.open(BatchQuickEntryDialogComponent, {
      data: { dates },
    });
    ref.afterClosed().subscribe(async (result: BatchQuickEntryDialogResult | undefined) => {
      if (!result) return;
      await this.svc.saveBatchEntries(dates, result.type);
    });
  }

  async onDeleteEntry(id: string): Promise<void> {
    await this.svc.deleteEntry(id);
    this.snackbar.open(this.translate.instant('reports.entryDeleted'), 'OK', { duration: 3000 });
  }

  onLogin(): void {
    this.svc.navigateToLogin();
  }

  // ── Private ──────────────────────────────────────────────────────────────────

  private _parseTime(baseDate: Date, timeStr: string): Date {
    const [h, m] = timeStr.split(':').map(Number);
    const d = new Date(baseDate);
    d.setHours(h, m, 0, 0);
    return d;
  }
}
