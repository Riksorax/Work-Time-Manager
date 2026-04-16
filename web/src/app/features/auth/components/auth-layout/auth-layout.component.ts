import { ChangeDetectionStrategy, Component } from '@angular/core';

@Component({
  selector: 'wtm-auth-layout',
  standalone: true,
  template: `<p>Auth Layout</p>`,
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class AuthLayoutComponent {}
