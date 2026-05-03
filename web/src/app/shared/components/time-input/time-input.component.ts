import { ChangeDetectionStrategy, Component, computed, input, output } from '@angular/core';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatIconModule } from '@angular/material/icon';
import { MatButtonModule } from '@angular/material/button';

@Component({
  selector: 'app-time-input',
  imports: [MatFormFieldModule, MatInputModule, MatIconModule, MatButtonModule],
  templateUrl: './time-input.component.html',
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
