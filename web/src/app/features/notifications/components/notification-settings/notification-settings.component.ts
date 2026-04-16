import { ChangeDetectionStrategy, Component } from '@angular/core';

@Component({
  selector: 'wtm-notification-settings',
  standalone: true,
  template: `<p>Benachrichtigungen</p>`,
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class NotificationSettingsComponent {}
