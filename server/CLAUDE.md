# CLAUDE.md — Backend (.NET API)

Ergänzt die Root-`CLAUDE.md` (Firestore-Datenpfade, Key Rules).
Arbeitsablauf, Branches und Commits: `CONTRIBUTING.md` im Repo-Root.

## Commands (aus `server/`)

```bash
dotnet restore WorkTimeManager.slnx
dotnet build WorkTimeManager.slnx -c Release          # wie CI
dotnet test WorkTimeManager.slnx -c Release           # Unit- + Integrationstests
dotnet test WorkTimeManager.slnx --filter "FullyQualifiedName~ReportCalculator"   # Auswahl
dotnet run --project src/WorkTimeManager.Api          # lokal, Swagger unter /swagger
```

In Cloud-Sessions installiert der SessionStart-Hook das .NET-10-SDK
(`.claude/hooks/session-start.sh`). Docker gibt es dort nicht, deshalb werden die
Firestore-Integrationstests übersprungen (`SkippableFact`) — das ist erwartet.

## Aufbau (`src/WorkTimeManager.Api/`)

| Ordner | Inhalt | Regel |
|---|---|---|
| `Contracts/` | API-DTOs (JSON, ISO-8601) | Öffentlicher Vertrag mit Web und Flutter — Änderungen abwärtskompatibel halten |
| `Firestore/Documents/` | `[FirestoreData]`-POCOs | Spiegeln das Flutter-kanonische Firestore-Format |
| `Firestore/FirestoreMappings.cs` | POCO ↔ DTO | **Einziger** Ort für Mapping; days-Map-Keys ohne führende Null (`"5"`) |
| `Firestore/*Repository.cs` | Firestore-Zugriff | Pfade immer über `ProfileScope.Collection(...)` |
| `Domain/` | `BreakCalculator`, `ReportCalculator` | Pure, ohne DI/Firestore; kanonische Rechenlogik für alle Clients |
| `Endpoints/` | Minimal-API-Gruppen je Ressource | UID nur aus dem Token (`user.GetUid()`), nie aus Route/Body |
| `Program.cs` | Auth, CORS, Swagger, Mapping | Neue Gruppen unter `api` (erfordert Auth) registrieren |

## Endpunkte (alle unter `/api`, authentifiziert; UID kommt aus dem Token)

