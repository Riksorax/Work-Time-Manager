import { DestroyRef, Injectable, Injector, afterNextRender, inject, signal } from '@angular/core';
import { DOCUMENT } from '@angular/common';
import { firstValueFrom } from 'rxjs';
import { ApiClient } from '../../../../core/services/api-client';
import { LEAVE_NOW } from '../../../../core/services/leave-balance';
import { WorkProfileService } from '../../../../core/services/work-profile';
import { YearlyLeaveReport } from '../../../../domain/models/leave.models';
import { DEFAULT_WORK_PROFILE_ID } from '../../../../shared/models';

/** Klasse auf `<html>`: solange sie steht, druckt die Seite nur die Urlaubs- und Krankheitsauswertung (`styles.scss`). */
export const LEAVE_PRINT_CLASS = 'print-leave-report';

/** Inhalt der Druckansicht, beim Klick festgehalten (Jahr, Profil und Erstellungszeit ändern sich danach nicht mehr). */
export interface LeaveReportPrintData {
  report: YearlyLeaveReport;
  /** Laufendes Jahr: nur dann gelten Anspruch und Resturlaub. */
  isCurrentYear: boolean;
  /** Name des Zusatzprofils; `null` beim Standard-Profil. */
  profileName: string | null;
  createdAt: Date;
}

export type LeaveReportPrintResult = 'printed' | 'error' | 'busy';

/**
 * Urlaubs- und Krankheitsauswertung als Druckansicht (#284). Lädt die Werte für Jahr und aktives Profil frisch vom
 * Backend (`GET /api/reports/yearly/{year}`), rendert die Druckansicht und ruft erst danach `window.print()`.
 * Kein Offline-Fallback, keine Rechnung im Client. Von `ReportsComponent` bereitgestellt (nicht root).
 *
 * Getrennter Druck: Während des Drucks steht `LEAVE_PRINT_CLASS` auf `<html>`; die Druckregel blendet dann den
 * Jahres-Tab (`.print-area`) aus und die Auswertung ein. Ohne die Klasse erscheint die Auswertung nie im Druck.
 */
@Injectable()
export class LeaveReportPrintService {
  private readonly api         = inject(ApiClient);
  private readonly workProfile = inject(WorkProfileService);
  private readonly now         = inject(LEAVE_NOW);
  private readonly document    = inject(DOCUMENT);
  private readonly injector    = inject(Injector);

  private readonly _loading = signal(false);
  private readonly _data    = signal<LeaveReportPrintData | null>(null);
  private readonly _onAfterPrint = () => this.endPrintMode();

  readonly loading = this._loading.asReadonly();
  readonly data    = this._data.asReadonly();

  constructor() {
    inject(DestroyRef).onDestroy(() => this.endPrintMode());
  }

  /**
   * Lädt und druckt die Auswertung für `year`. `busy`: es lädt schon (Doppelklick); `error`: Laden fehlgeschlagen,
   * es öffnet sich kein Druckdialog. Das Premium-Gate prüft der Aufrufer.
   */
  async print(year: number): Promise<LeaveReportPrintResult> {
    if (this._loading()) return 'busy';
    this._loading.set(true);
    // Profil zum Klick festhalten: Daten und Profilname gehören zusammen, auch wenn während des Ladens gewechselt wird.
    const profileId = this.workProfile.activeProfileId();
    const apiProfileId = this.workProfile.activeProfileIdForApi;
    const profileName = profileId === DEFAULT_WORK_PROFILE_ID
      ? null
      : this.workProfile.profiles().find(p => p.id === profileId)?.name ?? null;
    let report: YearlyLeaveReport;
    try {
      report = await firstValueFrom(this.api.getYearlyLeave(year, apiProfileId));
    } catch {
      this._loading.set(false);
      return 'error';
    }
    const now = this.now();
    this._data.set({ report, isCurrentYear: year === now.getFullYear(), profileName, createdAt: now });
    this._loading.set(false);
    // Erst nach dem Rendern der Druckansicht drucken, sonst druckt der Browser den alten Stand.
    await new Promise<void>(resolve => afterNextRender(() => resolve(), { injector: this.injector }));
    this._startPrintMode();
    this.document.defaultView?.print();
    return 'printed';
  }

  /** Beendet den Druckmodus der Auswertung (nach dem Druck, vor dem Druck des Jahres-Tabs, beim Verlassen der Seite). */
  endPrintMode(): void {
    this.document.documentElement.classList.remove(LEAVE_PRINT_CLASS);
    this.document.defaultView?.removeEventListener('afterprint', this._onAfterPrint);
  }

  private _startPrintMode(): void {
    this.document.documentElement.classList.add(LEAVE_PRINT_CLASS);
    // `afterprint` statt „nach print()“: `print()` blockiert nicht in jedem Browser.
    this.document.defaultView?.addEventListener('afterprint', this._onAfterPrint, { once: true });
  }
}
