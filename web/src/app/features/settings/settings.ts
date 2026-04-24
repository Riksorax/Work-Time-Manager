import { ChangeDetectionStrategy, Component, inject } from '@angular/core';
import { DatePipe } from '@angular/common';
import { MatButtonModule } from '@angular/material/button';
import { MatDialog } from '@angular/material/dialog';
import { MatDividerModule } from '@angular/material/divider';
import { MatIconModule } from '@angular/material/icon';
import { MatListModule } from '@angular/material/list';
import { MatProgressSpinnerModule } from '@angular/material/progress-spinner';
import { MatSlideToggleModule } from '@angular/material/slide-toggle';
import { MatSnackBar } from '@angular/material/snack-bar';
import { SettingsPageService } from './settings.service';
import {
  EditTargetHoursDialogComponent,
  EditTargetHoursDialogResult,
} from './components/edit-target-hours-dialog/edit-target-hours-dialog.component';
import {
  EditWorkdaysDialogComponent,
  EditWorkdaysDialogResult,
} from './components/edit-workdays-dialog/edit-workdays-dialog.component';
import {
  AdjustOvertimeDialogComponent,
  AdjustOvertimeDialogResult,
} from './components/adjust-overtime-dialog/adjust-overtime-dialog.component';

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
  ],
  templateUrl: './settings.html',
  styleUrl: './settings.scss',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class SettingsComponent {
  protected readonly svc      = inject(SettingsPageService);
  private  readonly dialog    = inject(MatDialog);
  private  readonly snackbar  = inject(MatSnackBar);

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

  // ── Actions ─────────────────────────────────────────────────────────────────

  openEditTargetHoursDialog(): void {
    const ref = this.dialog.open(EditTargetHoursDialogComponent, {
      data: { currentHours: this.svc.settings()?.weeklyTargetHours ?? 40 },
    });
    ref.afterClosed().subscribe(async (result: EditTargetHoursDialogResult | undefined) => {
      if (!result) return;
      await this.svc.setTargetHours(result.hours);
      this.snackbar.open('Soll-Arbeitsstunden gespeichert', 'OK', { duration: 2500 });
    });
  }

  openEditWorkdaysDialog(): void {
    const ref = this.dialog.open(EditWorkdaysDialogComponent, {
      data: { currentDays: this.svc.settings()?.workdaysPerWeek ?? 5 },
    });
    ref.afterClosed().subscribe(async (result: EditWorkdaysDialogResult | undefined) => {
      if (!result) return;
      await this.svc.setWorkdays(result.days);
      this.snackbar.open('Arbeitstage gespeichert', 'OK', { duration: 2500 });
    });
  }

  openAdjustOvertimeDialog(): void {
    const ref = this.dialog.open(AdjustOvertimeDialogComponent, {
      data: { currentOvertimeMs: this.svc.overtimeMs() },
    });
    ref.afterClosed().subscribe(async (result: AdjustOvertimeDialogResult | undefined) => {
      if (!result) return;
      const ms = result === 'reset' ? 0 : result.overtimeMs;
      await this.svc.setOvertime(ms);
      this.snackbar.open('Gleitzeit-Bilanz gespeichert', 'OK', { duration: 2500 });
    });
  }

  onThemeToggle(dark: boolean): void {
    this.svc.setTheme(dark);
  }

  onLogin(): void {
    this.svc.navigateToLogin();
  }

  onLogout(): void {
    this.svc.logout();
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
          ? 'Bitte erneut anmelden und dann erneut versuchen.'
          : 'Account konnte nicht gelöscht werden.';
        this.snackbar.open(msg, 'OK', { duration: 5000 });
      }
    });
  }

  async onSync(): Promise<void> {
    const result = await this.svc.sync();
    if (result.errors.length === 0) {
      this.snackbar.open(
        `Synchronisierung erfolgreich! Einträge: ${result.workEntriesSynced}`,
        'OK',
        { duration: 4000 }
      );
    } else {
      this.snackbar.open(
        `Synchronisierung mit Fehlern: ${result.errors.join(', ')}`,
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
  imports: [MatDialogModule, MatButtonModule],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <h2 mat-dialog-title>Account endgültig löschen</h2>
    <mat-dialog-content>
      <p>
        Warnung: Diese Aktion kann nicht rückgängig gemacht werden.
        Alle Ihre Daten werden dauerhaft gelöscht.
      </p>
    </mat-dialog-content>
    <mat-dialog-actions align="end">
      <button mat-button mat-dialog-close>Abbrechen</button>
      <button mat-flat-button
              [style.background-color]="'var(--mat-sys-error)'"
              [style.color]="'var(--mat-sys-on-error)'"
              (click)="confirm()"
              aria-label="Account endgültig löschen">
        Endgültig löschen
      </button>
    </mat-dialog-actions>
  `,
})
export class ConfirmDeleteDialogComponent {
  private readonly dialogRef = inject(MatDialogRef<ConfirmDeleteDialogComponent>);
  confirm(): void { this.dialogRef.close(true); }
}
