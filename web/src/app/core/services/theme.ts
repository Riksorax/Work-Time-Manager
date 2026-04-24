import { Injectable, signal } from '@angular/core';

const LS_KEY = 'theme';

@Injectable({ providedIn: 'root' })
export class ThemeService {
  private readonly _isDark = signal(
    typeof localStorage !== 'undefined' && localStorage.getItem(LS_KEY) === 'dark'
  );

  readonly isDarkMode = this._isDark.asReadonly();

  setTheme(dark: boolean): void {
    this._isDark.set(dark);
    localStorage.setItem(LS_KEY, dark ? 'dark' : 'light');
    document.documentElement.classList.toggle('dark-theme', dark);
  }

  applyStoredTheme(): void {
    document.documentElement.classList.toggle('dark-theme', this._isDark());
  }
}
