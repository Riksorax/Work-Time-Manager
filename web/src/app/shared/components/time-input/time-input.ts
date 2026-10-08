import { ChangeDetectionStrategy, Component, computed, input, output } from '@angular/core';
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

  readonly timeSelected = output<string>();
  readonly cleared      = output<void>();

  readonly formattedValue = computed(() => {
    const v = this.value();
    if (!v) return '';
    const h = String(v.getHours()).padStart(2, '0');
    const m = String(v.getMinutes()).padStart(2, '0');
    return `${h}:${m}`;
  });

  onTimeChange(event: Event): void {
    const val = (event.target as HTMLInputElement).value;
    if (val) this.timeSelected.emit(val);
  }

  onClear(): void {
    this.cleared.emit();
  }
}
