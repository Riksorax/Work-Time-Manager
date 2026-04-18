import { Component, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { AbstractControl, FormBuilder, ReactiveFormsModule, ValidationErrors, ValidatorFn, Validators } from '@angular/forms';
import { Router, RouterLink } from '@angular/router';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatButtonModule } from '@angular/material/button';
import { AuthService } from '../../../../core/auth/auth.service';
import { ToastService } from '../../../../shared/components/toast/toast.service';

export const mustMatchValidator: ValidatorFn = (control: AbstractControl): ValidationErrors | null => {
  const password = control.get('password');
  const confirmPassword = control.get('confirmPassword');

  return password && confirmPassword && password.value !== confirmPassword.value 
    ? { mustMatch: true } 
    : null;
};

@Component({
  selector: 'app-register',
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
    <form [formGroup]="registerForm" (ngSubmit)="onSubmit()">
      <mat-form-field appearance="outline" class="full-width">
        <mat-label>Anzeigename</mat-label>
        <input matInput formControlName="displayName" placeholder="Max Mustermann">
        @if (registerForm.get('displayName')?.hasError('required')) {
          <mat-error>Anzeigename ist erforderlich</mat-error>
        }
      </mat-form-field>

      <mat-form-field appearance="outline" class="full-width">
        <mat-label>E-Mail</mat-label>
        <input matInput type="email" formControlName="email" placeholder="email@example.com">
        @if (registerForm.get('email')?.hasError('required')) {
          <mat-error>E-Mail ist erforderlich</mat-error>
        }
        @if (registerForm.get('email')?.hasError('email')) {
          <mat-error>Geben Sie eine gültige E-Mail-Adresse ein</mat-error>
        }
      </mat-form-field>

      <mat-form-field appearance="outline" class="full-width">
        <mat-label>Passwort</mat-label>
        <input matInput type="password" formControlName="password">
        @if (registerForm.get('password')?.hasError('required')) {
          <mat-error>Passwort ist erforderlich</mat-error>
        }
        @if (registerForm.get('password')?.hasError('minlength')) {
          <mat-error>Passwort muss mindestens 8 Zeichen lang sein</mat-error>
        }
      </mat-form-field>

      <mat-form-field appearance="outline" class="full-width">
        <mat-label>Passwort bestätigen</mat-label>
        <input matInput type="password" formControlName="confirmPassword">
        @if (registerForm.hasError('mustMatch') && registerForm.get('confirmPassword')?.touched) {
          <mat-error>Passwörter stimmen nicht überein</mat-error>
        }
      </mat-form-field>

      <div class="actions">
        <button mat-raised-button color="primary" type="submit" [disabled]="registerForm.invalid || isLoading()">
          Registrieren
        </button>
      </div>

      <div class="footer-links">
        <span>Bereits ein Konto? <a routerLink="/auth/login">Anmelden</a></span>
      </div>
    </form>
  `,
  styles: `
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
export class RegisterComponent {
  private fb = inject(FormBuilder);
  private authService = inject(AuthService);
  private router = inject(Router);
  private toast = inject(ToastService);

  registerForm = this.fb.group({
    displayName: ['', [Validators.required, Validators.minLength(2)]],
    email: ['', [Validators.required, Validators.email]],
    password: ['', [Validators.required, Validators.minLength(8)]],
    confirmPassword: ['', [Validators.required]]
  }, { validators: mustMatchValidator });

  isLoading = signal(false);

  async onSubmit() {
    if (this.registerForm.invalid) return;

    this.isLoading.set(true);
    const { email, password, displayName } = this.registerForm.value;

    try {
      await this.authService.register(email!, password!, displayName!);
      this.toast.success('Konto erfolgreich erstellt!');
      this.router.navigate(['/dashboard']);
    } catch (error: any) {
      this.handleError(error);
    } finally {
      this.isLoading.set(false);
    }
  }

  private handleError(error: any) {
    let message = 'Ein Fehler ist aufgetreten.';
    if (error.code === 'auth/email-already-in-use') {
      message = 'Diese E-Mail-Adresse wird bereits verwendet.';
    } else if (error.code === 'auth/weak-password') {
      message = 'Das Passwort ist zu schwach.';
    }
    this.toast.error(message);
  }
}
