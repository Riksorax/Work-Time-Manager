import { ChangeDetectionStrategy, Component } from '@angular/core';

@Component({
  selector: 'wtm-session-list',
  standalone: true,
  template: `<p>Zeiterfassung</p>`,
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class SessionListComponent {}
