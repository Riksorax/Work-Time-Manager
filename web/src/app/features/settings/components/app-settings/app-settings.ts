import { Component, inject, computed } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { MatCardModule } from '@angular/material/card';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatRadioModule } from '@angular/material/radio';
import { MatSelectModule } from '@angular/material/select';
import { MatDividerModule } from '@angular/material/divider';
import { MatDialog, MatDialogModule } from '@angular/material/dialog';
import { UserProfileService } from '../../services/user-profile.service';
import { OvertimeService } from '../../../time-tracking/services/overtime.service';
import { ToastService } from '@shared/components/toast/toast.service';
import { OvertimePipe } from '@shared/pipes/overtime.pipe';
import { AdjustmentDialogComponent } from '../adjustment-dialog/adjustment-dialog';
import { toSignal } from '@angular/core/rxjs-interop';

@Component({
  selector: 'app-app-settings',
  standalone: true,
  imports: [
    CommonModule, 
    ReactiveFormsModule, 
    MatCardModule, 
    MatFormFieldModule, 
    MatInputModule, 
    MatButtonModule, 
    MatIconModule,
    MatRadioModule,
    MatSelectModule,
    MatDividerModule,
    MatDialogModule,
    OvertimePipe
  ],
  template: `
    <div class="settings-container">
      <mat-card>
        <mat-card-header>
          <mat-card-title>⚙️ App-Einstellungen</mat-card-title>
        </mat-card-header>
        
        <mat-card-content>
          <form [formGroup]="settingsForm" (ngSubmit)="saveSettings()">
            <h3>Arbeitszeitziel</h3>
            <div class="form-row">
              <mat-form-field appearance="outline">
                <mat-label>Wöchentliche Sollstunden</mat-label>
                <input matInput type="number" formControlName="weeklyTargetHours">
              </mat-form-field>
              
              <mat-form-field appearance="outline">
                <mat-label>Tägliche Sollstunden</mat-label>
                <input matInput type="number" formControlName="dailyTargetHours">
              </mat-form-field>
            </div>

            <mat-divider></mat-divider>

            <h3>Überstunden-Bilanz (Gleitzeit)</h3>
            <div class="balance-info">
              <span>Aktueller Saldo: <strong>{{ balanceMinutes() | overtime }}</strong></span>
              <button mat-stroked-button type="button" (click)="openAdjustmentDialog()">
                <mat-icon>edit</mat-icon> Saldo anpassen
              </button>
            </div>

            <mat-divider></mat-divider>

            <h3>Design</h3>
            <mat-radio-group formControlName="theme" class="theme-group">
              <mat-radio-button value="light">Hell</mat-radio-button>
              <mat-radio-button value="dark">Dunkel</mat-radio-button>
              <mat-radio-button value="system">Systemeinstellung</mat-radio-button>
            </mat-radio-group>

            <h3>Sprache</h3>
            <mat-form-field appearance="outline">
              <mat-label>Bevorzugte Sprache</mat-label>
              <mat-select formControlName="language">
                <mat-option value="de">🇩🇪 Deutsch</mat-option>
                <mat-option value="en">🇬🇧 English</mat-option>
              </mat-select>
            </mat-form-field>

            <div class="actions">
              <button mat-raised-button color="primary" type="submit" [disabled]="settingsForm.pristine">
                Speichern
              </button>
            </div>
          </form>
        </mat-card-content>
      </mat-card>
    </div>
  `,
  styles: `
    .settings-container { display: flex; justify-content: center; padding: 1rem; }
    mat-card { width: 100%; max-width: 600px; }
    .form-row { display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; }
    @media (max-width: 480px) { .form-row { grid-template-columns: 1fr; } }
    h3 { margin: 1.5rem 0 1rem; color: #3f51b5; }
    .balance-info { display: flex; align-items: center; justify-content: space-between; margin-bottom: 1.5rem; }
    .theme-group { display: flex; flex-direction: column; gap: 0.5rem; margin-bottom: 1.5rem; }
    .actions { margin-top: 2rem; text-align: right; }
    mat-divider { margin: 1rem 0; }
  `
})
export class AppSettingsComponent {
  private fb = inject(FormBuilder);
  private profileService = inject(UserProfileService);
  private overtimeService = inject(OvertimeService);
  private toast = inject(ToastService);
  private dialog = inject(MatDialog);

  balance = toSignal(this.overtimeService.getBalance());
  balanceMinutes = computed(() => this.balance()?.minutes || 0);

  settingsForm = this.fb.group({
    weeklyTargetHours: [40, [Validators.required, Validators.min(0)]],
    dailyTargetHours: [8, [Validators.required, Validators.min(0)]],
    theme: ['system'],
    language: ['de']
  });

  constructor() {
    const profile = this.profileService.profile;
    if (profile()) {
      this.settingsForm.patchValue(profile()!.settings);
    }
  }

  async saveSettings() {
    if (this.settingsForm.invalid) return;
    
    try {
      await this.profileService.updateSettings(this.settingsForm.value as any);
      this.toast.success('Einstellungen gespeichert!');
      this.settingsForm.markAsPristine();
    } catch (error) {
      this.toast.error('Fehler beim Speichern der Einstellungen.');
    }
  }

  openAdjustmentDialog() {
    const dialogRef = this.dialog.open(AdjustmentDialogComponent, {
      width: '400px',
      data: { currentBalance: this.balanceMinutes() }
    });

    dialogRef.afterClosed().subscribe(async (result) => {
      if (result !== undefined) {
        await this.overtimeService.updateBalance(result);
        this.toast.success('Saldo aktualisiert!');
      }
    });
  }
}
