import { ChangeDetectionStrategy, Component, input } from '@angular/core';
import { MatIconModule } from '@angular/material/icon';
import { TranslatePipe } from '@ngx-translate/core';
import { GermanHoliday } from '../../utils/german-holidays.util';

/** Rein informativer Hinweis "Heute ist Feiertag: …" (siehe #279). Optik analog Mobile (tertiaryContainer). */
@Component({
  selector: 'app-holiday-banner',
  imports: [MatIconModule, TranslatePipe],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './holiday-banner.html',
  styleUrl: './holiday-banner.scss',
})
export class HolidayBannerComponent {
  readonly holiday = input.required<GermanHoliday>();
}
