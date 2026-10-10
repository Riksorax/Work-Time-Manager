# Mobile-Developer (Flutter) — Referenz Phase „Umsetzung“

## Rolle
Du implementierst den freigegebenen Plan in `mobile/` — Schritt für Schritt, Test-First.

> Lies zuerst `mobile/CLAUDE.md`.

## Voraussetzung
- `mobile/thoughts/<issue>-plan.md` freigegeben ✅

## Commands (aus `mobile/`)

```bash
flutter pub get
flutter test                                   # alle Tests
flutter test test/path/to/file_test.dart       # einzelne Datei
flutter analyze --no-fatal-infos               # wie CI
dart run custom_lint                           # riverpod_lint
dart run build_runner build --delete-conflicting-outputs   # .g.dart / .mocks.dart
flutter gen-l10n                               # nach ARB-Änderungen
```

Formatierung läuft automatisch über den PostToolUse-Hook (`.claude/hooks/dart-format.sh`) und wird
in der CI mit `dart format --set-exit-if-changed lib test` erzwungen — kein manuelles
`dart format` nötig.

In Cloud-Sessions installiert ein SessionStart-Hook (`.claude/hooks/session-start.sh`, falls
das Projekt einen hat) die Toolchain.

## Regeln (NIEMALS brechen)

- **Generierte Dateien** (`*.g.dart`, `*.mocks.dart`, `lib/l10n/app_localizations*.dart`)
  nie von Hand ändern — neu generieren.
- **Riverpod:** Infrastruktur (Datenquellen, Repositories, Use Cases) nutzt `@riverpod`-Codegen
  in `core/providers/providers.dart` → danach `build_runner`. ViewModels sind dagegen
  manuelle `NotifierProvider`, jeweils in eigener Datei neben ihrem `Notifier` registriert
  (kein Codegen) — Vorlage laut `mobile/CLAUDE.md`.
- **Repository-Muster des Projekts** nie umgehen. Interface-Änderungen in allen Varianten
  nachziehen (Remote-, Lokal-, Hybrid-Implementierung, Datenquellen).
- **SharedPreferences** nur über den Override aus `main.dart`.
- **Feature-Gates** (z. B. Premium) nur über den vorgesehenen Provider/Launcher aus `mobile/CLAUDE.md`.
- **Texte:** `final l10n = AppLocalizations.of(context);` — nie hart kodiert.
  Neue Keys in der Template-ARB (mit `@key`-Beschreibung) und in allen weiteren Sprachdateien.
  Datumsformate mit `Localizations.localeOf(context).toString()`, nie ein Locale hart kodieren.
- **Fehler** über den zentralen Logger (`logger.e(...)`, geht an Crashlytics), kein `debugPrint`
  für Fehlerfälle.
- **Zeiten** über die zentralen Hilfen (`lib/core/utils/`) runden/formatieren, wie im restlichen Code.

## Test-Muster

```dart
@GenerateMocks([SettingsRepository, OvertimeRepository])
void main() {
  late ProviderContainer container;
  setUp(() {
    container = ProviderContainer(overrides: [
      settingsRepositoryProvider.overrideWithValue(mockSettings),
    ]);
  });
  tearDown(() => container.dispose());
}
```

Widget-Tests: `MaterialApp(localizationsDelegates: AppLocalizations.localizationsDelegates,
supportedLocales: AppLocalizations.supportedLocales, locale: const Locale('de'), ...)` —
Referenz-Test im Projekt unter `test/presentation/screens/`.

Keine Tests, die vom aktuellen Datum abhängen (Wochenende, Monatswechsel, Zeitzone).

## Workflow je Plan-Schritt
1. Test schreiben → rot
2. Implementieren → grün
3. `flutter analyze --no-fatal-infos` → keine neuen Warnungen
4. Fortschritt im Plan abhaken (`mobile/thoughts/<issue>-plan.md`)
