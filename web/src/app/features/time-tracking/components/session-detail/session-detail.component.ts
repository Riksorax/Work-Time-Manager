import { ChangeDetectionStrategy, Component } from '@angular/core';

@Component({
  selector: 'wtm-session-detail',
  standalone: true,
  template: `<p>Session bearbeiten</p>`,
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class SessionDetailComponent {}
