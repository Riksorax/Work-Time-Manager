import { ChangeDetectionStrategy, Component } from '@angular/core';

@Component({
  selector: 'wtm-register',
  standalone: true,
  template: `<p>Register</p>`,
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class RegisterComponent {}
