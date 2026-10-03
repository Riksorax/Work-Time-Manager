import { ChangeDetectionStrategy, Component, inject, signal } from '@angular/core';
import { DatePipe } from '@angular/common';
import { MatButtonModule } from '@angular/material/button';
import { MatDialog } from '@angular/material/dialog';
import { MatDividerModule } from '@angular/material/divider';
import { MatIconModule } from '@angular/material/icon';
import { MatProgressSpinnerModule } from '@angular/material/progress-spinner';
import { MatSnackBar } from '@angular/material/snack-bar';
import { MatTabsModule } from '@angular/material/tabs';
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
import { WebPremiumService } from '../../core/services/web-premium';
import { WorkEntry, WorkEntryType } from '../../shared/models/index';
import { toDateKey } from '../../domain/services/report-calculator';
import { Router } from '@angular/router';
import { LeaveBalanceService } from '../../core/services/leave-balance';
import { LeaveBalanceCardComponent } from '../../shared/components/leave-balance-card/leave-balance-card';

@Component({
  selector: 'app-reports',
  imports: [
    DatePipe,
    MatButtonModule,
    MatDividerModule,
    MatIconModule,
    MatProgressSpinnerModule,
    MatTabsModule,
    CalendarComponent,
    LeaveBalanceCardComponent,
    TranslatePipe,
  ],
  templateUrl: './reports.html',
  styleUrl: './reports.scss',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class ReportsComponent {
  protected readonly svc        = inject(ReportsService);
  protected readonly leave      = inject(LeaveBalanceService);
  private  readonly router      = inject(Router);
  private  readonly premiumSvc  = inject(WebPremiumService);
  private  readonly dialog      = inject(MatDialog);
  private  readonly snackbar    = inject(MatSnackBar);
  private  readonly translate   = inject(TranslateService);
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

  formatDuration(ms: number): string {
    if (!isFinite(ms)) return '00:00';
    const abs = Math.abs(ms);
    const h   = Math.floor(abs / 3600000);
    const m   = Math.floor((abs % 3600000) / 60000);
    return `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}`;
  }

  formatOvertime(ms: number): string {
    if (!isFinite(ms)) return '+00:00';
    const sign = ms >= 0 ? '+' : '-';
    const abs  = Math.abs(ms);
    const h    = Math.floor(abs / 3600000);
    const m    = Math.floor((abs % 3600000) / 60000);
    return `${sign}${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}`;
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
