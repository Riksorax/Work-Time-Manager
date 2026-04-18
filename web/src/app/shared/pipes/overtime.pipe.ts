import { Pipe, PipeTransform } from '@angular/core';
import { formatOvertime } from '../utils/time-calculations.util';

@Pipe({
  name: 'overtime',
  standalone: true
})
export class OvertimePipe implements PipeTransform {
  transform(minutes: number | null | undefined): string {
    if (minutes === null || minutes === undefined) return '+0h 00min';
    return formatOvertime(minutes);
  }
}
