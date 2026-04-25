import { ChangeDetectionStrategy, Component, inject, signal } from '@angular/core';
import { Router } from '@angular/router';
import { MatButtonModule } from '@angular/material/button';
import { MatCardModule } from '@angular/material/card';
import { MatDividerModule } from '@angular/material/divider';
import { MatIconModule } from '@angular/material/icon';
import { MatProgressSpinnerModule } from '@angular/material/progress-spinner';
import { MatSnackBar } from '@angular/material/snack-bar';
import { AuthService } from './auth';
import { DataSyncService } from '../services/data-sync';

@Component({
  selector: 'app-login',
  imports: [MatButtonModule, MatCardModule, MatDividerModule, MatIconModule, MatProgressSpinnerModule],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <div class="login-container">
      <div class="login-card">

        <!-- Logo -->
        <div class="logo-wrapper" aria-hidden="true">
          <mat-icon class="logo-icon">schedule</mat-icon>
        </div>

        <!-- Titel -->
        <h1 class="app-title">Work Time Manager</h1>
        <p class="app-subtitle">Erfassen Sie Ihre Arbeitszeit</p>

        <!-- Login-Bereich -->
        <div class="login-box">
          @if (status() === 'loading') {
            <div class="loading-state" role="status" aria-label="Anmeldung läuft">
              <mat-spinner diameter="36" />
              <p>{{ loadingMessage() }}</p>
            </div>
          } @else {
            @if (errorMessage()) {
              <p class="error-text" role="alert">{{ errorMessage() }}</p>
            }

            <button mat-flat-button class="google-btn"
                    (click)="loginWithGoogle()"
                    aria-label="Mit Google anmelden">
              <mat-icon>login</mat-icon>
              Mit Google anmelden
            </button>

            <mat-divider class="divider" />

            <button mat-button class="guest-btn"
                    (click)="continueAsGuest()"
                    aria-label="Ohne Konto fortfahren — Daten werden lokal gespeichert">
              <mat-icon>person_outline</mat-icon>
              Weiter ohne Konto
            </button>

            <p class="guest-hint">Daten werden lokal gespeichert</p>
          }
        </div>

        <!-- Legal Links -->
        <div class="legal-links">
          <a href="/privacy.html" target="_blank" rel="noopener">Datenschutz</a>
          <span aria-hidden="true">·</span>
          <a href="/terms.html" target="_blank" rel="noopener">Nutzungsbedingungen</a>
          <span aria-hidden="true">·</span>
          <a href="/imprint.html" target="_blank" rel="noopener">Impressum</a>
        </div>

      </div>
    </div>
  `,
  styles: [`
    .login-container {
      display: flex;
      justify-content: center;
      align-items: center;
      min-height: 100vh;
      padding: 24px;
      background-color: var(--mat-sys-surface-container);
    }

    .login-card {
      display: flex;
      flex-direction: column;
      align-items: center;
      width: 100%;
      max-width: 400px;
      padding: 40px 32px 32px;
      background: var(--mat-sys-surface);
      border-radius: 24px;
      border: 1px solid var(--mat-sys-outline-variant);
      gap: 0;
    }

    .logo-wrapper {
      width: 88px;
      height: 88px;
      border-radius: 50%;
      background: var(--mat-sys-primary-container);
      display: flex;
      align-items: center;
      justify-content: center;
      margin-bottom: 24px;
    }

    .logo-icon {
      font-size: 44px;
      width: 44px;
      height: 44px;
      color: var(--mat-sys-on-primary-container);
    }

    .app-title {
      margin: 0 0 8px;
      font-size: 1.6rem;
      font-weight: 700;
      text-align: center;
      color: var(--mat-sys-on-surface);
    }

    .app-subtitle {
      margin: 0 0 32px;
      font-size: 0.95rem;
      color: var(--mat-sys-on-surface-variant);
      text-align: center;
    }

    .login-box {
      width: 100%;
      display: flex;
      flex-direction: column;
      align-items: stretch;
      gap: 12px;
      margin-bottom: 24px;
    }

    .loading-state {
      display: flex;
      flex-direction: column;
      align-items: center;
      gap: 12px;
      padding: 16px 0;
      color: var(--mat-sys-on-surface-variant);
      font-size: 0.9rem;
    }

    .error-text {
      margin: 0;
      padding: 10px 14px;
      background: var(--mat-sys-error-container);
      color: var(--mat-sys-on-error-container);
      border-radius: 8px;
      font-size: 0.875rem;
      text-align: center;
    }

    .google-btn {
      padding: 12px 24px;
      font-size: 1rem;
      font-weight: 500;
      border-radius: 12px;
      display: flex;
      gap: 8px;
      align-items: center;
      justify-content: center;
    }

    .divider {
      margin: 4px 0;
    }

    .guest-btn {
      color: var(--mat-sys-on-surface-variant);
      display: flex;
      gap: 6px;
      align-items: center;
      justify-content: center;
    }

    .guest-hint {
      margin: -4px 0 0;
      font-size: 0.75rem;
      color: var(--mat-sys-on-surface-variant);
      text-align: center;
      opacity: 0.7;
    }

    .legal-links {
      display: flex;
      gap: 8px;
      align-items: center;
      flex-wrap: wrap;
      justify-content: center;
      font-size: 0.75rem;

      a {
        color: var(--mat-sys-on-surface-variant);
        text-decoration: none;
        &:hover { text-decoration: underline; }
      }

      span { color: var(--mat-sys-on-surface-variant); opacity: 0.5; }
    }
  `],
})
export class LoginComponent {
  private readonly authService  = inject(AuthService);
  private readonly dataSyncSvc  = inject(DataSyncService);
  private readonly snackbar     = inject(MatSnackBar);
  private readonly router       = inject(Router);

  protected readonly status         = signal<'idle' | 'loading'>('idle');
  protected readonly loadingMessage = signal('Anmeldung läuft...');
  protected readonly errorMessage   = signal<string | null>(null);

  async loginWithGoogle(): Promise<void> {
    this.status.set('loading');
    this.loadingMessage.set('Anmeldung läuft...');
    this.errorMessage.set(null);

    try {
      await this.authService.signInWithGoogle();

      // Lokale Daten automatisch synchronisieren
      this.loadingMessage.set('Synchronisiere lokale Daten...');
      await this.dataSyncSvc.syncAll();

      this.router.navigate(['/dashboard']);
    } catch (e: unknown) {
      this.status.set('idle');
      const code = (e as { code?: string }).code;
      if (code === 'auth/popup-closed-by-user' || code === 'auth/cancelled-popup-request') {
        return; // Nutzer hat selbst abgebrochen — kein Fehler anzeigen
      }
      this.errorMessage.set('Anmeldung fehlgeschlagen. Bitte erneut versuchen.');
    }
  }

  continueAsGuest(): void {
    this.router.navigate(['/dashboard']);
  }
}
