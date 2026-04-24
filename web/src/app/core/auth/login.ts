import { ChangeDetectionStrategy, Component, inject } from '@angular/core';
import { MatButtonModule } from '@angular/material/button';
import { MatCardModule } from '@angular/material/card';
import { MatIconModule } from '@angular/material/icon';
import { MatSnackBar } from '@angular/material/snack-bar';
import { AuthService } from './auth';

@Component({
  selector: 'app-login',
  imports: [MatButtonModule, MatCardModule, MatIconModule],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <div class="login-container">
      <mat-card class="login-card">
        <mat-card-header>
          <mat-card-title>Willkommen</mat-card-title>
          <mat-card-subtitle>Work Time Manager</mat-card-subtitle>
        </mat-card-header>
        <mat-card-content>
          <p>Bitte melden Sie sich an, um Ihre Arbeitszeiten zu verwalten.</p>
        </mat-card-content>
        <mat-card-actions>
          <button mat-flat-button (click)="login()" aria-label="Mit Google anmelden">
            <mat-icon>login</mat-icon>
            Mit Google anmelden
          </button>
        </mat-card-actions>
      </mat-card>
    </div>
  `,
  styles: [`
    .login-container {
      display: flex;
      justify-content: center;
      align-items: center;
      height: 100vh;
      background-color: var(--mat-sys-surface-container);
    }
    .login-card {
      max-width: 400px;
      width: 100%;
      padding: 16px;
    }
    mat-card-actions {
      justify-content: center;
      padding-top: 16px;
    }
  `],
})
export class LoginComponent {
  private readonly authService = inject(AuthService);
  private readonly snackbar    = inject(MatSnackBar);

  async login(): Promise<void> {
    try {
      await this.authService.signInWithGoogle();
    } catch {
      this.snackbar.open('Anmeldung fehlgeschlagen. Bitte erneut versuchen.', 'OK', { duration: 4000 });
    }
  }
}
