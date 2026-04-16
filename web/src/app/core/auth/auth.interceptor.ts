// core/auth/auth.interceptor.ts
// Injiziert Firebase ID-Token in alle HTTP-Requests (für künftige REST-API)

import { HttpInterceptorFn } from '@angular/common/http';
import { inject } from '@angular/core';
import { from, switchMap } from 'rxjs';
import { AuthService } from './auth.service';

export const authInterceptor: HttpInterceptorFn = (req, next) => {
  const auth = inject(AuthService);

  // Nur für API-Requests (nicht für Firebase direkt, das handled Firebase SDK intern)
  if (!req.url.includes('/api/')) {
    return next(req);
  }

  return from(auth.getIdToken()).pipe(
    switchMap(token => {
      if (!token) return next(req);
      return next(
        req.clone({
          setHeaders: { Authorization: `Bearer ${token}` },
        })
      );
    })
  );
};
