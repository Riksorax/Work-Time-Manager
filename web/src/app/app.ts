import { ChangeDetectionStrategy, Component, effect, inject, signal } from '@angular/core';
import { RouterOutlet } from '@angular/router';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { ThemeService } from './core/services/theme';

const PLAY_STORE_URL = 'https://play.google.com/store/apps/details?id=app.work_time_manager';
const DISMISSED_KEY  = 'android_banner_dismissed';

// ── Android App Banner ────────────────────────────────────────────────────────

@Component({
  selector: 'app-android-banner',
  imports: [MatButtonModule, MatIconModule],
  changeDetection: ChangeDetectionStrategy.OnPush,
  styles: [`
    .banner {
      display: flex;
      align-items: center;
      gap: 12px;
      padding: 10px 16px;
      background: var(--mat-sys-primary-container);
      color: var(--mat-sys-on-primary-container);
    }
    .banner-icon { font-size: 28px; width: 28px; height: 28px; flex-shrink: 0; }
    .banner-text { flex: 1; min-width: 0; }
    .banner-title { font-size: 0.875rem; font-weight: 500; margin: 0; }
    .banner-sub   { font-size: 0.75rem;  opacity: 0.8;     margin: 0; }
  `],
  template: `
    @if (visible()) {
      <div class="banner" role="banner" aria-label="Android-App verfügbar">
        <mat-icon class="banner-icon" aria-hidden="true">android</mat-icon>
        <div class="banner-text">
          <p class="banner-title">Work Time Manager App</p>
          <p class="banner-sub">Kostenlos im Google Play Store</p>
        </div>
        <a mat-flat-button [href]="playStoreUrl" target="_blank" rel="noopener"
           aria-label="App im Play Store öffnen">
          Öffnen
        </a>
        <button mat-icon-button (click)="dismiss()" aria-label="Banner schließen">
          <mat-icon>close</mat-icon>
        </button>
      </div>
    }
  `,
})
export class AndroidBannerComponent {
  protected readonly playStoreUrl = PLAY_STORE_URL;
  readonly visible = signal(!localStorage.getItem(DISMISSED_KEY));

  dismiss(): void {
    localStorage.setItem(DISMISSED_KEY, '1');
    this.visible.set(false);
  }
}

// ── App Root ──────────────────────────────────────────────────────────────────

@Component({
  selector: 'app-root',
  imports: [RouterOutlet, AndroidBannerComponent],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './app.html',
  styleUrl:    './app.scss',
})
export class App {
  private readonly theme = inject(ThemeService);

  protected readonly isAndroid = signal(
    typeof navigator !== 'undefined' && /Android/i.test(navigator.userAgent)
  );

  constructor() {
    this.theme.applyStoredTheme();
    effect(() => {
      document.documentElement.classList.toggle('dark-theme', this.theme.isDarkMode());
    });
  }
}
