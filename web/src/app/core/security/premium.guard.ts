import { inject } from '@angular/core';
import { Router, CanActivateFn } from '@angular/router';

export const premiumGuard: CanActivateFn = () => {
  const router = inject(Router);
  
  // TODO: Implement actual check using PremiumService signal
  // For now, allow but log
  console.warn('PremiumGuard: Actual check not implemented yet');
  
  const isPremium = false; // Mock value
  
  if (isPremium) {
    return true;
  } else {
    router.navigate(['/settings/premium']);
    return false;
  }
};
