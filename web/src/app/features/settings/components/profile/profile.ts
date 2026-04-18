import { Component, inject, signal, computed } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { MatCardModule } from '@angular/material/card';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatDividerModule } from '@angular/material/divider';
import { UserProfileService } from '../../services/user-profile.service';
import { AuthService } from '../../../../core/auth/auth.service';
import { ToastService } from '../../../../shared/components/toast/toast.service';
import { ConfirmDialogService } from '../../../../shared/components/confirm-dialog/confirm-dialog.service';
import { mustMatchValidator } from '../../../auth/components/register/register';

@Component({
  selector: 'app-profile',
  standalone: true,
  imports: [
    CommonModule, 
    ReactiveFormsModule, 
    MatCardModule, 
    MatFormFieldModule, 
    MatInputModule, 
    MatButtonModule, 
    MatIconModule,
    MatDividerModule
  ],
  template: `
    <div class="profile-container">
      <mat-card>
        <mat-card-header>
          <mat-card-title>👤 Profil</mat-card-title>
        </mat-card-header>
        
        <mat-card-content>
          <div class="user-summary">
            <div class="avatar-placeholder">
              <mat-icon>person</mat-icon>
            </div>
            <div class="user-details">
              <h2>{{ profileService.profile()?.displayName || 'Benutzer' }}</h2>
              <p>{{ profileService.profile()?.email }}</p>
            </div>
          </div>

          <form [formGroup]="nameForm" (ngSubmit)="updateName()">
            <mat-form-field appearance="outline" class="full-width">
              <mat-label>Anzeigename</mat-label>
              <input matInput formControlName="displayName">
            </mat-form-field>
            <div class="actions">
              <button mat-raised-button color="primary" type="submit" [disabled]="nameForm.pristine || nameForm.invalid">
                Name speichern
              </button>
            </div>
          </form>

          <mat-divider></mat-divider>

          <div class="danger-zone">
            <h3>Gefahrenzone</h3>
            <p>Das Löschen des Kontos ist permanent und kann nicht rückgängig gemacht werden.</p>
            <button mat-raised-button color="warn" (click)="deleteAccount()">
              <mat-icon>delete_forever</mat-icon> Konto löschen
            </button>
          </div>
        </mat-card-content>
      </mat-card>
    </div>
  `,
  styles: `
    .profile-container { display: flex; justify-content: center; padding: 1rem; }
    mat-card { width: 100%; max-width: 600px; }
    .user-summary { display: flex; align-items: center; gap: 2rem; margin-bottom: 2rem; }
    .avatar-placeholder { 
      width: 80px; height: 80px; border-radius: 50%; 
      background: #e0e0e0; display: flex; align-items: center; justify-content: center; 
    }
    .avatar-placeholder mat-icon { font-size: 40px; width: 40px; height: 40px; color: #9e9e9e; }
    .user-details h2 { margin: 0; }
    .user-details p { margin: 0; color: rgba(0,0,0,0.6); }
    .full-width { width: 100%; }
    .actions { text-align: right; margin-bottom: 2rem; }
    .danger-zone { margin-top: 2rem; padding: 1.5rem; border: 1px solid #ffcdd2; border-radius: 8px; background: #fff9f9; }
    .danger-zone h3 { color: #d32f2f; margin-top: 0; }
    .danger-zone p { font-size: 0.9rem; color: #555; }
    mat-divider { margin: 2rem 0; }
  `
})
export class ProfileComponent {
  private fb = inject(FormBuilder);
  profileService = inject(UserProfileService);
  private authService = inject(AuthService);
  private toast = inject(ToastService);
  private confirm = inject(ConfirmDialogService);

  nameForm = this.fb.group({
    displayName: ['', [Validators.required, Validators.minLength(2)]]
  });

  constructor() {
    const profile = this.profileService.profile;
    if (profile()) {
      this.nameForm.patchValue({ displayName: profile()!.displayName || '' });
    }
  }

  async updateName() {
    if (this.nameForm.invalid) return;
    try {
      await this.profileService.updateProfile({ displayName: this.nameForm.value.displayName! });
      this.toast.success('Name aktualisiert!');
      this.nameForm.markAsPristine();
    } catch (error) {
      this.toast.error('Fehler beim Aktualisieren des Namens.');
    }
  }

  async deleteAccount() {
    const confirmed = await this.confirm.confirm({
      title: 'Konto löschen',
      message: 'Sind Sie sicher? Alle Ihre Daten gehen unwiederbringlich verloren.',
      confirmLabel: 'Ja, Konto löschen',
      cancelLabel: 'Abbrechen'
    });

    if (confirmed) {
      // Normalerweise Re-Auth erforderlich, hier vereinfacht:
      this.toast.info('Bitte loggen Sie sich erneut ein, um das Konto zu löschen.');
      // Hier würde man zu einer Re-Auth Seite leiten oder Passwort abfragen
    }
  }
}
