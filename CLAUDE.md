# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Structure

This is a monorepo for a German work-time tracking app:

- `mobile/` — Flutter app (primary, production-ready). Has its own detailed `mobile/CLAUDE.md`.
- `web/` — Angular web app (feature-complete on `feature/angular-web-scaffold`).

For all Flutter/mobile work, refer to `mobile/CLAUDE.md` for commands, architecture details, and workflow rules.

## Mobile (Flutter) — Quick Reference

All commands run from inside `mobile/`:

```bash
flutter run
flutter test
flutter test test/path/to/file.dart
flutter analyze && dart run custom_lint
dart run build_runner build          # Regenerate .g.dart and .mocks.dart
flutter build appbundle --release \
  --dart-define=RC_ANDROID_KEY=<key> \
  --dart-define=RC_IOS_KEY=<key>
```

## Web (Angular) — Quick Reference

Commands run from inside `web/`:

```bash
npm ci --legacy-peer-deps            # Install
npm start                            # Dev-Server http://localhost:4200
npm run build -- --configuration production
```

## CI/CD

| Workflow | Trigger | Target |
|---|---|---|
| `flutter.yml` | Push to `main` | Android AAB → Google Play |
| `deploy-angular.yml` | Push to `main`/`develop` | Angular → Firebase Hosting |

Firebase project: `work-time-manager-riksorax`. Required secrets: `FIREBASE_SERVICE_ACCOUNT_WORK_TIME_MANAGER_RIKSORAX`, `RC_ANDROID_KEY`, `RC_IOS_KEY`, `RECAPTCHA_SITE_KEY`, Android keystore secrets.

## Mobile Architecture

Clean Architecture with three layers (`domain/`, `data/`, `presentation/`) and Riverpod for DI and state. Firebase Firestore for authenticated users; SharedPreferences as local fallback. **Hybrid Repository** pattern switches transparently based on auth state. See `mobile/CLAUDE.md` for full details.

## Web Architecture (`web/src/app/`)

The Angular app is a full port of the Flutter app sharing the same Firebase backend.

### Layer Structure

```
core/
├── auth/           AuthService (Firebase Auth, Google Sign-In), AuthGuard
│                   — deleteAccount() via Firebase deleteUser()
├── services/
│   ├── work-entry.ts      Hybrid Firebase/localStorage — getAllLocalEntries() für DataSync
│   ├── overtime.ts        Hybrid — getOvertime() / saveOvertime() / getLastUpdateDate()
│   ├── settings.ts        Hybrid — getSettings() Observable / saveSettings()
│   ├── profile.ts         ProfileService — isPremium Signal (Firestore-Flag, kein RevenueCat)
│   ├── theme.ts           ThemeService — isDarkMode Signal + localStorage-Persistenz
│   └── data-sync.ts       DataSyncService — localStorage→Firebase-Migration bei Login

domain/
├── models/
│   └── reports.models.ts  DailyStat, WeeklyReport, MonthlyReport
├── services/
│   ├── break-calculator.service.ts   Pure — Pflichtpausen (30min/6h, 45min/9h)
│   └── report-calculator.service.ts  Pure — ISO-8601-Wochennummer, DailyStat, Weekly/MonthlyReport
└── utils/
    └── overtime.utils.ts  Pure — getEffectiveDailyTarget, getWeekEntriesForDate, isSameDay

features/
├── dashboard/      DashboardComponent + DashboardService (Timer, Pausen, Überstunden)
├── reports/        ReportsComponent + ReportsService (Täglich/Wöchentlich/Monatlich, Premium-Gate)
└── settings/       SettingsComponent + SettingsPageService (Profil, Arbeitszeit, Gleitzeit, Sync, Theme)

shared/
├── components/
│   ├── calendar/          CalendarComponent — Multi-Select + Pointer-Drag
│   ├── edit-entry-dialog/ EditEntryDialogComponent
│   └── time-input/        TimeInputComponent
└── models/index.ts        WorkEntry, WorkEntryType, Break, UserSettings, UserProfile
```

### Feature-Services (Pattern)

Jedes Feature hat einen eigenen `*.service.ts` der Core-Services aggregiert:

| Feature-Service | Aggregiert |
|---|---|
| `DashboardService` | WorkEntryService, OvertimeService, SettingsService |
| `ReportsService` | WorkEntryService, SettingsService, ProfileService, AuthService, OvertimeService, ReportCalculatorService |
| `SettingsPageService` | SettingsService, AuthService, ProfileService, OvertimeService, ThemeService, DataSyncService |

### Key Angular-Regeln

- **Kein `standalone: true`** — Default in Angular v20+, nie explizit setzen
- **Signals-first**: `signal()` + `computed()` + `effect()`, öffentliche Signals via `.asReadonly()`
- **`inject()` statt Constructor-Parameter**
- **`@if` / `@for`** statt `*ngIf` / `*ngFor`
- **`ChangeDetectionStrategy.OnPush`** bei allen Components
- **Kein `color="primary/warn/accent"`** auf Material-Buttons (M3-deprecated)
- **Premium-Gate**: `ProfileService.isPremium` — kein RevenueCat (Web nutzt Firestore-Flag)
- **Firebase**: nur modular API v10, kein AngularFire Compat-Layer
- **Kein `CommonModule`** — nur spezifische Imports (`DatePipe`, `AsyncPipe` etc.)

### Dark Mode

`ThemeService` verwaltet Hell/Dunkel. `app.ts` appliziert beim Start via `applyStoredTheme()` + `effect()` die Klasse `.dark-theme` auf `<html>`. SCSS-Override in `styles.scss` überschreibt dann das Angular Material M3-Theme.

### Daten-Synchronisation

`DataSyncService.syncAll()` liest alle localStorage-Einträge (via `WorkEntryService.getAllLocalEntries()` + `LS_KEYS`-Index) und schreibt sie nach Firebase. Wird manuell aus den Einstellungen getriggert.

## Web-Port Workflow (5 Phasen)

Für neue Feature-Portierungen:

| Command | Phase |
|---|---|
| `/web-analyze <feature>` | Phase 1 — Flutter-Feature analysieren |
| `/web-design <feature>` | Phase 2 — UI entwerfen (Stitch API oder manuell) |
| `/web-plan <feature>` | Phase 3 — Implementierungsplan |
| `/web-implement <feature>` | Phase 4 — Code schreiben (TDD) |
| `/web-review <feature>` | Phase 5 — Review + PR |

Stitch API Key in `.claude/settings.local.json`: `{ "env": { "STITCH_API_KEY": "..." } }`
**Hinweis:** Stitch API ist aktuell nicht verfügbar (HTTP 405) — UI wird manuell nach Flutter-Vorlage designed.

## Key Rules (Gesamt)

- `*.g.dart` / `*.mocks.dart` nicht editieren — generiert.
- `dart run build_runner build` nach `@Riverpod`-Änderungen.
- Alle User-Strings auf Deutsch — kein i18n-System.
- Premium-Features hinter `isPremiumProvider` (Flutter) bzw. `ProfileService.isPremium` (Web).
- Hybrid-Layer nie umgehen — immer über `WorkEntryService` / `OvertimeService`.
