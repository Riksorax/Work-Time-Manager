# Agent 09 — Settings & Profile

> **WICHTIGE VORGABE:** Die Angular Web-App muss 1:1 exakt dieselben Funktionen bieten wie die Flutter App. Das UI soll an das Web (Desktop/Browser) angepasst werden, aber alle Funktionen und Features müssen lückenlos vorhanden sein.


## Rolle
Du implementierst alle Einstellungs-Screens. Wichtig: Bug #107 aus den Issues ist hier zu lösen — App-Einstellungen und Profil-Einstellungen müssen klar voneinander getrennt sein (eigene Routen, eigene Komponenten).

## Input
- `AGENT-00-flutter-analysis-report.md` (UserProfile-Modell, Bug #107)
- Outputs von Agent 03 (Models, ToastService, ConfirmDialogService)
- Outputs von Agent 04 (AuthService: updateEmail, updatePassword, deleteAccount)

## Bug #107 Fix: Klare Trennung

```
/settings/profile  → Profil-Einstellungen
                     (Name, Foto, E-Mail, Passwort, Account löschen)

/settings/app      → App-Einstellungen
                     (Sollstunden, Sprache, Theme, Standard-Pausenzeit)

/settings/notifications → Benachrichtigungs-Einstellungen (Agent 08)
/settings/premium  → Premium/Paywall (Agent 07)
/settings/profiles → Multi-Profile (Premium, Agent 09)
```

Sidebar-Eintrag "Einstellungen" zeigt Sub-Menü mit allen 5 Punkten.

## Deine Aufgaben

### 9.1 UserProfileService

Datei: `src/app/features/settings/services/user-profile.service.ts`

```typescript
@Injectable({ providedIn: 'root' })
export class UserProfileService {

  // Echtzeit-Profil als Signal (Firestore → Signal)
  readonly profile = toSignal<UserProfile | null>(
    authService.currentUser$.pipe(
      switchMap(user => user
        ? docData(doc(firestore, `users/${user.uid}`), { idField: 'uid' })
        : of(null)
      )
    ),
    { initialValue: null }
  )

  // Profil anlegen (nach erstem Login, idempotent via merge: true)
  async ensureProfile(user: FirebaseUser): Promise<void>

  // Profil-Updates
  async updateProfile(updates: Partial<UserProfile>): Promise<void>
  async updateSettings(settings: Partial<UserSettings>): Promise<void>
  // Nutzt Firestore Dot-Notation für verschachtelte Felder:
  // "settings.language": "en"

  // Premium-Status synchron halten (aufgerufen von PremiumService)
  async updatePremiumStatus(isPremium: boolean, expiresAt: Date | null): Promise<void>
}
```

### 9.2 ProfileComponent

Route: `/settings/profile`

```
┌─────────────────────────────────────────────────────┐
│  👤 Profil                                          │
├─────────────────────────────────────────────────────┤
│  [Avatar-Bild, 80px] [Name]  [E-Mail]               │
│                                                     │
│  Anzeigename:  [Input]  [Speichern]                 │
│                                                     │
│  ─── E-Mail ändern ─────────────────────────────── │
│  Neue E-Mail:  [Input]                              │
│  Passwort:     [Input]  (Re-Auth erforderlich)      │
│  [E-Mail ändern]                                    │
│                                                     │
│  ─── Passwort ändern ───────────────────────────── │
│  Aktuelles Passwort:  [Input]                       │
│  Neues Passwort:      [Input]                       │
│  Bestätigung:         [Input]                       │
│  [Passwort ändern]                                  │
│                                                     │
│  ─── Gefahrenzone ──────────────────────────────── │
│  [🗑️ Konto löschen]  (rot, mit Bestätigungs-Dialog) │
└─────────────────────────────────────────────────────┘
```

Google-User: E-Mail/Passwort-Felder deaktivieren, Hinweis "Verwalte dein Google-Konto".

Konto löschen:
- `ConfirmDialogService` öffnen: "Bist du sicher? Alle Daten werden gelöscht."
- Falls confirmed: `AuthService.deleteAccount(password)` aufrufen
- Redirect zu `/auth/login` (vom AuthService automatisch)

### 9.3 AppSettingsComponent

Route: `/settings/app`

```
┌─────────────────────────────────────────────────────┐
│  ⚙️ App-Einstellungen                               │
├─────────────────────────────────────────────────────┤
│  Arbeitszeitziel                                    │
│  Wöchentliche Sollstunden:  [40] ±                  │
│  Tägliche Sollstunden:      [8]  ±                  │
│  Standard-Pausenzeit (Min): [30] ±                  │
│                                                     │
│  ─── Überstunden-Bilanz (Gleitzeit) ─────────────── │
│  Aktueller Saldo:  [+12:30]                         │
│  [Saldo anpassen]  (Öffnet AdjustmentDialog)        │
│                                                     │
│  Design                                             │
│  Theme:  ○ Hell  ○ Dunkel  ● Systemeinstellung     │
│                                                     │
│  Sprache                                            │
│  [🇩🇪 Deutsch]  [🇬🇧 English]                      │
│                                                     │
│  [Speichern]                                        │
└─────────────────────────────────────────────────────┘
```

**AdjustmentDialog (1:1 Flutter-Funktion):**
- Auswahl: Überstunden (+) / Minusstunden (-)
- Input für Stunden und Minuten
- Button: "Auf 0 zurücksetzen"
- Speichert via `OvertimeService.updateBalance()`

### 9.4 ProfilesComponent (Premium: Multi-Arbeitgeber)
...

Route: `/settings/profiles` [PremiumGuard]

```
┌─────────────────────────────────────────────────────┐
│  💼 Arbeitgeber-Profile                             │
├─────────────────────────────────────────────────────┤
│  [🟢 Hauptarbeitgeber]  40h/Woche  [Standard] [✏️]  │
│  [🔵 Nebenjob]          10h/Woche              [✏️]  │
│                                                     │
│  [+ Neues Profil hinzufügen]                        │
└─────────────────────────────────────────────────────┘
```

WorkProfileService (in diesem Agent anlegen):
```typescript
@Injectable({ providedIn: 'root' })
export class WorkProfileService {
  profiles$: Observable<WorkProfile[]>       // Echtzeit aus Firestore
  activeProfile = computed(...)              // Aus UserProfile.activeProfileId
  createProfile(profile: Partial<WorkProfile>): Promise<string>
  updateProfile(id: string, updates: Partial<WorkProfile>): Promise<void>
  deleteProfile(id: string): Promise<void>
  setDefaultProfile(id: string): Promise<void>
}
```

Profil-Dialog: MatDialog mit Feldern Name, Farbe (ColorPicker), Sollstunden.

## Output
- `src/app/features/settings/services/user-profile.service.ts`
- `src/app/features/settings/services/work-profile.service.ts`
- `src/app/features/settings/components/profile/`
- `src/app/features/settings/components/app-settings/`
- `src/app/features/settings/components/profiles/`
- `src/app/features/settings/components/profile-dialog/`

## Tests
- `user-profile.service.spec.ts`: Mock Firestore, prüfe `updateSettings` mit Dot-Notation
- `profile.component.spec.ts`: Formular-Validierung, Re-Auth bei E-Mail-Änderung
