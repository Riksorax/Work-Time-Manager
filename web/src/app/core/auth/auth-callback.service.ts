import { Injectable, inject, effect } from '@angular/core';
import { AuthService } from './auth.service';
import { UserProfileService } from '../../features/settings/services/user-profile.service';
import { Router } from '@angular/router';

@Injectable({
  providedIn: 'root'
})
export class AuthCallbackService {
  private authService = inject(AuthService);
  private profileService = inject(UserProfileService);
  private router = inject(Router);

  constructor() {
    effect(async () => {
      const user = this.authService.currentUser();
      if (user) {
        await this.profileService.ensureProfile(user);
        // Nach Login zum Dashboard, falls wir auf /auth waren
        if (this.router.url.includes('/auth/')) {
          this.router.navigate(['/dashboard']);
        }
      }
    });
  }
}
