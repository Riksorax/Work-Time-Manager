import { ChangeDetectionStrategy, Component } from '@angular/core';

@Component({
  selector: 'wtm-profiles',
  standalone: true,
  template: `<p>Profile</p>`,
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class ProfilesComponent {}
