import { ChangeDetectionStrategy, Component } from '@angular/core';
import { RouterLink } from '@angular/router';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { TranslatePipe } from '@ngx-translate/core';

@Component({
  selector: 'app-not-found',
  imports: [RouterLink, MatButtonModule, MatIconModule, TranslatePipe],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <div class="not-found-container">
      <mat-icon class="not-found-icon" aria-hidden="true">search_off</mat-icon>
      <h1>{{ 'notFound.title' | translate }}</h1>
      <p>{{ 'notFound.message' | translate }}</p>
      <a mat-flat-button routerLink="/dashboard">{{ 'notFound.backToDashboard' | translate }}</a>
    </div>
  `,
  styles: [`
    .not-found-container {
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      min-height: 100vh;
      padding: 24px;
      text-align: center;
      gap: 12px;
    }

    .not-found-icon {
      font-size: 64px;
      width: 64px;
      height: 64px;
      color: var(--mat-sys-on-surface-variant);
      margin-bottom: 8px;
    }

    h1 {
      margin: 0;
      font-size: 1.5rem;
      color: var(--mat-sys-on-surface);
    }

    p {
      margin: 0 0 12px;
      color: var(--mat-sys-on-surface-variant);
    }
  `],
})
export class NotFoundComponent {}
