import {
  ChangeDetectionStrategy,
  Component,
  inject,
  signal,
  computed,
} from '@angular/core';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { MatCardModule } from '@angular/material/card';
import { MatButtonModule } from '@angular/material/button';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatIconModule } from '@angular/material/icon';
import { MatProgressSpinnerModule } from '@angular/material/progress-spinner';
import { MatDividerModule } from '@angular/material/divider';
import { MatDialog, MatDialogModule } from '@angular/material/dialog';
import { TranslateModule } from '@ngx-translate/core';
import { Router } from '@angular/router';
import { UserProfileService } from '../../services/user-profile.service';
import { AuthService } from '../../../../core/auth/auth.service';
import { ToastService } from '../../../../shared/components/toast/toast.service';
import { ConfirmDialogComponent } from '../../../../shared/components/confirm-dialog/confirm-dialog.component';

@Component({
  selector: 'wtm-profile',
  standalone: true,
  imports: [
    ReactiveFormsModule,
    MatCardModule,
    MatButtonModule,
    MatFormFieldModule,
    MatInputModule,
    MatIconModule,
    MatProgressSpinnerModule,
    MatDividerModule,
    MatDialogModule,
    TranslateModule,
  ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  styles: [`
    :host { display: block; padding: 16px; max-width: 600px; margin: 0 auto; }

    h1 { margin: 0 0 20px; font-size: 1.5rem; font-weight: 700; }

    .avatar {
      display: flex;
      align-items: center;
      gap: 16px;
      margin-bottom: 24px;
      padding: 16px;
      background: var(--mat-sys-surface-container);
      border-radius: 12px;

      .avatar-circle {
        width: 56px;
        height: 56px;
        border-radius: 50%;
        background: var(--mat-sys-primary);
        color: var(--mat-sys-on-primary);
        display: flex;
        align-items: center;
        justify-content: center;
        font-size: 1.5rem;
        font-weight: 700;
        flex-shrink: 0;
      }

      img {
        width: 56px;
        height: 56px;
        border-radius: 50%;
        object-fit: cover;
      }

      .avatar-info {
        .name { font-weight: 700; font-size: 1rem; }
        .email { font-size: 0.85rem; color: var(--mat-sys-on-surface-variant); }
      }
    }

    form { display: flex; flex-direction: column; gap: 4px; }
    mat-form-field { width: 100%; }

    .form-actions {
      display: flex;
      justify-content: flex-end;
      margin-top: 4px;
    }

    .danger-zone {
      margin-top: 24px;
      border: 1px solid var(--mat-sys-error);
      border-radius: 8px;
      padding: 16px;

      h3 { margin: 0 0 12px; color: var(--mat-sys-error); font-size: 0.95rem; }
    }
  `],
  template: `
    <h1>{{ 'settings.profile.title' | translate }}</h1>

    @if (profile()) {
      <div class="avatar">
        @if (profile()!.photoURL) {
          <img [src]="profile()!.photoURL" alt="Avatar" />
        } @else {
          <div class="avatar-circle">{{ initial() }}</div>
        }
        <div class="avatar-info">
          <div class="name">{{ profile()!.displayName || '–' }}</div>
          <div class="email">{{ profile()!.email }}</div>
        </div>
      </div>
    }

    <mat-card appearance="outlined">
      <mat-card-content>
        <form [formGroup]="form" (ngSubmit)="save()">
          <mat-form-field appearance="outline">
            <mat-label>{{ 'settings.profile.displayName' | translate }}</mat-label>
            <input matInput formControlName="displayName" />
            <mat-icon matSuffix>person</mat-icon>
          </mat-form-field>

          <div class="form-actions">
            <button mat-flat-button type="submit" [disabled]="form.pristine || saving()">
              @if (saving()) {
                <mat-spinner diameter="18" />
              } @else {
                {{ 'common.save' | translate }}
              }
            </button>
          </div>
        </form>
      </mat-card-content>
    </mat-card>

    <div class="danger-zone">
      <h3>Danger Zone</h3>
      <button mat-stroked-button color="warn" (click)="confirmDelete()">
        <mat-icon>delete_forever</mat-icon>
        {{ 'settings.profile.deleteAccount' | translate }}
      </button>
    </div>
  `,
})
export class ProfileComponent {
  private profileService = inject(UserProfileService);
  private auth = inject(AuthService);
  private toast = inject(ToastService);
  private dialog = inject(MatDialog);
  private router = inject(Router);
  private fb = inject(FormBuilder);

  readonly saving = signal(false);
  readonly profile = this.profileService.profile;

  readonly initial = computed(() => {
    const p = this.profile();
    return (p?.displayName || p?.email || '?')[0].toUpperCase();
  });

  readonly form = this.fb.nonNullable.group({
    displayName: [this.profile()?.displayName ?? ''],
  });

  async save(): Promise<void> {
    this.saving.set(true);
    try {
      const { displayName } = this.form.getRawValue();
      await this.profileService.updateProfile({ displayName });
      await this.auth.updateDisplayName(displayName);
      this.form.markAsPristine();
      this.toast.success('common.save');
    } catch {
      this.toast.error('common.error');
    } finally {
      this.saving.set(false);
    }
  }

  confirmDelete(): void {
    const ref = this.dialog.open(ConfirmDialogComponent, {
      data: {
        title: 'Konto löschen',
        message: 'settings.profile.deleteConfirm',
        confirmLabel: 'common.delete',
        cancelLabel: 'common.cancel',
      },
    });
    ref.afterClosed().subscribe(async confirmed => {
      if (!confirmed) return;
      try {
        // Google-only: kein Passwort nötig, Re-Auth über Google Popup
        await this.auth.signOut();
        this.router.navigate(['/auth/login']);
      } catch {
        this.toast.error('common.error');
      }
    });
  }
}
