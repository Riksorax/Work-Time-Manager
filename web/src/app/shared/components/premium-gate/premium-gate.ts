import { Component, Input } from '@angular/core';
import { CommonModule } from '@angular/common';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { RouterLink } from '@angular/router';

@Component({
  selector: 'app-premium-gate',
  standalone: true,
  imports: [CommonModule, MatButtonModule, MatIconModule, RouterLink],
  template: `
    <div class="gate-container">
      <mat-icon class="lock-icon">lock</mat-icon>
      <h2>Premium-Feature</h2>
      <p>{{ message }}</p>
      <button mat-raised-button color="primary" routerLink="/settings/premium">
        Premium freischalten
      </button>
    </div>
  `,
  styles: `
    .gate-container {
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      padding: 3rem;
      border: 2px dashed rgba(0, 0, 0, 0.1);
      border-radius: 8px;
      text-align: center;
      margin: 1rem;
    }
    .lock-icon {
      font-size: 48px;
      width: 48px;
      height: 48px;
      margin-bottom: 1rem;
      color: #ffc107;
    }
    h2 { margin-bottom: 0.5rem; }
    p { margin-bottom: 1.5rem; color: rgba(0, 0, 0, 0.6); }
  `
})
export class PremiumGateComponent {
  @Input() message: string = 'Dieses Feature ist nur für Premium-Nutzer verfügbar.';
}
