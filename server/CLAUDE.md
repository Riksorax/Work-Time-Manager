# CLAUDE.md — Backend (.NET API)

Ergänzt die Root-`CLAUDE.md` (Abschnitt „Backend“: Endpunkte, Firestore-Pfade, Rechenregeln).
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
  (Prod) bzw. `FIRESTORE_EMULATOR_HOST` (Tests).

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
