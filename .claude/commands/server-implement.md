# /server-implement — Backend-Änderung umsetzen

Issue: $ARGUMENTS

Starte den Subagent `server-developer` (Agent-Tool, `subagent_type: server-developer`) mit diesem Auftrag:

> Issue #$ARGUMENTS lesen (GitHub-MCP `issue_read`, lokal `gh issue view $ARGUMENTS --comments`).
> Vertrag festlegen (DTO, Route, `profileId`). Hängen Web oder Flutter davon ab: zuerst nur den
> Vertrag zurückgeben und auf Freigabe warten. Sonst TDD je Schicht umsetzen
> (Domain → Mappings → Repository → Endpoint). Aus `server/`:
> `dotnet build WorkTimeManager.slnx -c Release` und `dotnet test WorkTimeManager.slnx -c Release`
> — beide grün. Endpunkt-Tabelle in `server/CLAUDE.md`, neue Firestore-Pfade in der Root-`CLAUDE.md`
> nachziehen. Commit `feat|fix(api): … (#$ARGUMENTS)`, PR gegen `develop`.

Gibt der Subagent einen Vertrag zur Freigabe zurück: dem Nutzer vorlegen und danach denselben
Subagent (SendMessage) bzw. einen neuen mit dem freigegebenen Vertrag weiterarbeiten lassen.
