# Mobile-Plan: #379 — Mobile-Dashboard: Tageswechsel (Mitternacht) wird nicht behandelt
Research: mobile/thoughts/379-research.md (inkl. „Entscheidungen zu den offenen Fragen")
Web-Referenz: web/thoughts/372-plan.md, 372-pr.md (Variante B, stiller Wechsel, Guard, Generationszähler)
UI-Report: entfällt (Bugfix, keine UI-Änderung, keine neuen Texte, keine ARB-Keys)

## Ziel
Das Dashboard kennt den Tageswechsel: gestoppter/leerer Eintrag schaltet still auf den neuen Tag, ein laufender Timer läuft
über Mitternacht weiter (Eintrag bleibt am Starttag), Soll/`isExtraDay`/Überstunden hängen am Eintragsdatum, keine
Schreibaktion landet im Vortag. Eine zentrale „heute"-Quelle (`todayProvider`) ersetzt die Doppel-Logik im `HolidayBanner`.

## Architektur-Entscheidungen
| Frage | Entscheidung | Begründung |
|---|---|---|
| Neue Entity / Feld? | Nein. `DashboardState` bekommt kein neues Feld; `DashboardState.initial({DateTime? now})` nimmt optional die Uhr (Default `DateTime.now()`) | Eintragsdatum reicht als „Tag"; id-Format des Platzhalters bleibt |
| Repository-Interface ändern? | Nein. Hybrid-/Firebase-/Local-/ApiDataSource unverändert | Nur Uhr-Injektion in Use Cases; Zugriff weiter ausschließlich über `GetTodayWorkEntry`/`SaveWorkEntry`/`ToggleBreak` |
| Neuer Provider? | `todayProvider` manuell (`NotifierProvider<TodayNotifier, DateTime>`, State = lokaler Tag `DateTime(y,m,d)`), **kein** Codegen, root, nicht autoDispose, in `lib/core/providers/today_provider.dart` | Pendant zu Web `TodayService`; überlebt Tabwechsel (Dashboard-VM lebt weiter, Widgets nicht). `DateTime`-Gleichheit verhindert Doppelauslösung |
| `providers.dart` | `getTodayWorkEntryUseCase`/`toggleBreakUseCase`/`startOrStopTimerUseCase` reichen `ref.watch(clockProvider)` als Konstruktor-Clock durch → `dart run build_runner build --delete-conflicting-outputs` (`providers.g.dart`) | Entscheidung 6; `call()`-Signaturen und Bestandsmocks bleiben |
| Use-Case-Uhr | Benannter Konstruktor-Parameter `DateTime Function() clock = DateTime.now`; Minuten-Rundung via `roundToMinute(_clock())`. `nowToMinute()` selbst unverändert | Andere Aufrufer (Reports, Edit-VM, Extensions) bleiben unberührt |
| Dashboard-VM | `ref.listen(todayProvider)` in `build()` → `_onDayChange`; `_init({bool dayChange = false})`; `_initGen` + `_initRun`; `_ensureCurrentDay()`; `ref.mounted`-Checks; try/catch im Ladeblock; `ref.onDispose` (Timer, Autosave, `_initGen++`) | Entscheidungen 2/3/7/9; `_initGen++` in `onDispose` entschärft auch überlappende Läufe bei Rebuild (Login/Profil/Settings-Repo) |
| Zustand beim Reinit | `_init` baut den `DashboardState` **neu** (Konstruktor), nicht per `copyWith` | `copyWith` ignoriert `null`: nach Wechsel von abgeschlossenem Vortag auf leeren Tag blieben `actualWorkDuration`/`grossWorkDuration`/`expectedEndTime`/`expectedEndTotalZero`/`elapsedTime` stale (Fund aus dem Code, nicht in Research) |
| Soll-Kopplung | `_getEffectiveTargetDailyHours(DateTime forDate)`; Aufrufer: `_init` → `workEntry.date`, `_recalculateOvertime`/`_calculateExpectedEndTime` → `state.workEntry.date`, `_recalculateStateAndSave` → `updatedEntry.date`. `isExtraDay` wird in `_recalculateOvertime`/`_recalculateStateAndSave` mitgeführt (`target == Duration.zero`). `getEffectiveDailyTarget` unverändert | Kein Soll-Sprung Fr→Sa / So→Mo |
| `_loadedOk`-Flag | VM merkt, ob der letzte `_init` erfolgreich war; Guard versucht bei `false` einen Retry und bricht die Aktion bei Fehlschlag ab | Offline: sonst würde der Platzhalter-Eintrag (`DashboardState.initial`, ISO-Timestamp-id) beschrieben; hängender `isLoading` wird beendet |
| Basis-Überstunden | `_init(dayChange: true)`: Basis = `storedOvertime`; Ausnahme `dailyAlreadyStored` (`workStart && workEnd && lastUpdate >= workEnd`) → bestehende Heuristik. Normaler `_init` unverändert (Heuristik nur mit `clock()` statt `DateTime.now()`). `saveLastUpdateDate(clock())` | Nebenbefund Heuristik bleibt, wird nicht verschlimmert |
| Stop eines Vortags-Laufs | Nach abgeschlossenem Speichern (`_recalculateStateAndSave`) Reinit `_init(dayChange: true)`, falls `dateOnly(entry.date) != today` | Entscheidung 3 |
| Standby-Härtung | Im 1-s-Tick `ref.read(todayProvider.notifier).refresh()` | Entscheidung 7 |
| Autosave-Schutz | Tick-Closure merkt `gen` + Eintrags-id; `_autoSave` speichert nur bei Übereinstimmung und `ref.mounted` | Kein Überschreiben des neuen Tags mit altem Eintrag |
| `HolidayBanner`/`holidayTodayProvider` | `holidayTodayProvider` watcht `todayProvider` statt `clockProvider`; `HolidayBanner` wird zum `ConsumerWidget` (kein eigener Timer/Observer mehr) | Entscheidung 5; behebt Cache-Nebenbefund (Banner nach Tabwechsel über Nacht stale) |
| Toter Code | `_loadWeekEntries`/`_weekEntries` entfernt, **eigener Commit**, vor dem VM-Umbau (Schritt 4.0) | Entscheidung 8; `getWeekEntriesForDate` bleibt in `overtime_utils.dart` (hat eigene Tests) |
| Premium-Gate | Nein | Dashboard nicht gated |
| Pro Arbeitszeit-Profil? | Kein `profileId`-Durchreichen nötig; Profilwechsel-Verhalten außerhalb (eigenes Issue). `_initGen`/`onDispose` machen ihn später zu „nur einem weiteren Trigger" | Entscheidung 9 |
| Backend-Änderung? | Nein; keine neue Rechenlogik, keine Rules (`web/firestore.rules`) | Nur Mobile |
| Neue Texte? | Nein, keine ARB-Änderung, kein `flutter gen-l10n` | Entscheidung 10 |
| Test-Aufbau | **Neue** Testdatei `dashboard_view_model_day_change_test.dart` mit eigenen In-Memory-Fakes (`WorkRepository`, `OvertimeRepository`), Settings über Fake/Stub; Bestandstest `dashboard_view_model_test.dart` + `.mocks.dart` bleiben unberührt | Echte Use Cases (mit Clock) laufen gegen Fake-Repo: Tests prüfen gespeicherte Einträge pro Tagesschlüssel statt Mock-Aufrufe; vor dem Fix scheitern sie an Assertions, nicht am Compiler; keine Mock-Regenerierung |

## Dateien
| Datei | neu/geändert | Zweck |
|---|---|---|
| `mobile/lib/domain/usecases/get_today_work_entry.dart` | geändert | Konstruktor-Clock, `getWorkEntry(_clock())` |
| `mobile/lib/domain/usecases/toggle_break.dart` | geändert | Konstruktor-Clock, `roundToMinute(_clock())` (2 Stellen) |
| `mobile/lib/domain/usecases/start_or_stop_timer.dart` | geändert | Konstruktor-Clock (nicht vom VM genutzt, aber konsistent, Entscheidung 6) |
| `mobile/lib/core/providers/providers.dart` (+ `providers.g.dart` generiert) | geändert | Clock in drei Use-Case-Providern; `build_runner` |
| `mobile/lib/core/providers/today_provider.dart` | neu | `TodayNotifier`: Tag, Mitternachts-Timer (min. 1 s, `DateTime(y,m,d+1)`), `WidgetsBindingObserver.resumed`, `refresh()`, Cleanup per `ref.onDispose` |
| `mobile/lib/presentation/state/dashboard_state.dart` | geändert | `initial({DateTime? now})` |
| `mobile/lib/presentation/view_models/dashboard_view_model.dart` | geändert | `_ensureCurrentDay`, `_initGen`, `_initRun`, `ref.mounted`, try/catch, `onDispose`, Soll am Eintragsdatum, `isExtraDay`, `clock()` statt `DateTime.now()`/`nowToMinute()` (Z. 68, 82, 120, 164, 199, 210, 254, 294, 339, 377, 397, 446, 520, 549), Basis `dayChange`, Autosave-Schutz, Reinit nach Stop, Tick-Refresh, toter Code raus |
| `mobile/lib/presentation/view_models/holiday_today_provider.dart` | geändert | watcht `todayProvider` |
| `mobile/lib/presentation/widgets/holiday_banner.dart` | geändert | `ConsumerWidget`, Timer/Observer/`dart:async` raus |
| `mobile/lib/presentation/screens/dashboard_screen.dart` | unverändert (Audit) | Z. 66 `DateTime.now()` nur laufende-Pause-Anzeige; bleibt, im Review melden |
| `mobile/CLAUDE.md` | geändert | Abschnitt „Tageswechsel (#379)" (Analog Web) + Verweis `today_provider.dart` |
| `mobile/test/support/fake_clock.dart` | neu | Veränderbare Uhr, an `FakeAsync.elapsed` koppelbar |
| `mobile/test/support/fake_repositories.dart` | neu | In-Memory-`WorkRepository` (Key `yyyy-MM-dd`, Speicherlog mit Reihenfolge, Fehlerschalter, optionale Completer pro `getWorkEntry`) und `OvertimeRepository` (emuliert Backend: `lastUpdate` = Uhr beim Speichern, Fehlerschalter) |
| `mobile/test/domain/usecases/get_today_work_entry_test.dart` | neu | |
| `mobile/test/domain/usecases/toggle_break_test.dart`, `start_or_stop_timer_test.dart` | geändert | Fälle mit fester Uhr ergänzen, Bestandsfälle unverändert |
| `mobile/test/core/providers/today_provider_test.dart` | neu | |
| `mobile/test/presentation/view_models/dashboard_view_model_day_change_test.dart` | neu | alle VM-Pflichtfälle |
| `mobile/test/presentation/view_models/holiday_today_provider_test.dart` | geändert | `TestWidgetsFlutterBinding.ensureInitialized()` (todayProvider registriert Observer), neuer Tabwechsel-Fall |
| `mobile/test/presentation/widgets/holiday_banner_test.dart` | geändert | Anpassung #279-Tests (siehe Schritt 5), neuer Remount-Fall |
| `mobile/test/presentation/screens/dashboard_screen_holiday_test.dart` | prüfen | Fake-VM + `clockProvider`-Override; sollte unverändert grün bleiben (todayProvider liest Clock) |

Keine Änderung: `lib/data/**`, `lib/l10n/**`, `time_precision.dart`, `clock_provider.dart`, `settings_view_model.dart`, Backend, `web/`.

## Test-Konventionen (für alle Schritte)
- Feste lokale Daten (`DateTime(2026, 10, 2, 23, 59, 30)`), nie `DateTime.now()`, keine Wochentags-/Zeitzonenannahme im Code. Bezugsdaten: Fr 2026-10-02, Sa 2026-10-03, So 2026-10-04, Mo 2026-10-05; Soll-Settings fest `workdays [1..5]`, 40 h (also 8 h Mo–Fr, 0 Sa/So) — Wochentage der festen Daten sind zonenunabhängig, daher kein `workdaysIncludingToday()`.
- Dauern nie hart kodiert („24 h"): erwartete Delays = `DateTime(y,m,d+1).difference(start)`; Elapsed = absolute Differenz.
- **Zeitsteuerung:** `fakeAsync` für VM-/Provider-Tests (ProviderContainer **innerhalb** des `fakeAsync`-Callbacks anlegen, damit `Timer`/`Timer.periodic` fake sind; `async.flushMicrotasks()`/`async.elapse()`). `DateTime.now()` bewegt Fake-Async nicht: `FakeClock.bind(async)` liefert `base + async.elapsed + offset`, `jumpTo(DateTime)` setzt den Offset (Uhrsprung ohne Timer-Ablauf, z. B. Standby/Resume). Widget-Tests (Banner) bleiben bei `testWidgets` + `tester.pump(Duration)`.
- **`fakeAsync`-Verfügbarkeit (Schritt 0):** `fake_async` ist nur transitiv (pubspec.lock, nicht in `pubspec.yaml`). Probe: reicht `import 'package:flutter_test/flutter_test.dart'` für `fakeAsync`? Wenn nein: `fake_async` mit der gelockten Version unter `dev_dependencies` ergänzen (sonst schlägt `depend_on_referenced_packages` an) und `flutter pub get`. Im Repo wird `fakeAsync` bisher nirgends genutzt.
- `WidgetsBinding.instance.addObserver` in reinen `test()`: `TestWidgetsFlutterBinding.ensureInitialized()` in `setUpAll`; Lifecycle per `binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed)`.
- Kein Timer-Leak: am Ende `container.dispose()` im `fakeAsync`, dann `expect(async.pendingTimersCount, 0)` bzw. `nonPeriodicTimerCount`/`periodicTimerCount` = 0.
- **Zeitzonen-Läufe** (aus `mobile/`): `TZ=Europe/Berlin flutter test` (CI, **ganze Suite**, `ci.yml` Z. 52–53) sowie lokal zusätzlich `TZ=UTC`, `TZ=America/Los_Angeles`, `TZ=Pacific/Auckland flutter test` (mindestens alle neuen/geänderten Testdateien; ganze Suite als Baseline in Schritt 0, vorher bestehende Rotfälle nur melden). Kein `Platform.environment['TZ']`/Zeitzonen-Setzen im Test. DST: Berlin 2026-03-29 (23 h) und 2026-10-25 (25 h) als feste Daten; in UTC/LA/Auckland fallen sie nicht auf DST-Tage → DST-Tests als **Invarianten** formulieren (Key = lokaler Folgetag; Delay = Differenz lokaler Mitternächte; Elapsed = absolute Differenz) und per Liste zusätzlich LA (2026-03-08, 2026-11-01) und Auckland (2026-04-05, 2026-09-27) abdecken. CI-Matrix bleibt unverändert (kein Eingriff in `ci.yml`).
- Rot-vor-Fix: Pro Schritt steht, welche Tests nach dem Schreiben **vor** der Implementierung rot sein müssen; der Entwickler führt sie aus und bestätigt Rot, bevor Impl beginnt. „Rot (Assertion)" = Test kompiliert gegen den alten Code und scheitert inhaltlich; „Rot (Compile)" = benötigt neue API.

## Schritte (TDD — jeder Schritt beginnt mit dem Test)

### Schritt 0: Baseline und Testinfrastruktur
- [x] Baseline: `TZ=Europe/Berlin`, `UTC`, `America/Los_Angeles`, `Pacific/Auckland flutter test` ganze Suite, Ergebnis notieren (grün erwartet; sonst nur melden).
- [x] `fakeAsync`-Probe (siehe oben), ggf. `fake_async` in `pubspec.yaml`.
- [x] `test/support/fake_clock.dart`, `test/support/fake_repositories.dart` anlegen (reine Hilfen, noch ohne Testfälle der Features). Mini-Selbsttest, dass `FakeClock` mit `fakeAsync.elapse` mitläuft und `jumpTo` den Offset setzt.
- [x] Audit: `grep DateTime.now` in den Dashboard-/Holiday-Tests; Bestandstests nur lesen, nicht anfassen.

### Schritt 1: Domain — Use Cases mit Konstruktor-Clock (`test/domain/usecases/`)
Tests zuerst:
- [x] `get_today_work_entry_test.dart` (neu): fester Clock 2026-10-02 23:59 → Repo bekommt `getWorkEntry(DateTime(2026,10,2,23,59))`-Datum (Tag Fr); Clock 2026-10-03 00:00:01 → Tag Sa; DST-Invarianten-Liste (Clock-Wert wird unverändert durchgereicht). **Rot (Compile)**, `clock:` existiert noch nicht.
- [x] `toggle_break_test.dart`: Pause starten/beenden mit fester Clock 2026-10-03 09:00:40 → `start`/`end` = 09:01 bzw. gerundet nach `roundToMinute`, nicht Echtzeit. **Rot (Compile)**; Bestandsfälle (ohne `clock:`) bleiben grün.
- [x] `start_or_stop_timer_test.dart`: Start/Stop mit fester Clock. **Rot (Compile)**.
- [x] Impl: Parameter `{DateTime Function() clock = DateTime.now}` in allen drei, `roundToMinute(_clock())`. Danach alle Usecase-Tests grün.

### Schritt 2: Data
- [x] Keine Änderung (Repository-Interface, Hybrid/Firebase/Local/ApiDataSource unberührt). Kurz im Review bestätigen: kein Aufrufer von `GetTodayWorkEntry(...)`/`ToggleBreak(...)`/`StartOrStopTimer(...)` außerhalb `providers.dart` und Tests (Grep zeigt: nur Provider und Use-Case-Tests).

### Schritt 3: Provider (`lib/core/providers/`)
Tests zuerst, `test/core/providers/today_provider_test.dart` (neu, `fakeAsync` + `FakeClock`, `TestWidgetsFlutterBinding.ensureInitialized()`); alle **Rot (Compile)**, bis die Datei existiert:
- [x] Initial = Tag der Uhr (2026-10-03 12:00 → `DateTime(2026,10,3)`).
- [x] 23:59:30 → `elapse(31 s)` → Folgetag; 23:59:59.999 + 1 ms → Folgetag; Delay-Minimum 1 s (Uhr exakt 00:00:00.000: kein Spin, genau ein Timer pending).
- [x] Folgetag-Timer wird neu geplant: zweiter Wechsel nach `DateTime(y,m,d+1).difference(now)` (Tag 2).
- [x] Jahreswechsel 2026-12-31 → 2027-01-01; Schaltjahr 2028-02-28 → 2028-02-29 → 2028-03-01.
- [x] DST: Berlin 2026-03-28 → 29 → 30 und 2026-10-24 → 25 → 26 (Delay = lokale Mitternachtsdifferenz, 23 h/25 h in Berlin) plus LA/Auckland-Datenliste per Schleife mit Invariante „Key = lokaler Folgetag"; Delay exakt: `elapse(delay − 1 ms)` → unverändert, `+1 ms` → neu.
- [x] `resumed` nach Uhrsprung (`jumpTo` Folgetag, kein Timer-Ablauf) → Key aktualisiert, Timer neu geplant (nicht doppelt: genau ein Timer pending); `paused`/`inactive` ändern nichts.
- [x] `refresh()` öffentlich: setzt Key; zweimal ohne Tageswechsel → Listener feuert nicht (Listener-Zähler = 1 pro Tageswechsel).
- [x] Cleanup: `container.dispose()` → pending Timer 0; danach `resumed`-Event löst keinen Zugriff auf `clockProvider`/keine Ausnahme aus (Clock-Zähler unverändert); Observer ist entfernt (kein Aufruf nach Dispose).
- [x] Impl: `today_provider.dart` (manueller `NotifierProvider<TodayNotifier, DateTime>`), `ref.watch(clockProvider)` in `build()`, `ref.onDispose` für Timer + `removeObserver`.
- [x] `providers.dart`: `ref.watch(clockProvider)` in `getTodayWorkEntryUseCase`/`toggleBreakUseCase`/`startOrStopTimerUseCase` → `dart run build_runner build --delete-conflicting-outputs`. Check: Bestandstests grün (`clockProvider`-Default = `DateTime.now`).

### Schritt 4: Presentation — `DashboardViewModel`
Alle Fälle in `dashboard_view_model_day_change_test.dart` (neu): Container mit `workRepositoryProvider`-, `overtimeRepositoryProvider`-, `settingsRepositoryProvider`- und `clockProvider`-Overrides (echte Use Cases mit Clock über `providers.dart`, kein Override der Use-Case-Provider). Der Entwickler schreibt je Teilschritt zuerst die Tests, bestätigt Rot, dann Impl. Der Bestandstest `dashboard_view_model_test.dart` bleibt nach **jedem** Teilschritt grün.

**4.0 Toter Code (eigener Commit, Refactor)**
- [x] Test (**Rot (Assertion)**): `_init` ruft `getWorkEntriesForMonth` auf dem Repo nicht mehr auf (Aufrufzähler im Fake = 0; vorher 1).
- [x] Impl: `_loadWeekEntries`, `_weekEntries` und ungenutzte Imports (`addCalendarDays`-Import prüfen) entfernen. Bestandstests grün.

**4.1 Soll/`isExtraDay` am Eintragsdatum + Uhr aus `clockProvider`**
Tests zuerst (alle **Rot (Assertion)** gegen alten Code, sofern nicht anders markiert):
- [x] **Fr→Sa Soll springt nicht:** laufender Fr-Eintrag (Start Fr 22:00), Uhr → Sa 01:00 (`jumpTo` + 1 Tick): `dailyOvertime` = elapsed − 8 h (= −5 h), nicht +3 h; `expectedEndTime`/`expectedEndTotalZero` gleich wie vor Mitternacht (bezogen auf Fr-Soll); `isExtraDay` false.
- [x] **So→Mo:** laufender So-Eintrag (Soll 0, `isExtraDay` true), Uhr → Mo: Soll bleibt 0, `isExtraDay` bleibt true (alter Code: Soll 8 h). Gegenprobe: Mo-Eintrag lädt Soll 8 h.
- [x] **Timer Fr 22:00 → Sa 01:00, Stop:** `startOrStopTimer()` um Sa 01:00 → Repo: Eintrag mit `date` Fr, `workEnd` Sa 01:00; `saveOvertime(base + (3 h − 8 h))` (alter Code: `base + 3 h`, also 8 h zu hoch); Gleitzeit korrekt.
- [x] Beendeter Eintrag + `updateBreak`/`deleteBreak` nach Mitternacht rechnet mit Soll des Eintragstags.
- [x] `setManualStartTime`/`setManualEndTime` bei leerem Eintrag: Datum = Eintragsdatum, nicht Uhr-„heute" (Eintrag ohne Guard-Umweg, Uhr gesprungen; Absicherung der Datumsquelle, mit Guard später = heute).
- [x] DST-Tage Laufender Timer über 2026-03-29 (Start 22:00 Vortag, bis 03:00) und 2026-10-25: Elapsed = absolute Differenz (aus `FakeClock` abgeleitet, nicht hart kodiert), Soll am Starttag, keine Fehlrechnung (Invarianten, in UTC/LA/Auckland ebenfalls grün).
- [x] Impl: `_now()`-Helper (`ref.read(clockProvider)()`), `_getEffectiveTargetDailyHours(forDate)`, Aufrufer anpassen, `isExtraDay` mitführen, `roundToMinute(_now())` statt `nowToMinute()`, `saveLastUpdateDate(_now())`, `setManual*` auf `entry.date`; `DashboardState.initial({now})`.

**4.2 Generationszähler, Fehlerbehandlung, Cleanup (ohne `todayProvider`-Bezug)**
Tests zuerst:
- [x] **Überholter `_init`/Rebuild:** `getWorkEntry` des Fake-Repos liefert pro Aufruf einen `Completer`; Rebuild per `container.invalidate(getTodayWorkEntryUseCaseProvider)` startet Lauf 2; Lauf 2 fertig (Eintrag B), danach Lauf 1 fertig (Eintrag A) → State bleibt B, Timer/Overtime von B; alter Lauf startet keinen Timer (Timer-Zähler). **Rot (Assertion)**.
- [x] **Login um 23:59 + Mitternacht:** Rebuild + Tageswechsel überlappen → genau ein gültiger Endzustand (Eintrag des neuen Tags). (Tageswechsel-Teil erst nach 4.3 grün; Test hier mit zwei Rebuilds, Variante mit Mitternacht in 4.3.)
- [x] **Offline-Fehler:** `getWorkEntry` wirft beim Start → `isLoading` ist `false`, kein unbehandelter Fehler aus dem Microtask (fakeAsync meldet ihn sonst als Testfehler), `_loadedOk` false. **Rot (Assertion)**: alter Code bleibt `isLoading` true.
- [x] **Dispose mitten im Lauf:** `container.dispose()` während `ensureOvertimeLoaded`/`saveWorkEntry` offen → keine Ausnahme (`ref.mounted`), danach `pendingTimersCount == 0`; Dispose bei laufendem Timer → Timer und Autosave-Timer sind weg (`periodicTimerCount == 0`). **Rot (Assertion)**: heute nirgends `onDispose`.
- [x] Impl: `_initGen`, `_initRun`, `_loadedOk`, `final gen = ++_initGen` und `if (gen != _initGen || !ref.mounted) return;` nach jedem `await`, try/catch um den Ladeblock (Fehlerpfad: nur wenn `gen` aktuell → `isLoading = false`), `_stopTimer()` zu Beginn, `ref.onDispose` (Timer, Autosave, `_initGen++`), `ref.mounted`-Check vor `_startTimerIfNeeded` in `_recalculateStateAndSave`/`_autoSave`; `_init` baut den State per Konstruktor neu. Test dazu (**Rot (Assertion)**): Wechsel abgeschlossener Vortag (Daily +1 h) → leerer Tag: `actualWorkDuration`, `grossWorkDuration`, `expectedEndTime`, `expectedEndTotalZero` = null, `elapsedTime` = 0.

**4.3 Tageswechsel: stiller Wechsel, laufender Timer, Basis, Standby**
Tests zuerst (**Rot (Assertion)** gegen alten Code):
- [x] **Fr→Sa stiller Wechsel, leerer Eintrag** (Uhr 23:59:30, Fake liefert nach Mitternacht Sa): nach `elapse(31 s)` ist `workEntry.date` = Sa 2026-10-03 (`id` = Tagesschlüssel), Soll 0 / `isExtraDay` true; **kein** `saveWorkEntry`, **kein** `saveOvertime`.
- [x] **So→Mo:** Eintrag Mo, Soll 8 h, `isExtraDay` false.
- [x] **Gestoppter, abgeschlossener Vortag** (08:00–17:00, 30 min Pause) → neuer Tag leer, Daily/Total für den neuen Tag, keine Speicherung.
- [x] **Laufender Timer unverändert** (Fr 22:00 gestartet): Uhr über Mitternacht → kein zweiter `getWorkEntry`-Aufruf (Zähler), `workEntry.date` = Fr, `workStart` unverändert, Timer läuft weiter (Tick aktualisiert `elapsedTime`), kein Save mit neuem Datum; Autosave (30 Ticks) schreibt Eintrag mit Fr-`date`/-`id` in den Fr-Schlüssel.
- [x] **Resume über Mitternacht ohne Timer-Ablauf:** `jumpTo` Sa 09:00, `handleAppLifecycleStateChanged(resumed)` → Wechsel erfolgt (async flush).
- [x] **Standby-Härtung im Tick:** laufender Timer, Uhr springt auf Sa (Midnight-Timer ohne Ablauf), nach `elapse(1 s)` steht `todayProvider` auf Sa (Holiday/Banner-Quelle zieht nach), Eintrag bleibt Fr. Gegenprobe: Der Tick ohne Tageswechsel löst keinen `_init` aus.
- [x] **Midnight-Timer und Cleanup:** nach `container.dispose()` feuert nichts mehr (`pendingTimersCount == 0`, keine Repo-Zugriffe nach Dispose, Aufrufzähler unverändert) — kein Leak.
- [x] **Basis-Überstunden:** `stored` = 120 min, `lastUpdate` = **neuer** Tag, neuer Eintrag mit `workStart` → `initialOvertime` = 120 min (nicht 120 min − Daily), Total = Basis + Daily. Ausnahme `dailyAlreadyStored` (neuer Eintrag mit Start+Ende, `lastUpdate >= workEnd`) → Heuristik greift (Base = stored − Daily). Gegenprobe normaler `_init` (ohne `dayChange`) unverändert.
- [x] **Login um 23:59 + Mitternacht** (aus 4.2 vervollständigt): genau ein gültiger Endzustand.
- [x] **DST-Wechsel** 2026-03-28→29 und 2026-10-24→25→26 (Berlin) mit stillem Wechsel; Invariante „Eintragsdatum = lokaler Folgetag" in UTC/LA/Auckland ebenfalls.
- [x] **Offline-Reinit:** `getWorkEntry` wirft beim Tageswechsel → Zustand bleibt Vortag (leer/abgeschlossen), kein hängendes `isLoading`, kein Fehler nach außen; Retry beim nächsten Trigger.
- [x] Impl: `ref.listen(todayProvider, …)` in `build()` → `_onDayChange` (läuft Timer → nichts; sonst `_init(dayChange: true)`), `_init`-Basis-Zweig, Tick-`refresh()`, Autosave-Schutz (Generation + id).

**4.4 Aktionen-Guard `_ensureCurrentDay()` (Regression Kern des Bugs)**
Tests zuerst, Uhr springt **ohne** Timer-/Resume-Ereignis (`jumpTo`) (**Rot (Assertion)** gegen alten Code):
- [x] **„Start" nach Mitternacht:** leerer Fr-Eintrag geladen, Uhr Sa 09:00, `startOrStopTimer()` → Repo: Sa-Schlüssel mit `workStart` Sa 09:00; Fr-Schlüssel nicht beschrieben (Speicherlog enthält keinen Eintrag mit Fr-`date`).
- [x] **„Neue Session" überschreibt keinen abgeschlossenen Vortag:** Fr 08:00–17:00 abgeschlossen geladen, Uhr Sa 09:00; `startNewSession()` und `startNewSessionKeepBreaks()` (Schleife): Fr-Eintrag im Repo unverändert (Gleichheit mit Original), Sa-Eintrag `workStart` 09:00, `workEnd` null, Pausen leer.
- [x] **Schleife über alle Schreibaktionen** (`startOrStopBreak`, `setManualStartTime`, `setManualEndTime`, `clearEndTime`, `updateBreak`, `deleteBreak`, `startOrStopTimer`, `startNewSession*`) auf gestopptem Vortag: schreiben ausschließlich unter dem heutigen Schlüssel; Vortags-Schlüssel unverändert.
- [x] **Laufender Vortags-Eintrag:** Pause starten/beenden bleibt am Starttag; Stop nach Mitternacht speichert auf Starttag (`calculateAndApplyBreaks` bei Brutto > 24 h ohne Fehler), `saveOvertime` mit Soll Starttag.
- [x] **Reinit nach Stop eines Vortags-Laufs:** Reihenfolge im Speicherlog: erst Fr-Eintrag (mit `workEnd`), danach Leseaufruf Sa; kein Save auf den neuen Tag mit altem Eintrag; State = leerer Sa-Eintrag, Total = gespeicherter Wert (Basis aus `stored`, `lastUpdate` = Sa-Zeitpunkt des Stops).
- [x] **Doppeltipp/überholter `_init`:** zwei parallele `startOrStopTimer()` während ein Reinit offen ist (Completer) → genau **ein** `getWorkEntry`-Aufruf für den Wechsel (zweiter wartet auf `_initRun`), keine Schreibaktion landet auf dem Vortag; zwei parallele Wechsel-Trigger (Resume + Midnight) → ein Endzustand.
- [x] **Offline-Guard:** `getWorkEntry` wirft → Aktion bricht ab (kein einziger `saveWorkEntry`); nach Wiederherstellung funktioniert die nächste Aktion (Retry über `_loadedOk`); Fehler beim ersten Laden (Platzhalter-Eintrag) → Aktion schreibt nie den Platzhalter.
- [x] **Resume nach Hintergrund über Mitternacht + Aktion**: `jumpTo` Sa 09:00 ohne Ereignis, direkt `startOrStopTimer` → Sa (Guard ruft selbst `refresh()`).
- [x] Impl: `_ensureCurrentDay()` (Rückgabe `bool`): läuft Eintrag (`workStart != null && workEnd == null`) → `true`; sonst `refresh()`, laufenden `_initRun` abwarten, bei `!_loadedOk` oder `dateOnly(entry.date) != today` `await _init(dayChange: true)`, danach `state.workEntry` neu lesen; Fehlschlag/Überholung → `false` → Aktion bricht ab. Aufruf am Anfang aller Schreibaktionen; Reinit nach Stop eines Vortags-Laufs am Ende von `startOrStopTimer`.

### Schritt 5: Presentation — `HolidayBanner`/`holidayTodayProvider`
Tests zuerst:
- [x] **Bestehende #279-Tests laufen zuerst gegen den alten Code grün** (Baseline), dann nach der Umstellung grün. Erwartete Anpassungen: `holiday_today_provider_test.dart` → `TestWidgetsFlutterBinding.ensureInitialized()` (Observer im `todayProvider`); ansonsten bleiben Clock-Overrides und Assertions. `holiday_banner_test.dart`: die Tests „Mitternacht schaltet um und plant neu", „Resume aktualisiert", „Dispose räumt Timer auf" laufen jetzt über `todayProvider`-Timer/-Observer (gleiche Erwartungen); Dispose-Test erwartet weiterhin keinen Pending-Timer nach `pumpWidget(SizedBox())`.
- [x] **Neu, Banner nach Tabwechsel über Nacht:** `UncontrolledProviderScope` (Container bleibt am Leben wie im echten App-Root), Banner gemountet am 2026-10-02 (kein Feiertag) → Banner entfernen (Tabwechsel) → `pump(Duration)` über Mitternacht (Uhr gekoppelt) → Banner neu mounten → zeigt Feiertag 2026-10-03 ohne Lifecycle-Ereignis. **Rot (Assertion)** gegen alten Code (gecachter Wert, Timer tot).
- [x] **Neu auf Provider-Ebene:** `holidayTodayProvider` gecacht, Mitternacht per `fakeAsync` verstreichen lassen, erneut lesen → neuer Tag (Rot gegen alten Code).
- [x] Impl: `holiday_today_provider.dart` watcht `todayProvider` (`today.year`/`today` als Map-Key); `HolidayBanner` als `ConsumerWidget`, `dart:async`/Observer/Timer-Code und `invalidate` entfernen.
- [x] `dashboard_screen_holiday_test.dart` laufen lassen (Clock-Override, Fake-VM) → unverändert grün.

### Schritt 6: Texte
- [x] Entfällt: keine ARB-Keys, kein `flutter gen-l10n`.

### Schritt 7: Doku + Gesamtlauf
- [x] `mobile/CLAUDE.md`: Abschnitt „Tageswechsel (#379)" (Variante B, `todayProvider`, stiller Wechsel, `_ensureCurrentDay`, `_initGen`, Basis aus Stored, Soll am Eintragsdatum, Test-Konventionen/`FakeClock`), Eintrag `today_provider.dart` unter Dependency Injection.
- [x] `dart format --set-exit-if-changed lib test && flutter analyze --no-fatal-infos && dart run custom_lint && flutter test` (Berlin, wie CI).
- [x] `TZ=UTC`, `TZ=America/Los_Angeles`, `TZ=Pacific/Auckland flutter test` mindestens für die neuen/geänderten Testdateien (Schritt 0 Baseline vergleichen).
- [ ] Manuelle Verifikation (nicht automatisierbar): Gerät/Emulator, Systemuhr über Mitternacht stellen (gestoppter Eintrag, laufender Timer, App im Hintergrund/Standby); Banner an einem Feiertag nach Tabwechsel.
- [ ] Commit-Vorschlag für die Hauptsession (der Planer committet nicht): (1) Use-Case-Clock, (2) `todayProvider` + `providers.dart`, (3) toter Code (4.0), (4) VM-Umbau 4.1–4.4 (ggf. ein Commit je Teilschritt), (5) Banner-Umstellung, (6) Doku.

## Validierung
- `dart format --set-exit-if-changed lib test`, `flutter analyze --no-fatal-infos`, `dart run custom_lint`, `flutter test` (alle aus `mobile/`), plus TZ-Läufe oben.
- Rot-vor-Fix je Teilschritt dokumentieren (Tabelle im PR/`thoughts`-Verlauf): Schritt 1 und 3 Compile-Rot; 4.0–4.4, 5 Assertion-Rot.

## Risiken / Hinweise
- Echte `Timer.periodic` im VM: nur in `fakeAsync`-Tests, sonst Pending-Timer; `ref.onDispose`-Cleanup ist Voraussetzung dafür.
- `copyWith` ignoriert `null`: jede State-Rücksetzung beim Wechsel muss über den Konstruktor laufen (4.2).
- Laufender Vortags-Eintrag + App-Neustart: `GetTodayWorkEntry` lädt den heutigen Tag, ein über Mitternacht laufender Vortag bleibt verwaist (bestehendes Verhalten, außerhalb von #379; im PR vermerken).
- Doppeltipp: Der Guard serialisiert nur den Reinit; zwei schnelle Taps toggeln wie bisher Start/Stop (nicht verschlimmert).
- Nebenbefunde (nur melden, nicht ändern): `recalculateOvertimeFromSettings` rechnet beendete Einträge mit „jetzt"; `ToggleBreak` speichert doppelt; Basis-Heuristik fragil; `dashboard_screen.dart` Z. 66 nutzt `DateTime.now()` für die laufende Pause (nur Anzeige).

## Offene Fragen an die Hauptsession
- Keine inhaltlichen. Optional: TZ-Matrix (UTC/LA/Auckland) nur lokal/manuell (Plan-Default, CI bleibt Berlin) oder zusätzlich als CI-Matrix.
