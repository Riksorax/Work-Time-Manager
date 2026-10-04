import { ChangeDetectionStrategy, Component, inject } from '@angular/core';
import { MAT_DIALOG_DATA, MatDialogModule, MatDialogRef } from '@angular/material/dialog';
import { MatButtonModule } from '@angular/material/button';
import { TranslatePipe } from '@ngx-translate/core';

export interface ConfirmSwitchWhileRunningData { from: string; to: string }

/** Bestätigung beim Profilwechsel mit laufender Zeiterfassung (#380): „Abbrechen" (Standard-Fokus) oder
 * „Beenden und wechseln". Esc/Backdrop schließen ohne Ergebnis (= Abbrechen). */
@Component({
  selector: 'app-confirm-switch-while-running-dialog',
  imports: [MatDialogModule, MatButtonModule, TranslatePipe],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <h2 mat-dialog-title>{{ 'shared.switchWhileRunningTitle' | translate }}</h2>
    <mat-dialog-content>
      <p>{{ 'shared.switchWhileRunningText' | translate: { from: data.from, to: data.to } }}</p>
    </mat-dialog-content>
    <mat-dialog-actions align="end">
      <button mat-button cdkFocusInitial mat-dialog-close>{{ 'common.cancel' | translate }}</button>
      <button mat-flat-button (click)="confirm()">{{ 'shared.stopAndSwitchButton' | translate }}</button>
    </mat-dialog-actions>
  `,
})
export class ConfirmSwitchWhileRunningDialogComponent {
  private readonly dialogRef = inject(MatDialogRef<ConfirmSwitchWhileRunningDialogComponent>);
  protected readonly data    = inject<ConfirmSwitchWhileRunningData>(MAT_DIALOG_DATA);

  confirm(): void { this.dialogRef.close(true); }
}
