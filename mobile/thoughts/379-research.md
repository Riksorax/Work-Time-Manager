# Mobile-Research: #379 — Mobile-Dashboard: Tageswechsel (Mitternacht) wird nicht behandelt
Datum: 2026-10-04
Typ: BUG-Analyse (reine Code-Analyse, nicht auf Gerät reproduziert)
Referenz: Web #372/#378 (`web/thoughts/372-research.md`, `372-plan.md`, `web/src/app/core/services/today.ts`, `features/dashboard/dashboard.service.ts`)

## Aufgabe

Das Dashboard (`DashboardViewModel`) lädt den heutigen Eintrag einmalig und kennt danach keinen Tageswechsel. Gleichzeitig
rechnen Soll, Timer und Überstunden mit einem frischen `DateTime.now()`. Folgen: Soll springt um Mitternacht, „Start"
nach Mitternacht schreibt in den Vortag, Überstunden werden verfälscht.

Akzeptanzkriterien (Issue + Web-Entscheidungen):
1. Reproduzierbar (Uhr über Mitternacht, App im Hintergrund über Mitternacht), Ursache im ViewModel bestätigt (unten).
2. Soll/`isExtraDay`/Überstunden/`expectedEndTime` hängen am **Eintragsdatum**, nicht an „jetzt".
3. Alle Schreibaktionen stellen sicher, dass das Eintragsdatum „heute" ist, sonst erst auf den neuen Tag umschalten.
4. Laufender Timer läuft über Mitternacht weiter (kein Splitten, Eintrag bleibt am Starttag).
5. Mitternachts-Timer + Resume über `clockProvider` (#279).
6. Generationszähler gegen überholte Ladeläufe.
7. Tests mit Fake-Uhr, festen Daten, grün unter `TZ=Europe/Berlin` (CI) und TZ-unabhängig.

Nicht Teil der Aufgabe: Splitten bei 00:00, Profilwechsel-Verhalten (eigenes Thema wie Web #380), Reports/Kalender/Insights („heute"
dort), UI-Hinweis beim Wechsel, neue Texte (keine ARB-Änderung nötig).

## Betroffene Dateien

| Datei | Warum |
|---|---|
| `mobile/lib/presentation/view_models/dashboard_view_model.dart` | Hauptort des Bugs; Reinit, Soll-Kopplung, Aktionen-Guard, Generationszähler, Timer-Cleanup |
| `mobile/lib/presentation/state/dashboard_state.dart` | `initial()` nutzt `DateTime.now()` (id = ISO-Timestamp, nicht `yyyy-MM-dd`); ggf. Feld für „Tag" nicht nötig (Eintragsdatum reicht) |
| `mobile/lib/domain/usecases/get_today_work_entry.dart` | `DateTime.now()` fest verdrahtet, lädt immer „jetzt" |
| `mobile/lib/domain/usecases/toggle_break.dart`, `start_or_stop_timer.dart` | `nowToMinute()` fest verdrahtet (Toggle-Break ist vom VM aktiv genutzt; `StartOrStopTimer` wird vom VM nicht benutzt) |
| `mobile/lib/core/utils/time_precision.dart` | `nowToMinute()` = `roundToMinute(DateTime.now())`, nicht injizierbar |
| `mobile/lib/core/providers/clock_provider.dart` (+ `.g.dart`) | Vorhandene testbare Uhr (`DateTime Function()`), Default `DateTime.now` |
| `mobile/lib/core/providers/providers.dart` (+ `providers.g.dart`) | `getTodayWorkEntryUseCase`/`toggleBreakUseCase` verdrahten; ggf. Clock injizieren → `build_runner` |
| `mobile/lib/core/providers/today_provider.dart` (NEU, Vorschlag) | Zentrale „heute"-Quelle (Tages-Key, Mitternachts-Timer, Resume) — Pendant zu Web `TodayService` |
| `mobile/lib/presentation/view_models/holiday_today_provider.dart`, `widgets/holiday_banner.dart` | Bestehendes Mitternacht+Resume-Muster; Nebenbefund (s. u.), optional auf neuen Provider umstellen |
| `mobile/lib/presentation/screens/dashboard_screen.dart` | Z. 66 `DateTime.now()` für laufende Pause (reine Anzeige, nur Audit); UI sonst unverändert |
| `mobile/lib/presentation/view_models/settings_view_model.dart` (Z. 241/286/300) | ruft `updateOvertimeFromSettings`/`recalculateOvertimeFromSettings` am Dashboard-VM (müssen mit Eintragsdatum-Soll arbeiten) |
| `mobile/test/presentation/view_models/dashboard_view_model_test.dart` (+ `.mocks.dart`) | Bestandstests (nutzen `DateTime.now()`), Erweiterung um neue Gruppe |
| `mobile/CLAUDE.md` | Abschnitt „Tageswechsel (#379)" analog Web ergänzen |

Keine Änderung nötig: `lib/l10n/*`, Backend, `web/firestore.rules` (keine neuen Pfade/Felder), Premium (Dashboard nicht gated).

## Ist-Zustand / Ursache

### Wie „heute" geladen wird
- `build()` (Z. 25): `ref.watch` auf `getTodayWorkEntryUseCaseProvider`, `getOvertimeUseCaseProvider`, `settingsRepositoryProvider`, dann `Future.microtask(_init)`.
  Jede Änderung von Auth/Profil/Settings-Repo triggert damit einen **Rebuild + neues `_init`** (ohne Abbruchlogik).
- `_init` (Z. 36): `GetTodayWorkEntry.call()` → `HybridWorkRepositoryImpl.getWorkEntry(DateTime.now())`; danach
  `ensureOvertimeLoaded()`/`ensureLastUpdateLoaded()`, `_loadWeekEntries`, Soll via `_getEffectiveTargetDailyHours()`
  (`DateTime.now()`), `isExtraDay`, `initialDailyOvertime`, Basis-Überstunden (Heuristik `lastUpdateDate` gleicher Tag), dann `state = ...`, `_recalculateStateAndSave(save:false)`, `_startTimerIfNeeded()`.
- `_init` hat **kein** try/catch um die Repo-Aufrufe (nur `_loadWeekEntries` fängt): wirft `getWorkEntry` (eingeloggt/offline, API-Fehler), bleibt `isLoading` true bzw. der Fehler geht unbehandelt aus dem Microtask. Relevant für Reinit bei Tageswechsel (siehe Risiken).

### Was vom „heute" abhängt (alles direkt an `DateTime.now()`, nirgends reaktiv)

| Stelle (Zeile) | Datumsbezug | Verhalten nach Mitternacht |
|---|---|---|
| `state.workEntry` (id/date) | Tag des `_init` | bleibt Vortag |
| `_getEffectiveTargetDailyHours()` (153–168) | `getEffectiveDailyTarget(date: DateTime.now(), …)` **bei jedem Aufruf frisch** | Soll springt auf Wochentag des neuen Tags, Eintrag bleibt Vortag |
| `_recalculateOvertime()` (Tick jede Sekunde), `_calculateExpectedEndTime`, `_recalculateStateAndSave` (433) | über `_getEffectiveTargetDailyHours` | Daily/Total/`expectedEndTime`/`expectedEndTotalZero` springen; beim Stop wird der verfälschte Wert **gespeichert** (`saveOvertime`) |
| `isExtraDay` | nur in `_init` gesetzt (51, 110); **wird nirgends in der UI gelesen** (nur State/Log; `reports_page` rechnet eigen) | bleibt stale; rein informativ, trotzdem konsistent halten |
| `_calculateElapsedTime`/Tick/`_calculateTotalBreakDuration(now)` | `DateTime.now()`, absolute Differenz | läuft weiter (>24 h möglich), korrekt für Variante B |
| `_autoSave` (alle 30 Ticks) | speichert `state.workEntry` unverändert | schreibt weiter in den Starttag (ok für Variante B), aber nach Reinit/Überholung ohne Schlüssel-Check riskant |
| `startOrStopTimer`/`startNewSession*` (339/377/396) | `nowToMinute()` = jetzt, aber `date`/`id` aus altem `state.workEntry` | **Start nach Mitternacht schreibt `workStart=jetzt` in den Vortagseintrag** |
| `startOrStopBreak` → `ToggleBreak` | `nowToMinute()` + `repository.saveWorkEntry` (speichert **selbst**, danach nochmal im VM) | Pause am Vortagseintrag mit Zeit des neuen Tags |
| `setManualStartTime/EndTime` (519/547) | Datum aus `workStart ?? DateTime.now()` bzw. `workEnd ?? workStart ?? DateTime.now()` | bei leerem Eintrag (workStart null) landet die Zeit auf **heute** im Eintrag des **Vortags**; sonst konsistent zum Eintrag |
| `_recalculateStateAndSave` (446) | `saveLastUpdateDate(DateTime.now())` | Datum „jetzt" statt Eintragsdatum → Basis-Heuristik, siehe unten |
| `_loadWeekEntries` (117) | `DateTime.now()` | Ergebnis `_weekEntries` wird **nirgends gelesen** (toter Zustand seit #217), kostet aber einen zusätzlichen Repo-Call pro `_init` |
| `DashboardState.initial()` | `DateTime.now()` (id = ISO-Timestamp, nicht `yyyy-MM-dd`) | nur Übergangszustand vor `_init`; Aktionen in diesem Fenster würden eine fremde id schreiben |
| `HolidayBanner`/`holidayTodayProvider` | `clockProvider`, Timer + Resume | **einziges** Stück mit Tageswechsel (nur solange der Banner gemountet ist) |

Gibt es ein „Wochen-Ist" im Mobile-Dashboard? **Nein** (Web-Äquivalent existiert nicht): `getWeekEntriesForDate` wird nur noch in `_loadWeekEntries` aufgerufen, dessen Ergebnis ungenutzt bleibt.

### Fehlerlage mit Beispielen
Annahmen: Mo–Fr, 40 h/Woche → Soll 8 h an Mo–Fr, 0 an Sa/So. Berlin. „Heute" ist So 2026-10-04.

1. **Fr→Sa, gestoppt/leer (häufigster Fall: App offen über Nacht).** Dashboard lädt Fr 2026-10-02 17:00 den Eintrag (`id '2026-10-02'`). Sa 2026-10-03 09:00 „Start": `state.workEntry.copyWith(workStart: Sa 09:00)` → `date`/`id` = Freitag. `LocalWorkRepositoryImpl.saveWorkEntry` bildet den Tagesschlüssel aus `entry.date` (Z. 187/188), `ApiClient.saveWorkEntry` sendet `DateTime.utc(m.date.y, m.date.m, m.date.d)` → beides Freitag. Ergebnis: Freitagseintrag hat `workStart` = Samstag 09:00, Samstag bleibt leer. Zusätzlich Soll = 0 (Sa), obwohl der Eintrag Freitag ist.
   - Variante mit abgeschlossenem Freitag (Start 08:00/Ende 17:00): „Start"-Button öffnet den Restart-Dialog; `startNewSession()` überschreibt `workStart`/`workEnd`/`breaks` des **Freitags** → **Datenverlust am Vortag**.
2. **So→Mo.** So 21:00 geladen (Eintrag So, Soll 0, `isExtraDay`=true). Mo 2026-10-05 07:30 „Start" → Sonntagseintrag erhält `workStart` Montag 07:30; Soll jetzt 8 h (Mo) für einen So-Eintrag.
3. **Laufender Timer über Mitternacht (Fr 22:00 → Sa 01:00).** Um 00:00 springt Soll 8 h→0: Daily von −5:00 (3 h − 8 h) auf +3:00, `expectedEndTime`/`expectedEndTotalZero` springen. Stop um 01:00 → `calculateAndApplyBreaks` + `saveOvertime(base + Daily)` mit Soll 0 → gespeicherte Gleitzeit **8 h zu hoch**, dauerhaft.
4. **Überstunden-Basis.** `saveLastUpdateDate(DateTime.now())` bzw. das Backend (`ApiDataSource.saveLastOvertimeUpdate` ist No-Op, Backend setzt `lastUpdated` = Serverzeit) markiert „heute gespeichert", auch wenn der Vortag gespeichert wurde. Nach Stop von Fr-Eintrag am Sa 01:00 und folgendem Reinit/Neustart ist `lastUpdate` = Sa; ist der neue Sa-Eintrag dann nicht leer (`workStart` gesetzt), zieht `_init` (Z. 81–91) `initialDailyOvertime` vom gespeicherten Wert ab → falsche Basis. Beim stillen Reinit auf einen **leeren** neuen Tag ist `initialDaily` = 0, dort tritt es nicht auf; die Heuristik ist aber ohnehin fragil (siehe Nebenbefunde). Web löst das mit „Basis = Gespeichertes bei `dayChange`, Ausnahme: neuer Eintrag schon abgeschlossen und danach gespeichert".
5. **Resume aus dem Hintergrund über Mitternacht.** Nur `HolidayBanner` reagiert (`resumed` → invalidate). Das Dashboard zeigt weiter den Vortag; bei laufendem Timer tickt `Timer.periodic` nach dem Resume mit neuem „jetzt"/neuem Soll weiter (Fall 3).
6. **Überholte Ladeläufe.** `build()` startet bei jedem Rebuild (Login/Logout/Profil/Settings-Repo) ein neues `_init`; mehrere Läufe können überlappen, der zuletzt fertige gewinnt. Zusätzlich liest `_init` nach `await` weiter per `ref.read` (Riverpod 3: `ref.mounted` prüfen, sonst Fehler nach Dispose).

Ursache bestätigt (Code-Ebene): keine Datumsprüfung in Aktionen, `DateTime.now()` im Soll, kein Reinit-Trigger. Skizze eines fehlschlagenden Tests: Uhr 2026-10-02 12:00 → VM laden (Eintrag Fr leer) → Uhr 2026-10-03 09:00 → `startOrStopTimer()` → erwartet `saveWorkEntry` mit `date` = 2026-10-03, ist aber 2026-10-02.

## Datenfluss

Heute: `DashboardScreen` (ConsumerWidget, liest `dashboardViewModelProvider`) → `DashboardViewModel` (Notifier) → `GetTodayWorkEntry` / `SaveWorkEntry` / `ToggleBreak` → `HybridWorkRepositoryImpl` → (eingeloggt) `WorkRepositoryImpl` → `ApiDataSource`/`ApiClient` → .NET-Backend (Standard- und zusätzliche Profile gehen hier über `profileId`) | (ausgeloggt) `LocalWorkRepositoryImpl` → SharedPreferences (`monthKey`/`days[dayKey]`, Schlüssel aus `entry.date`). Überstunden: VM → `overtimeRepositoryProvider` (`HybridOvertimeRepositoryImpl` → `FirebaseOvertimeRepositoryImpl` mit Cache bzw. `LocalOvertimeRepositoryImpl`).

Ziel: `todayProvider` (Tages-Key, Mitternachts-Timer, Resume) → VM hört auf Wechsel → `_onDayChange` → `_init(dayChange: true)`; Aktionen → `_ensureCurrentDay()` → Repo. Zeit überall aus `clockProvider`.

Zu klärende Punkte zum Aufbau:
- **Dashboard als Tab, wird das VM weiterverwendet?** Ja. `HomeScreen` baut nur den gewählten Tab (`_widgetOptions.elementAt`), das `DashboardScreen`-Widget wird beim Tabwechsel entsorgt, der `NotifierProvider` ist **nicht** autoDispose und lebt weiter (Timer/Autosave laufen im Hintergrund-Tab weiter). Konsequenz: Tageswechsel-Logik muss im VM bzw. einem root-Provider leben, **nicht** in einem Widget (wie `HolidayBanner`, das beim Tabwechsel mit Timer/Observer verschwindet).
- Einzige Invalidierungen des VM: nach Sync (`settings_page.dart` Z. 497), Logout (Z. 723), Login (`login_page.dart` Z. 191) sowie implizit über `ref.watch` im `build()`.
- `main.dart`: `_MyAppState` ist bereits `WidgetsBindingObserver` (nur `paused` für App-Lock, #223); `HolidayBanner` ist der einzige `resumed`-Handler. Ein eigener Observer im neuen Provider ist unkritisch.

## Hybrid-Repo / Offline

- Hybrid-Pattern bleibt unangetastet: nur über `GetTodayWorkEntry`/`SaveWorkEntry`/`ToggleBreak`. Neu nötig: das Datum bzw. die Uhr in `GetTodayWorkEntry` (und `ToggleBreak`/`StartOrStopTimer`) injizierbar machen. Empfehlung: Konstruktor-Parameter `DateTime Function() now` (Default `DateTime.now`), im Provider mit `ref.watch(clockProvider)` befüllt → `call()`-Signatur und bestehende Mocks (`when(mockGetTodayWorkEntry())`) bleiben unverändert. Alternative `call(DateTime date)` ändert Mocks/Bestandstests.
- Offline (ausgeloggt/lokal): synchron und tagesschlüsselbasiert, Tageswechsel unkritisch, aber derselbe Start-auf-Vortag-Fehler.
- Eingeloggt + offline: `getWorkEntry`/`ensure…Loaded` können werfen; `saveWorkEntry`-Fehler fängt `_recalculateStateAndSave` bereits (#336), `_autoSave` ebenfalls. Der Reinit-Pfad braucht ein eigenes try/catch (Zustand bleibt beim Vortag, Retry beim nächsten Trigger/bei der nächsten Aktion); ohne Fang bleibt `isLoading` hängen.
- `FirebaseOvertimeRepositoryImpl` cached Saldo und `lastUpdate` pro Repo-Instanz; `ensure…Loaded` lädt neu. Beim Reinit zählt der **geladene** Wert (nicht der Cache), gleiches Verhalten wie `_init` heute.

## Plattformübergreifend

- **Nur Mobile.** Web ist mit #372/#378 erledigt, Backend braucht nichts (keine neuen Felder/Endpunkte, keine Split-Semantik). Rechenlogik: es wird **keine** neue Pausen-/Überstundenlogik eingeführt, nur das bestehende Backend-konforme Soll (Eintragsdatum) konsistent angewandt. Kein Eintrag in `web/firestore.rules`. → `cross-platform-coordinator` nicht nötig.
- Prüfen/Abgleich mit Web: gleiche Entscheidungen (Variante B, stiller Wechsel, Guard, Generationszähler, Basis-Ausnahme `dailyAlreadyStored = workStart&&workEnd && lastUpdate >= workEnd`). Mobile-Besonderheit: kein 1-s-Tick-Abgleich nötig, wenn Resume-Handler + Mitternachts-Timer vorhanden sind; den Tick-Abgleich (`today.refresh()` bei laufendem Timer) kann Mobile trotzdem billig mitnehmen (Standby-Härtung, kostet nichts).

## „Heute"-Quellen, Lifecycle, Notifications

- `clockProvider` (`@riverpod DateTime Function() clock(Ref)` = `DateTime.now`): in Produktion benutzt von `holidayTodayProvider`, `HolidayBanner`, `appLockServiceProvider`. Das VM nutzt ihn **nicht** (12× `DateTime.now()` + 3× `nowToMinute()` direkt, Liste oben); in `DateTime.now()`-Aufrufen im VM-Pfad also: Z. 68, 82, 120, 164, 199, 210, 254, 294, 446, 520, 549. Alle über `ref.read(clockProvider)()` ersetzen (nicht `ref.watch` in Callbacks).
- `HolidayBanner`-Muster: Timer bis `DateTime(y, m, d + 1)` (min. 1 s, DST-sicher), `resumed` → `ref.invalidate` + neu planen, `mounted`-Check. Übertragbar, aber als eigener Provider mit `ref.onDispose` statt Widget-State.
- **Nebenbefund #279 (Banner):** `holidayTodayProvider` ist ein nicht-autoDispose `Provider`, der Wert wird beim ersten Read gecacht; `HolidayBanner.initState` invalidiert **nicht**. Wechselt der Nutzer abends auf Reports/Einstellungen und kommt am nächsten Tag ohne Lifecycle-Wechsel zurück, kann der Banner den Feiertag des Vortags zeigen, bis Mitternachts-Timer/Resume feuern. Dieser Mangel verschwindet, wenn `holidayTodayProvider` künftig den neuen `todayProvider` beobachtet (Entscheidung Frage 5).
- App-Lifecycle: Nach Resume über Mitternacht feuern Dart-Timer in der Regel wieder; ein gestoppter/leerer Eintrag wird ohne Resume-/Mitternachts-Hook nicht aktualisiert. `WidgetsBindingObserver` im Provider (nicht im Widget) registrieren und in `ref.onDispose` entfernen. Auf Web (`kIsWeb`) liefert Flutter `resumed` beim Sichtbarwerden des Tabs.
- Notifications: `NotificationService.scheduleDailyReminder` plant **wöchentlich wiederkehrende** Erinnerungen (`dayOfWeekAndTime`, `tz.TZDateTime.now` nur zur Berechnung des nächsten Termins), kennt weder den Eintrag noch „heute" → **nicht betroffen**. `showOvertimeWarning` wird nach dem Stop mit dem berechneten Total ausgelöst → profitiert indirekt von der Soll-Kopplung. Es gibt keine Home-Screen-Widgets/Background-Worker (`home_widget`/`workmanager` nicht im Projekt).

## Profilwechsel (nur Befund, eigenes Thema)

Anders als Web reagiert Mobile auf den Profilwechsel: `activeWorkProfileIdProvider` → `workRepositoryProvider`/`overtimeRepositoryProvider`/`settingsRepositoryProvider` → `build()` des VM (`ref.watch`) → Rebuild + `_init` für das neue Profil. Offene Punkte dort: der Rebuild setzt `state` zwar auf `initial()`, räumt aber `_timer`/`_autoSaveTimer` nicht per `ref.onDispose` auf; bis zum Ende des neuen `_init` kann der alte Timer weiter ticken (Autosave ist durch `workStart == null` im Initialzustand blockiert). Zusätzlich keine Absicherung gegen überlappende `_init`-Läufe. Der Generationszähler + `ref.onDispose`-Cleanup, die dieses Issue ohnehin braucht, entschärfen beides; ein separates Issue (wie Web #380) nur für verbleibende Profilthemen. Nicht im Scope dieses Issues.

## Nebenbefunde (nicht im Scope, nur melden)

- `recalculateOvertimeFromSettings()` (Z. 181) rechnet bei bereits **beendetem** Eintrag mit `now` statt `workEnd` (`_calculateElapsedTime`) → Settings-Änderung nach Feierabend verfälscht Daily/Total im State. Bei der Soll-Kopplung mitbetrachten (gleiche Funktion).
- Basis-Heuristik in `_init` (Z. 80–95) subtrahiert bei laufendem Eintrag und `lastUpdate == heute` den laufenden Fortschritt (nur korrekt, wenn der gespeicherte Wert den heutigen Tag enthält) — fragil, gilt auch ohne Mitternacht (zweite Session am selben Tag). Nicht anfassen, nur nicht verschlimmern.
- `ToggleBreak` speichert den Eintrag selbst, das VM speichert danach nochmals (`_recalculateStateAndSave`) → doppelter Save pro Pausen-Toggle.
- `_weekEntries`/`_loadWeekEntries` tot (siehe oben): entfernen wäre eine kleine Entlastung des Reinit (weniger Calls offline), aber eigener Aufräum-Schritt (Frage 8).
- Reports/Kalender/Insights/WeeklyReflection nutzen `DateTime.now()` für „heute" und bleiben wie in Web außerhalb dieses Issues.

## Empfohlene Lösungsrichtung (für Phase 2)

1. **`todayProvider`** (`lib/core/providers/today_provider.dart`, manuelles `NotifierProvider`, kein Codegen): State = lokaler Tag als `DateTime(y, m, d)` (oder `yyyy-MM-dd`-Key); liest `clockProvider`; `Timer` bis `DateTime(y, m, d + 1)` (min. 1 s); `WidgetsBindingObserver.resumed` → `refresh()` + neu planen; `ref.onDispose` räumt Timer und Observer auf; öffentliches `refresh()`.
2. **VM:** `ref.listen(todayProvider, …)` im `build()` (bzw. `ref.listen` nach Riverpod-3-Regeln) → `_onDayChange`: läuft Timer (`workStart != null && workEnd == null`) → nichts tun; sonst `_init(dayChange: true)` still (kein Zurücksetzen des States, kein Speichern).
3. **Soll an Eintragsdatum:** `_getEffectiveTargetDailyHours(forDate)`; Aufrufer übergeben `state.workEntry.date` (in `_init` das geladene `workEntry.date`); `isExtraDay` in `_recalculateOvertime`/`_recalculateStateAndSave` mit aktualisieren. `getEffectiveDailyTarget` bleibt unverändert (pure, nimmt `date`).
4. **Aktionen-Guard `_ensureCurrentDay()`** (Rückgabe `bool`): vor `startOrStopTimer` (Start-Zweig; Stop/Pause gehören beim laufenden Eintrag zum Starttag), `startNewSession*`, `startOrStopBreak`, `setManualStart/EndTime`, `clearEndTime`, `updateBreak`, `deleteBreak`. Ablauf: `today.refresh()` → ist Eintrag laufend oder `dateOnly(entry.date) == today` → ok, sonst `await _init(dayChange: true)`, bei Fehlschlag/Überholung Aktion abbrechen (Vorbild Web: `while (_initRun != null) await _initRun`). Danach `state.workEntry` neu lesen.
5. **Generationszähler** `_initGen` (+ `Future<void>? _initRun`): nach jedem `await` `if (gen != _initGen || !ref.mounted) return;`; `_stopTimer()` am Anfang des Reinit; try/catch um den Ladeblock.
6. **Basis-Überstunden:** `_init({bool dayChange = false})`: bei `dayChange` Basis = `storedOvertime`, außer `dailyAlreadyStored` (neuer Eintrag `workStart && workEnd` und `lastUpdate >= workEnd`) → Heuristik. Normaler `_init` unverändert.
7. **Autosave-Schutz:** `_autoSave` merkt Generation + Eintrags-id und speichert nur bei Übereinstimmung.
8. **Nach Stop eines Vortagseintrags** (Eintragsdatum != heute, Speichern fertig) Reinit auf den neuen Tag (Web-Default O1).
9. **Uhr überall `clockProvider`:** `GetTodayWorkEntry`/`ToggleBreak`/(`StartOrStopTimer`) per Konstruktor-Clock; im VM `roundToMinute(clock())` statt `nowToMinute()`; `DashboardState.initial()` ggf. auf fest-id/Clock umstellen (oder leer lassen, da nur Übergang).
10. **Cleanup:** `ref.onDispose` für `_timer`, `_autoSaveTimer` (heute nirgends).

## Tests

Gemeinsame Regeln: feste lokale Daten (`DateTime(2026, 10, 2, 23, 59, 30)` etc.), nie `DateTime.now()`, keine Wochentags-/Zeitzonenannahme; Dauern über Differenz lokaler Mitternächte statt „24 h" (23/25-h-Tage); `clockProvider.overrideWithValue(() => now)` mit veränderlichem `now` (Vorbild `holiday_banner_test.dart`, `holiday_today_provider_test.dart`). Läufe: `TZ=Europe/Berlin flutter test` (CI, `ci.yml` Z. 52–53) plus lokal `TZ=UTC`, `TZ=America/Los_Angeles`, `TZ=Pacific/Auckland`; DST-Tage Berlin 2026-03-29 (23 h) und 2026-10-25 (25 h; liegt in 3 Wochen).
- **Zeitsteuerung der Timer:** `Timer`/`Timer.periodic` brauchen Fake-Async (`testWidgets` + `tester.pump(Duration)` wie `holiday_banner_test.dart`, oder `fakeAsync`; Verfügbarkeit über `flutter_test` bzw. Dev-Dependency `fake_async` im Plan prüfen — aktuell wird `fakeAsync` im Repo nicht benutzt). `DateTime.now()` wird von Fake-Async **nicht** verschoben, deshalb muss `now` im Test an die fake-verstrichene Zeit gekoppelt werden (`start.add(async.elapsed)`) — das geht nur, weil der Code den `clockProvider` nutzt.
- Reine `test()` ohne Widget-Binding: `WidgetsBinding.instance.addObserver` braucht `TestWidgetsFlutterBinding.ensureInitialized()` im `todayProvider`-Test; bei Bedarf Observer-Registrierung kapseln.
- **`todayProvider`:** Initial = Tag der Uhr; 23:59:30 → +31 s → Folgetag; min. 1 s; Folgetag-Timer neu geplant; `resumed` nach Uhrsprung aktualisiert; Jahreswechsel 2026-12-31 → 2027-01-01; Schaltjahr 2028-02-28 → 02-29; DST 2026-03-28→29→30 und 2026-10-24→25→26; Dispose räumt Timer/Observer auf.
- **VM Soll-Kopplung:** laufender Fr-Eintrag, Uhr → Sa 01:00: Daily = elapsed − 8 h (nicht − 0), `expectedEndTime` unverändert; So→Mo: Soll 0 bleibt, `isExtraDay` true; beendeter Eintrag + `updateBreak` nach Mitternacht rechnet mit Soll des Eintragstags.
- **Stiller Wechsel:** Fr leer/beendet 23:59:30 → nach Mitternacht `workEntry.date` = Sa, Soll/Daily für Sa, kein `saveWorkEntry`/`saveOvertime`; So→Mo; Resume ohne Timer-Ablauf (Uhr springen + Lifecycle `resumed`); laufender Timer → kein Reinit, `date` bleibt Starttag, Autosave schreibt Starttag-Eintrag.
- **Regression Guard:** gestoppter Vortagseintrag, Uhr nach Mitternacht ohne Timer-/Resume-Ereignis: `startOrStopTimer` speichert `date`/`id` = heute (kein Save auf Vortag); `startNewSession`/`…KeepBreaks` lassen den Vortag unverändert; `it`-Schleife über alle Schreibaktionen; Stop eines Vortags-Laufs speichert Starttag, danach Reinit auf heute (Reihenfolge: alter Eintrag vor Reinit).
- **Basis:** `getOvertime` = 120 min, `lastUpdate` = neuer Tag, neuer Eintrag mit `workStart` → Basis = 120 min (nicht minus Daily); Gegenprobe normaler `_init`.
- **Generationszähler:** zwei überlappende `_init` (Completer, später fertiger alter Lauf überschreibt nicht), Login um 23:59 + Mitternacht → genau ein Endzustand; nach `container.dispose()` keine Ausnahme, keine Timer (`ref.onDispose`).
- **Offline/Fehler:** Reinit mit werfendem `getWorkEntry` (Mock) → Zustand bleibt Vortag, kein hängendes `isLoading`, Retry bei nächster Aktion.
- **Bestandstests** (`dashboard_view_model_test.dart`): nutzen `DateTime.now()` und `workdaysIncludingToday()` → bleiben grün, solange der Default-`clockProvider` `DateTime.now` ist; neue Tests in eigener Gruppe (nicht die Alt-Tests anfassen). Mocks regenerieren, falls `@GenerateMocks`/Use-Case-Signaturen geändert werden.

## Offene Fragen (mit Empfehlung)

1. **Laufender Timer über Mitternacht:** weiterlaufen (Variante B, Eintrag bleibt Starttag) oder bei 00:00 splitten? Empfehlung: **B** (wie Web; Splitten = eigenes Feature, betrifft Backend/Reports/Pflichtpausen).
2. **Gestoppter/leerer Eintrag nach Mitternacht:** still auf neuen Tag umschalten ohne Dialog? Empfehlung: **ja**, plus Aktionen-Guard.
3. **Nach Stop eines über Mitternacht gelaufenen Eintrags** sofort auf den neuen, leeren Tag umschalten (Web-Default O1) oder den beendeten Eintrag sichtbar lassen, bis die nächste Aktion/der nächste Resume? Empfehlung: **sofort umschalten** (konsistent zu Frage 2; Ergebnis ist ohnehin gespeichert, Gleitzeit-Anzeige bleibt über Basis korrekt).
4. **Wohin mit der Mitternachts-/Resume-Logik?** Empfehlung: neuer root-`todayProvider` in `core/providers/` (nicht ins Widget, wegen Tabwechsel-Dispose), manuelles `NotifierProvider`, Uhr über `clockProvider`.
5. **`HolidayBanner`/`holidayTodayProvider` auf `todayProvider` umstellen?** Empfehlung: **ja, klein**, behebt den Cache-Nebenbefund (Banner ohne Resume am Folgetag stale) und entfernt doppelte Mitternachts-Logik; Risiko: #279-Tests (`holiday_banner_test.dart`, `holiday_today_provider_test.dart`) anpassen. Alternative: Banner unverändert lassen und separates Issue — dann bleibt die Doppel-Logik.
6. **Uhr in Use Cases:** Konstruktor-Clock in `GetTodayWorkEntry`/`ToggleBreak`/`StartOrStopTimer` (Mocks bleiben) statt `call(DateTime)`? Empfehlung: **Konstruktor-Clock**. `nowToMinute()` selbst unverändert lassen (viele andere Aufrufer: Reports, `edit_work_entry_view_model`, `work_entry_extensions`), im Dashboard-Pfad `roundToMinute(clock())` nutzen.
7. **Standby-Härtung per Tick:** zusätzlich im 1-s-Tick `todayProvider.refresh()` aufrufen (Web-Entscheidung 7)? Empfehlung: **ja** (kostet nichts, deckt verpasste Timer/Resume ab).
8. **Toten Code `_loadWeekEntries`/`_weekEntries` entfernen?** Empfehlung: **ja, im selben PR als kleiner, separater Commit** (spart einen Repo-Call im Reinit und eine `DateTime.now()`-Stelle), sonst `today` durchreichen. Alternativ bewusst liegen lassen (minimaler Diff).
9. **Profilwechsel:** nur melden, **eigenes Issue** (wie Web #380); Generationszähler/Cleanup aus diesem Issue so bauen, dass `profileId`-Reinit später nur ein weiterer Trigger ist. Empfehlung: ja.
10. **UI-Rückmeldung beim Wechsel (Snackbar „Neuer Tag")?** Empfehlung: **nein** (keine neuen ARB-Keys, stiller Wechsel wie Web).
11. **Weitere „heute"-Stellen** (Reports/Insights/WeeklyReflection/Leave): außerhalb, ggf. Folge-Issues. Empfehlung: nicht in #379.
12. **`isExtraDay`** wird im Dashboard nirgends angezeigt: nur konsistent mitführen (wie Web) oder entfernen? Empfehlung: konsistent mitführen, nicht entfernen (kein Scope).

## Risiken

- **Datenverlust/Verfälschung beim Umschalten:** ein laufender `_autoSave` darf nach Reinit nicht den neuen Tag mit altem Eintrag überschreiben (Generation + Eintrags-id prüfen). Bei Variante B gibt es keinen Final-Save-Zwang, weil jede Aktion sofort speichert; das Fenster ist nur der 30-s-Autosave.
- **Laufender Timer:** Brutto > 24 h möglich; `calculateAndApplyBreaks` beim Stop auf dieser Basis (Verhalten heute schon so); Backend/Reports ordnen den Eintrag dem Starttag zu (wie Web akzeptiert).
- **Ungespeicherte Pausen:** offene Pause läuft über Mitternacht weiter; Pause-Toggle speichert sofort (zweifach, siehe Nebenbefund), kein zusätzliches Verlustfenster.
- **Offline/API-Fehler beim Reinit:** `_init` fängt heute nichts; ohne eigenes try/catch hängt `isLoading` oder der Vortag bleibt unbemerkt stehen; Aktionen-Guard muss bei Fehlschlag abbrechen statt in den Vortag zu schreiben.
- **Rebuild-Überlappung:** `build()`-`Future.microtask(_init)` plus neuer Reinit können überlappen (Login/Profil um Mitternacht) → Generationszähler zwingend, `ref.mounted` nach `await`.
- **Tests:** das VM startet echte `Timer.periodic`/`Timer`; ohne `ref.onDispose`-Cleanup hängen Timer nach `container.dispose()` (Fake-Async meldet pending Timer in `testWidgets`). `WidgetsBinding` in reinen `test()`s initialisieren.
- **DST:** lokale Mitternacht über `DateTime(y, m, d + 1)` (wie Banner/`addCalendarDays`, #362) statt `+ Duration(days: 1)`; Elapsed bleibt absolute Differenz. In UTC fallen die Berlin-DST-Tage nicht an → DST-Tests über Invarianten („Key = lokaler Folgetag", Delay = Differenz lokaler Mitternächte) formulieren, Berlin-Daten nur zusätzlich.
- **Generierter Code:** ändert sich `providers.dart` (Clock-Injektion in Use-Case-Provider) → `dart run build_runner build`; `*.g.dart`/`*.mocks.dart` nie von Hand.
- **Zwei Stellen mit Mitternachts-Timer** (Banner + `todayProvider`), falls Frage 5 mit „nein" beantwortet wird → Doppellogik und der Banner-Cache-Nebenbefund bleiben.

## Entscheidungen zu den offenen Fragen (Hauptsession)

Alle Empfehlungen übernommen: (1) Variante B: laufender Timer läuft über Mitternacht weiter, kein Splitten (Splitten = #381); (2) gestoppter/leerer Eintrag schaltet still auf den neuen Tag, plus Aktionen-Guard `_ensureCurrentDay()` vor allen Schreibaktionen (Start, Neue Session, Pause/ToggleBreak, Stop, …): „Start"/„Neue Session" nach Mitternacht darf nie in den Vortag schreiben oder einen abgeschlossenen Vortag überschreiben; (3) nach Stop eines Vortags-Laufs sofort auf den neuen leeren Tag umschalten; (4) neuer root-`todayProvider` in `core/providers/` (manueller `NotifierProvider`, Midnight-Timer + `WidgetsBindingObserver`-Resume über `clockProvider`, Cleanup per `ref.onDispose`); (5) `HolidayBanner`/`holidayTodayProvider` auf `todayProvider` umstellen (behebt den Cache-Nebenbefund), die #279-Tests entsprechend anpassen; (6) Uhr per Konstruktor-Clock in `GetTodayWorkEntry`/`ToggleBreak`/`StartOrStopTimer` (Mocks bleiben; Default `DateTime.now`), im Dashboard-Pfad `roundToMinute(clock())`; (7) zusätzlich `refresh()` im 1-s-Tick als Standby-Härtung; (8) toten Code `_loadWeekEntries`/`_weekEntries` in einem eigenen kleinen Commit entfernen; (9) Profilwechsel nur melden (#380 für Web; Mobile triggert bereits `_init` über `ref.watch`, ergänze `_initGen`/`ref.mounted`/try-catch gegen überholte Läufe und hängenden `isLoading` offline); (10) keine UI-Rückmeldung, keine neuen ARB-Keys; (11) Reports/Insights/WeeklyReflection/Leave bleiben außerhalb (Folge-Issues); (12) `isExtraDay` konsistent mitführen. Soll/`isExtraDay`/Überstunden am Eintragsdatum; `_init(dayChange: true)` mit Basis aus dem Gespeicherten (Ausnahme: `workStart && workEnd && lastUpdate >= workEnd` → Heuristik bleibt); Autosave nur bei gleicher Generation und id. Plan prüft `fakeAsync`-Verfügbarkeit (`flutter_test`) und `build_runner` für `providers.dart`. Nebenbefunde (`recalculateOvertimeFromSettings` rechnet bei beendetem Eintrag mit „jetzt" statt `workEnd`; `ToggleBreak` speichert doppelt; Basis-Heuristik fragil) nur melden bzw. falls durch den Umbau berührt mit Test absichern.
