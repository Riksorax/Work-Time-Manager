import { ChangeDetectionStrategy, Component, inject, signal } from '@angular/core';
import { Router } from '@angular/router';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatProgressSpinnerModule } from '@angular/material/progress-spinner';
import { TranslateModule } from '@ngx-translate/core';
import { AuthService } from '../../../../core/auth/auth.service';
import { ToastService } from '../../../../shared/components/toast/toast.service';

@Component({
  selector: 'wtm-register',
  standalone: true,
  imports: [MatButtonModule, MatIconModule, MatProgressSpinnerModule, TranslateModule],
  changeDetection: ChangeDetectionStrategy.OnPush,
  styles: [`
    :host {
      display: flex;
      flex-direction: column;
      align-items: center;
      gap: 16px;
      padding: 8px 0;
    }
    p { margin: 0; font-size: 0.875rem; color: var(--mat-sys-on-surface-variant); text-align: center; }
    button { width: 100%; }
  `],
  template: `
    <p>Erstelle ein Konto mit deinem Google-Profil.</p>

    <button mat-flat-button (click)="signInWithGoogle()" [disabled]="loading()">
      @if (loading()) {
        <mat-spinner diameter="18" />
      } @else {
        <ng-container>
          <mat-icon svgIcon="google" />
          {{ 'auth.googleSignIn' | translate }}
        </ng-container>
      }
    </button>
  `,
})
export class RegisterComponent {
  private auth = inject(AuthService);
  private router = inject(Router);
  private toast = inject(ToastService);

  readonly loading = signal(false);

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
