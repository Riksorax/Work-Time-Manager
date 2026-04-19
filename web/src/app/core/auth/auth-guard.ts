import { inject } from '@angular/core';
import { Router, CanActivateFn } from '@angular/router';
import { Auth } from '@angular/fire/auth';

export const authGuard: CanActivateFn = async () => {
  const auth   = inject(Auth);
  const router = inject(Router);

  await auth.authStateReady();

  if (auth.currentUser) {
    return true;
  }

  return router.createUrlTree(['/auth/login']);
};
