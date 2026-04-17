// core/auth/auth.guard.ts
import { inject } from '@angular/core';
import { CanActivateFn, Router } from '@angular/router';
import { filter, map, take } from 'rxjs/operators';
import { AuthService } from './auth.service';

export const authGuard: CanActivateFn = () => {
  const auth = inject(AuthService);
  const router = inject(Router);

  // filter(u => u !== undefined) wartet auf Firebase-Session-Restore aus IndexedDB,
  // bevor take(1) feuert — verhindert Fehlweiterleitung bei frischem Page-Load.
  return auth.currentUser$.pipe(
    filter(user => user !== undefined),
    take(1),
    map(user => {
      if (user) return true;
      return router.createUrlTree(['/auth/login']);
    })
  );
};

// core/security/premium.guard.ts
// (In eigener Datei src/app/core/security/premium.guard.ts)
