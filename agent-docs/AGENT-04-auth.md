# Agent 04 — Auth Feature

> **WICHTIGE VORGABE:** Die Angular Web-App muss 1:1 exakt dieselben Funktionen bieten wie die Flutter App. Das UI soll an das Web (Desktop/Browser) angepasst werden, aber alle Funktionen und Features müssen lückenlos vorhanden sein.


## Rolle
Du implementierst die vollständige Authentifizierung. Nach diesem Agent kann sich ein User registrieren, anmelden (E-Mail + Google), abmelden und das Passwort zurücksetzen. Das Profil wird automatisch in Firestore angelegt.

## Input
- `AGENT-00-flutter-analysis-report.md` (Auth-Provider, Profil-Datenmodell)
- Outputs von Agent 02 (Security: Guards, Interceptor)
- Outputs von Agent 03 (Core: Models, ToastService, Shell)

## Flutter → Angular Mapping

| Flutter | Angular |
|---|---|
| `firebase_auth` + `google_sign_in` | `@angular/fire/auth` + `GoogleAuthProvider` |
| Riverpod `authStateProvider` | `toSignal(authState(auth))` |
| Riverpod `currentUserProvider` | `AuthService.currentUser` Signal |
| Profil-Repository | `UserProfileService.ensureProfile()` |

## Deine Aufgaben

### 4.1 AuthService

Datei: `src/app/core/auth/auth.service.ts`

```typescript
@Injectable({ providedIn: 'root' })
export class AuthService {
  // Signals
  readonly currentUser$   // authState() Observable
  readonly currentUser    // toSignal()
  readonly isLoggedIn     // computed(() => !!currentUser())
  readonly uid            // computed(() => currentUser()?.uid ?? null)

  // Methoden
  signInWithEmail(email, password): Promise<UserCredential>
  signInWithGoogle(): Promise<UserCredential>       // GoogleAuthProvider mit prompt: 'select_account'
  register(email, password, displayName?): Promise<UserCredential>
  sendPasswordReset(email): Promise<void>
  updateDisplayName(displayName): Promise<void>
  updateUserEmail(newEmail, currentPassword): Promise<void>   // Re-Auth erforderlich
  updateUserPassword(currentPassword, newPassword): Promise<void>  // Re-Auth erforderlich
  deleteAccount(currentPassword): Promise<void>               // Re-Auth + Cloud Function Trigger
  getIdToken(): Promise<string | null>
  signOut(): Promise<void>                          // → navigate to /auth/login
}
```

**Wichtig Re-Auth:** Vor `updateEmail`, `updatePassword` und `deleteAccount` muss `reauthenticateWithCredential` aufgerufen werden. Nicht optional.

### 4.2 Post-Login-Flow

Nach jedem erfolgreichen Login/Register/Google-SignIn:
1. `UserProfileService.ensureProfile(user)` aufrufen
2. `PremiumService.initialize(user.uid)` aufrufen (RevenueCat)
3. `NotificationService` Reminder wiederherstellen (aus gespeicherten Settings)
4. Zu `/dashboard` navigieren

Dieser Flow gehört in einen `AuthCallbackService` oder direkt in die `AppComponent` via `effect()` auf `AuthService.currentUser`.

### 4.3 AuthLayout Component

Datei: `src/app/features/auth/components/auth-layout/auth-layout.component.ts`

- Zentriertes Layout (vertikale + horizontale Zentrierung)
- App-Logo oben
- `<router-outlet>` für Login/Register/ForgotPassword
- Responsive: Auf Mobile Vollbild, auf Desktop Karte mit max-width 420px
- Kein Sidebar/Header (Shell wird hier nicht genutzt)

### 4.4 LoginComponent

Datei: `src/app/features/auth/components/login/login.component.ts`

Formular (Reactive Forms):
```
Email-Feld     [required, email]
Passwort-Feld  [required, minLength: 6]  + Passwort-Anzeigen Toggle
[Anmelden] Button
[Mit Google anmelden] Button  (eigenes Styling, Google-Logo)
[Passwort vergessen?] Link → /auth/forgot-password
[Konto erstellen] Link → /auth/register
```

Fehlerbehandlung:
- `auth/user-not-found` → "E-Mail-Adresse nicht gefunden"
- `auth/wrong-password` → "Falsches Passwort"
- `auth/too-many-requests` → "Zu viele Versuche. Bitte später erneut versuchen."
- Alle anderen → generische Fehlermeldung via `ToastService.error()`

Loading-State: Button deaktiviert + Spinner während Anmeldung läuft.

### 4.5 RegisterComponent

Datei: `src/app/features/auth/components/register/register.component.ts`

Formular:
```
Anzeigename    [required, minLength: 2]
Email-Feld     [required, email]
Passwort       [required, minLength: 8]
Passwort best. [required, mustMatch(passwort)]
[Registrieren] Button
[Bereits Konto?] Link → /auth/login
```

Custom Validator `mustMatch`: Prüft ob beide Passwort-Felder übereinstimmen.

Fehlerbehandlung:
- `auth/email-already-in-use` → "Diese E-Mail-Adresse ist bereits registriert"
- `auth/weak-password` → "Das Passwort ist zu schwach"

### 4.6 ForgotPasswordComponent

Datei: `src/app/features/auth/components/forgot-password/forgot-password.component.ts`

Formular:
```
Email-Feld  [required, email]
[Reset-Link senden] Button
```

Nach Erfolg: Bestätigungsmeldung anzeigen (nicht weiterleiten).
Fehler: Toast mit Fehlermeldung.

### 4.7 Routing (in app.routes.ts eintragen)

```
/auth                → AuthLayoutComponent
/auth/login          → LoginComponent
/auth/register       → RegisterComponent
/auth/forgot-password → ForgotPasswordComponent
```

Alle `/auth/*` Routen sind öffentlich (kein AuthGuard).
Wenn User bereits eingeloggt ist und `/auth/login` aufruft → Redirect zu `/dashboard`.

## Output
- `src/app/core/auth/auth.service.ts`
- `src/app/features/auth/components/auth-layout/`
- `src/app/features/auth/components/login/`
- `src/app/features/auth/components/register/`
- `src/app/features/auth/components/forgot-password/`

## Tests
- `auth.service.spec.ts`: Mock Auth, prüfe signIn/signOut/register
- `login.component.spec.ts`: Formular-Validierung, Fehleranzeige

## Übergabe
`AuthService` wird von allen anderen Feature-Agents (via `inject()`) genutzt um die aktuelle User-UID zu ermitteln. `UserProfileService` (Agent 09) ist Abhängigkeit dieses Agents.
