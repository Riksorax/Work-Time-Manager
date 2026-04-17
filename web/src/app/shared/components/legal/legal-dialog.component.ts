import { ChangeDetectionStrategy, Component, inject, input } from '@angular/core';
import { MatButtonModule } from '@angular/material/button';
import { MatDialogModule, MatDialogRef, MAT_DIALOG_DATA } from '@angular/material/dialog';
import { MatIconModule } from '@angular/material/icon';

export interface LegalDialogData {
  title: string;
  content: string;
}

@Component({
  selector: 'wtm-legal-dialog',
  standalone: true,
  imports: [MatButtonModule, MatDialogModule, MatIconModule],
  changeDetection: ChangeDetectionStrategy.OnPush,
  styles: [`
    h2[mat-dialog-title] { display: flex; align-items: center; gap: 8px; }

    [mat-dialog-content] {
      max-height: 60vh;
      overflow-y: auto;
      white-space: pre-wrap;
      font-size: 0.875rem;
      line-height: 1.6;
      color: var(--mat-sys-on-surface-variant);
    }
  `],
  template: `
    <h2 mat-dialog-title>
      <mat-icon>gavel</mat-icon>
      {{ data.title }}
    </h2>
    <div mat-dialog-content>{{ data.content }}</div>
    <div mat-dialog-actions align="end">
      <button mat-flat-button mat-dialog-close>Schließen</button>
    </div>
  `,
})
export class LegalDialogComponent {
  protected data: LegalDialogData = inject(MAT_DIALOG_DATA);
}
