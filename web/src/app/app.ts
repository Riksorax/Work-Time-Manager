import { Component, effect, inject, signal } from '@angular/core';
import { RouterOutlet } from '@angular/router';
import { ThemeService } from './core/services/theme';

@Component({
  selector: 'app-root',
  imports: [RouterOutlet],
  templateUrl: './app.html',
  styleUrl: './app.scss',
})
export class App {
  protected readonly title = signal('work-time-manager-web');
  private  readonly theme  = inject(ThemeService);

  constructor() {
    this.theme.applyStoredTheme();
    effect(() => {
      document.documentElement.classList.toggle('dark-theme', this.theme.isDarkMode());
    });
  }
}
