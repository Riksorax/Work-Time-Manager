import { ChangeDetectionStrategy, Component } from '@angular/core';
import { RouterLink } from '@angular/router';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';

@Component({
  selector: 'wtm-forgot-password',
  standalone: true,
  imports: [RouterLink, MatButtonModule, MatIconModule],
  changeDetection: ChangeDetectionStrategy.OnPush,
  styles: [`
    :host {
      display: flex;
      flex-direction: column;
      align-items: center;
      gap: 16px;
      padding: 8px 0;
      text-align: center;
    }
    p { margin: 0; font-size: 0.875rem; color: var(--mat-sys-on-surface-variant); }
    button { width: 100%; }
  `],
  template: `
    <mat-icon style="font-size:48px;width:48px;height:48px;color:var(--mat-sys-primary)">
      account_circle
    </mat-icon>
    <p>Da wir nur Google Sign-In verwenden, kannst du dein Passwort direkt über dein Google-Konto zurücksetzen.</p>
    <a mat-stroked-button routerLink="../login">
      <mat-icon>arrow_back</mat-icon>
      Zurück zur Anmeldung
    </a>
  `,
})
export class ForgotPasswordComponent {}
