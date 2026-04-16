// core/security/premium.guard.ts

import { inject } from '@angular/core';
import { CanActivateFn, Router } from '@angular/router';
import { PremiumService } from '../../features/premium/services/premium.service';

export const premiumGuard: CanActivateFn = () => {
  const premium = inject(PremiumService);
  const router = inject(Router);

  if (premium.isPremium()) {
    return true;
  }
  return router.createUrlTree(['/settings/premium']);
};
