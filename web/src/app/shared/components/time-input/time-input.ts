import { ChangeDetectionStrategy, Component, DestroyRef, computed, effect, inject, input, output, untracked } from '@angular/core';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatIconModule } from '@angular/material/icon';
import { MatButtonModule } from '@angular/material/button';
import { TranslatePipe } from '@ngx-translate/core';

@Component({
  selector: 'app-time-input',
  imports: [MatFormFieldModule, MatInputModule, MatIconModule, MatButtonModule, TranslatePipe],
  templateUrl: './time-input.html',
  // `time-input.scss` ist in keiner Komponente eingebunden, `.time-field { width: 100% }` galt daher nie: das Feld blieb
  // ~240 px breit, während Karten und Hauptbutton die volle Breite nutzen. Das Host-Element ist ein Custom-Element (inline).
  styles: [`
    :host { display: block; }
    .time-field { width: 100%; }
  `],
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class TimeInputComponent {
  readonly label     = input<string>('');
  readonly value     = input<Date | null | undefined>(undefined);
  readonly disabled  = input<boolean>(false);
  readonly showClear = input<boolean>(false);
  /**
   * Opt-in (Default aus): Eingaben zusammenfassen. Das `change`-Event eines `<input type="time">` feuert in Chromium nach jeder
   * gültigen Teiländerung („0930“: 09:00, 09:03, 09:30). Mit `settle` geht `timeSelected` erst nach `_settleMs` Ruhe oder
   * sofort beim Verlassen des Feldes (blur) einmal mit dem letzten Wert hinaus. Ist das Feld gesperrt (`disabled`), wird nicht
   * gesendet, ein vorgemerkter Wert aber nicht verworfen: er geht beim Entsperren hinaus. Beim Zerstören verfällt er.
   */
  readonly settle    = input<boolean>(false);

  readonly timeSelected = output<string>();
  readonly cleared      = output<void>();

  readonly formattedValue = computed(() => {
    const v = this.value();
    if (!v) return '';
    const h = String(v.getHours()).padStart(2, '0');
    const m = String(v.getMinutes()).padStart(2, '0');
    return `${h}:${m}`;
  });

  /** Ruhezeit in ms; Literal, keine importierte Konstante (Vite-SSR-Falle, web/CLAUDE.md). */
  private readonly _settleMs = 600;
  private readonly _destroyRef = inject(DestroyRef);
  private _timer: ReturnType<typeof setTimeout> | null = null;
  /** Letzter getippter, noch nicht gesendeter Wert (nur mit `settle`). */
  private _pending: string | null = null;

  constructor() {
    this._destroyRef.onDestroy(() => {
      this._clearTimer();
      this._pending = null;
    });
    // Ist die Ruhezeit während einer Sperre abgelaufen, geht der vorgemerkte Wert beim Entsperren hinaus.
    effect(() => {
      if (this.disabled()) return;
      untracked(() => {
        if (this._pending !== null && this._timer === null) this._flush();
      });
    });
  }

  onTimeChange(event: Event): void {
    const val = (event.target as HTMLInputElement).value;
    if (!val) return;
    if (!this.settle()) {
      this.timeSelected.emit(val);
      return;
    }
    this._pending = val;
    this._clearTimer();
    this._timer = setTimeout(() => {
      this._timer = null;
      this._flush();
    }, this._settleMs);
  }

  /** Verlassen des Feldes: vorgemerkten Wert sofort senden (Flush), sonst nichts. */
  onBlur(): void {
    if (this._pending === null) return;
    this._clearTimer();
    this._flush();
  }

  private _flush(): void {
    const val = this._pending;
    if (val === null || this.disabled()) return; // gesperrt: Wert behalten, beim Entsperren senden
    this._pending = null;
    this.timeSelected.emit(val);
  }

  private _clearTimer(): void {
    if (this._timer !== null) {
      clearTimeout(this._timer);
      this._timer = null;
    }
  }

  onClear(): void {
    this.cleared.emit();
  }
}
