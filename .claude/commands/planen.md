# /planen — Phase 2: Umsetzungsplan erstellen

Argumente: $ARGUMENTS  (`<issue-nr> [plattform]`, Plattform: `flutter` | `angular` | `dotnet` | `react`; ohne Angabe aus Issue und
Root-`CLAUDE.md` ableiten)

Voraussetzung: `<ordner>/thoughts/<nr>-research.md` existiert und ihre offenen Fragen sind beantwortet. Falls nicht: zuerst `/analysieren`.

Starte den Subagent `analyst` (Agent-Tool, `subagent_type: analyst`) mit diesem Auftrag:

> Issue #<nr> im Repo aus der Root-`CLAUDE.md` bearbeiten (GitHub-MCP `issue_read`, lokal `gh issue view <nr> --comments`).
> Plattform: <plattform>. Phase: **plan**. Playbook: `.claude/skills/playbook-<plattform>/`.
> Aus der Research-Datei den TDD-Plan erstellen: Architektur-Entscheidungen, alle neuen/geänderten Dateien mit Pfad, Schritte in Layer-Reihenfolge, jeder Schritt beginnt mit dem Test. Ergebnis: `<ordner>/thoughts/<nr>-plan.md`. Kein Code.

Danach in der Hauptsession: Den Nutzer den Plan freigeben lassen (Pfad nennen, nicht den ganzen Plan ausgeben). Nächster Schritt: `/umsetzen <nr>`.
