import { DestroyRef, Injectable, inject, signal } from '@angular/core';
import { toDateKey } from '../../shared/utils/german-holidays.util';

/**
 * Lokales „heute" als `YYYY-MM-DD` (#372). Wechselt zur lokalen Mitternacht (setTimeout bis zur nächsten
 * lokalen Mitternacht, DST-sicher) sowie bei `visibilitychange` (visible), `window.focus` und `pageshow`
 * (Standby/Hintergrund-Tabs, in denen Timer gedrosselt oder verpasst werden). Alle Listener und der Timer
 * werden über `DestroyRef` aufgeräumt.
 */
@Injectable({ providedIn: 'root' })
export class TodayService {
  private readonly destroyRef = inject(DestroyRef);
  private readonly _today = signal<string>(toDateKey(new Date()));
  private _handle: ReturnType<typeof setTimeout> | null = null;

  readonly today = this._today.asReadonly();

  constructor() {
    const onVisibility = (): void => {
      if (document.visibilityState === 'visible') this._resync();
    };
    const onFocus = (): void => this._resync();
    const onPageShow = (): void => this._resync();

    document.addEventListener('visibilitychange', onVisibility);
    window.addEventListener('focus', onFocus);
    window.addEventListener('pageshow', onPageShow);
    this._schedule();

    this.destroyRef.onDestroy(() => {
      document.removeEventListener('visibilitychange', onVisibility);
      window.removeEventListener('focus', onFocus);
      window.removeEventListener('pageshow', onPageShow);
      if (this._handle !== null) clearTimeout(this._handle);
      this._handle = null;
    });
  }

  /** Setzt den Key aus der aktuellen lokalen Zeit (Signal-Gleichheit verhindert Doppel-Auslösung). */
  refresh(): void {
    this._today.set(toDateKey(new Date()));
  }

  private _resync(): void {
    this.refresh();
    this._schedule();
  }

  private _schedule(): void {
    if (this._handle !== null) clearTimeout(this._handle);
    const now = new Date();
    const nextMidnight = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1).getTime();
    const delay = Math.max(1000, nextMidnight - now.getTime());
    this._handle = setTimeout(() => this._resync(), delay);
  }
}
