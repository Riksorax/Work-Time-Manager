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

# Format-Check (wie CI) - Formatierung selbst läuft automatisch über den
# PostToolUse-Hook (.claude/hooks/dart-format.sh)
dart format --output=none --set-exit-if-changed lib test

# Analyze / lint (wie CI; custom_lint zusätzlich lokal)
flutter analyze --no-fatal-infos
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

**Riverpod** is used throughout, with two registration styles depending on the layer:

- **Infrastructure** (data sources, repositories, use cases) uses `@Riverpod` / `@riverpod` code generation, wired in `lib/core/providers/providers.dart` and its generated counterpart `providers.g.dart` — after changing them, run `build_runner build`.
- **ViewModels** are manually registered `NotifierProvider`s, each declared next to its `Notifier` subclass in its own file under `lib/presentation/view_models/` (e.g. `dashboard_view_model.dart`), not in `providers.dart` and not code-generated. `EditWorkEntryViewModel` follows this rule too, via `NotifierProvider.family.autoDispose` (see #296).

New ViewModels always follow the manual `NotifierProvider` pattern; new infrastructure providers use `@riverpod` codegen.

`lib/core/providers/today_provider.dart` (`todayProvider`, manueller `NotifierProvider<TodayNotifier, DateTime>`) ist die zentrale "heute"-Quelle (lokaler Tag, Pendant zum Web-`TodayService`): wechselt zur lokalen Mitternacht, bei `AppLifecycleState.resumed` und bei `refresh()`. Alles, was "heute" braucht (Dashboard-VM, `holidayTodayProvider`), watcht/listent diesen Provider statt eigener Timer.

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

All user-facing strings in `lib/presentation/` go through `AppLocalizations.of(context)` (commonly aliased to a local `l10n` variable at the top of `build()`), never hardcoded literals. Locale-dependent formatting (`DateFormat`, weekday/month names) must use `Localizations.localeOf(context).toString()` instead of a hardcoded `'de_DE'` — see `domain/utils/weekday_labels.dart` for the pattern (`weekdayShortLabel`/`formatWorkdays` take an explicit `locale` parameter). Deutsche Texte duzen die Nutzer ("Möchtest du …", "Deine Daten …"). Services ohne `BuildContext` (z. B. `NotificationService`, `AppLockService`) enthalten keine Texte, sondern bekommen `AppLocalizations` bzw. den fertigen Text als Parameter; ViewModels ohne Context holen sie per `lookupAppLocalizations(Locale(settingsRepository.getLocale()))`. Bereits geplante Benachrichtigungen tragen ihren Text fest in sich und werden bei Sprachwechsel neu geplant (`updateLocale`). Legal documents (Impressum/Datenschutz/AGB) are loaded from Markdown assets in `assets/legal/` and are **not** translated — only their dialog titles are localized; the documents themselves remain German-only.

Widget tests that pump a screen using `AppLocalizations.of(context)` must configure `MaterialApp` with `localizationsDelegates: AppLocalizations.localizationsDelegates` and `supportedLocales: AppLocalizations.supportedLocales` (plus `locale: const Locale('de')` to keep existing assertions on German text working) — see `test/presentation/screens/settings_page_test.dart` for the reference pattern.

### Testing

Tests mirror the `lib/` directory structure under `test/`. Use `mockito` with `@GenerateMocks([...])` annotations and `ProviderContainer(overrides: [...])` to inject mock dependencies into Riverpod providers. After adding new `@GenerateMocks` annotations, run `build_runner build` to regenerate `*.mocks.dart` files.

### Tageswechsel (#379)

Das Dashboard kennt den Tageswechsel (stiller Wechsel, analog Web #372):

- `todayProvider` liefert den lokalen Tag; `DashboardViewModel` hört per `ref.listen` darauf (`_onDayChange`). Ein gestoppter/leerer Eintrag schaltet still auf den neuen Tag (`_init(dayChange: true)`), ein **laufender Timer läuft über Mitternacht weiter** — Eintrag, Soll, `isExtraDay` und Überstunden bleiben am Eintragsdatum (`_getEffectiveTargetDailyHours(forDate)`).
- `_ensureCurrentDay()` läuft am Anfang jeder Schreibaktion: lädt bei Bedarf den aktuellen Tag nach und bricht die Aktion ab, wenn das fehlschlägt (nie in den Vortag oder einen Platzhalter schreiben). Nach dem Stop eines Vortags-Laufs folgt ein Reinit.
- `_initGen`/`_initRun`/`_loadedOk`: überholte oder nach Dispose beendete Ladeläufe verwerfen ihr Ergebnis; `_init` baut den `DashboardState` per Konstruktor neu (`copyWith` ignoriert `null`).
- Beim Tageswechsel ist `storedOvertime` die Basis (Ausnahme: neuer Eintrag schon abgeschlossen und danach gespeichert).
- Use Cases (`GetTodayWorkEntry`, `ToggleBreak`, `StartOrStopTimer`) bekommen die Uhr per Konstruktor (`clock:`) aus `clockProvider`.
- Tests: `test/support/fake_clock.dart` (an `fakeAsync.elapsed` koppelbar, `jumpTo` für Uhrsprünge) und `test/support/fake_repositories.dart` (In-Memory-Repos). VM-/Provider-Tests laufen in `fakeAsync` (Container innerhalb anlegen, am Ende `dispose` und Timer-Zähler prüfen); `TestWidgetsFlutterBinding.ensureInitialized()` ist nötig, weil `todayProvider` einen `WidgetsBindingObserver` registriert. DST-Tests als Invarianten formulieren (lokale Folgetag-Schlüssel), CI läuft in Europe/Berlin; lokal zusätzlich `TZ=UTC`/`America/Los_Angeles`/`Pacific/Auckland flutter test`.

Reports, Urlaub, Insights und Jahres-Tab folgen dem Tageswechsel ebenfalls über `todayProvider` (#387), nicht über `DateTime.now()`:

- In Notifier-`build()` immer `ref.listen(todayProvider, ...)`, **nie** `ref.watch(todayProvider)`: `watch` baut den Notifier jeden Tag neu (Zustands- und Auswahlverlust, bei Urlaub 12 Abfragen pro Tag).
- `ReportsViewModel`: Die Auswahl (`selectedDay`/`focusedDay`, ggf. `selectedMonth` samt Monats-Reload) folgt dem Tageswechsel nur, wenn sie auf dem bisherigen "heute" stand; manuell gewählte Tage/Monate und Multi-Select bleiben unangetastet.
- `LeaveBalanceViewModel`: lädt nur beim **Jahreswechsel** neu und verwirft dabei die Vorjahres-Bilanz (Ladezustand statt falschem Resturlaub). `leaveBalanceNowProvider` entfällt; Tests überschreiben `clockProvider`. `YearlyLeaveRows` watcht `todayProvider.select((d) => d.year)`.
- Insights und Jahres-Tab lesen "heute"/Jahr nur beim Laden per `ref.read(todayProvider)`, ohne Listener und ohne Auto-Reload (keine Reads für Nutzer ohne Zugriff, gewähltes Jahr bleibt).

### Profilwechsel (#388)

Ein Wechsel des Arbeitszeit-Profils (`activeWorkProfileIdProvider`) invalidiert Repos, UseCases und `DashboardViewModel`; die Repos sind konstruktor-gebunden an ihr Profil. Analog Web #380 (Stufe 1):

- **Einfrieren (bewusste Entscheidung):** `onDispose` bricht Timer und Autosave beim Wechsel ab, **ohne zu speichern**. Der Eintrag bleibt im alten Profil mit `workStart` und ohne `workEnd` stehen (wie nach einem App-Neustart); Rückwechsel setzt ihn fort, die in B verbrachte Zeit zählt in A mit. Nach dem Wechsel schreibt nichts mehr ins alte Profil. Ein Bestätigungsdialog "Beenden und wechseln" ist nicht Teil von PR 1 (offen, siehe #388).
- **Writes einer Aktion:** Jede Schreibaktion des `DashboardViewModel` ruft `_beginAction()` **synchron direkt nach** `_ensureCurrentDay()` auf und hält so `_initGen`, `SaveWorkEntry`, Overtime-/Settings-Repo und Uhr fest (`_ActionCtx`, Pflichtparameter von `_recalculateStateAndSave`). Eintrag und Saldo landen immer im Profil des Aktionsbeginns. Bei Überholung (`ctx.gen != _initGen` oder `!ref.mounted`) laufen die Writes zu Ende; nur `state =`, `_startTimerIfNeeded` und Reinit entfallen. Ein Fehler beim Saldo-Write einer überholten Aktion wird geloggt und geschluckt. Neue Schreibaktionen müssen `_beginAction()` aufrufen und nie nach einem `await` `ref.read(...UseCaseProvider)` nutzen. Überholung nie über `ref.mounted` allein prüfen: es bleibt über einen Rebuild `true` (riverpod 3.0.3), und `onDispose` der Abhängigen läuft erst im Rebuild (Scheduler-Task), nicht beim `setActiveProfile`.
- **`deleteProfile(aktiv)`:** erst auf Standard wechseln, dann API, bei Fehler Rückwechsel und Exception weiterreichen. `addProfile` wechselt automatisch ins neue Profil (friert also ein); ein Guard vor dem API-Aufruf fehlt noch.
- **Bekannte Grenzen:** (1) Parallelbetrieb: A eingefroren und "laufend", B startet einen eigenen Timer. (2) Offene Einträge im vergessenen Profil werden nie automatisch beendet; ihre Darstellung in Reports/Kalender ist nicht untersucht. Kehrt der Nutzer in dieses Profil zurück, weist der Banner aus „Offene Einträge vor heute (#385)“ auf einen offenen Vortag hin (nur das aktive Profil wird geprüft). (3) Stop-Pfad: `startOrStopTimer` bricht `_timer` vor `saveOvertime` ab und fängt dessen Exception nicht; bei einem Fehler bleibt der State "laufend" ohne Timer und die Exception geht an den Aufrufer (per Probe bestätigt, nicht behoben, Folge-Issue #402). (4) Bereits verfälschte Daten (A-Eintrag in B) werden nicht repariert. (5) `ProfileScope` im Backend prüft keine Profilexistenz (nicht verifiziert).
- **Tests:** `Harness(profiles: true)` bzw. `scenario(..., profiles: true)` (zweites Repo-Set `workB`/`overtimeB`/`settingsB`, Test-Notifier, gemeinsames `writeLog` mit Repo-Label). Wechsel nur über `h.switchProfile(id)`: es lässt per `elapse(Duration.zero)` den Rebuild-Task laufen. Hold-Flags: `holdReads`, `holdSaves`, `holdSaveOvertime`, `holdOvertimeLoad`, `failSaveOvertime`. Datei: `test/presentation/view_models/dashboard_view_model_profile_test.dart`.

### Offene Einträge vor heute (#385)

Ein über Mitternacht gelaufener Timer bleibt nach App-Neustart als offener Eintrag (`workStart != null`, `workEnd == null`) am Vortag stehen; `DashboardViewModel._load` kennt nur "heute". Das Dashboard zeigt dafür einen nicht-modalen Banner (`OpenEntryBanner`, neben `HolidayBanner`). Es ändert sich nie etwas ohne Nutzeraktion, kein automatisches Splitten (#381).

- **Suche:** `GetOpenPastWorkEntries` (Provider `getOpenPastWorkEntriesUseCaseProvider`) liest **aktuellen + Vormonat** über `workRepositoryProvider` (also das aktive Profil) und filtert auf Typ `work`, Start gesetzt, kein Ende, Kalendertag vor heute; neuester zuerst. Je Monat eigenes try/catch (`logger.e`, keine Eintragsinhalte). Ältere Einträge, andere Profile und ein `resumed`-Re-Check sind bewusst nicht Teil.
- **ViewModel:** `OpenEntryViewModel` (manueller `NotifierProvider`, `open_entry_view_model.dart`) sucht beim Start sowie bei Profil-/Auth-Wechsel (Rebuild über `ref.watch` der UseCases) und Tageswechsel (`ref.listen(todayProvider)`, nie `watch`). Der im Dashboard laufende Eintrag (z. B. #379) ist nie Kandidat; stoppt das Dashboard ihn, wird er aus den Kandidaten entfernt. `_epoch` (Rebuild) und `_loadGen` (Suchlauf) verwerfen späte Ergebnisse.
- **Später:** blendet den ganzen Banner (alle Kandidaten des Profils) nur für die Sitzung aus. Speicher: `openEntryDismissedProvider` (Schlüssel `profileId|yyyy-MM-dd`, nicht persistent, unabhängig vom Repo, damit er den VM-Rebuild überlebt).
- **Beenden:** `CloseOpenWorkEntry` (`closeOpenWorkEntryUseCaseProvider`) validiert das Ende (`isValidOpenEntryEnd`: nach Start, nicht nach jetzt, nicht vor einer Pause), liest den Eintrag **frisch** (bereits beendet -> `alreadyClosed`, keine Writes), schließt offene Pausen zum Ende, wendet Auto-Pausen wie der Stop an und schreibt **erst den Saldo, dann den Eintrag**. Saldo inkrementell: `neu = alt + Netto - Soll am Eintragsdatum` (Soll über `effectiveTargetForDate`). `lastUpdated` wird **bewusst nicht** gesetzt: `_load` zieht bei `lastUpdated == heute` den Tagesanteil des geladenen heutigen Eintrags vom Saldo ab. Eingeloggt setzt das Backend `lastUpdated` bei jedem `PUT /api/overtime`; deshalb sendet der Use Case `saveOvertime(..., keepLastUpdated: true)` (Body `{"minutes": n, "keepLastUpdated": true}`, Feld nur bei `true`; Backend ab #408, eine ältere API ignoriert es und setzt `lastUpdated` weiterhin, #406). Deploy-Reihenfolge: API vor App. Alle anderen Aufrufer (Stop-Pfad, `AddAdjustment`, `ResetOvertime`, `DataSyncService`) behalten den Default `false`. Ein Teilfehler zwischen Saldo- und Eintrags-Write bleibt ein Rest-Risiko (wie #402). Der VM hält Use Case, Settings und Dashboard-Notifier am Aktionsbeginn fest (kein `ref.read` nach `await`), ignoriert Doppeltippen (`busy`) und fasst bei überholter Aktion (Profilwechsel) weder State noch Dashboard an.
- **Dashboard-Reload:** nach `closed` ruft der VM `DashboardViewModel.reloadAfterRetroClose()` (`_init(dayChange: true)`, damit `initialOvertime` den neuen Saldo enthält). Läuft im Dashboard ein Vortag über Mitternacht, bleibt er unangetastet und nur die Saldo-Basis wird erneuert. Danach folgt ein Re-Check (nächster offener Eintrag wird sichtbar).
- **Ende-Vorschlag (Dialog):** `suggestOpenEntryEnd` in `overtime_utils.dart`: Soll-Ende = Start + Soll + geschlossene Pausen (Duration-Addition); liegt es vor jetzt, ist es die Vorbelegung, sonst "Jetzt" nur bei höchstens 24 h Alter, sonst keine Vorbelegung (Bestätigen gesperrt, bis der Nutzer eine Zeit wählt). Soft-Warnung ab 16 h Netto.
- **Grenzen:** Fortsetzen eines offenen Eintrags kommt als PR 1b; Darstellung offener Einträge in Reports (#404) und die Web-Parität sind eigene Aufgaben. Ein ungelesener Monat (Lesefehler) führt nur zu fehlenden Kandidaten, nicht zu einem Fehler.
- **Tests:** `get_open_past_work_entries_test`, `close_open_work_entry_test`, `open_entry_end_suggestion_test`, `open_entry_view_model_test` (Harness mit `profiles: true`), `dashboard_view_model_reload_test`, Widget-Tests `open_entry_banner_test`/`open_entry_end_dialog_test`, `dashboard_screen_open_entry_test`. Screen-Tests, die `DashboardScreen` pumpen, müssen `openEntryViewModelProvider` überschreiben. `FakeWorkRepository` kennt dafür `monthReads`/`failMonths` und lässt `holdReads`/`failReads` auch auf Monats-Reads wirken.

### Code Generation

Files ending in `.g.dart` are generated — do not edit them manually. Regenerate with `dart run build_runner build`. Mock files (`*.mocks.dart`) are generated by `mockito` and also must not be edited manually.

---

## Workflow-Regeln (IMMER einhalten)

1. **Niemals direkt coden ohne Phase 1 + 2 abgeschlossen** — auch bei kleinen Tasks
2. **Context bei ~60% → `/clear` → Fortschritt aus `thoughts/`-Datei laden**
3. **Tests vor Implementation schreiben (TDD)** — Tests dürfen nicht von Datum, Wochentag oder Zeitzone abhängen
4. **Nach `@riverpod`-Änderungen immer `dart run build_runner build` ausführen**
5. **Keine direkten Änderungen an `*.g.dart` oder `*.mocks.dart`**
6. **`SharedPreferences` nur über den `main.dart`-Override — nie direkt**
7. **Premium-Features immer hinter `isPremiumProvider` absichern**
8. **Hybrid-Repository-Pattern nicht umgehen — immer über HybridImpl gehen**
9. **Alle User-Strings über `AppLocalizations.of(context)`** — ARB-Keys in `lib/l10n/app_de.arb` (+ Übersetzung in `app_en.arb`) ergänzen, nie deutschen Text hart codieren. Nach ARB-Änderungen `flutter gen-l10n` ausführen

## Agenten-Übersicht

Die Agents liegen im Repo-Root unter `.claude/agents/` und sind Subagents: Die Commands starten sie
über das Agent-Tool, jeder läuft in eigenem Kontext und gibt nur eine Kurzfassung zurück.
Rückfragen und Freigaben laufen über die Hauptsession.

| Subagent | Datei | Wann verwenden |
|---|---|---|
| Analyst | `.claude/agents/mobile-analyst.md` | Aufgabe verstehen, hinterfragen |
| Planner | `.claude/agents/mobile-planner.md` | Implementierungsplan erstellen |
| Developer | `.claude/agents/mobile-developer.md` | Code schreiben, TDD |
| Tester | `.claude/agents/mobile-tester.md` | Tests, Testlücken, CI-Checks lokal |
| UI-Reviewer | `.claude/agents/mobile-ui-reviewer.md` | UI prüfen (Widget-Tests, lokal `flutter run`) |
| Reviewer | `.claude/agents/mobile-reviewer.md` | Code Review, Commit, PR |

Betrifft ein Issue mehrere Plattformen, zuerst `/issue <nr>` bzw. den Subagent `cross-platform-coordinator` nutzen.

## Slash Commands

| Command | Phase |
|---|---|
| `/issue 123` | Einstieg — Issue lesen, Plattformen bestimmen, Branch anlegen |
| `/mobile-analyze 123` | Phase 1 — Aufgabe analysieren → `mobile/thoughts/123-research.md` |
| `/mobile-plan 123` | Phase 2 — Plan erstellen → `mobile/thoughts/123-plan.md` |
| `/mobile-implement 123` | Phase 3 — Code schreiben (TDD) |
| `/mobile-validate 123` | Phase 4 — Testen + UI |
| `/mobile-review 123` | Phase 5 — Review + PR gegen `develop` |

Das Argument ist die GitHub-Issue-Nummer. Branch-, Commit- und Release-Konventionen: `CONTRIBUTING.md` im Repo-Root.
