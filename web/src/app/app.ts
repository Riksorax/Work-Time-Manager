import { Component, inject } from '@angular/core';
import { RouterOutlet } from '@angular/router';
import { AuthCallbackService } from './core/auth/auth-callback.service';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [RouterOutlet],
  template: `<router-outlet></router-outlet>`
})
export class AppComponent {
  // Inject service to trigger the effect
  private authCallback = inject(AuthCallbackService);
}
