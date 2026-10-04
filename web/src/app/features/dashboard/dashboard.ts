import {
  ChangeDetectionStrategy, Component, ElementRef, Injector, afterNextRender, computed, effect, inject, untracked, viewChild,
} from '@angular/core';
import { LiveAnnouncer } from '@angular/cdk/a11y';
import { DatePipe } from '@angular/common';
import { MatButtonModule } from '@angular/material/button';
import { MatCardModule } from '@angular/material/card';
import { MatChipsModule } from '@angular/material/chips';
import { MatDialog } from '@angular/material/dialog';
import { MatDividerModule } from '@angular/material/divider';
import { MatIconModule } from '@angular/material/icon';
import { MatProgressSpinnerModule } from '@angular/material/progress-spinner';
import { MatSnackBar } from '@angular/material/snack-bar';
import { MatTooltipModule } from '@angular/material/tooltip';
import { TranslatePipe, TranslateService } from '@ngx-translate/core';
import { firstValueFrom } from 'rxjs';
import { BreakNamePipe } from '../../shared/pipes/break-name.pipe';
import { DashboardService } from './dashboard.service';
import { EditBreakDialogComponent, EditBreakDialogData, EditBreakDialogResult } from './components/edit-break-dialog/edit-break-dialog';
import { RestartSessionDialogComponent, RestartSessionDialogResult } from './components/restart-session-dialog/restart-session-dialog';
import { AdjustOvertimeDialogComponent, AdjustOvertimeDialogResult } from '../settings/components/adjust-overtime-dialog/adjust-overtime-dialog';
import { TimeInputComponent } from '../../shared/components/time-input/time-input';
import { Break } from '../../shared/models/index';
import { Router } from '@angular/router';
import { LeaveBalanceService } from '../../core/services/leave-balance';
import { LanguageService } from '../../core/services/language';
import { formatEntryDay, formatHm } from '../../domain/utils/open-entry.utils';
import { OpenEntryBannerComponent } from '../../shared/components/open-entry-banner/open-entry-banner';
import { OpenEntryService } from './open-entry';
import { OpenEntryCandidate } from './open-entry-close';
import {
  OpenEntryEndDialogComponent, OpenEntryEndDialogData, OpenEntryEndDialogResult,
} from './components/open-entry-end-dialog/open-entry-end-dialog';
import { HolidayBannerComponent } from '../../shared/components/holiday-banner/holiday-banner';
import { LeaveBalanceCardComponent } from '../../shared/components/leave-balance-card/leave-balance-card';

@Component({
  selector: 'app-dashboard',
  imports: [
    DatePipe,
    MatButtonModule,
    MatCardModule,
    MatChipsModule,
    MatDividerModule,
    MatIconModule,
    MatProgressSpinnerModule,
    MatTooltipModule,
    TimeInputComponent,
    LeaveBalanceCardComponent,
    HolidayBannerComponent,
    OpenEntryBannerComponent,
    TranslatePipe,
    BreakNamePipe,
  ],
  templateUrl: './dashboard.html',
  styleUrl: './dashboard.scss',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class DashboardComponent {
  protected readonly svc    = inject(DashboardService);
  protected readonly leave  = inject(LeaveBalanceService);
  private  readonly dialog  = inject(MatDialog);
  private  readonly router  = inject(Router);
  protected readonly openEntry = inject(OpenEntryService);
  private  readonly language = inject(LanguageService);
  private  readonly snackBar = inject(MatSnackBar);
  private  readonly translate = inject(TranslateService);
  private  readonly announcer = inject(LiveAnnouncer);
  private  readonly injector = inject(Injector);

  private readonly banner = viewChild(OpenEntryBannerComponent);
  private readonly focusAnchor = viewChild<ElementRef<HTMLElement>>('focusAnchor');

  /** Daten des aktuellen Banners für offene Einträge vor heute (#385), `null` = kein Banner. */
  protected readonly openBanner = computed(() => {
    const candidate = this.openEntry.current();
    if (!candidate) return null;
    const start = this.openEntry.entryOf(candidate.id)?.workStart;
    return {
      candidate,
      dateText: formatEntryDay(candidate.id, this.language.locale()),
      time: start ? formatHm(start) : '',
    };
  });

  private readonly announced = new Set<string>();
  private lastClosedCount = 0;
  private endDialogOpen = false;

  constructor() {
    this.lastClosedCount = this.openEntry.closedCount();

    // Einmalige, höfliche Ansage je Eintrag beim ersten Erscheinen (eingefügte Live-Regionen sind nicht überall zuverlässig).
    effect(() => {
      const view = this.openBanner();
      if (!view) return;
      untracked(() => {
        const key = `${view.candidate.profileId}|${view.candidate.id}`;
        if (this.announced.has(key)) return;
        this.announced.add(key);
        const text = this.translate.instant('dashboard.openEntryBannerTitle', { date: view.dateText, time: view.time });
        void this.announcer.announce(text, 'polite');
      });
    });

    // Fehler beim Beenden: Snackbar (jedes Vorkommen ist ein neues Objekt); der Banner bleibt.
    effect(() => {
      const error = this.openEntry.saveError();
      if (!error) return;
      untracked(() => this.snackBar.open(this.translate.instant('dashboard.openEntrySaveError'), 'OK', { duration: 5000 }));
    });

    // Nach dem Entfall eines Banners: Fokus auf den nächsten Banner, sonst auf einen stabilen Anker (kein Fokusverlust).
    effect(() => {
      const count = this.openEntry.closedCount();
      untracked(() => {
        if (count === this.lastClosedCount) return;
        this.lastClosedCount = count;
        afterNextRender(() => {
          const next = this.banner();
          if (next) next.focus();
          else this.focusAnchor()?.nativeElement.focus();
        }, { injector: this.injector });
      });
    });
  }

  async onEndOpenEntry(candidate: OpenEntryCandidate): Promise<void> {
    if (this.endDialogOpen) return;
    this.endDialogOpen = true;
    try {
      const data = await this.openEntry.prepareEnd(candidate);
      if (!data) return;
      const ref = this.dialog.open<OpenEntryEndDialogComponent, OpenEntryEndDialogData, OpenEntryEndDialogResult>(
        OpenEntryEndDialogComponent, { data, maxWidth: '95vw' });
      const end = await firstValueFrom(ref.afterClosed());
      if (!end) return;
      await this.openEntry.endEntry(candidate, end);
    } finally {
      this.endDialogOpen = false;
    }
  }

  goToSettings(): void {
    void this.router.navigate(['/settings']);
  }

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

  openAdjustOvertimeDialog(): void {
    const ref = this.dialog.open(AdjustOvertimeDialogComponent, {
      data: { currentOvertimeMs: this.svc.totalOvertime() ?? 0 },
    });
    ref.afterClosed().subscribe(async (result: AdjustOvertimeDialogResult | undefined) => {
      if (!result) return;
      const ms = result === 'reset' ? 0 : result.overtimeMs;
      await this.svc.updateInitialOvertime(ms);
    });
  }

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
