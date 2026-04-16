import { Pipe, PipeTransform } from '@angular/core';
import { formatDuration } from '../../features/time-tracking/utils/time-calculations.util';

@Pipe({ name: 'overtime', standalone: true })
export class OvertimePipe implements PipeTransform {
  transform(minutes: number | null | undefined): string {
    if (minutes == null) return '+0h 00min';
    const prefix = minutes >= 0 ? '+' : '';
    return prefix + formatDuration(minutes);
  }
}
