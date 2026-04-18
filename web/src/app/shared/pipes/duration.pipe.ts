import { Pipe, PipeTransform } from '@angular/core';
import { formatDuration } from '../utils/time-calculations.util';

@Pipe({
  name: 'duration',
  standalone: true
})
export class DurationPipe implements PipeTransform {
  transform(minutes: number | null | undefined): string {
    if (minutes === null || minutes === undefined) return '0h 00min';
    return formatDuration(minutes);
  }
}
