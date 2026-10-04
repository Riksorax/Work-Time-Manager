import { ChangeDetectionStrategy, Component, inject } from '@angular/core';
import { DatePipe } from '@angular/common';
import { MatButtonModule } from '@angular/material/button';
import { firstValueFrom } from 'rxjs';
import { MatDialog } from '@angular/material/dialog';
import { MatDividerModule } from '@angular/material/divider';
import { MatIconModule } from '@angular/material/icon';
import { MatListModule } from '@angular/material/list';
import { MatProgressSpinnerModule } from '@angular/material/progress-spinner';
import { MatSlideToggleModule } from '@angular/material/slide-toggle';
import { MatSnackBar } from '@angular/material/snack-bar';
import { MatButtonToggleModule } from '@angular/material/button-toggle';
import { TranslatePipe, TranslateService } from '@ngx-translate/core';
import { SettingsPageService } from './settings.service';
import { formatWorkdays as formatWorkdaysUtil } from '../../shared/utils/weekday-labels.util';
import {
  EditTargetHoursDialogComponent,
  EditTargetHoursDialogResult,
} from './components/edit-target-hours-dialog/edit-target-hours-dialog';
import {
  EditWorkdaysDialogComponent,
  EditWorkdaysDialogResult,
} from './components/edit-workdays-dialog/edit-workdays-dialog';
import {
  AdjustOvertimeDialogComponent,
  AdjustOvertimeDialogResult,
} from './components/adjust-overtime-dialog/adjust-overtime-dialog';
import {
  EditVacationDaysDialogComponent,
  EditVacationDaysDialogResult,
} from './components/edit-vacation-days-dialog/edit-vacation-days-dialog';
import {
  EditBundeslandDialogComponent,
  EditBundeslandDialogResult,
} from './components/edit-bundesland-dialog/edit-bundesland-dialog';
import { LeaveBalanceService } from '../../core/services/leave-balance';
import { DEFAULT_VACATION_DAYS_PER_YEAR } from '../../shared/models/index';
import { LeaveBalanceCardComponent } from '../../shared/components/leave-balance-card/leave-balance-card';

