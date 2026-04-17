import {
  ChangeDetectionStrategy,
  Component,
  inject,
  signal,
} from '@angular/core';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { RouterLink } from '@angular/router';
import { MatButtonModule } from '@angular/material/button';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatIconModule } from '@angular/material/icon';
import { MatInputModule } from '@angular/material/input';
import { MatProgressSpinnerModule } from '@angular/material/progress-spinner';
import { TranslateModule } from '@ngx-translate/core';
import { AuthService } from '../../../../core/auth/auth.service';
import { ToastService } from '../../../../shared/components/toast/toast.service';

@Component({
  selector: 'wtm-forgot-password',
  standalone: true,
  imports: [
    ReactiveFormsModule,
    RouterLink,
    MatButtonModule,
    MatFormFieldModule,
    MatIconModule,
    MatInputModule,
    MatProgressSpinnerModule,
    TranslateModule,
  ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  styles: [`
    :host { display: block; }

    h2 {
      margin: 0 0 8px;
      font-size: 1.125rem;
      font-weight: 600;
    }

    p.hint {
      margin: 0 0 20px;
      font-size: 0.875rem;
      color: var(--mat-sys-on-surface-variant);
    }

    form { display: flex; flex-direction: column; gap: 4px; }

    mat-form-field { width: 100%; }

    .actions {
      display: flex;
      flex-direction: column;
      gap: 8px;
      margin-top: 8px;
    }

    .success-box {
      display: flex;
      flex-direction: column;
      align-items: center;
      gap: 12px;
      padding: 16px 0;
      text-align: center;

      mat-icon {
        font-size: 48px;
        width: 48px;
        height: 48px;
        color: var(--mat-sys-primary);
      }

      p {
        margin: 0;
        color: var(--mat-sys-on-surface-variant);
        font-size: 0.875rem;
      }
    }
  `],
  template: `
    @if (!sent()) {
      <h2>{{ 'auth.resetPassword' | translate }}</h2>
      <p class="hint">Gib deine E-Mail-Adresse ein. Wir schicken dir einen Link zum Zurücksetzen.</p>

      <form [formGroup]="form" (ngSubmit)="submit()">
        <mat-form-field appearance="outline">
          <mat-label>{{ 'auth.email' | translate }}</mat-label>
          <input matInput type="email" formControlName="email" autocomplete="email" />
          <mat-icon matSuffix>mail</mat-icon>
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
              {{ 'auth.resetPassword' | translate }}
            }
          </button>

          <a mat-button routerLink="../login">
            <mat-icon>arrow_back</mat-icon>
            Zurück zur Anmeldung
          </a>
        </div>
      </form>
    } @else {
      <div class="success-box">
        <mat-icon>mark_email_read</mat-icon>
        <strong>E-Mail gesendet</strong>
        <p>{{ 'auth.resetSent' | translate }}</p>
        <a mat-stroked-button routerLink="../login">
          <mat-icon>arrow_back</mat-icon>
          Zurück zur Anmeldung
        </a>
      </div>
    }
  `,
})
export class ForgotPasswordComponent {
  private auth = inject(AuthService);
  private toast = inject(ToastService);
  private fb = inject(FormBuilder);

  readonly loading = signal(false);
  readonly sent = signal(false);

  readonly form = this.fb.nonNullable.group({
    email: ['', [Validators.required, Validators.email]],
  });

  async submit(): Promise<void> {
    if (this.form.invalid) return;
    this.loading.set(true);
    try {
      await this.auth.sendPasswordReset(this.form.getRawValue().email);
      this.sent.set(true);
    } catch {
      this.toast.error('Fehler beim Senden der E-Mail. Bitte versuche es erneut.');
    } finally {
      this.loading.set(false);
    }
  }
}
