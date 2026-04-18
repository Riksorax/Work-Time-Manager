import { Component, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { Router, RouterLink } from '@angular/router';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { AuthService } from '../../../../core/auth/auth.service';
import { ToastService } from '../../../../shared/components/toast/toast.service';

@Component({
  selector: 'app-login',
  standalone: true,
  imports: [
    CommonModule,
    ReactiveFormsModule,
    RouterLink,
    MatFormFieldModule,
    MatInputModule,
    MatButtonModule,
    MatIconModule
  ],
  template: `
    <form [formGroup]="loginForm" (ngSubmit)="onSubmit()">
      <mat-form-field appearance="outline" class="full-width">
        <mat-label>E-Mail</mat-label>
        <input matInput type="email" formControlName="email" placeholder="email@example.com">
        @if (loginForm.get('email')?.hasError('required')) {
          <mat-error>E-Mail ist erforderlich</mat-error>
        }
        @if (loginForm.get('email')?.hasError('email')) {
          <mat-error>Geben Sie eine gültige E-Mail-Adresse ein</mat-error>
        }
      </mat-form-field>

      <mat-form-field appearance="outline" class="full-width">
        <mat-label>Passwort</mat-label>
        <input matInput [type]="hidePassword() ? 'password' : 'text'" formControlName="password">
        <button mat-icon-button matSuffix (click)="hidePassword.set(!hidePassword())" type="button">
          <mat-icon>{{ hidePassword() ? 'visibility_off' : 'visibility' }}</mat-icon>
        </button>
        @if (loginForm.get('password')?.hasError('required')) {
          <mat-error>Passwort ist erforderlich</mat-error>
        }
      </mat-form-field>

      <div class="actions">
        <button mat-raised-button color="primary" type="submit" [disabled]="loginForm.invalid || isLoading()">
          Anmelden
        </button>
        <button mat-stroked-button type="button" (click)="onGoogleSignIn()" [disabled]="isLoading()">
          <img src="assets/icons/google.svg" alt="" class="google-icon">
          Mit Google anmelden
        </button>
      </div>

      <div class="footer-links">
        <a routerLink="/auth/forgot-password">Passwort vergessen?</a>
        <span>Noch kein Konto? <a routerLink="/auth/register">Konto erstellen</a></span>
      </div>
    </form>
  `,
  styles: `
    .full-width { width: 100%; margin-bottom: 1rem; }
    .actions { display: flex; flex-direction: column; gap: 1rem; margin-top: 1rem; }
    .google-icon { width: 18px; height: 18px; margin-right: 8px; vertical-align: middle; }
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
export class LoginComponent {
  private fb = inject(FormBuilder);
  private authService = inject(AuthService);
  private router = inject(Router);
  private toast = inject(ToastService);

  loginForm = this.fb.group({
    email: ['', [Validators.required, Validators.email]],
    password: ['', [Validators.required, Validators.minLength(6)]]
  });

  hidePassword = signal(true);
  isLoading = signal(false);

  async onSubmit() {
    if (this.loginForm.invalid) return;

    this.isLoading.set(true);
    const { email, password } = this.loginForm.value;

    try {
      await this.authService.signInWithEmail(email!, password!);
      this.router.navigate(['/dashboard']);
    } catch (error: any) {
      this.handleError(error);
    } finally {
      this.isLoading.set(false);
    }
  }

  async onGoogleSignIn() {
    this.isLoading.set(true);
    try {
      await this.authService.signInWithGoogle();
      this.router.navigate(['/dashboard']);
    } catch (error: any) {
      this.handleError(error);
    } finally {
      this.isLoading.set(false);
    }
  }

  private handleError(error: any) {
    let message = 'Ein unerwarteter Fehler ist aufgetreten.';
    if (error.code === 'auth/user-not-found' || error.code === 'auth/wrong-password' || error.code === 'auth/invalid-credential') {
      message = 'E-Mail oder Passwort ist falsch.';
    } else if (error.code === 'auth/too-many-requests') {
      message = 'Zu viele Versuche. Bitte versuchen Sie es später erneut.';
    }
    this.toast.error(message);
  }
}
