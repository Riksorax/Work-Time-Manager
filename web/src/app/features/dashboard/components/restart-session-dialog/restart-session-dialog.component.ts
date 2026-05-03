import { ChangeDetectionStrategy, Component, inject } from '@angular/core';
import { MatButtonModule } from '@angular/material/button';
import { MatDialogModule, MatDialogRef } from '@angular/material/dialog';
import { MatIconModule } from '@angular/material/icon';

export type RestartSessionDialogResult = 'keep-breaks' | 'discard-breaks' | null;

@Component({
  selector: 'app-restart-session-dialog',
  imports: [MatButtonModule, MatDialogModule, MatIconModule],
  template: `
    <h2 mat-dialog-title>Neue Session starten?</h2>

    <mat-dialog-content>
      <p>Der heutige Arbeitstag wurde bereits beendet. Möchtest du eine neue Session starten?</p>
    </mat-dialog-content>

    <mat-dialog-actions align="end">
      <button mat-button mat-dialog-close aria-label="Abbrechen">Abbrechen</button>
      <button mat-stroked-button (click)="confirm(false)" aria-label="Pausen verwerfen">
        Pausen verwerfen
      </button>
      <button mat-flat-button (click)="confirm(true)" aria-label="Pausen behalten">
        Pausen behalten
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
