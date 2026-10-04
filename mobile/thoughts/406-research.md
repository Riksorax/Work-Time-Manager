# Mobile-Research: #406 — Beenden eines offenen Eintrags setzt im Cloud-Betrieb lastUpdated (Mobile-Teil)
Datum: 2026-10-04

## Aufgabe
Backend (#408) und Web (#409) sind gemergt. Mobile muss das nachträgliche Beenden aus #385/PR #405 im
eingeloggten Betrieb mit `keepLastUpdated: true` an `PUT /api/overtime` senden, damit das Backend `lastUpdated` nicht auf
"jetzt" setzt. Sonst greift im Dashboard (`DashboardViewModel._load`, Zweig `DateUtils.isSameDay(lastUpdateDate, _now())`)
die Heuristik "Saldo enthält schon den Tagesanteil" fälschlich (Szenario aus dem Issue: Sa beenden, Sa Timer starten, Reload,
Saldo beim späteren Stop um bis zu das Tages-Soll zu hoch).

Akzeptanz (Issue-Kommentare): `ApiDataSource.saveOvertime` mit optionalem Parameter `keepLastUpdated`, durchgereicht bis
`CloseOpenWorkEntry`, plus Test. Default unverändert, alle anderen Aufrufer unverändert. Nicht Teil: Heuristik im Dashboard
ersetzen, Saldo-Rollback (Mobile), Web.

## Betroffene Dateien
| Datei | Warum |
|---|---|
| `lib/domain/repositories/overtime_repository.dart` | Interface: `saveOvertime(Duration, {bool keepLastUpdated = false})` |
| `lib/data/repositories/hybrid_overtime_repository_impl.dart` | reicht an aktives Repo durch |
| `lib/data/repositories/firebase_overtime_repository_impl.dart` | reicht an `FirestoreDataSource.saveOvertime` durch (Cache wie bisher) |
| `lib/data/repositories/local_overtime_repository_impl.dart` | nimmt Parameter an, ignoriert ihn (schreibt `lastUpdate` in `saveOvertime` ohnehin nie) |
| `lib/data/datasources/remote/firestore_datasource.dart` | Interface `FirestoreDataSource.saveOvertime` + `FirestoreDataSourceImpl` (nimmt Parameter an; direkter Firestore-Write setzt `lastUpdated` nie, siehe unten) |
| `lib/data/datasources/remote/api_data_source.dart` | `saveOvertime` → `_api.saveOvertime(..., keepLastUpdated:)`; Kommentar im No-op `saveLastOvertimeUpdate` |
| `lib/data/datasources/remote/api_client.dart` | `saveOvertime(int, {profileId, keepLastUpdated = false})`: Body nur bei `true` mit Feld |
| `lib/domain/usecases/close_open_work_entry.dart` | ruft `saveOvertime(..., keepLastUpdated: true)`; Doc-Kommentar anpassen |
| `test/support/fake_repositories.dart` | `FakeOvertimeRepository` muss die neue Signatur implementieren |
| `test/presentation/widgets/add_adjustment_modal_test.dart` | `_DelayedOvertimeRepository implements OvertimeRepository` (Kompilierfehler ohne Signaturanpassung) |
| 10 committete `*.mocks.dart` | per `build_runner` neu erzeugen (siehe unten) |
| `mobile/CLAUDE.md` | Abschnitt #385 ("`lastUpdated` wird bewusst nicht gesetzt", Deploy/Alt-API) |

Nicht betroffen: `DashboardViewModel` (Stop-Pfad ruft weiter `saveOvertime(x)` + `saveLastUpdateDate(now)`), `AddAdjustment`/
`ResetOvertime` (`overtime_usecases.dart`), `DataSyncService`, `OpenEntryViewModel`.

## Ist-Zustand / Pfad (Frage 1)
`CloseOpenWorkEntry.call` → `ensureOvertimeLoaded()` → `OvertimeRepository.saveOvertime(alt + Netto − Soll)` → danach
`WorkRepository.saveWorkEntry`. Es ruft **nie** `saveLastUpdateDate` (durch Test `setzt lastUpdated nie` gesichert).

Provider (`providers.dart`, `overtimeRepository`): `HybridOvertimeRepositoryImpl(firebase, local, userId)`, aktiv nach `userId`.
- **Eingeloggt (alle Profile, Standard und zusätzliche, siehe #239):** `FirebaseOvertimeRepositoryImpl(dataSource: apiDataSourceProvider,
  profileId)` → `ApiDataSource.saveOvertime` → `ApiClient.saveOvertime` → `PUT /api/overtime[?profileId=]` mit Body `{"minutes": n}`.
  **`lastUpdated` setzt hier das Backend** bei jedem PUT (Datenquelle: Issue + `OvertimeRepository.cs`). `ApiDataSource.saveLastOvertimeUpdate`
  ist No-op. Die Agenten-Faustregel "zusätzliche Profile direkt Firestore" gilt für Overtime nicht: alles geht über die API. Die
  `FirestoreDataSourceImpl.saveOvertime` ist für Overtime im Provider-Graph nicht verdrahtet; sie schreibt nur `minutes` (merge),
  `lastUpdated` nur über `saveLastOvertimeUpdate`.
- **Ausgeloggt:** `LocalOvertimeRepositoryImpl` (SharedPreferences): `saveOvertime` schreibt nur `local_overtime_minutes`;
  `local_overtime_date` nur über `saveLastUpdateDate`, und die ruft der Beenden-Pfad nie auf. Lokal ist das Verhalten also schon korrekt
  (wie im Issue festgestellt); der Parameter ist dort wirkungslos.
- **Stop-Pfad (Dashboard)** setzt `lastUpdated` weiterhin gewollt: eingeloggt implizit über das Backend, lokal über
  `saveLastUpdateDate(actionCtx.now())` (`dashboard_view_model.dart:620-622`). Bleibt unverändert.
- Der Firebase-Cache `_cachedLastUpdate` wird von `saveOvertime` nicht berührt, `ensureLastUpdateLoaded` lädt frisch vom Backend: kein
  Cache-Problem durch `keepLastUpdated`.

## Datenfluss (Soll)
`OpenEntryViewModel` → `CloseOpenWorkEntry` → `OvertimeRepository.saveOvertime(x, keepLastUpdated: true)` → Hybrid → (eingeloggt)
`FirebaseOvertimeRepositoryImpl` → `FirestoreDataSource.saveOvertime(..., keepLastUpdated: true)` (= `ApiDataSource`) →
`ApiClient.saveOvertime(min, profileId:, keepLastUpdated: true)` → Body `{"minutes": n, "keepLastUpdated": true}`; (ausgeloggt) Local ignoriert.

## Minimaler, abwärtskompatibler Eingriff (Frage 2)
- Überall **optionaler benannter Parameter `bool keepLastUpdated = false`** (nicht nullable: Mockito-Defaults sind dann `false`, bestehende
  `verify(mock.saveOvertime(x))`/`when(...)` bleiben gültig, weil Stub und Aufruf denselben Default tragen). Alle anderen Aufrufer unverändert.
- `ApiClient`: Body wie Web `api-client.ts`: `{'minutes': m}` bzw. nur bei `true` `{'minutes': m, 'keepLastUpdated': true}` (nie `false` senden,
  Body für Default byte-identisch zu heute).
- `FirestoreDataSourceImpl`: Parameter annehmen, ignorieren (Kommentar warum).
- Folge der Interface-Änderung (Pflicht, sonst Kompilierfehler): `FakeOvertimeRepository`, `_DelayedOvertimeRepository` (implements);
  `_FakeOvertimeRepository extends Fake` ist unkritisch. Mocks: `dart run build_runner build` erzeugt neu u. a.
  `api_data_source_test`, `firebase_overtime_repository_test`, `settings_repository_impl_test`, `auth_repository_impl_test`,
  `overtime_usecases_test`, `dashboard_view_model_test`, `settings_view_model_test`, `reports_view_model_test`,
  `yearly_report_view_model_test`, `data_sync_view_model_test` (`*.mocks.dart`, nie von Hand). Nur Diffs der `saveOvertime`-Signaturen erwartet;
  weitere Diffs prüfen (Mockito-Version).
- Kein neuer `@riverpod`-Provider, kein ARB-Key, keine neue Firestore-Regel (Pfade unverändert) ⇒ **kein** `build_runner` für Provider nötig, nur Mocks.
  Kein Premium-Bezug, kein neues Backend-Feld (Vertrag aus #408).

## Rollback / Reihenfolge (Frage 3)
`CloseOpenWorkEntry` schreibt Saldo, dann Eintrag; bei Fehler des Eintrag-Writes bleibt der Saldo um das Delta verschoben, ein Wiederholen
zählt doppelt (gleiches Rest-Risiko wie #402 / im Stop-Pfad). Web hat dafür einen best-effort-Rollback (`saveOvertime(stored, pid,
{keepLastUpdated:true})`). **Nicht Teil dieses PR.** Falls später nachgezogen: der Rollback muss ebenfalls `keepLastUpdated: true` senden
(sonst setzt er `lastUpdated`). Trivial wäre es nicht (neuer Fehlerpfad, Tests, Entscheidung zu `failed`-Semantik), daher Empfehlung: eigenes Issue.

## Deploy-Reihenfolge / Verhalten gegen ältere API (Frage 4)
- API (#408) muss vor den Clients live sein (Release nach `main`; `deploy-api.yml` und `flutter-production.yml` triggern beide auf Push nach
  `main`, parallel; der Play-Closed-Testing-Rollout hinkt praktisch hinterher). Das Feld wird nur bei `true` gesendet.
- Ältere API (vor #408): unbekanntes JSON-Feld wird von der ASP.NET-Minimal-API-Bindung ignoriert (`UnmappedMemberHandling` ist im Server nicht
  gesetzt, `grep` ohne Treffer in `server/src/**/*.cs`), PUT klappt wie heute, `lastUpdated` wird gesetzt, Fehlverhalten wie vor dem Fix, kein Fehler.
- Ältere App gegen neue API: sendet kein Feld, Default = altes Verhalten.
- Mobile-spezifisch: Alte App-Versionen im Feld bleiben fehlerhaft, bis sie aktualisiert werden (unvermeidbar). Der Kommentar in
  `close_open_work_entry.dart` und `mobile/CLAUDE.md` nennen die Voraussetzung "API ab #408".

## Testplan (Frage 5)
Alle Daten fest (`DateTime(2026, 10, 2/3, ...)`, bestehende Konstanten `friday`/`saturday`/`now` in `close_open_work_entry_test.dart`), keine
`DateTime.now()`, keine Zeitzonenannahme (CI: `TZ=Europe/Berlin`; lokal zusätzlich `TZ=UTC`/`America/Los_Angeles`/`Pacific/Auckland flutter test <dateien>`).

1. `api_client_test.dart`: `_RecordingHttpClient` um `Object? lastBody` erweitern (nur `put`). Tests: (a) `saveOvertime(30)` → `jsonDecode(body)` ==
   `{'minutes': 30}` (kein Schlüssel `keepLastUpdated`); (b) `keepLastUpdated: true` → `{'minutes': 30, 'keepLastUpdated': true}`;
   (c) mit `profileId: 'p1'` bleiben Query und Feld beide erhalten (Query nur `profileId`, nie `keepLastUpdated`); (d) `false` explizit → Feld fehlt.
2. `api_data_source_test.dart`: `saveOvertime(..., keepLastUpdated: true, profileId: 'p1')` → `verify(mockApi.saveOvertime(45, profileId: 'p1',
   keepLastUpdated: true))`; ohne Parameter → `keepLastUpdated: false`; Rundung (`toStoredMinutes`) unverändert.
3. `firebase_overtime_repository_test.dart`: `repository.saveOvertime(x, keepLastUpdated: true)` → `verify(mockDataSource.saveOvertime(user, x,
   profileId: null, keepLastUpdated: true))`; Default → `false`; Cache nach Save aktualisiert (beide Fälle).
4. Neu `hybrid_overtime_repository_test.dart` (existiert nicht): eingeloggt → Firebase-Fake bekommt Flag, Local nichts; ausgeloggt → Local bekommt
   Aufruf, Firebase nichts. Kleine Fakes (`FakeOvertimeRepository`) genügen.
5. `local_overtime_repository_test.dart`: `saveOvertime(x, keepLastUpdated: true)` und Default schreiben Minuten und lassen `getLastUpdateDate()` unverändert
   (Fixierung des heutigen Verhaltens; MockSharedPreferences/`setMockInitialValues`).
6. `FakeOvertimeRepository`: neue Liste `savedKeepLastUpdated` (parallel zu `savedOvertimes`) und optional `DateTime Function()? serverNow`, die das
   Backend nachbildet (`saveOvertime` ohne Flag setzt `lastUpdate = serverNow()`, mit Flag nicht). Das **Writelog-Format bleibt unverändert**
   (bestehende Tests erwarten `A:overtime:-180`); bei Backend-Simulation nur dann `A:lastUpdate` loggen. Ohne diese Simulation wäre der bestehende Test
   `setzt lastUpdated nie` auch ohne Fix grün (der Fake setzt `lastUpdate` in `saveOvertime` nie).
7. `close_open_work_entry_test.dart`: (a) `savedKeepLastUpdated.single == true`; (b) Backend-simulierender Fake mit `lastUpdate = DateTime(2026, 9, 1)` und
   `serverNow = Sa 09:00`: nach Beenden bleibt `lastUpdate == DateTime(2026, 9, 1)`; (c) Fehlerpfad (`failSaveOvertime`) unverändert; (d) Profil-Kapselung
   (bestehender Test) bleibt grün.
8. Gegenprobe "andere Aufrufer unverändert": ein Dashboard-/Usecase-Test, der prüft, dass Stop/`AddAdjustment`/`ResetOvertime` `keepLastUpdated: false`
   (Default) übergeben, z. B. `savedKeepLastUpdated` leer-oder-alle-false im Fake-Szenario eines Stops in `dashboard_view_model_*_test` bzw. `verify(
   mockRepository.saveOvertime(overtime))` in `overtime_usecases_test` (bleibt unverändert und beweist den Default).
9. Optional (Integrationsgefühl, klein): `open_entry_view_model_test` Szenario "Beenden, dann Dashboard-Reload": Fake mit `serverNow` + `lastUpdate` vorher
   null; nach `closed` und `reloadAfterRetroClose` ist `initialOvertime` = neuer Saldo, nicht Saldo − Tagesanteil. Nur wenn die Harness-Anpassung klein ist.

**Mutationsproben (jeweils eine Mutation, erwartet Rot, danach zurücknehmen):**
- `CloseOpenWorkEntry` ruft `saveOvertime` ohne `keepLastUpdated: true` → 7a/7b rot.
- `FirebaseOvertimeRepositoryImpl` reicht das Flag nicht durch (immer `false`) → 3 rot (und 7b nur im Fake-Pfad, deshalb 3/2 separat nötig).
- `HybridOvertimeRepositoryImpl` verschluckt das Flag → 4 rot.
- `ApiDataSource` verschluckt das Flag → 2 rot.
- `ApiClient` sendet `keepLastUpdated` immer (auch `false`) → 1a/1d rot; sendet das Feld in die Query statt in den Body → 1c rot.
- `CloseOpenWorkEntry` ruft zusätzlich `saveLastUpdateDate` → bestehender Test `setzt lastUpdated nie` rot.
- `LocalOvertimeRepositoryImpl.saveOvertime` schreibt bei Default das Datum → 5 rot.

**Rot-Nachweis-Plan:** Schritt 1 Tests schreiben (Kompilierfehler wegen fehlender Parameter = rot, Ausgabe festhalten); Schritt 2 Signaturen durch
alle Schichten ziehen, **Flag zunächst nirgends weiterreichen** und Mocks regenerieren → alles kompiliert, die Verhaltenstests (1b, 2, 3, 4, 7a/b) sind
**inhaltlich** rot (Beweis, dass sie das Feature prüfen und nicht nur die Signatur); Schritt 3 Weiterreichen implementieren → grün; Schritt 4 Mutationsproben.
CI-Checks: `dart format --set-exit-if-changed lib test && flutter analyze --no-fatal-infos && dart run custom_lint && flutter test` (TZ Berlin), zusätzlich
TZ-Läufe der geänderten Testdateien.

## Doku (Frage 6)
- `api_data_source.dart`, No-op `saveLastOvertimeUpdate`: Kommentar ergänzen: "Das Backend setzt `lastUpdated` beim Speichern des Saldos, außer mit
  `keepLastUpdated: true` (PUT-Body, ab #408; Mobile: nachträgliches Beenden, #385/#406)."
- `close_open_work_entry.dart` Doc: "`lastUpdated` wird bewusst nicht gesetzt" um "eingeloggt per `keepLastUpdated: true` (Backend ab #408, ältere API
  ignoriert das Feld und setzt es weiterhin)" ergänzen.
- `mobile/CLAUDE.md`, Abschnitt #385, Bullet "Beenden": Satz zu `keepLastUpdated`, Deploy-Reihenfolge API vor App; Fehlen von Rollback bleibt "Rest-Risiko #402".
  Abschnitt "Hybrid Repository Pattern" muss nicht geändert werden.
- Dokumentierte Abweichung zu Web (Web CLAUDE.md nennt "Mobile zieht in einem Folge-PR nach, #406"): nach dem Merge dort nichts mehr zu tun außer ggf. den Satz
  zu entfernen (Web ist nicht Teil dieses Auftrags).
- Kein Eintrag in Root-`CLAUDE.md` nötig (Datenpfade unverändert).

## Plattformübergreifend
Nur Mobile. Backend (#408) und Web (#409) sind erledigt; kein neuer Vertrag. Nach Merge: Issue #406 schließen (mit "Closes #406" im Mobile-PR).

## Risiken
- Mock-Regenerierung kann bei abweichender Mockito-Version mehr als die `saveOvertime`-Signatur ändern; Diff prüfen.
- `bool keepLastUpdated = false` im Interface zwingt alle `implements OvertimeRepository` (auch Test-Fakes) zur Anpassung; ein übersehener Fake bricht die Kompilierung (gut sichtbar).
- Alte API im Feld: Fix wirkt erst nach API-Deploy; kein Fehler, nur altes Verhalten.
- Mockito-Falle: Stubs mit `any` für Positionsargumente bleiben gültig; ein Stub mit explizitem `keepLastUpdated: true` matcht den Default-Aufruf nicht (gewollt).
- Fake-Backend-Simulation (`serverNow`) ist eine Annahme zum Backend-Verhalten; sie ist durch Backend-Tests (#408, `OvertimeSaveTests`) gedeckt, nicht durch Mobile.
- Rest-Risiko Teilfehler (Saldo geschrieben, Eintrag nicht) bleibt (#402).

## Offene Fragen
1. Rollback des Saldos bei Eintrag-Fehler (wie Web) in diesem PR? Empfehlung: nein, eigenes Issue (#402-Umfeld), PR klein halten.
2. Parametertyp `bool keepLastUpdated = false` (Empfehlung) oder `bool?`? Empfehlung `bool` mit Default `false`: Mockito-/Fake-freundlich, kein Tri-State.
3. Optionaler Integrationstest 9 (Beenden → Dashboard-Reload mit Backend-Simulation) mitnehmen? Empfehlung: ja, falls die Harness-Anpassung unter ca. 30 Zeilen bleibt, sonst weglassen (7b deckt den Kern).
4. `FirestoreDataSourceImpl` (direkter Firestore-Pfad, für Overtime nicht verdrahtet): Parameter nur annehmen und ignorieren (Empfehlung) oder `lastUpdated`-Verhalten angleichen? Empfehlung: ignorieren, Kommentar.
5. Releasenotes/Versionshinweis nötig? Empfehlung: nein (Bugfix, kein UI-Text).

---

# Plan (TDD, klein, ein PR gegen `develop`, Branch `claude/week-number-display-bug-x5xq8r`)

Umfang klein: 6 Lib-Dateien + Doku, ca. 8 Testdateien plus Mock-Regenerierung. Reihenfolge Tests zuerst; "Rot" wie oben beschrieben.

1. **Fakes/Testhilfen (Test-first-Vorbereitung, ohne Verhaltensänderung):** `FakeOvertimeRepository` (Signatur, `savedKeepLastUpdated`, optional `serverNow`), `_DelayedOvertimeRepository` (Signatur), `_RecordingHttpClient.lastBody`. Kompiliert erst nach Schritt 3 (Interface); Schritt 1 und 2 gemeinsam committen oder Tests lokal rot lassen.
2. **Tests schreiben** (Testplan 1–8, ggf. 9) gegen die gewünschte API. Lauf: rot (Kompilierfehler festhalten).
3. **Signaturen durchziehen, Flag noch nicht weiterreichen:** `OvertimeRepository`, `HybridOvertimeRepositoryImpl`, `FirebaseOvertimeRepositoryImpl`, `LocalOvertimeRepositoryImpl`, `FirestoreDataSource`/`FirestoreDataSourceImpl`, `ApiDataSource`, `ApiClient` (`saveOvertime(int, {profileId, keepLastUpdated = false})`). `dart run build_runner build --delete-conflicting-outputs` für die 10 Mocks (Diff prüfen). Lauf: kompiliert; Verhaltenstests 1b, 2, 3, 4, 7a/b rot (Rot-Nachweis dokumentieren).
4. **Implementieren:** Flag weiterreichen (Hybrid, Firebase, ApiDataSource, ApiClient-Body nur bei `true`), `CloseOpenWorkEntry` übergibt `keepLastUpdated: true`. Lauf: grün.
5. **Mutationsproben** (siehe oben), jeweils rot, zurücknehmen, am Ende alles grün; Ergebnis im PR-Text.
6. **Doku:** Kommentar `saveLastOvertimeUpdate` (`api_data_source.dart`), Doc in `close_open_work_entry.dart`, `mobile/CLAUDE.md` (#385-Abschnitt).
7. **Checks:** `dart format --set-exit-if-changed lib test && flutter analyze --no-fatal-infos && dart run custom_lint && flutter test` (TZ Berlin); geänderte Testdateien zusätzlich mit `TZ=UTC` und `TZ=Pacific/Auckland`.
8. **PR** gegen `develop` ("Closes #406", Hinweis Deploy-Reihenfolge API vor App, Rest-Risiko #402 unverändert).

## Entscheidungen zu den offenen Fragen (Hauptsession)

1. Kein Saldo-Rollback in diesem PR (Mobile-Beenden hat keinen; Web hat ihn). Als Nebenbefund im PR-Text nennen; Hauptsession entscheidet über ein Folge-Issue. Wird er später nachgezogen, muss er `keepLastUpdated: true` senden.
2. Typ `bool keepLastUpdated = false` (benannter Parameter), nicht `bool?`.
3. Optionaler Integrationstest „Beenden → reloadAfterRetroClose" nur, wenn die Harness-Anpassung unter ca. 30 Zeilen bleibt; die Backend-Simulation im Fake deckt den Kern ab.
4. `FirestoreDataSourceImpl`: Parameter annehmen und ignorieren, mit Kommentar.
5. Keine Releasenotes.
6. Der Plan-Abschnitt am Ende der Datei gilt; Plan-Schritte mit Test zuerst und Rot-Nachweis in drei Stufen wie dort beschrieben.
