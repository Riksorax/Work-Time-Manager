import { Component, inject, signal, effect, computed } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormBuilder, FormGroup, ReactiveFormsModule, Validators } from '@angular/forms';
import { MatCardModule } from '@angular/material/card';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatSelectModule } from '@angular/material/select';
import { MatDividerModule } from '@angular/material/divider';
import { MatListModule } from '@angular/material/list';
import { MatSnackBar, MatSnackBarModule } from '@angular/material/snack-bar';
import { MatChipsModule } from '@angular/material/chips';
import { SettingsService } from '../../core/services/settings';
import { ProfileService } from '../../core/services/profile';
import { AuthService } from '../../core/auth/auth';
import { toSignal } from '@angular/core/rxjs-interop';

@Component({
  selector: 'app-settings',
  standalone: true,
  imports: [
    CommonModule,
    ReactiveFormsModule,
    MatCardModule,
    MatFormFieldModule,
    MatInputModule,
    MatButtonModule,
    MatIconModule,
    MatSelectModule,
    MatDividerModule,
    MatListModule,
    MatSnackBarModule,
    MatChipsModule
  ],
  templateUrl: './settings.html',
  styleUrl: './settings.scss'
})
export class SettingsComponent {
  private fb = inject(FormBuilder);
  private settingsService = inject(SettingsService);
  private profileService = inject(ProfileService);
  private authService = inject(AuthService);
  private snackBar = inject(MatSnackBar);

  loading = signal(false);
  
  settings = toSignal(this.settingsService.getSettings());
  profile = this.profileService.profile;
  isPremium = this.profileService.isPremium;

  form = this.fb.group({
    weeklyTargetHours: [40, [Validators.required, Validators.min(1), Validators.max(168)]],
    workdaysPerWeek: [5, [Validators.required, Validators.min(1), Validators.max(7)]]
  });

  constructor() {
    effect(() => {
      const current = this.settings();
      if (current) {
        this.form.patchValue({
          weeklyTargetHours: current.weeklyTargetHours,
          workdaysPerWeek: current.workdaysPerWeek
        }, { emitEvent: false });
      }
    });
  }

  async save() {
    if (this.form.invalid) return;
    this.loading.set(true);
    try {
      const current = this.settings();
      if (current) {
        await this.settingsService.saveSettings({
          ...current,
          weeklyTargetHours: this.form.value.weeklyTargetHours!,
          workdaysPerWeek: this.form.value.workdaysPerWeek!
        });
        this.snackBar.open('Einstellungen gespeichert', 'OK', { duration: 3000 });
      }
    } catch (error) {
      this.snackBar.open('Fehler beim Speichern', 'OK', { duration: 5000 });
    } finally {
      this.loading.set(false);
    }
  }

  logout() {
    this.authService.signOut();
  }
}
