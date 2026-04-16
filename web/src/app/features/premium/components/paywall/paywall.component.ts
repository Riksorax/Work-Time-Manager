import { ChangeDetectionStrategy, Component } from '@angular/core';

@Component({
  selector: 'wtm-paywall',
  standalone: true,
  template: `<p>Premium</p>`,
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class PaywallComponent {}
