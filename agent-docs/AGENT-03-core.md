# Agent 03 — Core / Foundation

> **WICHTIGE VORGABE:** Die Angular Web-App muss 1:1 exakt dieselben Funktionen bieten wie die Flutter App. Das UI soll an das Web (Desktop/Browser) angepasst werden, aber alle Funktionen und Features müssen lückenlos vorhanden sein.


## Rolle
Du baust das laufende Fundament der App: Firebase-Initialisierung, alle Datenmodelle, i18n-Setup, Shell-Layout und geteilte Komponenten. Erst wenn dieser Agent fertig ist, können Feature-Agents (04–09) starten.

## Input
- `AGENT-00-flutter-analysis-report.md`
- `AGENT-01-architecture.md`
- Alle Outputs von Agent 02 (Security)

## Deine Aufgaben

### 3.1 app.config.ts — Zentraler Provider-Hub

`src/app/app.config.ts` muss folgende Provider registrieren:

```typescript
provideFirebaseApp(...)       // Firebase initialisieren
provideAuth(...)              // Firebase Auth
provideFirestore(...)         // Cloud Firestore
provideMessaging(...)         // Firebase Cloud Messaging
provideAppCheck(...)          // App Check (aus Agent 02)
provideRouter(routes, withComponentInputBinding())
provideAnimationsAsync()
provideHttpClient(withInterceptors([authInterceptor]))
importProvidersFrom(TranslateModule.forRoot(...))  // ngx-translate
```

**Keine** Magic-Strings — alles referenziert `environment.*`.

### 3.2 Alle TypeScript-Modelle

Datei: `src/app/shared/models/index.ts`

Erstelle TypeScript Interfaces für **alle** Modelle aus `AGENT-00-flutter-analysis-report.md`. Exakt:

```typescript
export type WorkEntryType = 'work' | 'vacation' | 'sick' | 'holiday';

export interface Break {
  id: string;
  name: string;
  start: Date;
  end?: Date;
  isAutomatic: boolean;
}

export interface WorkEntry {
  id: string; // Wird als YYYY-MM-DD formatiert
  date: Date;
  workStart?: Date;
  workEnd?: Date;
  type: WorkEntryType;
  description?: string;
  isManuallyEntered: boolean;
  manualOvertimeMinutes?: number;
  breaks: Break[];
}

export interface WorkMonth {
  id: string; // YYYY-MM
  days: { [day: string]: WorkEntry };
}

export interface OvertimeBalance {
  minutes: number;
  lastUpdated: Date;
}

export interface UserProfile {
  uid: string;
  email: string;
  displayName?: string;
  photoURL?: string;
  isPremium: boolean;
  settings: UserSettings;
}

export interface UserSettings {
  language: 'de' | 'en';
  theme: 'light' | 'dark' | 'system';
  weeklyTargetHours: number;
  dailyTargetHours: number;
}
```

- `DEFAULT_USER_PROFILE` Konstante
- `WorkProfile` (Premium: Mehrere Arbeitgeber)
- `DailyReport`, `WeeklyReport`, `MonthlyReport`, `YearlyReport`
- `CategoryBreakdown`
- `PremiumStatus`
- `NotificationReminder`

**Kein** Firestore-spezifischer Code in den Models — nur plain TypeScript Interfaces.

### 3.3 Shared Pipes

Datei: `src/app/shared/pipes/duration.pipe.ts`

```typescript
// Transformiert Minuten → "8h 30min"
// Nutzt formatDuration() aus time-calculations.util.ts
@Pipe({ name: 'duration', standalone: true })
export class DurationPipe implements PipeTransform {
  transform(minutes: number | null | undefined): string { ... }
}
```

Datei: `src/app/shared/pipes/overtime.pipe.ts`
```typescript
// Transformiert Minuten → "+1h 30min" oder "-0h 30min"
// Positiv = grün, Negativ = rot (via CSS-Klasse im Template)
```

### 3.4 Shared Components

**LoadingSpinnerComponent** (`shared/components/loading-spinner/`)
- Zentrierter Material Spinner
- Input: `message?: string`
- Genutzt von allen Features während async Operationen

