import { ChangeDetectionStrategy, Component } from '@angular/core';

@Component({
  selector: 'wtm-monthly-report',
  standalone: true,
  template: `<p>Monatsbericht</p>`,
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class MonthlyReportComponent {}
