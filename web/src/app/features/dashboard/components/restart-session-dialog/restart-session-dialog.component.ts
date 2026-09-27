import { ChangeDetectionStrategy, Component, inject } from '@angular/core';
import { MatButtonModule } from '@angular/material/button';
import { MatDialogModule, MatDialogRef } from '@angular/material/dialog';
import { MatIconModule } from '@angular/material/icon';
import { TranslatePipe } from '@ngx-translate/core';

export type RestartSessionDialogResult = 'keep-breaks' | 'discard-breaks' | null;

@Component({
  selector: 'app-restart-session-dialog',
  imports: [MatButtonModule, MatDialogModule, MatIconModule, TranslatePipe],
  template: `
    <h2 mat-dialog-title>{{ 'dashboard.restartSessionTitle' | translate }}</h2>

    <mat-dialog-content>
      <p>{{ 'dashboard.restartSessionText' | translate }}</p>
    </mat-dialog-content>

    <mat-dialog-actions align="end">
      <button mat-button mat-dialog-close [attr.aria-label]="'common.cancel' | translate">{{ 'common.cancel' | translate }}</button>
      <button mat-stroked-button (click)="confirm(false)" [attr.aria-label]="'dashboard.discardBreaksAria' | translate">
        {{ 'dashboard.discardBreaksButton' | translate }}
      </button>
      <button mat-flat-button (click)="confirm(true)" [attr.aria-label]="'dashboard.keepBreaksAria' | translate">
        {{ 'dashboard.keepBreaksButton' | translate }}
      </button>
    </mat-dialog-actions>
  `,
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class RestartSessionDialogComponent {
  private readonly dialogRef = inject(MatDialogRef<RestartSessionDialogComponent, RestartSessionDialogResult>);

  confirm(keepBreaks: boolean): void {
    this.dialogRef.close(keepBreaks ? 'keep-breaks' : 'discard-breaks');
  }
}