**ConfirmDialogComponent** (`shared/components/confirm-dialog/`)
- Angular Material Dialog
- Inputs: `title`, `message`, `confirmLabel`, `cancelLabel`
- Gibt `true`/`false` zurück
- Genutzt für Löschen-Bestätigungen (Bug #108 Fix)

**PremiumGateComponent** (`shared/components/premium-gate/`)
- Wird angezeigt wenn Feature Premium erfordert
- Input: `message: string`
- Zeigt Lock-Icon + Message + "Premium freischalten" Button
- Button navigiert zu `/settings/premium`

**ToastService** (`shared/components/toast/toast.service.ts`)
- Wraps Angular Material `MatSnackBar`
- Methoden: `success(msg)`, `error(msg)`, `info(msg)`
- Einheitliche Darstellung in der gesamten App

### 3.5 Shell Layout

`src/app/layout/shell/shell.component.ts`

- `<mat-sidenav-container>` als Root-Layout
- Sidebar (permanent auf Desktop ≥ 960px, Drawer auf Mobile)
- Sidebar-Links: Dashboard, Zeiterfassung, Berichte, Einstellungen
- Sidebar-Footer: User-Avatar, Name, Premium-Badge (falls aktiv)
- Header-Toolbar: App-Titel + Live-Timer-Widget (falls Session läuft) + Hamburger-Menu (Mobile)
- `<router-outlet>` als Haupt-Content-Bereich

`src/app/layout/sidebar/sidebar.component.ts`
- Navigation-Links mit `routerLinkActive`
- Premium-Badge: MatChip mit "PRO" wenn `premiumService.isPremium()`
- Logout-Button am unteren Rand

### 3.6 i18n Setup

Dateien: `src/assets/i18n/de.json` + `src/assets/i18n/en.json`

Alle Strings aus `AGENT-00-flutter-analysis-report.md` (Lokalisierungsstrings) in beide Dateien eintragen.

Struktur:
```json
{
  "common": { ... },
  "nav": { ... },
  "auth": { ... },
  "timer": { ... },
  "sessions": { ... },
  "dashboard": { ... },
  "reports": { ... },
  "premium": { ... },
  "settings": { "profile": { ... }, "app": { ... }, "notifications": { ... } }
}
```

Sprache wird beim App-Start aus `UserProfile.settings.language` geladen. Fallback: Browser-Sprache, dann `de`.

### 3.7 Angular Material Theme

Datei: `src/styles/theme.scss`

- Custom Theme mit `mat.define-theme()`
- Primary: Blau-Ton (passend zum Work-Timer-Kontext)
- Dark Mode: automatisch via `@media (prefers-color-scheme: dark)`
- Theme-Override wenn User explizit Light/Dark gewählt hat (via CSS-Klasse auf `<body>`)

### 3.8 main.ts

`src/main.ts` — bootstrapApplication mit `appConfig`.

Nach dem Bootstrap:
1. `TranslateService` Standardsprache setzen (`de`)
2. `NotificationService.listenForMessages()` starten

## Output
- `src/app/app.config.ts`
- `src/app/app.routes.ts`
- `src/app/shared/models/index.ts`
- `src/app/shared/pipes/duration.pipe.ts`
- `src/app/shared/pipes/overtime.pipe.ts`
- `src/app/shared/components/loading-spinner/`
- `src/app/shared/components/confirm-dialog/`
- `src/app/shared/components/premium-gate/`
- `src/app/shared/components/toast/toast.service.ts`
- `src/app/layout/shell/shell.component.ts` + `.html` + `.scss`
- `src/app/layout/sidebar/sidebar.component.ts` + `.html` + `.scss`
- `src/assets/i18n/de.json`
- `src/assets/i18n/en.json`
- `src/styles/theme.scss`
- `src/main.ts`

## Übergabe
Feature-Agents importieren Models aus `shared/models`, nutzen `ToastService` für Feedback, `ConfirmDialogService` für Bestätigungen und `PremiumGateComponent` für Premium-Gates.
