import { ChangeDetectionStrategy, Component, computed, inject } from '@angular/core';
import { MatMenuModule } from '@angular/material/menu';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatDividerModule } from '@angular/material/divider';
import { MatTooltipModule } from '@angular/material/tooltip';
import { MatDialog } from '@angular/material/dialog';
import { MatSnackBar } from '@angular/material/snack-bar';
import { TranslatePipe, TranslateService } from '@ngx-translate/core';
import { AuthService } from '../../../core/auth/auth';
import { ProfileService } from '../../../core/services/profile';
import { WorkProfileService } from '../../../core/services/work-profile';
import { AddWorkProfileDialogComponent, AddWorkProfileDialogResult } from './add-work-profile-dialog';
import { ManageWorkProfilesDialogComponent } from './manage-work-profiles-dialog';

/** Profil-Wechsler im Header (siehe #138/#244): zeigt alle Arbeitszeit-
 * Profile des Nutzers und erlaubt das Anlegen eines weiteren Profils,
 * begrenzt auf `WorkProfileService.maxProfileCount` (siehe #240). Für
 * ausgeloggte Nutzer unsichtbar, da Profile ein Login voraussetzen. */
@Component({
  selector: 'app-work-profile-switcher',
  imports: [MatMenuModule, MatButtonModule, MatIconModule, MatDividerModule, MatTooltipModule, TranslatePipe],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    @if (auth.user()) {
      <button mat-icon-button [matMenuTriggerFor]="menu"
              [attr.aria-label]="'shared.switchProfileAria' | translate"
              [matTooltip]="'shared.switchProfileAria' | translate">
        <mat-icon>badge</mat-icon>
      </button>
      <mat-menu #menu="matMenu">
        @for (profile of workProfile.profiles(); track profile.id) {
          <button mat-menu-item (click)="select(profile.id)">
            <mat-icon>{{ profile.id === workProfile.activeProfileId() ? 'check' : '' }}</mat-icon>
            <span>{{ profile.name }}</span>
          </button>
        }
        <mat-divider />
        <button mat-menu-item (click)="handleAdd()">
          <mat-icon>{{ canAdd() ? 'add' : 'lock_outline' }}</mat-icon>
          <span>{{ 'shared.newProfileTitle' | translate }}</span>
        </button>
        @if (workProfile.profiles().length > 1) {
          <button mat-menu-item (click)="openManage()">
            <mat-icon>delete_outline</mat-icon>
            <span>{{ 'shared.manageProfilesTitle' | translate }}</span>
          </button>
        }
      </mat-menu>
    }
  `,
})
export class WorkProfileSwitcherComponent {
  protected readonly auth        = inject(AuthService);
  protected readonly workProfile = inject(WorkProfileService);
  private readonly profileService = inject(ProfileService);
  private readonly dialog        = inject(MatDialog);
  private readonly snackBar      = inject(MatSnackBar);
  private readonly translate     = inject(TranslateService);

  protected readonly canAdd = computed(
    () => this.workProfile.profiles().length < this.workProfile.maxProfileCount()
  );

  select(id: string): void {
    this.workProfile.setActiveProfile(id);
  }

  handleAdd(): void {
    if (!this.profileService.isPremium()) {
      this.snackBar.open(this.translate.instant('shared.premiumProfilesFeature'), 'OK', { duration: 4000 });
      return;
    }
    if (!this.canAdd()) {
      this.snackBar.open(
        this.translate.instant('shared.maxProfilesReached', { count: this.workProfile.maxProfileCount() }),
        'OK',
        { duration: 4000 },
      );
      return;
    }
    const ref = this.dialog.open(AddWorkProfileDialogComponent);
    ref.afterClosed().subscribe(async (result: AddWorkProfileDialogResult | undefined) => {
      if (!result) return;
      try {
        const created = await this.workProfile.addProfile(result.name);
        this.snackBar.open(
          this.translate.instant('shared.profileCreated', { name: created.name }),
          'OK',
          { duration: 4000 },
        );
      } catch (e) {
        this.snackBar.open(
          this.translate.instant('shared.profileCreateFailed', { error: e }),
          'OK',
          { duration: 5000 },
        );
      }
    });
  }

  openManage(): void {
    this.dialog.open(ManageWorkProfilesDialogComponent);
  }
}
