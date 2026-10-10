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
- Ein laufender Vortag kann auch über „Fortsetzen“ des Banners für offene Einträge (#385, `resumePastEntry`) ins Dashboard kommen; er wird dann genauso behandelt (Soll/Überstunden am Eintragsdatum, kein Reinit beim Tageswechsel).
- Beim Tageswechsel ist `storedOvertime` die Basis (Ausnahme: neuer Eintrag schon abgeschlossen und danach gespeichert).
- Use Cases (`GetTodayWorkEntry`, `ToggleBreak`, `StartOrStopTimer`) bekommen die Uhr per Konstruktor (`clock:`) aus `clockProvider`.
- Tests: `test/support/fake_clock.dart` (an `fakeAsync.elapsed` koppelbar, `jumpTo` für Uhrsprünge) und `test/support/fake_repositories.dart` (In-Memory-Repos). VM-/Provider-Tests laufen in `fakeAsync` (Container innerhalb anlegen, am Ende `dispose` und Timer-Zähler prüfen); `TestWidgetsFlutterBinding.ensureInitialized()` ist nötig, weil `todayProvider` einen `WidgetsBindingObserver` registriert. DST-Tests als Invarianten formulieren (lokale Folgetag-Schlüssel), CI läuft in Europe/Berlin; lokal zusätzlich `TZ=UTC`/`America/Los_Angeles`/`Pacific/Auckland flutter test`.

Reports, Urlaub, Insights und Jahres-Tab folgen dem Tageswechsel ebenfalls über `todayProvider` (#387), nicht über `DateTime.now()`:

- In Notifier-`build()` immer `ref.listen(todayProvider, ...)`, **nie** `ref.watch(todayProvider)`: `watch` baut den Notifier jeden Tag neu (Zustands- und Auswahlverlust, bei Urlaub 12 Abfragen pro Tag).
- `ReportsViewModel`: Die Auswahl (`selectedDay`/`focusedDay`, ggf. `selectedMonth` samt Monats-Reload) folgt dem Tageswechsel nur, wenn sie auf dem bisherigen "heute" stand; manuell gewählte Tage/Monate und Multi-Select bleiben unangetastet.
- `LeaveBalanceViewModel`: lädt nur beim **Jahreswechsel** neu und verwirft dabei die Vorjahres-Bilanz (Ladezustand statt falschem Resturlaub). `leaveBalanceNowProvider` entfällt; Tests überschreiben `clockProvider`. `YearlyLeaveRows` watcht `todayProvider.select((d) => d.year)`.
- Insights und Jahres-Tab lesen "heute"/Jahr nur beim Laden per `ref.read(todayProvider)`, ohne Listener und ohne Auto-Reload (keine Reads für Nutzer ohne Zugriff, gewähltes Jahr bleibt).

### Kalendertag eines Eintrags (#418)

`date` wird als **UTC-Mitternacht des lokalen Kalendertags** gespeichert (`WorkEntryModel.toMap`, `ApiClient._entryToJson`; Schreibformat unverändert). Beim Lesen darf daraus kein Zeitpunkt in lokalen Feldern werden: westlich von UTC (Los Angeles) ergäbe `.toLocal()`/`Timestamp.toDate()` den Vortag.

- **Lesegrenzen-Vertrag:** Ab der Lesegrenze ist `WorkEntryEntity.date` die **lokale Mitternacht** des Kalendertags (in Europa also 00:00, nicht mehr 01:00/02:00). Der Tag kommt aus der `id` (`yyyy-MM-dd`) bzw. dem Tages-Key des Monatsdokuments, nie aus dem gespeicherten `date`. Helfer: `domain/utils/entry_day.dart` (`localDateFromEntryId` gibt bei ungültiger Id `null`, `calendarDateFromUtcMidnight` liest die UTC-Felder).
- **Wo:** `ApiClient._entryFromJson` (Id, sonst UTC-Felder von `date`), `WorkEntryModel.fromMap` (UTC-Felder) und `WorkEntryModel.fromDayMap` (Tages-Key gewinnt; beide Lese-Aufrufer der `FirestoreDataSourceImpl`), `ReportsViewModel._dayKey` (Berichtstage des Backends). Schreibpfade bleiben auf `date`. Neue Lesegrenzen (neue Mapper, neue Datenquellen) müssen dasselbe tun.
- **Regel für Verbraucher:** Der Tag eines Eintrags ist immer `entryDay(entry)` bzw. `entryDayKey(entry)` (`domain/utils/entry_day.dart`: Tag aus der `yyyy-MM-dd`-Id, sonst lokale Felder von `date`), **nie** `entry.date.year/month/day/weekday` oder `isSameDay(entry.date, …)`. Das gilt für „heute?“, Wochentag/Soll, KW, Arbeitstage, Monats-/Jahresgrenzen und die Kombination von Uhrzeiten mit dem Eintragstag. Defense-in-Depth zur Lesegrenze, damit ein inkonsistenter Eintrag (Id Montag, `date` Sonntag) nicht am Nachbartag landet. **Ausnahme Schreibpfade:** `toMap`, `_entryToJson`, Datasource-/Local-Repos und die Identitätskopien (`date: state.workEntry.date`) bleiben auf `date`; sie definieren das Speicherformat. Tests dafür nutzen inkonsistente Fixtures (`*_entry_day_test.dart`, zonenunabhängig).
- **Tests:** Zonen-Regressionstests heißen `*_tz_test.dart` und rufen `registerTimezoneCanary()` (`test/support/timezone_guard.dart`) auf: `TZ` wirkt nur als Umgebungsvariable des Prozesses `flutter test` und fällt bei unbekannter Zone **still auf UTC** zurück, der Canary prüft den Januar-Offset. `test/support/api_backed_work_repository.dart` schickt UTC-Mitternachts-JSON durch den echten `ApiClient`-Mapper (Tests mit lokal gebautem `date` umgehen genau die Lesegrenze). Lokal: `TZ=America/Los_Angeles flutter test $(find test -name '*_tz_test.dart')` (ebenso `Pacific/Auckland`, `UTC`, `Europe/Berlin`). CI: Vollauf unter UTC und Berlin plus der Schritt „Test (TZ=America/Los_Angeles, Pacific/Auckland)“ nur für die `*_tz_test.dart`; die Vollsuite unter LA/Auckland ist nicht vorgesehen.

### Profilwechsel (#388)

Ein Wechsel des Arbeitszeit-Profils (`activeWorkProfileIdProvider`) invalidiert Repos, UseCases und `DashboardViewModel`; die Repos sind konstruktor-gebunden an ihr Profil. Analog Web #380 (Stufe 1):

- **Einfrieren (bewusste Entscheidung):** `onDispose` bricht Timer und Autosave beim Wechsel ab, **ohne zu speichern**. Der Eintrag bleibt im alten Profil mit `workStart` und ohne `workEnd` stehen (wie nach einem App-Neustart); Rückwechsel setzt ihn fort, die in B verbrachte Zeit zählt in A mit. Nach dem Wechsel schreibt nichts mehr ins alte Profil. Wechsel über den Wechsler oder "Neues Profil" mit laufendem Timer fragen vorher nach (Bestätigungsdialog, siehe unten); `deleteProfile(aktiv)`, Logout und App-Neustart/gemerktes Profil haben bewusst **keinen** Dialog und frieren weiter ein.
- **Writes einer Aktion:** Jede Schreibaktion des `DashboardViewModel` ruft `_beginAction()` **synchron direkt nach** `_ensureCurrentDay()` auf und hält so `_initGen`, `SaveWorkEntry`, Overtime-/Settings-Repo und Uhr fest (`_ActionCtx`, Pflichtparameter von `_recalculateStateAndSave`). Eintrag und Saldo landen immer im Profil des Aktionsbeginns. Bei Überholung (`ctx.gen != _initGen` oder `!ref.mounted`) laufen die Writes zu Ende; nur `state =`, `_startTimerIfNeeded` und Reinit entfallen. Reihenfolge bei Aktionen mit Saldo-Block seit #412: **Eintrag -> Saldo -> State** (die #388-Entscheidung „bestehende Reihenfolge Saldo->Eintrag beibehalten“ ist damit bewusst überholt: nur der Eintrag ist rückrollbar, der Saldo-Write setzt `lastUpdated`; der nicht rückrollbare Schritt gehört ans Ende). Ein Fehler beim Eintrag- oder Saldo-Write wird immer geloggt und nicht weitergeworfen, auch bei einer überholten Aktion (siehe „Fehler beim Speichern (#402)“). Neue Schreibaktionen müssen `_beginAction()` aufrufen, über `_runAction` laufen (Reentranz-Sperre, #413) und nie nach einem `await` `ref.read(...UseCaseProvider)` nutzen. Überholung nie über `ref.mounted` allein prüfen: es bleibt über einen Rebuild `true` (riverpod 3.0.3), und `onDispose` der Abhängigen läuft erst im Rebuild (Scheduler-Task), nicht beim `setActiveProfile`.
- **`deleteProfile(aktiv)`:** erst auf Standard wechseln, dann API, bei Fehler Rückwechsel und Exception weiterreichen. `addProfile` (VM-Methode) wechselt automatisch ins neue Profil und ruft den Guard nicht selbst auf; den Guard ruft `AddWorkProfileDialog._save` vor dem API-Aufruf.
- **Bestätigungsdialog (PR 2):** `WorkProfileViewModel.checkSwitchAllowed({confirm})` liefert `ProfileSwitchGuardResult` (`allowed`/`cancelled`/`saveFailed`/`busy`; `_switchPending` sperrt Reentranz, Reset im `finally`). Läuft im Dashboard ein Timer (`DashboardViewModel.isTimerRunning`, während des Ladens `false`), zeigt `confirm` den Dialog (`showProfileSwitchConfirmDialog`, Texte `switchWhileRunning*`/`stopAndSwitchButton`); bei Bestätigung stoppt `DashboardViewModel.stopRunningForSwitch(fromProfileId)` über den **normalen** Stop-Pfad (`startOrStopTimer`, wartet einen Ladelauf ab, `false` bei geändertem Profil, Wirkungs-Check `!_isRunning` nach dem Stop, da `startOrStopTimer` auch `true` ohne Stop liefert). Gewechselt wird erst bei `allowed`, durch den Aufrufer. Guard-Orte: `WorkProfileSwitcher._handleSelectProfile` (aktives Profil erneut wählen = kein Dialog) und `AddWorkProfileDialog._save` (bei `cancelled`/`busy`/`saveFailed` bleibt der Anlege-Dialog offen, kein API-Aufruf). `saveFailed` zeigt `dashboardSaveError`. Ist das Dashboard-VM nicht baubar, erlaubt der Guard den Wechsel (geloggt). **Neue Wechselpfade müssen den Guard nutzen.** Tests: `dashboard_view_model_switch_test`, `work_profile_view_model_guard_test`, `work_profile_switcher_switch_guard_test`.
- **Bekannte Grenzen:** (1) Parallelbetrieb: A eingefroren und "laufend", B startet einen eigenen Timer (der Dialog verhindert nur das Einfrieren beim Wechsel, nicht einen späteren Start in B). (2) Offene Einträge im vergessenen Profil (Dialog umgangen: Löschen, Logout, Neustart) werden nie automatisch beendet; ihre Darstellung in Reports/Kalender ist nicht untersucht. Kehrt der Nutzer in dieses Profil zurück, weist der Banner aus „Offene Einträge vor heute (#385)“ auf einen offenen Vortag hin (nur das aktive Profil wird geprüft). (3) Stop-Pfad: bei einem Eintrag- oder Saldo-Fehler bleiben State und Timer unverändert und der Wechsel unterbleibt (`false`, Snackbar; #402/#412, siehe „Fehler beim Speichern (#402)“); nur ein Doppelfehler (Saldo plus Kompensation) ist ein Rest. (4) Bereits verfälschte Daten (A-Eintrag in B) werden nicht repariert. (5) `ProfileScope` im Backend prüft keine Profilexistenz (nicht verifiziert).
- **Tests:** `Harness(profiles: true)` bzw. `scenario(..., profiles: true)` (zweites Repo-Set `workB`/`overtimeB`/`settingsB`, Test-Notifier, gemeinsames `writeLog` mit Repo-Label). Wechsel nur über `h.switchProfile(id)`: es lässt per `elapse(Duration.zero)` den Rebuild-Task laufen. Hold-Flags: `holdReads`, `holdSaves`, `holdSaveOvertime`, `holdOvertimeLoad`, `failSaveOvertime`. Datei: `test/presentation/view_models/dashboard_view_model_profile_test.dart`.

### Fehler beim Speichern (#402)

Alle Schreibaktionen des `DashboardViewModel` (`startOrStopTimer`, `startNewSession`, `startNewSessionKeepBreaks`, `setManualStartTime`, `setManualEndTime`, `clearEndTime`, `startOrStopBreak`, `deleteBreak`, `updateBreak`) liefern `Future<bool>`: `true` = gespeichert oder nichts zu tun (z. B. Stop auf bereits beendetem Eintrag), `false` = bei einer Aktion mit Saldo-Block konnte der Eintrag oder der Saldo nicht gespeichert werden (jeweils ohne Teilfehler, siehe unten) oder der aktuelle Tag war nicht ladbar (`_ensureCurrentDay`, #416).

- **Stop-Pfad (Reihenfolge Eintrag -> Saldo -> State, #412):** `startOrStopTimer` bricht den `_timer` nicht mehr vor dem Speichern ab. Er wird erst in `_startTimerIfNeeded` nach dem Setzen des States beendet. `_recalculateStateAndSave` schreibt bei Aktionen mit Saldo-Block (nach der Aktion Start und Ende gesetzt) zuerst den Eintrag. Scheitert er (Fehler oder 30-s-Timeout), ist nichts geschrieben: loggen (`logger.e`, nur `runtimeType`, keine Eintragsinhalte), `false`, State, Timer und Saldo unverändert. Scheitert danach der Saldo-Write (`saveOvertime`/`saveLastUpdateDate`), wird der Eintrag best-effort auf `_ActionCtx.before` zurückgeschrieben (`_compensateEntry`), `false`, State/Timer unverändert. Nichts wird weitergeworfen (sonst meldet `PlatformDispatcher.onError` es als fatal an Crashlytics). Das gilt einheitlich für alle Aktionen mit Saldo-Block und auch für überholte Aktionen (#388; Writes nur über `ctx`-Objekte, also im Profil des Aktionsbeginns). Wiederholen ist idempotent: der Saldo ist absolut (`Basis + Tagesanteil`). Aktionen **ohne** Saldo-Block (Start, Pause auf laufendem Eintrag, `clearEndTime`, Neue Session) bleiben optimistisch (State sofort, Eintrag-Fehler geschluckt, `true`, Autosave heilt; Offline-Start muss funktionieren).
- **Profilwechsel (#388):** `stopRunningForSwitch` nutzt diesen Stop-Pfad; bei `false` wird nicht gewechselt (Snackbar `dashboardSaveError`).
- **UI:** `reportDashboardSave` (`widgets/common/dashboard_save_feedback.dart`) zeigt bei `false` die Snackbar `dashboardSaveError`; verwendet in `DashboardScreen` (Start/Stop, manuelle Zeiten, Endzeit löschen, Pause, Pause löschen, Neue Session) und `EditBreakModal`. Das ViewModel kennt kein Snackbar.
- **Kein Saldo-Rollback im Dashboard-Stop, stattdessen Eintrag-Kompensation:** der Stop schreibt `lastUpdated` mit, der Backend-Wert lässt sich nicht zurücksetzen; ein Saldo-Rollback verschlechtert den Fall (siehe `_load`-Heuristik). Rollback des Saldos nur dort, wo `lastUpdated` nie angefasst wird (`CloseOpenWorkEntry`, `keepLastUpdated: true`). Im Dashboard ist stattdessen der Eintrag rückrollbar: `_ActionCtx.before` (synchron in `_beginAction` aus `state.workEntry` festgehalten, auch vor einem Zwischen-`await` wie `toggleBreak.call`) ist der Vorzustand der Kompensation; sie fasst `lastUpdated` nie an.
- **Regelwerk Teilfehler:** (1) Fehler vor dem ersten Write lassen State, Timer und Daten unverändert und melden `false`. (2) Nach dem ersten erfolgreichen Write nie weiterwerfen, sondern loggen und ein definiertes Ergebnis liefern. (3) Saldo-Rollback nur mit `keepLastUpdated: true`. (4) Eintrag-Kompensation ist immer zulässig (kein `lastUpdated`-Bezug); ein Kompensationsfehler wird nur geloggt, das Ergebnis bleibt `false`. (5) Nicht rückrollbare Writes ans Ende der Kette.
- **Bekannte Grenzen:** (1) entfällt seit #412 (Eintrag vor Saldo). Rest: **Doppelfehler** (Saldo-Fehler und Kompensationsfehler): beim Stop heilt der Autosave (30 s) bzw. das Wiederholen den laufenden Eintrag, bei einem geschlossenen Eintrag bleibt Eintrag neu/Saldo alt/State alt bis zur nächsten Aktion, ein Reload davor verfälscht die Saldo-Basis. `saveLastUpdateDate`-Fehler nach erfolgreichem `saveOvertime` (nur Nicht-API-Repos): Saldo neu, `lastUpdated` alt, Eintrag kompensiert. Ein Eintrag-Write, der wirft, obwohl er serverseitig landete (mehrdeutiger Fehler), wird nicht kompensiert. **Spät landender Write nach Timeout:** ein per Timeout aufgegebener Write ist nicht abbrechbar und kann später landen; der Timeout wird wie ein Fehler behandelt (Eintrag-Timeout => `false`, Saldo-Timeout => `false` mit Kompensation des Eintrags), eine „Heilung nach spätem Landen“ gibt es bewusst nicht. Der Saldo ist absolut, der Eintrag wird beim nächsten Schreiben/Autosave überschrieben. (2) entfällt: Doppeltippen im Schreibfenster wird seit #413 verworfen (siehe „Reentranz-Sperre (#413)“). (3) Bereits entstandene Teilfehler-Daten werden nicht repariert.
- **Tests:** `dashboard_view_model_save_error_test` und `dashboard_view_model_partial_failure_test` (#412; Harness `profiles: true`, `h.overtime.failSaveOvertime`/`holdSaveOvertime`/`failSaveLastUpdate`, `h.work.failSaves`/`failSaveCalls` (1-basiert, z. B. `{2}` = nur der zweite Eintrag-Write, die Kompensation)/`saveCalls`), Widget-Tests `dashboard_screen_save_error_test` (echtes ViewModel mit Fakes, de/en) und `edit_break_modal_test`. Test-Fakes, die `DashboardViewModel` überschreiben, müssen `Future<bool>` liefern.

### Reentranz-Sperre (#413)

Alle neun Schreibaktionen des `DashboardViewModel` laufen über den privaten Wrapper `_runAction(body)`; jede öffentliche Aktion ist ein Einzeiler `=> _runAction(_xxxBody)`, der bisherige Rumpf (inkl. `_ensureCurrentDay` + `_beginAction`) steht unverändert in `_xxxBody`. Die Reihenfolge ist seit #412 Eintrag -> Saldo -> State (mit Eintrag-Kompensation bei Saldo-Fehler, siehe „Fehler beim Speichern (#402)“).

- **Verwerfen:** Läuft schon eine Aktion (`_busy`), liefert ein weiterer Aufruf sofort `true` (kein Fehler, kein Snackbar, kein State-Update, nur `logger.i` ohne Inhalte). `false` nur, wenn das VM nicht mehr aktiv ist (`!ref.mounted`) oder `_ensureCurrentDay` abbricht (#416). Exceptions aus dem Body (z. B. `toggleBreak`) werden unverändert weitergereicht, die Sperre ist danach frei.
- **Synchron:** Das Flag wird als erste Anweisung gesetzt, noch vor Autosave-Wartezeit und `_ensureCurrentDay`. So überlappt auch ein Tap in der Ladelücke nicht mit einem zweiten.
- **Token:** Jede Aktion hat ein Token (`_actionToken`); `finally` gibt Flag, `_actionDone` und `isSaving` nur frei, wenn das Token noch das aktuelle ist. `build()` (Profilwechsel) setzt Flag, Token, `_actionDone` und `_autoSaveRun` zurück (der Notifier bleibt dieselbe Instanz). Eine alte, spät endende Aktion löscht so nie die Sperre einer neuen; sie schreibt weiter zu Ende (#388).
- **`isSaving`:** `DashboardState.isSaving` spiegelt die Sperre (Wrapper setzt/löscht es nur bei `ref.mounted` und aktuellem Token; `_load` baut den State mit `isSaving: _busy`, ein Reinit mitten in der Aktion entsperrt die UI nicht). `DashboardScreen` deaktiviert dann Start/Stop, Pausen-Button, Pause-löschen-Icon und beide Zeitfelder, `EditBreakModal` das „Speichern“ (sonst ginge ein verworfenes Update still verloren, das Modal schließt sofort). Kein Spinner, kein neuer Text.
- **Autosave:** Läuft nur, wenn weder `_busy` noch `_autoSaveRun != null`. Beim Überspringen bleibt `_tickCounter >= 30` (Retry im nächsten Tick, kein 30-s-Loch). Der Wrapper wartet nach dem Flag-Setzen auf einen laufenden Autosave, bevor irgendein Write der Aktion beginnt (Voraussetzung für #412: der Autosave überholt den frischen Eintrag nie). Der `_autoSaveRun != null`-Guard im Tick ist heute nicht erreichbar (Autosave-Timeout = Intervall), bleibt als Verteidigung.
- **Timeouts:** `_writeTimeout` = 30 s, einzeln je Write-Block: (a) Saldo-Block (`saveOvertime` + `saveLastUpdateDate` + Warnprüfung) wie ein Saldo-Fehler (#402): geloggt (`TimeoutException`), `false`, State/Timer/Eintrag unverändert; ein `timedOut`-Flag verhindert, dass die weiterlaufende Schließung später `lastUpdate`/Warnung nachholt. (b) Eintrag-Write in `_recalculateStateAndSave`: bei Aktionen mit Saldo-Block wie ein Eintrag-Fehler (#412): geloggt, `false`, State/Timer unverändert, Saldo nicht geschrieben; bei Aktionen ohne Saldo-Block wie bisher geschluckt (#336, `true`, Autosave heilt). Ein Saldo-Timeout kompensiert zusätzlich den Eintrag (eigener 30-s-Timeout, Zeitbudget einer Aktion damit bis 120 s: Autosave-Wartezeit 30 + Eintrag 30 + Saldo 30 + Kompensation 30). (c) Autosave: geloggt, der nächste ist möglich. Nicht abgedeckt: `_ensureCurrentDay`-Lesezugriffe und `toggleBreak.call`.
- **`stopRunningForSwitch`:** Wartet auf den Ladelauf (Bestand), dann eine Schleife über `_actionDone` (`await done.future`, bricht bei bereits beendetem Completer ab, mit `ref.mounted`-Check; `onDispose` beendet den Completer, ein Profilwechsel lässt den Wartenden nicht hängen), danach **ohne weiteres `await`** Profilprüfung, `isTimerRunning` und `startOrStopTimer()` (dessen Wrapper setzt die Sperre synchron). Ein parallel getippter Stop lässt den Wechsel so weder fälschlich scheitern noch doppelt stoppen.
- **`resumePastEntry`:** Liefert `false`, wenn `_busy`: Prüfung am Anfang (vor dem Warten auf den Ladelauf) und nochmals direkt danach, vor der `todayIsEmpty`-Prüfung. Setzt selbst kein Flag (schreibt nichts).
- **Nicht gesperrt:** `reloadAfterRetroClose`, `updateOvertimeFromSettings`, `recalculateOvertimeFromSettings`, `_onDayChange`, `_load` (schreiben nichts bzw. würden sich selbst blockieren).
- **Bekannte Grenzen:** (1) Der Timeout deckt `_ensureCurrentDay`-Lesezugriffe und `toggleBreak.call` nicht ab; ein dort hängender Lesezugriff blockiert wie bisher, Folge-Taps werden aber verworfen statt aufgestaut. (2) Ein per Timeout abgebrochener Write ist nicht abbrechbar und kann später landen (unbekannter Ausgang; Wiederholen/Autosave überschreibt, der Saldo ist absolut; keine Heilung nach spätem Landen, auch nicht beim Eintrag-Timeout oder Autosave-Timeout, #412). (3) Ein verworfener Tap ist nur an den deaktivierten Buttons erkennbar (kein Hinweis). (4) entfällt (Teilfehler Saldo/Eintrag: #412). (5) Web: siehe `web/CLAUDE.md`, „Reentranz-Sperre (#426)“.
- **Tests:** `dashboard_view_model_busy_test` (Harness `profiles: true`; Holds `holdSaves`/`holdSaveOvertime`/`holdReads` müssen vor Szenario-Ende freigegeben werden, sonst löst der offene Timeout-Timer den Timer-Leak-Check aus), `dashboard_view_model_switch_test` (B12), `dashboard_view_model_resume_test` (B13), `dashboard_state_test`, Widget-Tests `dashboard_screen_save_error_test` (Sperre, de/en) und `edit_break_modal_test`. Timeout-Tests rechnen in `fakeAsync` mit dem 30-s-Raster des 1-s-Timers: ein Autosave-Tick fällt auf die Sekunde 30, daher den Aktionsbeginn für Autosave-Tests (B9) auf t=25 s legen.

### Offene Einträge vor heute (#385)

Ein über Mitternacht gelaufener Timer bleibt nach App-Neustart als offener Eintrag (`workStart != null`, `workEnd == null`) am Vortag stehen; `DashboardViewModel._load` kennt nur "heute". Das Dashboard zeigt dafür einen nicht-modalen Banner (`OpenEntryBanner`, neben `HolidayBanner`). Es ändert sich nie etwas ohne Nutzeraktion, kein automatisches Splitten (#381).

- **Suche:** `GetOpenPastWorkEntries` (Provider `getOpenPastWorkEntriesUseCaseProvider`) liest **aktuellen + Vormonat** über `workRepositoryProvider` (also das aktive Profil) und filtert auf Typ `work`, Start gesetzt, kein Ende, Kalendertag vor heute; neuester zuerst. Je Monat eigenes try/catch (`logger.e`, keine Eintragsinhalte). Ältere Einträge, andere Profile und ein `resumed`-Re-Check sind bewusst nicht Teil.
- **ViewModel:** `OpenEntryViewModel` (manueller `NotifierProvider`, `open_entry_view_model.dart`) sucht beim Start sowie bei Profil-/Auth-Wechsel (Rebuild über `ref.watch` der UseCases) und Tageswechsel (`ref.listen(todayProvider)`, nie `watch`). Der im Dashboard laufende Eintrag (z. B. #379) ist nie Kandidat; stoppt das Dashboard ihn, wird er aus den Kandidaten entfernt. `_epoch` (Rebuild) und `_loadGen` (Suchlauf) verwerfen späte Ergebnisse.
- **Später:** blendet den ganzen Banner (alle Kandidaten des Profils) nur für die Sitzung aus. Speicher: `openEntryDismissedProvider` (Schlüssel `profileId|yyyy-MM-dd`, nicht persistent, unabhängig vom Repo, damit er den VM-Rebuild überlebt).
- **Beenden:** `CloseOpenWorkEntry` (`closeOpenWorkEntryUseCaseProvider`) validiert das Ende (`isValidOpenEntryEnd`: nach Start, nicht nach jetzt, nicht vor einer Pause), liest den Eintrag **frisch** (bereits beendet -> `alreadyClosed`, keine Writes), schließt offene Pausen zum Ende, wendet Auto-Pausen wie der Stop an und schreibt **erst den Saldo, dann den Eintrag**. Saldo inkrementell: `neu = alt + Netto - Soll am Eintragsdatum` (Soll über `effectiveTargetForDate`). `lastUpdated` wird **bewusst nicht** gesetzt: `_load` zieht bei `lastUpdated == heute` den Tagesanteil des geladenen heutigen Eintrags vom Saldo ab. Eingeloggt setzt das Backend `lastUpdated` bei jedem `PUT /api/overtime`; deshalb sendet der Use Case `saveOvertime(..., keepLastUpdated: true)` (Body `{"minutes": n, "keepLastUpdated": true}`, Feld nur bei `true`; Backend ab #408, eine ältere API ignoriert es und setzt `lastUpdated` weiterhin, #406). Deploy-Reihenfolge: API vor App. Alle anderen Aufrufer (Stop-Pfad, `AddAdjustment`, `ResetOvertime`, `DataSyncService`) behalten den Default `false`. Scheitert der Eintrag-Write nach dem Saldo-Write, schreibt der Use Case den gelesenen Saldo best-effort zurück (`saveOvertime(stored, keepLastUpdated: true)`, #410, Vorbild Web `OpenEntryCloseService`; Ergebnis `failed`, Eintrag bleibt offen, Wiederholen zählt nicht doppelt). Kein Rollback, wenn schon der Saldo-Write scheitert. Scheitert der Rollback, wird nur geloggt (`logger.e`, ohne Eintragsinhalte) und der Saldo bleibt verschoben (Korrektur über „Überstunden anpassen“); Gleiches gilt bei einer API ohne #408 und bei einem Saldo-Write eines zweiten Geräts im Fenster (der absolute Rollback überschreibt ihn). Regelwerk für Teilfehler: nach dem ersten erfolgreichen Write nie weiterwerfen, sondern loggen und ein definiertes Ergebnis liefern; einen Saldo nur zurückrollen, wenn `lastUpdated` nie angefasst wurde (`keepLastUpdated: true`). Der Dashboard-Stop bekommt bewusst keinen Saldo-Rollback (`lastUpdated`-Kopplung, #402/#412); stattdessen schreibt er den Eintrag vor dem Saldo und kompensiert den Eintrag bei Saldo-Fehler. `CloseOpenWorkEntry` behält seine Reihenfolge Saldo -> Eintrag mit Saldo-Rollback (inkrementell, `keepLastUpdated: true`). Der VM hält Use Case, Settings und Dashboard-Notifier am Aktionsbeginn fest (kein `ref.read` nach `await`), ignoriert Doppeltippen (`busy`) und fasst bei überholter Aktion (Profilwechsel) weder State noch Dashboard an.
- **Dashboard-Reload:** nach `closed` ruft der VM `DashboardViewModel.reloadAfterRetroClose()` (`_init(dayChange: true)`, damit `initialOvertime` den neuen Saldo enthält). Läuft im Dashboard ein Vortag über Mitternacht, bleibt er unangetastet und nur die Saldo-Basis wird erneuert. Danach folgt ein Re-Check (nächster offener Eintrag wird sichtbar).
- **Ende-Vorschlag (Dialog):** `suggestOpenEntryEnd` in `overtime_utils.dart`: Soll-Ende = Start + Soll + geschlossene Pausen (Duration-Addition); liegt es vor jetzt, ist es die Vorbelegung, sonst "Jetzt" nur bei höchstens 24 h Alter, sonst keine Vorbelegung (Bestätigen gesperrt, bis der Nutzer eine Zeit wählt). Soft-Warnung ab 16 h Netto.
- **Fortsetzen (PR 1b):** Der Banner bietet für den **neuesten** Kandidaten „Fortsetzen“ an (`OpenEntryState.canResume`), wenn `canResumeOpenEntry` (`overtime_utils.dart`, einzige Regel für Anzeige **und** Durchsetzung) erfüllt ist: Typ `work`, Start, kein Ende, Tag vor heute, höchstens 24 h alt (inklusiv, wie „Jetzt“) und der heutige Tag im fertig geladenen Dashboard leer (ein heutiger Urlaub/Krank-Eintrag zählt nicht als leer). `OpenEntryViewModel.resume()` prüft die Regel zum Tap-Zeitpunkt erneut, hält Dashboard-Notifier/Uhr/`_epoch` vor dem `await` fest, ignoriert Doppeltippen (`busy`) und lädt nicht neu (der Listener blendet den Banner aus, sobald das Dashboard den Eintrag führt; „Später“ bleibt unberührt). Der Listener hört auf den Record `(laufender Tag, heute leer)`, damit Start/Stop heute den Button ein-/ausblenden. `DashboardViewModel.resumePastEntry(entry)` wartet auf den laufenden Ladelauf, prüft synchron und ohne `await` bis `_init` (`_loadedOk`, `!isLoading`, heute leer, `canResumeOpenEntry`) und pinnt dann per `_init(dayChange: true, pinnedDate: ...)`: `_load` liest den Eintrag **frisch** über `workRepositoryProvider.getWorkEntry` (nicht mehr offen, z. B. anderes Gerät -> kein Pin, Fallback auf heute, `false`). Basis ist der gespeicherte Saldo (`dayChange`-Pfad, nicht die `lastUpdated == heute`-Heuristik), Soll und `isExtraDay` stammen vom Starttag, der Timer läuft wie bei #379 über Mitternacht weiter (offene Pause läuft weiter). Fortsetzen **schreibt nichts** (erst Autosave/Stop) und braucht deshalb kein `_beginAction()`/`_ActionCtx`; Überholung (Profilwechsel) läuft über `_initGen`/`stale()`. Stop speichert am Starttag und schaltet auf heute um (bestehender Pfad). Ein abgelehntes Fortsetzen (`false`) bleibt still (kein Snackbar, kein neuer Text), der Banner sucht aber die Kandidaten neu (`_load`, nur lesend): ein inzwischen anderswo beendeter Eintrag verschwindet, ein weiterhin offener bleibt stehen.
- **Grenzen:** Fortsetzen nur für den neuesten Eintrag, nur bei leerem heutigen Tag und höchstens 24 h Alter, stiller Fehlschlag ohne Hinweis (Lesefehler loggt das Dashboard). **Start/Stop-Tap in der Ladelücke:** `dashboard_screen.dart` sperrt die Buttons nicht über `state.isLoading`; ein Tap, der während des Pinnens (eine Repo-Leseoperation) ausgelöst wird, wartet in `_ensureCurrentDay` auf den Pin und stoppt den gepinnten Lauf dann (festgeschrieben in `dashboard_view_model_resume_test`). Die Web-Parität der Kennzeichnung/des Fortsetzens ist eine eigene Aufgabe. Ein ungelesener Monat (Lesefehler) führt nur zu fehlenden Kandidaten, nicht zu einem Fehler.
- **Reports (#404):** `domain/utils/open_entry_report_utils.dart` (`reportNetDuration`, `isOpenBeforeToday`, Uhr als Parameter aus `clockProvider`) ist die einzige Stelle, die einen offenen Eintrag (Typ `work`, Start, kein Ende) für die Reports bewertet: Backend-konform Netto 0, **live bis jetzt nur, wenn der Eintragstag (`entryDay`, #418) == heute** ist. Ein im Dashboard über Mitternacht laufender Vortag (#379) zählt in den Reports 0. Tages-Tab (Summe, Tagessaldo), Eintragskarte und Tages-Sheet nutzen den Helper; offene Einträge vor heute zeigen dort `reportsEntryIncompleteTitle`/`reportsEntryIncompleteHint` statt Arbeitszeit (Karte ohne Überstundenzeile). Wochen-/Monatsliste, Kalender, Insights und PDF bleiben unverändert (offene Tage tauchen dort nicht auf). `calculatedWorkDuration` rechnet nie mit „jetzt“. Tests: `open_entry_report_utils_test`, `reports_page_open_entry_test`.
- **Tests:** `get_open_past_work_entries_test`, `close_open_work_entry_test`, `open_entry_end_suggestion_test`, `open_entry_view_model_test` (Harness mit `profiles: true`), `dashboard_view_model_reload_test`, `dashboard_view_model_resume_test`, `open_entry_resume_utils_test`, Widget-Tests `open_entry_banner_test`/`open_entry_end_dialog_test`, `dashboard_screen_open_entry_test`. Screen-Tests, die `DashboardScreen` pumpen, müssen `openEntryViewModelProvider` überschreiben. `FakeOvertimeRepository` zählt `saveOvertimeCalls` und lässt per `failSaveOvertimeCalls` (1-basiert, z. B. `{2}` = nur der zweite Aufruf) einzelne Saves scheitern (#410). `FakeWorkRepository` kennt dafür `monthReads`/`failMonths` und lässt `holdReads`/`failReads` auch auf Monats-Reads wirken.

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
