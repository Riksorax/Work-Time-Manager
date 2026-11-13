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
  **Ausnahme (#506, #522):** Erwartbare Ladefehler sind kein App-Fehler: vorübergehende Netzwerkfehler (Verbindungsabbruch, Offline,
  Timeout) und API-Aufrufe ohne angemeldeten Nutzer (kurz nach Abmelden/Konto-Löschung, `ApiClient` wirft dann `NotSignedInException`
  und sendet nichts). In jedem Ladepfad, der über `ApiDataSource`/HTTP läuft, zuerst `isExpectedLoadFailure(e)`
  (`lib/core/utils/api_errors.dart`) prüfen und dann nur `logger.i` schreiben; der Fehlerzustand in der UI bleibt. Gilt für **alle**
  Ladepfade eines neuen Features, nicht nur den ersten (#506 brauchte deshalb zwei Fix-PRs). Echte API-Fehler kommen als
  `ApiException` mit Status; in Log-Zeilen `errorLabel(e)` statt `e.runtimeType` verwenden, dann steht der Status in der Meldung.
- **Zeiten** über `lib/core/utils/time_precision.dart` auf Minuten runden. Widget-Test-Referenz: `test/presentation/screens/settings_page_test.dart`.

## Validierung
- Checks vollständig wie in der CI (Root-`CLAUDE.md`, „Checks je Plattform“): zusätzlich zu den vier Checks des Stack-Playbooks
  `dart format --output=none --set-exit-if-changed lib test`, `TZ=Europe/Berlin flutter test` und bei Datums-/Zeitlogik die
  `*_tz_test.dart` unter `TZ=America/Los_Angeles` und `TZ=Pacific/Auckland`.
- `flutter analyze` darf keine **neuen** Warnungen gegenüber `develop` enthalten (Infos erlaubt).
- Tests: Repository-Änderungen mit Hybrid-Umschaltung eingeloggt/ausgeloggt; Arbeitszeit-Profile: Standard-Profil **und** zusätzliches Profil;
  Widget-Tests für neue UI-Zustände inkl. **Premium-gesperrt**; neue ARB-Keys in `app_de.arb` **und** `app_en.arb`
  (`test/l10n/app_localizations_test.dart` läuft mit). Ladepfade über HTTP: ein Test, dass ein erwartbarer Ladefehler nicht als
  `logger.e` gemeldet wird (Hilfe: `test/support/reported_logs.dart`).
- Natives Android (`mobile/android/**`, Timer-Aktionen von außen, Notification-Aktionen, Assistant-Intents): Unit-Tests erreichen das
  nicht. Der Workflow `.github/workflows/android-emulator.yml` (`tool/android_e2e/run.sh`) läuft auf dem PR automatisch mit; sein
  Ergebnis gehört in den Abschnitt „Validierung“. In Cloud-Sessions gibt es weiterhin kein Gerät.
- UI: Premium-gesperrter Zustand führt zur Paywall (`showPaywall()`), nicht zu einer Snackbar; Deutsch **und** Englisch prüfen (Overflow).
  Edge-to-Edge (#468, SDK 35): nichts liegt unter Status- oder Navigationsleiste. Seitliche Insets kommen zentral aus
  `HorizontalSafeInsets` (kein eigenes `SafeArea` je Screen), Bottom Sheets nutzen unten `bottomSheetBottomInset(context)` statt
  `MediaQuery.viewInsets`; Regeln in `mobile/CLAUDE.md`, „Edge-to-Edge“.

## Review
- [ ] Hybrid-Repository-Pattern eingehalten, alle Repository-Varianten konsistent
- [ ] Premium-Gate korrekt (`isPremiumProvider`); Arbeitszeit-Profile berücksichtigt (`profileId`)
- [ ] Neue Firestore-Pfade haben eine Security Rule in `web/firestore.rules` (Hinweis im PR: Rules werden **nicht** automatisch deployt)
- [ ] Berechnungslogik widerspricht nicht dem Backend
- [ ] ARB de + en vollständig; Fehler über `logger.e` (Crashlytics), erwartbare Ladefehler nur `logger.i` (`isExpectedLoadFailure`)
- [ ] Neue Screens/Bottom Sheets: Insets nach `mobile/CLAUDE.md`, „Edge-to-Edge“ (`bottomSheetBottomInset`, kein doppeltes `SafeArea`)
- [ ] Nutzer-sichtbare Änderung: Vermerk für die Release-Notes (`mobile/whatsnew/de-DE.txt` wird erst im Release-Branch geschrieben, siehe `/release`)
