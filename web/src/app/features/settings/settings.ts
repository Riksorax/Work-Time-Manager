import { Component, inject, signal, effect } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormBuilder, FormGroup, ReactiveFormsModule, Validators } from '@angular/forms';
import { MatCardModule } from '@angular/material/card';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatSelectModule } from '@angular/material/select';
import { MatDividerModule } from '@angular/material/divider';
import { MatSnackBar, MatSnackBarModule } from '@angular/material/snack-bar';
import { SettingsService } from '../../core/services/settings';
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
    MatSnackBarModule
  ],
  template: `
    <div class="settings-container">
      <h2>Einstellungen</h2>
      
      <form [formGroup]="form" (ngSubmit)="save()">
        <mat-card class="settings-card">
          <mat-card-header>
            <mat-icon mat-card-avatar>timer</mat-icon>
            <mat-card-title>Arbeitszeit-Konfiguration</mat-card-title>
            <mat-card-subtitle>Basis für Ihre Überstunden-Berechnung</mat-card-subtitle>
          </mat-card-header>
          
          <mat-card-content>
            <div class="form-grid">
              <mat-form-field appearance="outline">
                <mat-label>Wochen-Sollstunden</mat-label>
                <input matInput type="number" formControlName="weeklyTargetHours" placeholder="z.B. 40">
                <mat-hint>Gesamtstunden pro Woche</mat-hint>
              </mat-form-field>

              <mat-form-field appearance="outline">
                <mat-label>Arbeitstage pro Woche</mat-label>
                <mat-select formControlName="workdaysPerWeek">
                  @for (days of [1,2,3,4,5,6,7]; track days) {
                    <mat-option [value]="days">{{ days }} Tage</mat-option>
                  }
                </mat-select>
                <mat-hint>Wie viele Tage pro Woche arbeiten Sie?</mat-hint>
              </mat-form-field>
            </div>
          </mat-card-content>
        </mat-card>

        <mat-card class="settings-card">
          <mat-card-header>
            <mat-icon mat-card-avatar>notifications</mat-icon>
            <mat-card-title>Benachrichtigungen</mat-card-title>
          </mat-card-header>
          <mat-card-content>
            <p>Die Browser-Benachrichtigungen werden in einer späteren Version implementiert.</p>
          </mat-card-content>
        </mat-card>

        <div class="actions">
          <button mat-flat-button color="primary" type="submit" [disabled]="form.invalid || loading()">
            <mat-icon>save</mat-icon>
            Änderungen speichern
          </button>
        </div>
      </form>
    </div>
  `,
  styles: [`
    .settings-container {
      max-width: 800px;
      margin: 0 auto;
      padding: 24px 0;
      
      h2 { margin-bottom: 24px; }
    }
    .settings-card {
      margin-bottom: 24px;
      border-radius: 16px;
    }
    .form-grid {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 16px;
      padding-top: 16px;
      
      @media (max-width: 600px) {
        grid-template-columns: 1fr;
      }
    }
    .actions {
      display: flex;
      justify-content: flex-end;
      padding-top: 16px;
    }
    mat-icon[mat-card-avatar] {
      color: var(--mat-sys-primary);
    }
  `]
})
export class SettingsComponent {
  private fb = inject(FormBuilder);
  private settingsService = inject(SettingsService);
  private snackBar = inject(MatSnackBar);

  loading = signal(false);
  
  settings = toSignal(this.settingsService.getSettings());

  form = this.fb.group({
    weeklyTargetHours: [40, [Validators.required, Validators.min(1), Validators.max(168)]],
    workdaysPerWeek: [5, [Validators.required, Validators.min(1), Validators.max(7)]]
  });

  constructor() {
    // Initialisiere Form mit geladenen Werten
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
        const updated = {
          ...current,
          weeklyTargetHours: this.form.value.weeklyTargetHours!,
          workdaysPerWeek: this.form.value.workdaysPerWeek!
        };
        await this.settingsService.saveSettings(updated);
        this.snackBar.open('Einstellungen erfolgreich gespeichert', 'OK', { duration: 3000 });
      }
    } catch (error) {
      this.snackBar.open('Fehler beim Speichern', 'OK', { duration: 5000 });
    } finally {
      this.loading.set(false);
    }
  }
}
