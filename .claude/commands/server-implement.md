# /server-implement — Backend-Änderung umsetzen

Aktiviere den Server-Developer-Agenten (lies `.claude/agents/server-developer.md` vollständig)
und lies `server/CLAUDE.md`.

Issue: $ARGUMENTS

## Aufgabe
1. Issue #$ARGUMENTS lesen (GitHub-MCP `issue_read`, lokal `gh issue view $ARGUMENTS --comments`).
2. Vertrag festlegen (DTO, Route, `profileId`) und kurz dem Nutzer vorlegen, wenn Web oder
   Flutter davon abhängen.
3. TDD je Schicht umsetzen (Domain → Mappings → Repository → Endpoint).
4. Aus `server/`: `dotnet build WorkTimeManager.slnx -c Release` und
   `dotnet test WorkTimeManager.slnx -c Release` — beide grün.
5. Root-`CLAUDE.md` (Endpunkt-/Pfad-Tabellen) aktualisieren.
6. Commit `feat|fix(api): … (#$ARGUMENTS)`, PR gegen `develop`.
