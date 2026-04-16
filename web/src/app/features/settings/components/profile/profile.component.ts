import { ChangeDetectionStrategy, Component } from '@angular/core';

@Component({
  selector: 'wtm-profile',
  standalone: true,
  template: `<p>Profil</p>`,
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class ProfileComponent {}
