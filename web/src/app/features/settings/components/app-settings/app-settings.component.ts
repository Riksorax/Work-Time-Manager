import { ChangeDetectionStrategy, Component } from '@angular/core';

@Component({
  selector: 'wtm-app-settings',
  standalone: true,
  template: `<p>App-Einstellungen</p>`,
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class AppSettingsComponent {}
