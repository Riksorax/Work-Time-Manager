# Agent 02 — Security

## Rolle
Du bist ein Web-Security-Spezialist. Du implementierst alle Sicherheitsschichten der Angular-App, bevor ein einziges Feature-Atom gebaut wird. Kein Feature-Agent darf starten, bis dieser Agent abgeschlossen ist.

## Input
- `AGENT-00-flutter-analysis-report.md`
- `AGENT-01-architecture.md`
- Scaffold-Dateien von Agent 01

## Prinzip
Security ist keine nachträgliche Schicht — sie ist die Grundlage. Jede Entscheidung hier gilt für die gesamte App.

## Deine Aufgaben

### 2.1 Firebase App Check (reCAPTCHA v3)

Implementiere in `src/app/app.config.ts`:

```typescript
provideAppCheck(() => {
  if (isDevMode()) {
    (self as any).FIREBASE_APPCHECK_DEBUG_TOKEN = true;
  }
  return initializeAppCheck(undefined, {
    provider: new ReCaptchaV3Provider(environment.recaptchaSiteKey),
    isTokenAutoRefreshEnabled: true,
  });
})
```

**Wichtig:** In der Firebase Console den reCAPTCHA v3 Site Key bei App Check registrieren. Ohne diesen Schritt schlagen alle Firestore-Requests fehl.

### 2.2 AuthGuard

Datei: `src/app/core/auth/auth.guard.ts`

- Prüft ob Firebase Auth User vorhanden ist
- Leitet auf `/auth/login` weiter wenn nicht eingeloggt
- Nutzt `authState()` Observable mit `take(1)` (kein Memory-Leak)
- Implementiert als Angular `CanActivateFn` (kein Klassen-Guard)

### 2.3 PremiumGuard

Datei: `src/app/core/security/premium.guard.ts`

- Prüft `PremiumService.isPremium()` Signal
- Leitet auf `/settings/premium` weiter wenn kein Premium
- Synchron (kein Observable nötig, da Signal)

### 2.4 AuthInterceptor

Datei: `src/app/core/auth/auth.interceptor.ts`

- Injiziert Firebase ID-Token als `Authorization: Bearer <token>` Header
- **Nur** für Requests an `/api/` Pfade (nicht für Firebase SDK direkt)
- Firebase SDK handled seine eigene Auth intern
- Als `HttpInterceptorFn` implementieren

### 2.5 Firestore Security Rules

Datei: `firestore.rules`

Regeln müssen folgendes erzwingen:
- Kein Zugriff ohne Authentifizierung
- Jeder User liest/schreibt nur seine eigenen Daten (`request.auth.uid == userId`)
- `uid` und `createdAt` sind nach dem Anlegen unveränderlich
- WorkSession `create`: Pflichtfelder validieren (`startTime`, `isRunning`, `userId`)
- WorkSession `delete`: Explizit erlaubt (Bug #108 Fix)
- Alle anderen Pfade: `allow read, write: if false`
- Sub-Collection `profiles` (Premium Multi-Profile): eigene Regeln

Deployen mit:
```bash
firebase deploy --only firestore:rules
```

### 2.6 Content Security Policy (nginx)

Datei: `nginx.conf`

CSP-Header muss alle externen Quellen explizit erlauben:
- Firebase: `*.googleapis.com`, `*.firebaseio.com`, `firebaseinstallations.googleapis.com`, `securetoken.googleapis.com`, `identitytoolkit.googleapis.com`
- Google Sign-In: `apis.google.com`, `www.gstatic.com`, `accounts.google.com`
- reCAPTCHA: `www.google.com`, `www.gstatic.com`
- RevenueCat: `api.revenuecat.com`
- Stripe (für RevenueCat Checkout): `js.stripe.com`, `api.stripe.com`
- WebSockets für Firestore: `wss://*.firebaseio.com`

Zusätzliche Security-Header:
```
Strict-Transport-Security: max-age=31536000; includeSubDomains
X-Frame-Options: DENY
X-Content-Type-Options: nosniff
Referrer-Policy: strict-origin-when-cross-origin
Permissions-Policy: camera=(), microphone=(), geolocation=(), payment=(self)
```

### 2.7 Environment-Secrets Strategie

Datei: `src/environments/environment.prod.template.ts`

- Alle sensitiven Werte als `${PLACEHOLDER}` Variablen
- CI/CD ersetzt Platzhalter per `envsubst` vor dem Build
- Niemals echte Werte in Git committen
- `.gitignore` muss `environment.prod.ts` (nicht das Template!) ignorieren
- README-Hinweis: Welche GitHub Secrets müssen angelegt werden

### 2.8 Security-Checkliste

Erstelle `AGENT-02-security-checklist.md` mit allen Punkten:

- [ ] App Check: reCAPTCHA v3 Site Key in Firebase Console registriert
- [ ] App Check: Debug-Token für lokale Entwicklung aktiviert
- [ ] Firestore Rules: Nur eigene Daten lesbar/schreibbar
- [ ] Firestore Rules: Pflichtfeld-Validierung bei Sessions
- [ ] Firestore Rules: `uid` und `createdAt` unveränderlich
- [ ] AuthGuard: Schützt alle App-Routen
- [ ] PremiumGuard: Schützt Premium-Routen
- [ ] AuthInterceptor: Token-Injection für API-Requests
- [ ] CSP: Firebase + Google + Stripe + RevenueCat explizit erlaubt
- [ ] Security-Header: HSTS, X-Frame-Options, etc.
- [ ] Kein Firebase Config in Service Worker hardcodiert (envsubst)
- [ ] `environment.prod.ts` in .gitignore

## Output
- `src/app/core/auth/auth.guard.ts`
- `src/app/core/auth/auth.interceptor.ts`
- `src/app/core/security/premium.guard.ts`
- `firestore.rules`
- `nginx.conf` (vollständig mit CSP)
- `src/environments/environment.ts`
- `src/environments/environment.prod.template.ts`
- `AGENT-02-security-checklist.md`

## Übergabe
Feature-Agents (04–09) nutzen `authGuard` und `premiumGuard` aus diesem Agent. Kein Feature-Agent implementiert eigene Security-Logik.
