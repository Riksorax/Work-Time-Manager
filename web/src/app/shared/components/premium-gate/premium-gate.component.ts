import { ChangeDetectionStrategy, Component, inject, input } from '@angular/core';
import { Router } from '@angular/router';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { TranslateModule } from '@ngx-translate/core';

@Component({
  selector: 'wtm-premium-gate',
  standalone: true,
  imports: [MatButtonModule, MatIconModule, TranslateModule],
  template: `
    <div class="gate-container">
      <mat-icon class="gate-icon">workspace_premium</mat-icon>
      <p class="gate-message">{{ message() }}</p>
      <button mat-flat-button (click)="openPaywall()">
        <mat-icon>lock_open</mat-icon>
        {{ 'premium.unlock' | translate }}
      </button>
    </div>
  `,
  styles: [`
    .gate-container {
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      gap: 16px;
      padding: 48px 24px;
      text-align: center;
    }
    .gate-icon {
      font-size: 56px;
      width: 56px;
      height: 56px;
      color: var(--wtm-premium-color);
    }
    .gate-message {
      margin: 0;
      font-size: 16px;
      color: var(--mat-sys-on-surface-variant);
      max-width: 320px;
    }
  `],
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class PremiumGateComponent {
  readonly message = input<string>('Dieses Feature ist nur für Premium-Nutzer verfügbar.');

  private router = inject(Router);

  openPaywall(): void {
    this.router.navigate(['/settings/premium']);
  }
}
