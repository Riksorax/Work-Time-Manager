import { ChangeDetectionStrategy, Component, inject, signal, viewChild } from '@angular/core';
import { MAT_DIALOG_DATA, MatDialogModule, MatDialogRef } from '@angular/material/dialog';
import { MatButtonModule } from '@angular/material/button';
import { TranslatePipe } from '@ngx-translate/core';
import { normalizeWorkLocations } from '../../utils/work-locations.util';
import { WorkLocationsInputComponent } from '../work-locations-input/work-locations-input';

export interface WorkLocationsDialogData { locations: string[]; }
export interface WorkLocationsDialogResult { locations: string[]; }

/**
 * Dialog „Arbeitsorte“ (#526): Orte hinzufügen, entfernen, speichern oder ohne Änderung abbrechen.
 * Das Ergebnis ist die bereinigte Liste (leer = alle Orte entfernen); Abbrechen liefert `undefined`.
 */
@Component({
  selector: 'app-work-locations-dialog',
  imports: [MatDialogModule, MatButtonModule, TranslatePipe, WorkLocationsInputComponent],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <h2 mat-dialog-title>{{ 'shared.workLocationDialogTitle' | translate }}</h2>
    <mat-dialog-content>
      <app-work-locations-input #input [(locations)]="locations" />
    </mat-dialog-content>
    <mat-dialog-actions align="end">
      <button mat-button mat-dialog-close>{{ 'common.cancel' | translate }}</button>
      <button mat-flat-button (click)="save()">{{ 'shared.workLocationSave' | translate }}</button>
    </mat-dialog-actions>
  `,
  styles: [`
    :host { display: block; }
    mat-dialog-content { min-width: min(360px, calc(95vw - 48px)); padding-top: 8px; }
  `],
})
export class WorkLocationsDialogComponent {
  private readonly dialogRef = inject(MatDialogRef<WorkLocationsDialogComponent, WorkLocationsDialogResult>);
  private readonly data      = inject<WorkLocationsDialogData>(MAT_DIALOG_DATA);
  private readonly input     = viewChild.required<WorkLocationsInputComponent>('input');

  protected readonly locations = signal<string[]>(normalizeWorkLocations(this.data.locations));

  save(): void {
    // Noch getippter Text zählt mit; ist er ungültig, bleibt der Dialog offen und erklärt es
    if (!this.input().commitPending()) return;
    this.dialogRef.close({ locations: normalizeWorkLocations(this.locations()) } satisfies WorkLocationsDialogResult);
  }
}