| Methode | Route | Zweck |
|---|---|---|
| GET | `/api/me` | UID des Tokens |
| GET | `/api/work-entries/{year}/{month}` | Einträge eines Monats |
| GET | `/api/work-entries/{year}/{month}/{day}` | Einzeleintrag (404 wenn fehlt) |
| PUT | `/api/work-entries` | Eintrag speichern (merge in days-Map, `isHomeOffice` und `workLocations` nur wenn gesetzt; ungültige Orte = 400, #526) |
| DELETE | `/api/work-entries/{year}/{month}/{day}` | Tag löschen |
| GET / PUT | `/api/overtime` | Gleitzeit-Saldo lesen/speichern (`minutes`, PUT optional `keepLastUpdated`, #406) |
| GET / PUT | `/api/settings` | Einstellungen lesen/speichern |
| GET | `/api/profile` | Premium-Status |
| GET | `/api/reports/daily/{year}/{month}/{day}` | Tagesstatistik |
| GET | `/api/reports/weekly/{year}/{month}/{day}` | Wochenbericht |
| GET | `/api/reports/monthly/{year}/{month}` | Monatsbericht |
| GET | `/api/reports/yearly/{year}` | Jahresauswertung Urlaub/Krank (#278): `{year, vacationDaysPerYear, vacationDaysTaken, vacationDaysRemaining, sickDays}`; Rest kann negativ sein, `holiday` zählt nicht, Jahr 2000–2100 |
| GET | `/api/reports/trend/{year}/{month}/{day}?granularity=week\|month` | Trend (#531): 12 Wochen bzw. 12 Monate bis zum Bezugstag + Wochen-Trend; `granularity` Pflicht (sonst 400), Jahr 2000–2100 |
| GET | `/api/reports/yearly-comparison/{year}?until=MM-dd` | Jahresvergleich mit dem Vorjahr (#530): `{until, current, previous, delta}`; `until` optional (ungültig = 400), Jahr 2001–2100 |
| GET | `/api/work-profiles` | Zusätzliche Arbeitszeit-Profile auflisten (ohne Standard-Profil, siehe #138/#239) |
| POST | `/api/work-profiles` | Neues Profil anlegen (`{ name }`) |
| DELETE | `/api/work-profiles/{profileId}` | Profil inkl. aller Daten löschen |

**Gleitzeit ohne `lastUpdated` (#406):** `PUT /api/overtime` nimmt im JSON-Body optional `keepLastUpdated` (`bool?`, camelCase, neben `minutes`). Fehlt es, ist es `null` oder `false` (alte Clients/App-Versionen), gilt das bisherige Verhalten: `minutes` und `lastUpdated = jetzt (UTC)` werden geschrieben. Bei `true` wird nur `minutes` gemergt (`SetOptions.MergeAll`); ein vorhandenes `lastUpdated` bleibt unverändert. Existiert das Dokument noch nicht, wird es nur mit `minutes` angelegt, `lastUpdated` fehlt dann und `GET` liefert `lastUpdated: null` (wie bei einem nie gespeicherten Saldo). Gilt auch mit `?profileId=...`. Die Antwort (aktueller Saldo per `GET`-Form) bleibt gleich. Body statt Query, weil der Body bereits die Nutzdaten (`minutes`) trägt und der Query-Parameter dem Profil-Scope vorbehalten ist. Zweck: nachträgliches Beenden eines offenen Eintrags vor heute darf die „lastUpdated ist heute"-Heuristik der Dashboards nicht auslösen. Deploy-Reihenfolge: API vor Clients (ein älterer API-Stand ignoriert das Feld und setzt `lastUpdated` weiterhin).

**Urlaubsanspruch (#278):** `SettingsDto.vacationDaysPerYear` (0–366, sonst 400; fehlt im Dokument: 30). Im `PUT /api/settings` optional: fehlt das Feld (alte Clients), bleibt der gespeicherte Wert erhalten (`SettingsMergeFields` lässt es aus dem Merge aus).

**Bundesland (#279):** `SettingsDto.bundesland` (`string?`, Dart-Enum-Name der 16 Bundesländer, z. B. `nordrheinWestfalen`; Whitelist in `FirestoreMappings.Bundeslaender`, exakte Schreibweise). Gilt je Profil in `settings/current`, kein neuer Pfad. GET: Wert oder `null` (nicht ausgewählt). PUT: `null`/fehlend lässt den gespeicherten Wert unangetastet (alte Clients), `""` löscht das Feld (`FieldValue.Delete`), ungültiger Wert ergibt 400. Das Backend kennt keine Feiertagslogik.

**Home-Office (#277):** `WorkEntryDto.isHomeOffice` (`bool?`) ↔ `days.{d}.isHomeOffice` (bool, Root und `profiles/{id}`, kein neuer Pfad, keine Rules/Migration). GET liefert immer `true`/`false` (fehlendes Feld = `false`). PUT: `true`/`false` wird geschrieben (`false` überschreibt ein gespeichertes `true`), `null`/fehlend (alte Clients) lässt den gespeicherten Wert unangetastet: `WorkEntryRepository.SaveAsync` schreibt per `SetOptions.MergeFields(FirestoreMappings.DayMergeFields(...))` statt `MergeAll`, die Feldliste enthält `days.{d}.isHomeOffice` nur bei gesetztem Flag. Neue `DayData`-Felder müssen in `DayMergeFields` ergänzt werden (Drift-Test). Der Server validiert nicht nach Typ; Clients ignorieren das Flag bei `vacation/sick/holiday`. Keine Report-/Rechenlogik-Änderung. Deploy-Reihenfolge: API vor Clients.

**Arbeitsorte (#526):** `WorkEntryDto.workLocations` (`string[]?`) ↔ `days.{d}.workLocations` (Array von Strings, Root und `profiles/{id}`, kein neuer Pfad, keine Rules/Migration; Altdokumente bleiben feldfrei, solange kein Client das Feld sendet). GET liefert immer eine Liste (fehlendes Feld = `[]`, nie `null`). PUT: `null`/fehlend (alte Clients, Schnelleintrag, Batch) lässt die gespeicherten Orte unangetastet (`DayMergeFields` nimmt den Pfad nur bei gesetztem Feld auf), `[]` entfernt das Feld (`WorkEntryRepository.SaveAsync`: Batch aus `Set` mit `MergeFields` und `Update` mit `FieldValue.Delete` auf `days.{d}.workLocations`, analog `bundesland`), eine Liste ersetzt die gespeicherte (Reihenfolge bleibt). Das Backend trimmt und verwirft Duplikate (ohne Beachtung der Groß-/Kleinschreibung, der erste bleibt, `NormalizeWorkLocations`). Validierung `FirestoreMappings.IsValidWorkLocations` nach dem Trimmen: höchstens 5 Einträge (nach Duplikat-Entfernung), keiner leer, keiner länger als 60 Zeichen, sonst 400 aus `PUT /api/work-entries` (einziger Schreib-Endpunkt für Einträge). Einstellungen je Profil in `settings/current`: `SettingsDto.showWorkLocationOnDashboard` (`bool?`, fehlt = `false`) und `showHomeOfficeOnDashboard` (`bool?`, fehlt = `true`); GET liefert immer einen konkreten Wert, PUT mit `null`/fehlend lässt den gespeicherten Wert unangetastet (`SettingsMergeFields`, Muster `vacationDaysPerYear`). Keine Report-/Rechenlogik-Änderung. Deploy-Reihenfolge: API vor Clients.

**Multi-Profile (`profileId`, siehe #239):** `work-entries`/`overtime`/`settings`/`reports`-Endpunkte akzeptieren optional `?profileId=...` (Query-Parameter). Fehlt er oder ist er `"default"`, wird der bestehende, nicht migrierte Pfad verwendet — vollständig abwärtskompatibel für bestehende Clients ohne den Parameter.

## Rechenlogik

**Berechnungslogik = Port der _korrigierten_ Web-`*-calculator`-Services** (Stand nach Web-Bugfix
`0ddd15b`, 10.06.2026). Das ist die mathematisch korrekte Variante. **Achtung:** Die Flutter-App
rechnet aktuell noch _anders_ (doppelte Pausen-Subtraktion in Wochen-/Monatsbericht, ignoriert
Urlaub/Krank/Feiertag, Tages-Überstunden=0, vereinfachte KW ohne Jahreswechsel-Korrektur,
Monats-Gesamtüberstunden ohne Gleitzeit-Altsaldo). Das Backend folgt **bewusst nicht** dieser
Flutter-Logik — Flutter soll perspektivisch auf die Backend-Logik gezogen werden, damit alle Clients
identisch rechnen. `ReportCalculator.GetIsoWeekNumber` ist gegen `System.Globalization.ISOWeek`
getestet.

**Tagessoll (#535):** `Wochenstunden × 3 600 000 ÷ Zahl der Arbeitstage`, auf die volle Minute gerundet;
Rundung wie `roundMsToMinute` im Web (kaufmännisch, .5 von der Null weg, `MidpointRounding.AwayFromZero`):
39 h an 7 Tagen = 334,29 min → 334 min, 37,5 h an 4 Tagen = 562,5 min → 563 min. Ohne Arbeitstage ist das
Soll 0. Bis #535 schnitt das Backend den Millisekundenwert nur ab.

**Soll-Tage, Abwesenheit an freien Tagen (#535):** Das Soll zählt jeden Tag höchstens einmal: Tage mit Arbeitseintrag
mit Start an einem Vertrags-Wochentag und **jeden** Tag mit Urlaub/Krank/Feiertag, auch an einem freien Tag. Ein
Abwesenheits-Eintrag zählt mit dem Tagessoll als geleistet und als Soll und erzeugt so nie Über- oder Minusstunden
(manuelle Überstunden am Eintrag zählen weiter). Tagesbericht ebenso (Soll = geleistet = Tagessoll, auch am freien Tag).
Unverändert: Arbeit an einem freien Tag (kein Soll, alles Überstunden), Einträge ohne Ende, Tage ohne Eintrag. `WorkDays`
enthielt alle Abwesenheitstage schon vorher. Ohne Arbeitstage (Tagessoll 0) sind Soll und geleistet 0. Gilt über
`SumPeriod` auch für den Trend.

**Monats-Gesamtüberstunden (#535):** `MonthlyReportDto.TotalOvertimeMs` = gespeicherter Gleitzeit-Saldo
(`overtime/balance`). Der Saldo ist ein laufender Stand und enthält den laufenden Monat schon; bis #535 wurde
`MonthlyOvertimeMs` addiert und der Monat doppelt gezählt. `MonthlyOvertimeMs` bleibt die Summe des Monats.

**Trend (#531):** `GET /api/reports/trend/{y}/{m}/{d}?granularity=week|month` → `TrendReportDto`
(`ReportCalculator.CalculateTrend`). Das Datum ist der Bezugstag des Clients (keine Server-Uhr).
`granularity` ist Pflicht und muss exakt `week` oder `month` sein, sonst 400. `buckets`: immer 12, älteste
zuerst, der letzte enthält den Bezugstag (laufende ISO-Woche bzw. laufender Monat, ggf. unvollständig);
`key` = `yyyy-Www` (ISO-Wochenjahr, `ISOWeek.GetYear`) bzw. `yyyy-MM`, `start`/`end` = UTC-Mitternacht des
ersten/letzten Kalendertags. Jeder Bucket rechnet mit demselben privaten Kern wie Wochen- und Monatsbericht
(`SumPeriod`): `workedMs` ist **netto** (= `TotalWorkedMs − TotalBreaksMs` der Berichte; Urlaub/Krank/Feiertag
mit Tagessoll), `targetMs` = Soll-Tage × Tagessoll (Regel siehe „Soll-Tage“), `overtimeMs` = `OvertimeMs`
des Wochen- bzw. `MonthlyOvertimeMs` des Monatsberichts (inkl. manueller Überstunden). **Kein Saldo:** der
gespeicherte Gleitzeit-Saldo fließt nicht ein, `cumulativeOvertimeMs` ist die laufende Summe ab 0. Buckets ohne
Eintrag: `hasData = false`, Werte 0. `weeklyTrend` (bei beiden Granularitäten): letzte abgeschlossene Woche = ISO-Woche
vor der Woche des Bezugstags, verglichen mit dem Mittel der vier Wochen davor; Wochen ohne Einträge zählen nicht,
Mittel kaufmännisch auf ganze ms gerundet (`AwayFromZero`), `deltaMs = lastWeekWorkedMs − averageWorkedMs`;
`null`, wenn die letzte Woche leer ist oder weniger als zwei Vergleichswochen Einträge haben. Es gelten die heutigen
Einstellungen für den ganzen Zeitraum. Daten über `WorkEntryRepository.GetRangeAsync` (alle berührten
Monatsdokumente parallel). Kein Premium-Check im Backend.

**Jahresvergleich (#530):** `GET /api/reports/yearly-comparison/{year}?until=MM-dd` → `YearlyComparisonDto`
(`ReportCalculator.CalculateYearlySummary` je Jahr, dann `CalculateYearlyComparison`). Der bestehende
`/reports/yearly/{year}` (Urlaubsbilanz) bleibt unverändert. `year` 2001–2100 (das Vorjahr muss in 2000–2100 liegen),
sonst 400. `until` optional, genau `MM-dd` (ASCII-Ziffern, `TryParseUntil`); Tage, die es auch im Schaltjahr nicht
gibt (`02-30`, `13-01`), und jede andere Form ergeben 400. `02-29` ist gültig und gilt in einem Nicht-Schaltjahr als
`02-28`. In **beiden** Jahren zählen nur Einträge bis einschließlich des Stichtags; ohne `until` das ganze Jahr. Der
Client sendet `until` nur für das laufende Jahr, das Backend nutzt keine Server-Uhr. `until` in der Antwort = der
übergebene Wert oder `null`. `current`/`previous` (`YearlySummaryDto`): jeder der 12 `months` rechnet mit `SumPeriod`
wie der Monatsbericht, die Jahreswerte sind die Summen der Monate. `totalWorkedMs` und `months[].workedMs` sind
**netto** (= `TotalWorkedMs − TotalBreaksMs` des Monatsberichts; Urlaub/Krank/Feiertag mit Tagessoll), `totalBreaksMs`
die Pausen, `overtimeMs` = `MonthlyOvertimeMs` (inkl. manueller Überstunden) bzw. deren Jahressumme, `workDays` wie im
Monatsbericht. **Kein Saldo:** der gespeicherte Gleitzeit-Saldo fließt nirgends ein. Monate nach dem Stichtag sind 0.
`vacationDays`/`sickDays`/`holidayDays`: ein Eintrag = ein Tag, auch am Wochenende (Regel wie `CalculateYearlyLeave`,
`holiday` analog), bis zum Stichtag. `hasData = false`, wenn im abgeschnittenen Jahr kein Eintrag existiert. `delta` =
`current − previous` je Feld (`workedMs`, `overtimeMs`, `workDays`, `vacationDays`, `sickDays`, `holidayDays`), `null`,
wenn `previous.hasData` `false` ist. `workedPercent` = `delta.workedMs ÷ previous.totalWorkedMs × 100`, kaufmännisch auf
eine Nachkommastelle (`decimal`, `AwayFromZero`: +12,35 → 12,4, −12,35 → −12,4), `null`, wenn
`previous.totalWorkedMs` 0 ist (z. B. nur offene Einträge). **Für beide Jahre gelten die heutigen Einstellungen**
(Wochenstunden, Arbeitstage), weil frühere nicht gespeichert sind. Daten: beide Jahre parallel über `GetRangeAsync`
(1.1. bis Stichtag, höchstens 24 Monatsdokumente). Kein Premium-Check im Backend (nur in den Clients).

**Gemeinsame Testfälle (#535):** `testdata/report-parity/cases.json` (Repo-Wurzel) prüft Backend
(`ReportParityTests`) und Web (`report-calculator.parity.tz.spec.ts`) mit denselben Fällen. Die erwarteten
Werte erzeugt das Backend (`REPORT_PARITY_UPDATE=1`, siehe `testdata/report-parity/README.md`).

## Regeln

- **Auth:** Jeder fachliche Endpunkt liegt in der `/api`-Gruppe mit `RequireAuthorization()`.
  Ausnahme ist nur `/health`. Neue Endpunkte in `EndpointAuthTests` aufnehmen (401 ohne Token).
- **Arbeitszeit-Profile (#239):** Endpunkte für profil-gebundene Daten nehmen `string? profileId`
  als Query-Parameter. `null` oder `"default"` = bisheriger Pfad `users/{uid}/...`.
- **Abwärtskompatibel:** Die App-Versionen im Play Store rufen ältere Vertragsformen auf.
  Felder nur hinzufügen, nicht umbenennen oder entfernen. Neue Pflichtfelder brauchen
  einen Default.
- **Rechenlogik:** Backend = kanonisch. Änderungen in `Domain/` im Web
  (`web/src/app/domain/services/`) nachziehen und im PR vermerken.
- **Firestore-Security-Rules:** Das Backend nutzt einen Service-Account und umgeht die Rules.
  Clients lesen aber direkt per `onSnapshot` — neue Pfade brauchen trotzdem eine Regel in
  `web/firestore.rules` (manuelles Deploy, siehe `CONTRIBUTING.md`).
- **Keine Secrets im Repo.** Credentials kommen aus `FIREBASE_SERVICE_ACCOUNT_BASE64`
  (Prod) bzw. `FIRESTORE_EMULATOR_HOST` (Tests), sonst Application Default Credentials.

## Tests

- Unit-Tests für `Domain/` und `FirestoreMappings` ohne Firestore.
- Endpunkt-Tests mit `WebApplicationFactory<Program>`.
- Repository-Tests gegen den Firestore-Emulator (`Integration/`, Testcontainers) als
  `[SkippableFact]`.
- Tests dürfen nicht vom aktuellen Datum abhängen.

## Deployment

Push auf `main` → `.github/workflows/deploy-api.yml` baut, pusht das Image
`riksorax/work-time-manager-api` und deployt auf Hetzner. Health-Check:
`https://api.work-time-manager.app/health`. Rollback: `CONTRIBUTING.md`.

## Fehler-Tracking

Sentry (`Sentry.AspNetCore`) fängt unbehandelte Exceptions im Request-Pipeline automatisch ab —
kein Code pro Endpunkt nötig. Aktiv nur, wenn `Sentry:Dsn` konfiguriert ist (Secret `SENTRY_DSN_API`,
siehe `CONTRIBUTING.md`); lokal/CI bleibt es aus. Neue Fehler landen über die Sentry-GitHub-Integration
automatisch als Issue mit Label `bug` (siehe Root-`CLAUDE.md`, „Fehler-Monitoring") und werden von
`/auto-bugfix` aufgegriffen.

**Sentry-Filter (#438–#440):** `SentryClientCancellationFilter` (`SetBeforeSend` in `Program.cs`) verwirft Events, deren Exception-Kette eine `OperationCanceledException` oder `RpcException(Cancelled)` enthält — der Client hat den Request abgebrochen, das ist kein Serverfehler.
