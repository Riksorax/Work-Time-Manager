import {
  ChangeDetectionStrategy,
  Component,
  inject,
  signal,
} from '@angular/core';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
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

@Component({
  selector: 'wtm-login',
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
        <mat-label>{{ 'auth.email' | translate }}</mat-label>
        <input matInput type="email" formControlName="email" autocomplete="email" />
        <mat-icon matSuffix>mail</mat-icon>
      </mat-form-field>

      <mat-form-field appearance="outline">
        <mat-label>{{ 'auth.password' | translate }}</mat-label>
        <input
          matInput
          [type]="showPassword() ? 'text' : 'password'"
          formControlName="password"
          autocomplete="current-password"
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
            {{ 'auth.login' | translate }}
          }
        </button>

        <a mat-stroked-button routerLink="../forgot-password">
          {{ 'auth.forgotPassword' | translate }}
        </a>
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
      <a routerLink="../register">{{ 'auth.noAccount' | translate }}</a>
    </div>
  `,
})
export class LoginComponent {
  private auth = inject(AuthService);
  private router = inject(Router);
  private toast = inject(ToastService);
  private fb = inject(FormBuilder);

  readonly loading = signal(false);
  readonly showPassword = signal(false);

  readonly form = this.fb.nonNullable.group({
    email: ['', [Validators.required, Validators.email]],
    password: ['', [Validators.required, Validators.minLength(6)]],
  });

  async submit(): Promise<void> {
    if (this.form.invalid) return;
    this.loading.set(true);
    try {
      const { email, password } = this.form.getRawValue();
      await this.auth.signInWithEmail(email, password);
      await this.router.navigate(['/dashboard']);
    } catch {
      this.toast.error('auth.loginError');
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
