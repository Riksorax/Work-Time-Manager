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
| PUT | `/api/work-entries` | Eintrag speichern (merge in days-Map) |
| DELETE | `/api/work-entries/{year}/{month}/{day}` | Tag löschen |
| GET / PUT | `/api/overtime` | Gleitzeit-Saldo lesen/speichern (`minutes`) |
| GET / PUT | `/api/settings` | Einstellungen lesen/speichern |
| GET | `/api/profile` | Premium-Status |
| GET | `/api/reports/daily/{year}/{month}/{day}` | Tagesstatistik |
| GET | `/api/reports/weekly/{year}/{month}/{day}` | Wochenbericht |
| GET | `/api/reports/monthly/{year}/{month}` | Monatsbericht |
| GET | `/api/reports/yearly/{year}` | Jahresauswertung Urlaub/Krank (#278): `{year, vacationDaysPerYear, vacationDaysTaken, vacationDaysRemaining, sickDays}`; Rest kann negativ sein, `holiday` zählt nicht, Jahr 2000–2100 |
| GET | `/api/work-profiles` | Zusätzliche Arbeitszeit-Profile auflisten (ohne Standard-Profil, siehe #138/#239) |
| POST | `/api/work-profiles` | Neues Profil anlegen (`{ name }`) |
| DELETE | `/api/work-profiles/{profileId}` | Profil inkl. aller Daten löschen |

**Urlaubsanspruch (#278):** `SettingsDto.vacationDaysPerYear` (0–366, sonst 400; fehlt im Dokument: 30). Im `PUT /api/settings` optional: fehlt das Feld (alte Clients), bleibt der gespeicherte Wert erhalten (`SettingsMergeFields` lässt es aus dem Merge aus).

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
