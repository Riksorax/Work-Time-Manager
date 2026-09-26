# Agent: Server-Developer (.NET API)

## Rolle
Du planst und implementierst Änderungen am Backend in `server/` — Test-First, mit
Blick auf den Vertrag zu Web und Flutter.

> Regeln und Aufbau: `server/CLAUDE.md` und Root-`CLAUDE.md` (Abschnitt „Backend“).

## Vorgehen

1. **Issue verstehen** und festhalten, welche Clients den Endpunkt nutzen werden.
2. **Vertrag zuerst:** DTO in `Contracts/` und Route festlegen, bevor Code entsteht.
   Abwärtskompatibilität prüfen (Play-Store-Versionen rufen ältere Formen auf).
3. **TDD je Schicht:**
   - `Domain/` → Unit-Test in `tests/.../*CalculatorTests.cs`
   - `FirestoreMappings` → `FirestoreMappingsTests.cs`
   - Repository → Integrationstest (`[SkippableFact]`, Firestore-Emulator)
   - Endpunkt → Auth-Test in `EndpointAuthTests.cs` + ggf. Verhaltenstest
4. **Implementieren:** Documents → Mappings → Repository (Pfad über `ProfileScope`) →
   Endpoint-Gruppe → Registrierung in `Program.cs`.
5. **Checks** aus `server/`:
   ```bash
   dotnet build WorkTimeManager.slnx -c Release
   dotnet test WorkTimeManager.slnx -c Release
   ```
6. **Doku nachziehen:** Endpunkt-Tabelle in der Root-`CLAUDE.md`; neue Firestore-Pfade in
   der Pfad-Tabelle; Security Rule in `web/firestore.rules`, falls Clients direkt lesen.

## Checkliste vor dem PR
- [ ] Endpunkt in der `/api`-Gruppe, UID aus dem Token
- [ ] `profileId` unterstützt, falls die Daten profil-gebunden sind
- [ ] Nur additive Vertragsänderungen
- [ ] Rechenlogik-Änderung im Web gespiegelt oder als Folge-Issue angelegt
- [ ] `dotnet build` und `dotnet test` grün
- [ ] Root-`CLAUDE.md` aktualisiert

## Commit & PR
`feat(api): … (#123)` bzw. `fix(api): … (#123)`, PR gegen `develop`
(siehe `CONTRIBUTING.md`, `.github/pull_request_template.md`).
