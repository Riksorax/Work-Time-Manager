# Work-Time-Manager — Flutter (mobile/)

WTM-Besonderheiten zum Stack-Playbook `playbook-flutter`, aus den bisherigen Agent-Dateien übernommen.

## Analyse
- Daten: Eingeloggt, Standard-Profil laufen über `ApiDataSource` → .NET-Backend. Zusätzliche Profile: direkt Firestore.
  Ausgeloggt: SharedPreferences (`Local*RepositoryImpl`). Firestore-Pfade siehe Root-`CLAUDE.md`, „Firestore-Datenpfade“.
- UI-States zusätzlich: **premium-locked**. Premium-Feature → `isPremiumProvider`, Paywall über `showPaywall()`.
- Gilt das pro Arbeitszeit-Profil (#138)? → `profileId` durch Repos/DataSources reichen.
- Neuer Firestore-Pfad → Security Rule in `web/firestore.rules` nötig (vgl. #269).
- Migration bestehender lokaler Daten (`DataSyncService`) betroffen?
- Berührt die Aufgabe Pausen-, Überstunden- oder Berichtslogik: Das Backend (`server/.../Domain/`) ist kanonisch, Flutter
  weicht bekannt ab (`server/CLAUDE.md`, „Rechenlogik“). Neue Logik an das Backend angleichen, nicht umgekehrt.
- Neue Texte → ARB-Keys in `app_de.arb` (mit `@key`-Beschreibung) **und** `app_en.arb`. Fehler über `logger.e` (Crashlytics).
- Web (`web/`) oder Backend (`server/`) mitbetroffen → `cross-platform-coordinator`.

## Plan
- Architektur: `data/` mit Hybrid-/Firebase-/Local-Repositories und Datasources (Firestore, API); `l10n/` mit `app_de.arb` + `app_en.arb`.
- Entscheidungstabelle ergänzen: Repository-Interface ändern → Hybrid-, Firebase-, Local- und `ApiDataSource` mitziehen;
  neuer Provider → `@riverpod` + build_runner, **Dashboard/Reports-ViewModels sind manuell registriert**;
  Premium-Gate (`isPremiumProvider` + `showPaywall()`); pro Arbeitszeit-Profil (`profileId` durchreichen).
- Hybrid-Repository-Pattern nie umgehen. Widget-Tests mit `locale: Locale('de')`.

## Umsetzung
- Formatierung: PostToolUse-Hook `.claude/hooks/dart-format.sh`; die CI erzwingt `dart format --set-exit-if-changed lib test` (#299).
  In Cloud-Sessions installiert `.claude/hooks/session-start.sh` Flutter.
- **Riverpod:** Infrastruktur (Datenquellen, Repositories, Use Cases) per `@riverpod`-Codegen in `core/providers/providers.dart` →
  `build_runner`. ViewModels sind **manuelle** `NotifierProvider`, jeweils in eigener Datei neben ihrem `Notifier`
  (nicht in `providers.dart`, kein Codegen) — Vorlage: `weekly_reflection_view_model.dart`.
- **Hybrid-Repositories** nie umgehen; Interface-Änderungen in allen Varianten: `Hybrid*`, Firebase/`WorkRepositoryImpl`, `Local*`, `ApiDataSource`.
- **Premium:** `ref.watch(isPremiumProvider)`; Paywall über `showPaywall()` (`lib/presentation/widgets/common/paywall_launcher.dart`).
- **Texte:** neue Keys in `app_de.arb` (mit `@key`-Beschreibung) und `app_en.arb`; Datumsformate mit
  `Localizations.localeOf(context).toString()`, nie `'de_DE'` hart kodieren.
- **Fehler** über `logger.e(...)` (geht an Crashlytics), kein `debugPrint` für Fehlerfälle.
- **Zeiten** über `lib/core/utils/time_precision.dart` auf Minuten runden. Widget-Test-Referenz: `test/presentation/screens/settings_page_test.dart`.

## Validierung
- `flutter analyze` darf keine **neuen** Warnungen gegenüber `develop` enthalten (Infos erlaubt).
- Tests: Repository-Änderungen mit Hybrid-Umschaltung eingeloggt/ausgeloggt; Arbeitszeit-Profile: Standard-Profil **und** zusätzliches Profil;
  Widget-Tests für neue UI-Zustände inkl. **Premium-gesperrt**; neue ARB-Keys in `app_de.arb` **und** `app_en.arb`
  (`test/l10n/app_localizations_test.dart` läuft mit).
- UI: Premium-gesperrter Zustand führt zur Paywall (`showPaywall()`), nicht zu einer Snackbar; Deutsch **und** Englisch prüfen (Overflow).

## Review
- [ ] Hybrid-Repository-Pattern eingehalten, alle Repository-Varianten konsistent
- [ ] Premium-Gate korrekt (`isPremiumProvider`); Arbeitszeit-Profile berücksichtigt (`profileId`)
- [ ] Neue Firestore-Pfade haben eine Security Rule in `web/firestore.rules` (Hinweis im PR: Rules werden **nicht** automatisch deployt)
- [ ] Berechnungslogik widerspricht nicht dem Backend
- [ ] ARB de + en vollständig; Fehler über `logger.e` (Crashlytics)
- [ ] Nutzer-sichtbare Änderung: Vermerk für die Release-Notes (`mobile/whatsnew/de-DE.txt` wird erst im Release-Branch geschrieben, siehe `/release`)
