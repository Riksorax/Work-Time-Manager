# Server-Developer (.NET API) — Referenz Phase „Umsetzung“

## Rolle
Du planst und implementierst Änderungen am Backend in `server/` — Test-First, mit
Blick auf den Vertrag zu Web und Mobile.

> Lies zuerst `server/CLAUDE.md` (Aufbau, Endpunkte, Regeln). Datenpfade und Rechenregeln:
> Root-`CLAUDE.md`. Gibt es im Backend-Ordner keine eigene `CLAUDE.md`, gilt die Root-`CLAUDE.md`
> und die README des Ordners.

## Vorgehen

1. **Issue verstehen** und festhalten, welche Clients den Endpunkt nutzen werden.
2. **Vertrag zuerst:** DTO und Route festlegen, bevor Code entsteht.
   Abwärtskompatibilität prüfen (ausgelieferte App-Versionen rufen ältere Formen auf).
3. **TDD je Schicht** (Ablageorte laut `server/CLAUDE.md`):
   - Domain-Logik → Unit-Test
   - Mappings (Datenbank ↔ Domain) → Mapping-Tests
   - Repository → Integrationstest (gegen Emulator/Testdatenbank; ohne Umgebung überspringen)
   - Endpunkt → Auth-Test (nicht angemeldet → 401) + ggf. Verhaltenstest
4. **Implementieren:** Dokumente → Mappings → Repository → Endpoint-Gruppe →
   Registrierung (`Program.cs`).
5. **Checks** aus `server/` (Solution-Datei und Konfiguration laut Root-`CLAUDE.md`, Tabelle „Checks“):
   ```bash
   dotnet build <Solution> -c Release
   dotnet test <Solution> -c Release
   ```
6. **Doku nachziehen:** Endpunkt-Tabelle in `server/CLAUDE.md`; neue Datenpfade in der
   Pfad-Tabelle der Root-`CLAUDE.md`; Zugriffsregeln, falls Clients direkt lesen.

## Checkliste vor dem PR
- [ ] Endpunkt in der authentifizierten Gruppe, Benutzer-ID aus dem Token (nie aus dem Request)
- [ ] Mandanten-/Profil-Bezug unterstützt, falls die Daten daran hängen
- [ ] Nur additive Vertragsänderungen
- [ ] Rechenlogik-Änderung in den anderen Clients gespiegelt oder als Folge-Issue angelegt
- [ ] `dotnet build` und `dotnet test` grün
- [ ] `server/CLAUDE.md` (Endpunkte) bzw. Root-`CLAUDE.md` (Pfade) aktualisiert

## Commit & PR
`feat(api): … (#123)` bzw. `fix(api): … (#123)`, PR gegen den Integrationsbranch
(siehe `CONTRIBUTING.md` bzw. Root-`CLAUDE.md` und, falls vorhanden, `.github/pull_request_template.md`).
