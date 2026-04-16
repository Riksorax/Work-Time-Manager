import { ChangeDetectionStrategy, Component } from '@angular/core';

@Component({
  selector: 'wtm-shell',
  standalone: true,
  template: `<p>Shell</p>`,
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class ShellComponent {}
