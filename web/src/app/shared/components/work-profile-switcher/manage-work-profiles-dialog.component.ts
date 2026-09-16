import { ChangeDetectionStrategy, Component, inject } from '@angular/core';
import { MAT_DIALOG_DATA, MatDialogModule, MatDialog, MatDialogRef } from '@angular/material/dialog';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatListModule } from '@angular/material/list';
import { MatSnackBar } from '@angular/material/snack-bar';
import { WorkProfileService } from '../../../core/services/work-profile';
import { WorkProfile } from '../../models';

/** Dialog zum Löschen zusätzlicher Arbeitszeit-Profile (siehe #238/#244). Das
 * Standard-Profil wird hier nicht aufgeführt - es kann nicht gelöscht werden. */
@Component({
  selector: 'app-manage-work-profiles-dialog',
  imports: [MatDialogModule, MatButtonModule, MatIconModule, MatListModule],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <h2 mat-dialog-title>Profile verwalten</h2>
    <mat-dialog-content>
      @if (additionalProfiles().length === 0) {
        <p>Keine zusätzlichen Profile vorhanden.</p>
      } @else {
        <mat-nav-list>
          @for (profile of additionalProfiles(); track profile.id) {
            <mat-list-item>
              <span matListItemTitle>{{ profile.name }}</span>
              <button mat-icon-button matListItemMeta (click)="confirmDelete(profile)"
                      aria-label="Profil löschen">
                <mat-icon>delete_outline</mat-icon>
              </button>
            </mat-list-item>
          }
        </mat-nav-list>
      }
    </mat-dialog-content>
    <mat-dialog-actions align="end">
      <button mat-button mat-dialog-close>Fertig</button>
    </mat-dialog-actions>
  `,
})
export class ManageWorkProfilesDialogComponent {
  private readonly dialogRef  = inject(MatDialogRef<ManageWorkProfilesDialogComponent>);
  private readonly dialog     = inject(MatDialog);
  private readonly snackBar   = inject(MatSnackBar);
  protected readonly workProfile = inject(WorkProfileService);

  protected readonly additionalProfiles = () =>
    this.workProfile.profiles().filter(p => p.id !== 'default');

  confirmDelete(profile: WorkProfile): void {
    const ref = this.dialog.open(ConfirmDeleteProfileDialogComponent, { data: { name: profile.name } });
    ref.afterClosed().subscribe(async (confirmed: boolean | undefined) => {
      if (!confirmed) return;
      try {
        await this.workProfile.deleteProfile(profile.id);
        this.snackBar.open(`Profil "${profile.name}" gelöscht.`, 'OK', { duration: 4000 });
        if (this.workProfile.profiles().length === 1) this.dialogRef.close();
      } catch (e) {
        this.snackBar.open(`Löschen fehlgeschlagen: ${e}`, 'OK', { duration: 5000 });
      }
    });
  }
}

@Component({
  selector: 'app-confirm-delete-profile-dialog',
  imports: [MatDialogModule, MatButtonModule],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <h2 mat-dialog-title>Profil löschen?</h2>
    <mat-dialog-content>
      <p>
        Profil "{{ data.name }}" und alle zugehörigen Arbeitseinträge,
        Überstunden und Einstellungen werden unwiderruflich gelöscht.
      </p>
    </mat-dialog-content>
    <mat-dialog-actions align="end">
      <button mat-button mat-dialog-close>Abbrechen</button>
      <button mat-flat-button
              [style.background-color]="'var(--mat-sys-error)'"
              [style.color]="'var(--mat-sys-on-error)'"
              (click)="confirm()">
        Löschen
      </button>
    </mat-dialog-actions>
  `,
})
export class ConfirmDeleteProfileDialogComponent {
  private readonly dialogRef = inject(MatDialogRef<ConfirmDeleteProfileDialogComponent>);
  protected readonly data    = inject<{ name: string }>(MAT_DIALOG_DATA);

  confirm(): void { this.dialogRef.close(true); }
}
