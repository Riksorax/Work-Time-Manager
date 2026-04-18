import { inject } from '@angular/core';
import { Router, CanActivateFn } from '@angular/router';
import { PremiumService } from '../../features/premium/services/premium.service';

export const premiumGuard: CanActivateFn = () => {
  const router = inject(Router);
  const premiumService = inject(PremiumService);
  
  if (premiumService.isPremium()) {
    return true;
  } else {
    router.navigate(['/settings/premium']);
    return false;
  }
};
