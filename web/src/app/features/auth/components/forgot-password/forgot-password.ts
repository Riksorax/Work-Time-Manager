import { Component, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { RouterLink } from '@angular/router';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatButtonModule } from '@angular/material/button';
import { AuthService } from '../../../../core/auth/auth.service';
import { ToastService } from '../../../../shared/components/toast/toast.service';

@Component({
  selector: 'app-forgot-password',
  standalone: true,
  imports: [
    CommonModule,
    ReactiveFormsModule,
    RouterLink,
    MatFormFieldModule,
    MatInputModule,
    MatButtonModule
  ],
  template: `
    <form [formGroup]="forgotForm" (ngSubmit)="onSubmit()">
      <p class="description">
        Geben Sie Ihre E-Mail-Adresse ein. Wir senden Ihnen einen Link zum Zurücksetzen Ihres Passworts.
      </p>

      <mat-form-field appearance="outline" class="full-width">
        <mat-label>E-Mail</mat-label>
        <input matInput type="email" formControlName="email" placeholder="email@example.com">
        @if (forgotForm.get('email')?.hasError('required')) {
          <mat-error>E-Mail ist erforderlich</mat-error>
        }
        @if (forgotForm.get('email')?.hasError('email')) {
          <mat-error>Geben Sie eine gültige E-Mail-Adresse ein</mat-error>
        }
      </mat-form-field>

      <div class="actions">
        <button mat-raised-button color="primary" type="submit" [disabled]="forgotForm.invalid || isLoading()">
          Reset-Link senden
        </button>
      </div>

      <div class="footer-links">
        <a routerLink="/auth/login">Zurück zum Login</a>
      </div>
    </form>
  `,
  styles: `
    .description { margin-bottom: 2rem; color: rgba(0, 0, 0, 0.6); font-size: 0.9rem; }
    .full-width { width: 100%; margin-bottom: 1rem; }
    .actions { display: flex; flex-direction: column; gap: 1rem; margin-top: 1rem; }
    .footer-links {
      display: flex;
      flex-direction: column;
      align-items: center;
      gap: 0.5rem;
      margin-top: 2rem;
      font-size: 0.9rem;
    }
  `
})
export class ForgotPasswordComponent {
  private fb = inject(FormBuilder);
  private authService = inject(AuthService);
  private toast = inject(ToastService);

  forgotForm = this.fb.group({
    email: ['', [Validators.required, Validators.email]]
  });

  isLoading = signal(false);

  async onSubmit() {
    if (this.forgotForm.invalid) return;

    this.isLoading.set(true);
    const { email } = this.forgotForm.value;

    try {
      await this.authService.sendPasswordReset(email!);
      this.toast.success('Reset-Link wurde versendet. Bitte prüfen Sie Ihr Postfach.');
    } catch (error: any) {
      this.toast.error('Fehler beim Versenden des Reset-Links.');
    } finally {
      this.isLoading.set(false);
    }
  }
}
