# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Structure

This is a monorepo for a German work-time tracking app:

- `mobile/` — Flutter app (primary, production-ready). Has its own detailed `mobile/CLAUDE.md`.
- `web/` — Angular web app (in progress, being scaffolded on `feature/angular-web-scaffold`).

For all Flutter/mobile work, refer to `mobile/CLAUDE.md` for commands, architecture details, and workflow rules.

## Mobile (Flutter) — Quick Reference

All commands run from inside `mobile/`:

```bash
flutter run                          # Run app
flutter test                         # Run all tests
flutter test test/path/to/file.dart  # Run single test
flutter analyze && dart run custom_lint
dart run build_runner build          # Regenerate .g.dart and .mocks.dart after annotation changes
flutter build appbundle --release \
  --dart-define=RC_ANDROID_KEY=<key> \
  --dart-define=RC_IOS_KEY=<key>
```

## Web (Angular) — Quick Reference

Commands run from inside `web/` once scaffolded:

```bash
npm ci --legacy-peer-deps   # Install
npm run build -- --configuration production
```

## CI/CD

| Workflow | Trigger | Target |
|---|---|---|
| `flutter.yml` | Push to `main` | Android AAB → Google Play |
| `deploy-angular.yml` | Push to `main`/`develop` | Angular → Firebase Hosting |

Firebase project: `work-time-manager-riksorax`. Required secrets: `FIREBASE_SERVICE_ACCOUNT_WORK_TIME_MANAGER_RIKSORAX`, `RC_ANDROID_KEY`, `RC_IOS_KEY`, `RECAPTCHA_SITE_KEY`, Android keystore secrets.

## Architecture Overview

The mobile app uses **Clean Architecture** with three layers (`domain/`, `data/`, `presentation/`) and Riverpod for DI and state. Firebase Firestore is the backend for authenticated users; SharedPreferences serves as local fallback. A **Hybrid Repository** pattern switches transparently between the two based on auth state. See `mobile/CLAUDE.md` for full details.

The Angular web app will share the same Firebase backend and mirror the mobile feature set (dashboard, reports, settings).

## Web-Port: Flutter → Angular (5-Phasen-Workflow)

Für die Portierung der Flutter-App nach Angular Web existieren dedizierte Agenten und Slash Commands.

### Agenten

| Agent | Datei | Wann verwenden |
|---|---|---|
| Web-Analyst | `.claude/agents/web-analyst.md` | Feature analysieren, Flutter→Angular Mapping |
| Web-UI-Designer | `.claude/agents/web-ui-designer.md` | UI mit Stitch API generieren |
| Web-Planner | `.claude/agents/web-planner.md` | Angular-Architekturplan erstellen |
| Web-Developer | `.claude/agents/web-developer.md` | Angular-Code implementieren (TDD) |
| Web-Reviewer | `.claude/agents/web-reviewer.md` | Code Review + Feature-Parität + PR |

### Slash Commands

| Command | Phase |
|---|---|
| `/web-analyze dashboard` | Phase 1 — Flutter-Feature analysieren |
| `/web-design dashboard` | Phase 2 — UI mit Stitch API generieren |
| `/web-plan dashboard` | Phase 3 — Implementierungsplan erstellen |
| `/web-implement dashboard` | Phase 4 — Angular-Code schreiben |
| `/web-review dashboard` | Phase 5 — Review + PR erstellen |

### Stitch API Key
Stitch API Key in `.claude/settings.local.json` als Env-Variable hinterlegen:
```json
{ "env": { "STITCH_API_KEY": "dein-key-hier" } }
```

### Angular-Architektur (`web/src/app/`)
- `domain/` — TypeScript-Port der Flutter-Entities und Pure-Services (kein Angular)
- `data/services/` — Firebase Web SDK v10 + localStorage Hybrid-Services
- `features/` — Standalone Angular Components (OnPush + Signals)
- `core/` — Auth, Firebase-Init, PremiumService, StorageService
- `shared/` — Pipes, Directives, wiederverwendbare Components

**Key Angular-Regeln:**
- Signals-first: `signal()` + `computed()` + `effect()` statt RxJS-Subjects
- `inject()` statt Constructor-Injection-Parameter
- `@if` / `@for` statt `*ngIf` / `*ngFor` (Angular 17+)
- Premium-Gate: `PremiumService.isPremium()` — kein RevenueCat (Web nutzt Firestore-Flag)
- Firebase: nur modular API v10, kein AngularFire Compat-Layer

## Key Rules

- Do not edit `*.g.dart` or `*.mocks.dart` files — they are generated.
- Run `dart run build_runner build` after any `@Riverpod`/`@riverpod` annotation changes or `@GenerateMocks` additions.
- All user-facing strings are German — no i18n system exists.
- Premium features must be gated behind `isPremiumProvider`.
- Always go through `HybridWorkRepositoryImpl` / `HybridOvertimeRepositoryImpl` — never bypass the hybrid layer.
