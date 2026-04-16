import { ChangeDetectionStrategy, Component } from '@angular/core';

@Component({
  selector: 'wtm-forgot-password',
  standalone: true,
  template: `<p>Passwort vergessen</p>`,
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class ForgotPasswordComponent {}
