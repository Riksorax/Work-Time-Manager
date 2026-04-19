import { ChangeDetectionStrategy, Component, inject } from '@angular/core';
import { DatePipe } from '@angular/common';
import { MatButtonModule } from '@angular/material/button';
import { MatCardModule } from '@angular/material/card';
import { MatChipsModule } from '@angular/material/chips';
import { MatDialog } from '@angular/material/dialog';
import { MatDividerModule } from '@angular/material/divider';
import { MatIconModule } from '@angular/material/icon';
import { MatListModule } from '@angular/material/list';
import { MatProgressSpinnerModule } from '@angular/material/progress-spinner';
import { MatTooltipModule } from '@angular/material/tooltip';
import { DashboardService } from './dashboard.service';
import { EditBreakDialogComponent, EditBreakDialogData, EditBreakDialogResult } from './components/edit-break-dialog/edit-break-dialog.component';
import { RestartSessionDialogComponent, RestartSessionDialogResult } from './components/restart-session-dialog/restart-session-dialog.component';
import { TimeInputComponent } from '../../shared/components/time-input/time-input.component';
import { Break } from '../../shared/models/index';

@Component({
  selector: 'app-dashboard',
  imports: [
    DatePipe,
    MatButtonModule,
    MatCardModule,
    MatChipsModule,
    MatDividerModule,
    MatIconModule,
    MatListModule,
    MatProgressSpinnerModule,
    MatTooltipModule,
    TimeInputComponent,
  ],
  templateUrl: './dashboard.html',
  styleUrl: './dashboard.scss',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class DashboardComponent {
  protected readonly svc    = inject(DashboardService);
  private  readonly dialog  = inject(MatDialog);

  // ─── Template helpers ────────────────────────────────────────────────────────

  formatDuration(ms: number | null): string {
    if (ms === null) return '00:00:00';
    const abs = Math.abs(ms);
    const h   = Math.floor(abs / 3600000);
    const m   = Math.floor((abs % 3600000) / 60000);
    const s   = Math.floor((abs % 60000) / 1000);
    return `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
  }

  formatOvertime(ms: number | null): string {
    if (ms === null) return '+00:00';
    const sign = ms >= 0 ? '+' : '-';
    const abs  = Math.abs(ms);
    const h    = Math.floor(abs / 3600000);
    const m    = Math.floor((abs % 3600000) / 60000);
    return `${sign}${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}`;
  }

  // ─── Actions ─────────────────────────────────────────────────────────────────

  async onMainAction(): Promise<void> {
    const result = await this.svc.startOrStopTimer();
    if (result === 'restart-dialog') {
      const ref = this.dialog.open<RestartSessionDialogComponent, undefined, RestartSessionDialogResult>(
        RestartSessionDialogComponent
      );
      ref.afterClosed().subscribe(async choice => {
        if (choice === 'keep-breaks')    await this.svc.startNewSession(true);
        if (choice === 'discard-breaks') await this.svc.startNewSession(false);
      });
    }
  }

  async onBreakAction(): Promise<void> {
    await this.svc.startOrStopBreak();
  }

  async onStartTimeSelected(timeStr: string): Promise<void> {
    await this.svc.setManualStartTime(timeStr);
  }

  async onEndTimeSelected(timeStr: string): Promise<void> {
    await this.svc.setManualEndTime(timeStr);
  }

  async onClearEndTime(): Promise<void> {
    await this.svc.clearEndTime();
  }

  onEditBreak(b: Break): void {
    const entry = this.svc.workEntry();
    const ref = this.dialog.open<EditBreakDialogComponent, EditBreakDialogData, EditBreakDialogResult>(
      EditBreakDialogComponent,
      { data: { break: b, entryDate: entry.date } }
    );
    ref.afterClosed().subscribe(async result => {
      if (result) await this.svc.updateBreak(result.updated);
    });
  }

  async onDeleteBreak(id: string): Promise<void> {
    await this.svc.deleteBreak(id);
  }
}
