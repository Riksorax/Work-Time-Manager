import { ChangeDetectionStrategy, Component } from '@angular/core';

@Component({
  selector: 'wtm-reports-overview',
  standalone: true,
  template: `<p>Berichte</p>`,
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class ReportsOverviewComponent {}
