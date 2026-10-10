# /entwerfen — Phase 2b: UI portieren (nur Angular-Port)

Argumente: $ARGUMENTS  (`<issue-nr> [plattform]`, Plattform: `flutter` | `angular` | `dotnet` | `react`; ohne Angabe aus Issue und
Root-`CLAUDE.md` ableiten)

Voraussetzung: `web/thoughts/<nr>-research.md` existiert. Nur für Plattformen, deren Playbook eine Referenz `design.md` hat (Angular-Port einer Flutter-Vorlage).

Starte den Subagent `developer` (Agent-Tool, `subagent_type: developer`) mit diesem Auftrag:

> Issue #<nr> im Repo aus der Root-`CLAUDE.md` bearbeiten (GitHub-MCP `issue_read`, lokal `gh issue view <nr> --comments`).
> Plattform: <plattform>. Phase: **design**. Playbook: `.claude/skills/playbook-<plattform>/`.
> Das Flutter-UI laut Research nach Angular portieren (alle UI-States, responsive, Texte als Übersetzungs-Keys, Accessibility). Ergebnis: HTML/SCSS im Feature-Ordner und `web/thoughts/<nr>-ui-report.md`.

Nächster Schritt: `/planen <nr> angular`.
