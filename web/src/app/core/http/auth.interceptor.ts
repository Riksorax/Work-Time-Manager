import { HttpInterceptorFn } from '@angular/common/http';
import { inject } from '@angular/core';
import { Auth } from '@angular/fire/auth';
import { from, switchMap } from 'rxjs';
import { environment } from '../../../environments/environment';

/**
 * Hängt das Firebase-ID-Token als `Authorization: Bearer` an alle Requests
 * an die Backend-API (`environment.apiUrl`). Andere Requests bleiben unverändert.
 * Nicht eingeloggte Nutzer senden keinen Header (Backend antwortet dann 401 —
 * die Services nutzen für diesen Fall ohnehin den localStorage-Pfad).
 */
export const authInterceptor: HttpInterceptorFn = (req, next) => {
  if (!req.url.startsWith(environment.apiUrl)) {
    return next(req);
  }

  const user = inject(Auth).currentUser;
  if (!user) {
    return next(req);
  }

  return from(user.getIdToken()).pipe(
    switchMap(token =>
      next(req.clone({ setHeaders: { Authorization: `Bearer ${token}` } }))
    )
  );
};
