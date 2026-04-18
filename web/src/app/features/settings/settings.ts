import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';

@Component({
  selector: 'app-settings',
  standalone: true,
  imports: [CommonModule],
  template: `
    <h2>Einstellungen</h2>
    <p>Hier können Sie Ihre App-Einstellungen anpassen (Coming Soon).</p>
  `,
  styles: [``]
})
export class SettingsComponent {}