@Component({
  selector: 'app-settings',
  imports: [
    DatePipe,
    MatButtonModule,
    MatDividerModule,
    MatIconModule,
    MatListModule,
    MatProgressSpinnerModule,
    MatSlideToggleModule,
    MatButtonToggleModule,
    LeaveBalanceCardComponent,
    TranslatePipe,
  ],
  templateUrl: './settings.html',
  styleUrl: './settings.scss',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class SettingsComponent {
  protected readonly svc      = inject(SettingsPageService);
  protected readonly leave    = inject(LeaveBalanceService);
  private  readonly dialog    = inject(MatDialog);
  private  readonly snackbar  = inject(MatSnackBar);
  private  readonly translate = inject(TranslateService);

  // ── Template helpers ────────────────────────────────────────────────────────

  formatOvertime(ms: number): string {
    const sign = ms >= 0 ? '+' : '-';
    const abs  = Math.abs(ms);
    const h    = Math.floor(abs / 3600000);
    const m    = Math.floor((abs % 3600000) / 60000);
    return `${sign}${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}`;
  }

  dailyTargetHours(): string {
    return this.svc.dailyTargetHours();
  }

  formatWorkdays(workdays: number[]): string {
    return formatWorkdaysUtil(workdays, this.translate.instant('common.weekdaysShort'));
  }

  // ── Actions ─────────────────────────────────────────────────────────────────

  openEditTargetHoursDialog(): void {
    const ref = this.dialog.open(EditTargetHoursDialogComponent, {
      data: { currentHours: this.svc.settings()?.weeklyTargetHours ?? 40 },
    });
    ref.afterClosed().subscribe(async (result: EditTargetHoursDialogResult | undefined) => {
      if (!result) return;
      await this.svc.setTargetHours(result.hours);
      this.snackbar.open(this.translate.instant('settings.targetHoursSaved'), 'OK', { duration: 2500 });
    });
  }

  openEditWorkdaysDialog(): void {
    const ref = this.dialog.open(EditWorkdaysDialogComponent, {
      data: { currentDays: this.svc.settings()?.workdays ?? [1, 2, 3, 4, 5] },
    });
    ref.afterClosed().subscribe(async (result: EditWorkdaysDialogResult | undefined) => {
      if (!result) return;
      await this.svc.setWorkdays(result.days);
      this.snackbar.open(this.translate.instant('settings.workdaysSaved'), 'OK', { duration: 2500 });
    });
  }

  async openEditVacationDaysDialog(): Promise<void> {
    const ref = this.dialog.open(EditVacationDaysDialogComponent, {
      data: { currentDays: this.svc.settings()?.vacationDaysPerYear ?? DEFAULT_VACATION_DAYS_PER_YEAR },
    });
    const result: EditVacationDaysDialogResult | undefined = await firstValueFrom(ref.afterClosed());
    if (!result) return;
    try {
      await this.svc.setVacationDays(result.days);
      this.snackbar.open(this.translate.instant('settings.vacationDaysSaved'), 'OK', { duration: 2500 });
    } catch {
      this.snackbar.open(this.translate.instant('settings.vacationDaysSaveError'), 'OK', { duration: 4000 });
    }
  }

  async openEditBundeslandDialog(): Promise<void> {
    const ref = this.dialog.open(EditBundeslandDialogComponent, {
      data: { current: this.svc.settings()?.bundesland ?? null },
    });
    const result: EditBundeslandDialogResult | undefined = await firstValueFrom(ref.afterClosed());
    if (!result) return;
    try {
      await this.svc.setBundesland(result.bundesland);
      this.snackbar.open(this.translate.instant('settings.bundesland.saved'), 'OK', { duration: 2500 });
    } catch {
      this.snackbar.open(this.translate.instant('settings.bundesland.saveError'), 'OK', { duration: 4000 });
    }
  }

  openAdjustOvertimeDialog(): void {
    const ref = this.dialog.open(AdjustOvertimeDialogComponent, {
      data: { currentOvertimeMs: this.svc.overtimeMs() },
    });
    ref.afterClosed().subscribe(async (result: AdjustOvertimeDialogResult | undefined) => {
      if (!result) return;
      const ms = result === 'reset' ? 0 : result.overtimeMs;
      await this.svc.setOvertime(ms);
      this.snackbar.open(this.translate.instant('settings.overtimeSaved'), 'OK', { duration: 2500 });
    });
  }

  onThemeToggle(dark: boolean): void {
    this.svc.setTheme(dark);
  }

  onLocaleChange(locale: string): void {
    this.svc.setLocale(locale);
  }

  onDeleteAccount(): void {
    const ref = this.dialog.open(
      // Inline confirm dialog via MatDialog
      ConfirmDeleteDialogComponent,
    );
    ref.afterClosed().subscribe(async (confirmed: boolean | undefined) => {
      if (!confirmed) return;
      try {
        await this.svc.deleteAccount();
      } catch (e: unknown) {
        const msg = e instanceof Error && e.message.includes('requires-recent-login')
          ? this.translate.instant('settings.deleteAccountReauth')
          : this.translate.instant('settings.deleteAccountFailed');
        this.snackbar.open(msg, 'OK', { duration: 5000 });
      }
    });
  }

  async onRestorePurchases(): Promise<void> {
    try {
      const restored = await this.svc.restorePurchases();
      this.snackbar.open(
        this.translate.instant(restored ? 'settings.restoreSuccess' : 'settings.restoreNotFound'),
        'OK',
        { duration: 4000 },
      );
    } catch {
      this.snackbar.open(this.translate.instant('settings.restoreError'), 'OK', { duration: 4000 });
    }
  }

  async onPresentPaywall(): Promise<void> {
    try {
      const purchased = await this.svc.presentPaywall();
      if (purchased) {
        this.snackbar.open(this.translate.instant('settings.purchaseSuccess'), 'OK', { duration: 4000 });
      }
    } catch (e: unknown) {
      const msg = e instanceof Error ? e.message : this.translate.instant('settings.purchaseError');
      this.snackbar.open(msg, 'OK', { duration: 4000 });
    }
  }

  async onSync(): Promise<void> {
    const result = await this.svc.sync();
    if (result.errors.length === 0) {
      const parts = [
        this.translate.instant('settings.syncEntriesCount', { count: result.workEntriesSynced }),
      ];
      if (result.settingsSynced) parts.push(this.translate.instant('settings.title'));
      if (result.overtimeSynced) parts.push(this.translate.instant('settings.syncOvertimeLabel'));
      this.snackbar.open(
        this.translate.instant('settings.syncSuccess', { parts: parts.join(', ') }),
        'OK',
        { duration: 4000 }
      );
    } else {
      this.snackbar.open(
        this.translate.instant('settings.syncErrors', { errors: result.errors.join(', ') }),
        'OK',
        { duration: 5000 }
      );
    }
  }
}

// ── Inline Bestätigungs-Dialog ────────────────────────────────────────────────

import { MatDialogModule, MatDialogRef } from '@angular/material/dialog';

@Component({
  selector: 'app-confirm-delete-dialog',
  imports: [MatDialogModule, MatButtonModule, TranslatePipe],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <h2 mat-dialog-title>{{ 'settings.deleteAccountAria' | translate }}</h2>
    <mat-dialog-content>
      <p>{{ 'settings.deleteAccountWarning' | translate }}</p>
    </mat-dialog-content>
    <mat-dialog-actions align="end">
      <button mat-button mat-dialog-close>{{ 'common.cancel' | translate }}</button>
      <button mat-flat-button
              [style.background-color]="'var(--mat-sys-error)'"
              [style.color]="'var(--mat-sys-on-error)'"
              (click)="confirm()"
              [attr.aria-label]="'settings.deleteAccountAria' | translate">
        {{ 'settings.deleteAccountConfirm' | translate }}
      </button>
    </mat-dialog-actions>
  `,
})
export class ConfirmDeleteDialogComponent {
  private readonly dialogRef = inject(MatDialogRef<ConfirmDeleteDialogComponent>);
  confirm(): void { this.dialogRef.close(true); }
}
