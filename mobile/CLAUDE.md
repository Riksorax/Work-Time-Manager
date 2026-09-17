# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Run the app
flutter run

# Run tests
flutter test

# Run a single test file
flutter test test/path/to/test_file.dart

# Analyze / lint
flutter analyze
dart run custom_lint

# Regenerate Riverpod providers after changing annotated files
dart run build_runner build

# Watch mode for code generation
dart run build_runner watch

# Build with required secrets (Android)
flutter build apk \
  --dart-define=RC_ANDROID_KEY=<key> \
  --dart-define=RECAPTCHA_SITE_KEY=<key>
```

## Architecture

The app follows **Clean Architecture** with three layers:

- `lib/domain/` — pure Dart: entities, repository interfaces, use cases, domain services
- `lib/data/` — implementations: models (JSON mapping), repository impls, datasources
- `lib/presentation/` — Flutter UI: screens, view models (Riverpod Notifiers), state classes, widgets
- `lib/core/` — cross-cutting: providers wiring, theme, logger, services (notifications, version)

### Dependency Injection & State Management

**Riverpod** is used throughout. Provider wiring lives in `lib/core/providers/providers.dart` and its generated counterpart `providers.g.dart`. Most providers use `@Riverpod` / `@riverpod` annotations — after changing them, run `build_runner build`. However, `DashboardViewModel` and `ReportsViewModel` are manually registered `Notifier`s in `providers.dart` (not code-generated) because they require complex setup.

`SharedPreferences` is provided via an override in `main.dart` and must not be accessed directly elsewhere.

### Hybrid Repository Pattern

Data storage switches automatically based on auth state:

- **Logged in** → Firebase Firestore (`WorkRepositoryImpl`, `FirebaseOvertimeRepositoryImpl`)
- **Logged out** → SharedPreferences (`LocalWorkRepositoryImpl`, `LocalOvertimeRepositoryImpl`)

`HybridWorkRepositoryImpl` and `HybridOvertimeRepositoryImpl` handle the switching transparently. The active repository is determined by whether `userId` is non-null.

### Key Domain Concepts

- `WorkEntryEntity` — one entry per calendar day; has `workStart`, `workEnd`, `breaks`, and `type` (`WorkEntryType`: `work`, `vacation`, `sick`, `holiday`)
- `BreakEntity` — a break with `start` and optional `end` (null = currently running)
- `BreakCalculatorService` — auto-calculates legally required breaks (30 min after 6h, 45 min after 9h) when a timer is stopped
- Overtime is stored separately in `OvertimeRepository`; the dashboard tracks `initialOvertime` (base from previous days) + `dailyOvertime` (today's delta)
- `DataSyncService` — migrates local SharedPreferences data to Firebase when a user logs in
- `work_entry_extensions.dart` — extension methods on `WorkEntryEntity` (e.g. effective work duration, type checks)
- `domain/utils/overtime_utils.dart` — pure functions for overtime calculations used across view models

### Screens

`HomeScreen` is a bottom-nav shell with three tabs:
1. `DashboardScreen` — live timer, breaks, daily overtime
2. `ReportsPage` — monthly/weekly reports (some features Premium-gated)
3. `SettingsPage` — target hours, workdays, notifications, account

### Premium / Subscriptions

RevenueCat (`purchases_flutter`) handles in-app purchases. `isPremiumProvider` (in `lib/core/providers/subscription_provider.dart`) exposes a simple `bool`. RevenueCat is **not initialized on web**. Build-time keys are injected via `--dart-define=RC_ANDROID_KEY` and `--dart-define=RC_IOS_KEY`.

### Localization

The app supports German (default) and English via Flutter's ARB/l10n system (`lib/l10n/app_de.arb` / `app_en.arb`, generated `AppLocalizations` class — see #221/#262). `app_de.arb` is the template file and carries `@key` descriptions; `app_en.arb` holds only the translated values. After editing an ARB file, run `flutter gen-l10n` (or `flutter pub get`, since `generate: true` is set in `pubspec.yaml`) to regenerate `lib/l10n/app_localizations*.dart` — these generated files must not be edited manually.

All user-facing strings in `lib/presentation/` go through `AppLocalizations.of(context)` (commonly aliased to a local `l10n` variable at the top of `build()`), never hardcoded literals. Locale-dependent formatting (`DateFormat`, weekday/month names) must use `Localizations.localeOf(context).toString()` instead of a hardcoded `'de_DE'` — see `domain/utils/weekday_labels.dart` for the pattern (`weekdayShortLabel`/`formatWorkdays` take an explicit `locale` parameter). Legal documents (Impressum/Datenschutz/AGB) are loaded from Markdown assets in `assets/legal/` and are **not** translated — only their dialog titles are localized; the documents themselves remain German-only.

Widget tests that pump a screen using `AppLocalizations.of(context)` must configure `MaterialApp` with `localizationsDelegates: AppLocalizations.localizationsDelegates` and `supportedLocales: AppLocalizations.supportedLocales` (plus `locale: const Locale('de')` to keep existing assertions on German text working) — see `test/presentation/screens/settings_page_test.dart` for the reference pattern.

### Testing

Tests mirror the `lib/` directory structure under `test/`. Use `mockito` with `@GenerateMocks([...])` annotations and `ProviderContainer(overrides: [...])` to inject mock dependencies into Riverpod providers. After adding new `@GenerateMocks` annotations, run `build_runner build` to regenerate `*.mocks.dart` files.

### Code Generation

Files ending in `.g.dart` are generated — do not edit them manually. Regenerate with `dart run build_runner build`. Mock files (`*.mocks.dart`) are generated by `mockito` and also must not be edited manually.

---

## Workflow-Regeln (IMMER einhalten)

1. **Niemals direkt coden ohne Phase 1 + 2 abgeschlossen** — auch bei kleinen Tasks
2. **Context bei ~60% → `/clear` → Fortschritt aus `thoughts/`-Datei laden**
3. **Tests vor Implementation schreiben (TDD)**
4. **Nach `@riverpod`-Änderungen immer `dart run build_runner build` ausführen**
5. **Keine direkten Änderungen an `*.g.dart` oder `*.mocks.dart`**
6. **`SharedPreferences` nur über den `main.dart`-Override — nie direkt**
7. **Premium-Features immer hinter `isPremiumProvider` absichern**
8. **Hybrid-Repository-Pattern nicht umgehen — immer über HybridImpl gehen**
9. **Alle User-Strings über `AppLocalizations.of(context)`** — ARB-Keys in `lib/l10n/app_de.arb` (+ Übersetzung in `app_en.arb`) ergänzen, nie deutschen Text hart codieren. Nach ARB-Änderungen `flutter gen-l10n` ausführen

## Agenten-Übersicht

| Agent | Datei | Wann verwenden |
|---|---|---|
| Analyst | `.claude/agents/analyst.md` | Aufgabe verstehen, hinterfragen |
| Planner | `.claude/agents/planner.md` | Implementierungsplan erstellen |
| Developer | `.claude/agents/developer.md` | Code schreiben, TDD |
| Tester | `.claude/agents/tester.md` | Tests + Coverage |
| UI-Reviewer | `.claude/agents/ui-reviewer.md` | UI validieren via mcp_flutter |
| Reviewer | `.claude/agents/reviewer.md` | Code Review + PR |

## Slash Commands

| Command | Phase |
|---|---|
| `/analyze TICKET-123` | Phase 1 — Aufgabe analysieren |
| `/plan TICKET-123` | Phase 2 — Plan erstellen |
| `/implement TICKET-123` | Phase 3 — Code schreiben |
| `/validate TICKET-123` | Phase 4 — Testen + UI |
| `/review TICKET-123` | Phase 5 — Review + PR |
