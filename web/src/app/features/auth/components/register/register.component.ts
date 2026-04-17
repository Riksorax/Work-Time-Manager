import {
  ChangeDetectionStrategy,
  Component,
  inject,
  signal,
} from '@angular/core';
import {
  AbstractControl,
  FormBuilder,
  ReactiveFormsModule,
  ValidationErrors,
  Validators,
} from '@angular/forms';
import { Router, RouterLink } from '@angular/router';
import { MatButtonModule } from '@angular/material/button';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatIconModule } from '@angular/material/icon';
import { MatInputModule } from '@angular/material/input';
import { MatProgressSpinnerModule } from '@angular/material/progress-spinner';
import { MatDividerModule } from '@angular/material/divider';
import { TranslateModule } from '@ngx-translate/core';
import { AuthService } from '../../../../core/auth/auth.service';
import { ToastService } from '../../../../shared/components/toast/toast.service';

function passwordsMatchValidator(control: AbstractControl): ValidationErrors | null {
  const password = control.get('password')?.value;
  const confirm = control.get('confirmPassword')?.value;
  return password && confirm && password !== confirm ? { passwordsMismatch: true } : null;
}

@Component({
  selector: 'wtm-register',
  standalone: true,
  imports: [
    ReactiveFormsModule,
    RouterLink,
    MatButtonModule,
    MatFormFieldModule,
    MatIconModule,
    MatInputModule,
    MatProgressSpinnerModule,
    MatDividerModule,
    TranslateModule,
  ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  styles: [`
    :host { display: block; }

    form { display: flex; flex-direction: column; gap: 4px; }

    mat-form-field { width: 100%; }

    .actions {
      display: flex;
      flex-direction: column;
      gap: 8px;
      margin-top: 8px;
    }

    .divider-row {
      display: flex;
      align-items: center;
      gap: 8px;
      margin: 8px 0;
      color: var(--mat-sys-on-surface-variant);
      font-size: 0.75rem;

      mat-divider { flex: 1; }
    }

    .links {
      text-align: center;
      margin-top: 16px;
      font-size: 0.875rem;
      color: var(--mat-sys-on-surface-variant);

      a { color: var(--mat-sys-primary); text-decoration: none; }
      a:hover { text-decoration: underline; }
    }
  `],
  template: `
    <form [formGroup]="form" (ngSubmit)="submit()">
      <mat-form-field appearance="outline">
        <mat-label>Name (optional)</mat-label>
        <input matInput formControlName="displayName" autocomplete="name" />
        <mat-icon matSuffix>person</mat-icon>
      </mat-form-field>

      <mat-form-field appearance="outline">
        <mat-label>{{ 'auth.email' | translate }}</mat-label>
        <input matInput type="email" formControlName="email" autocomplete="email" />
        <mat-icon matSuffix>mail</mat-icon>
        @if (form.get('email')?.hasError('email')) {
          <mat-error>Ungültige E-Mail-Adresse</mat-error>
        }
      </mat-form-field>

      <mat-form-field appearance="outline">
        <mat-label>{{ 'auth.password' | translate }}</mat-label>
        <input
          matInput
          [type]="showPassword() ? 'text' : 'password'"
          formControlName="password"
          autocomplete="new-password"
        />
        <button
          mat-icon-button
          matSuffix
          type="button"
          (click)="showPassword.set(!showPassword())"
          [attr.aria-label]="'Passwort anzeigen'"
        >
          <mat-icon>{{ showPassword() ? 'visibility_off' : 'visibility' }}</mat-icon>
        </button>
        @if (form.get('password')?.hasError('minlength')) {
          <mat-error>Mindestens 6 Zeichen</mat-error>
        }
      </mat-form-field>

      <mat-form-field appearance="outline">
        <mat-label>Passwort bestätigen</mat-label>
        <input
          matInput
          [type]="showPassword() ? 'text' : 'password'"
          formControlName="confirmPassword"
          autocomplete="new-password"
        />
        @if (form.hasError('passwordsMismatch')) {
          <mat-error>Passwörter stimmen nicht überein</mat-error>
        }
      </mat-form-field>

      <div class="actions">
        <button
          mat-flat-button
          type="submit"
          [disabled]="form.invalid || loading()"
        >
          @if (loading()) {
            <mat-spinner diameter="18" />
          } @else {
            {{ 'auth.register' | translate }}
          }
        </button>
      </div>

      <div class="divider-row">
        <mat-divider />
        <span>oder</span>
        <mat-divider />
      </div>

      <button
        mat-stroked-button
        type="button"
        (click)="signInWithGoogle()"
        [disabled]="loading()"
      >
        <mat-icon svgIcon="google" />
        {{ 'auth.googleSignIn' | translate }}
      </button>
    </form>

    <div class="links">
      <a routerLink="../login">{{ 'auth.hasAccount' | translate }}</a>
    </div>
  `,
})
export class RegisterComponent {
  private auth = inject(AuthService);
  private router = inject(Router);
  private toast = inject(ToastService);
  private fb = inject(FormBuilder);

  readonly loading = signal(false);
  readonly showPassword = signal(false);

  readonly form = this.fb.nonNullable.group(
    {
      displayName: [''],
      email: ['', [Validators.required, Validators.email]],
      password: ['', [Validators.required, Validators.minLength(6)]],
      confirmPassword: ['', Validators.required],
    },
    { validators: passwordsMatchValidator }
  );

  async submit(): Promise<void> {
    if (this.form.invalid) return;
    this.loading.set(true);
    try {
      const { email, password, displayName } = this.form.getRawValue();
      await this.auth.register(email, password, displayName || undefined);
      await this.router.navigate(['/dashboard']);
    } catch {
      this.toast.error('auth.registerError');
    } finally {
      this.loading.set(false);
    }
  }

  async signInWithGoogle(): Promise<void> {
    this.loading.set(true);
    try {
      await this.auth.signInWithGoogle();
      await this.router.navigate(['/dashboard']);
    } catch {
      this.toast.error('auth.loginError');
    } finally {
      this.loading.set(false);
    }
  }
}
