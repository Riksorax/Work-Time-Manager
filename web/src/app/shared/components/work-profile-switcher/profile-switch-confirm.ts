import { Injectable, inject } from '@angular/core';
import { MatDialog } from '@angular/material/dialog';
import { MatSnackBar } from '@angular/material/snack-bar';
import { TranslateService } from '@ngx-translate/core';
import { firstValueFrom } from 'rxjs';
import { ProfileSwitchRequest, WorkProfileService } from '../../../core/services/work-profile';
import { ConfirmSwitchWhileRunningDialogComponent } from './confirm-switch-while-running-dialog';

/**
 * Dialog und Fehlermeldung für den Profilwechsel mit laufender Zeiterfassung (#380). Eigener Service, damit
 * `DashboardService` weder `MatDialog` noch `TranslateService` kennen muss.
 */
@Injectable({ providedIn: 'root' })
export class ProfileSwitchConfirmService {
  private readonly dialog      = inject(MatDialog);
  private readonly snackBar    = inject(MatSnackBar);
  private readonly translate   = inject(TranslateService);
  private readonly workProfile = inject(WorkProfileService);

  /** `true` = „Beenden und wechseln"; Abbrechen, Esc und Backdrop liefern `false`. */
  async confirmStopAndSwitch(req: ProfileSwitchRequest): Promise<boolean> {
    const nameOf = (id: string): string => this.workProfile.profiles().find(p => p.id === id)?.name ?? id;
    const ref = this.dialog.open(ConfirmSwitchWhileRunningDialogComponent, {
      data: { from: nameOf(req.from), to: req.toName ?? (req.to === null ? '' : nameOf(req.to)) },
    });
    return (await firstValueFrom(ref.afterClosed())) === true;
  }

  notifySaveFailed(): void {
    this.snackBar.open(this.translate.instant('shared.switchSaveFailed'), 'OK', { duration: 5000 });
  }
}
