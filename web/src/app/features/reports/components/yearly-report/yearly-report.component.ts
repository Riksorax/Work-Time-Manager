import { ChangeDetectionStrategy, Component } from '@angular/core';

@Component({
  selector: 'wtm-yearly-report',
  standalone: true,
  template: `<p>Jahresbericht</p>`,
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class YearlyReportComponent {}
