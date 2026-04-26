import { Injectable, signal } from '@angular/core';

const LS_KEY = 'theme';

@Injectable({ providedIn: 'root' })
export class ThemeService {
  private readonly _isDark = signal(this._resolveInitial());

  private _resolveInitial(): boolean {
    const stored = typeof localStorage !== 'undefined' ? localStorage.getItem(LS_KEY) : null;
    if (stored === 'dark')  return true;
    if (stored === 'light') return false;
    // Kein gespeicherter Wert → OS-Präferenz übernehmen
    return typeof window !== 'undefined'
      && window.matchMedia('(prefers-color-scheme: dark)').matches;
  }

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
