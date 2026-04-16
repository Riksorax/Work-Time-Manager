import { ChangeDetectionStrategy, Component } from '@angular/core';

@Component({
  selector: 'wtm-dashboard',
  standalone: true,
  template: `<p>Dashboard</p>`,
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class DashboardComponent {}
