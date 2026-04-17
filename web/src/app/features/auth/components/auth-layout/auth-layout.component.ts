import { ChangeDetectionStrategy, Component } from '@angular/core';
import { RouterOutlet } from '@angular/router';
import { MatCardModule } from '@angular/material/card';

@Component({
  selector: 'wtm-auth-layout',
  standalone: true,
  imports: [RouterOutlet, MatCardModule],
  changeDetection: ChangeDetectionStrategy.OnPush,
  styles: [`
    :host {
      display: flex;
      align-items: center;
      justify-content: center;
      min-height: 100vh;
      background: var(--mat-sys-surface-container-low);
      padding: 16px;
    }

    mat-card {
      width: 100%;
      max-width: 420px;
    }

    .brand {
      text-align: center;
      margin-bottom: 24px;

      h1 {
        margin: 0;
        font-size: 1.5rem;
        font-weight: 700;
        color: var(--mat-sys-primary);
      }

      p {
        margin: 4px 0 0;
        font-size: 0.875rem;
        color: var(--mat-sys-on-surface-variant);
      }
    }
  `],
  template: `
    <mat-card appearance="outlined">
      <mat-card-content>
        <div class="brand">
          <h1>Work Time Manager</h1>
          <p>Einfach. Präzise. Deine Zeit.</p>
        </div>
        <router-outlet />
      </mat-card-content>
    </mat-card>
  `,
})
export class AuthLayoutComponent {}
