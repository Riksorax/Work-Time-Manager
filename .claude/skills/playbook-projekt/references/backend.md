# Work-Time-Manager — Backend (server/)

WTM-Besonderheiten zum Stack-Playbook `playbook-dotnet`, aus `server-developer` übernommen. Clients: Web und Flutter.

- **Vertrag zuerst:** DTO in `Contracts/` und Route festlegen. Abwärtskompatibilität prüfen (Play-Store-Versionen rufen ältere Formen auf).
- **TDD je Schicht:** `Domain/` → Unit-Test in `tests/.../*CalculatorTests.cs`; `FirestoreMappings` → `FirestoreMappingsTests.cs`;
  Repository → Integrationstest (`[SkippableFact]`, Firestore-Emulator); Endpunkt → Auth-Test in `EndpointAuthTests.cs` + ggf. Verhaltenstest.
- **Implementieren:** Documents → Mappings → Repository (Pfad über `ProfileScope`) → Endpoint-Gruppe → Registrierung in `Program.cs`.
- **Checks** aus `server/`: `dotnet build WorkTimeManager.slnx -c Release` und `dotnet test WorkTimeManager.slnx -c Release`.
- **Doku nachziehen:** Endpunkt-Tabelle in `server/CLAUDE.md`; neue Firestore-Pfade in der Pfad-Tabelle der Root-`CLAUDE.md`;
  Security Rule in `web/firestore.rules`, falls Clients direkt lesen.
- Checkliste: Endpunkt in der `/api`-Gruppe, UID aus dem Token; `profileId` unterstützt, falls die Daten profil-gebunden sind;
  nur additive Vertragsänderungen; Rechenlogik-Änderung im Web gespiegelt oder als Folge-Issue angelegt.
- Commit `feat(api): … (#123)` bzw. `fix(api): … (#123)`, PR gegen `develop`.
