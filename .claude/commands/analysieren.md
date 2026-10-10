# /analysieren — Phase 1: Aufgabe analysieren

Argumente: $ARGUMENTS  (`<issue-nr> [plattform]`, Plattform: `flutter` | `angular` | `dotnet` | `react`; ohne Angabe aus Issue und
Root-`CLAUDE.md` ableiten)

Starte den Subagent `analyst` (Agent-Tool, `subagent_type: analyst`) mit diesem Auftrag:

> Issue #<nr> im Repo aus der Root-`CLAUDE.md` bearbeiten (GitHub-MCP `issue_read`, lokal `gh issue view <nr> --comments`).
> Plattform: <plattform>. Phase: **analyse**. Playbook: `.claude/skills/playbook-<plattform>/`.
> Betroffene Dateien finden, Datenfluss und bei Bugs die Ursache beschreiben, prüfen ob andere Plattformen mitbetroffen sind, offene Fragen und Risiken listen. Ergebnis: `<ordner>/thoughts/<nr>-research.md`. Kein Code.

Danach in der Hauptsession: Die zurückgegebenen offenen Fragen dem Nutzer stellen und die Antworten in der Research-Datei ergänzen. Betrifft das Issue mehrere Plattformen, vorher `cross-platform-coordinator` einsetzen. Nächster Schritt: `/planen <nr>`.
