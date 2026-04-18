# Security Checklist — Agent 02

- [x] App Check: reCAPTCHA v3 Provider in `app.config.ts` implementiert
- [x] AuthGuard: `CanActivateFn` in `core/auth/auth.guard.ts` erstellt
- [x] PremiumGuard: Platzhalter in `core/security/premium.guard.ts` (Integration in Agent 07)
- [x] AuthInterceptor: Token-Injection für `/api/` Requests implementiert
- [x] Firestore Rules: `firestore.rules` mit WorkEntry-Logik erstellt
- [x] nginx: `nginx.conf` mit CSP und Security-Headern konfiguriert
- [x] Environments: `environment.prod.template.ts` für CI/CD erstellt
- [x] Routing: `authGuard` in `app.routes.ts` registriert
- [x] Config: `authInterceptor` in `app.config.ts` registriert

## Nächste Schritte
- In Agent 04: Login-Flow implementieren, damit der AuthGuard greifen kann.
- In Agent 07: `premiumGuard` mit echtem `PremiumService` verbinden.
