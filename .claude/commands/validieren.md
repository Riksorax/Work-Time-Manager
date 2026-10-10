# /validieren — Phase 4: Testen und UI prüfen

Argumente: $ARGUMENTS  (`<issue-nr> [plattform]`, Plattform: `flutter` | `angular` | `dotnet` | `react`; ohne Angabe aus Issue und
Root-`CLAUDE.md` ableiten)

Starte den Subagent `developer` (Agent-Tool, `subagent_type: developer`) mit diesem Auftrag:

> Issue #<nr> im Repo aus der Root-`CLAUDE.md` bearbeiten (GitHub-MCP `issue_read`, lokal `gh issue view <nr> --comments`).
> Plattform: <plattform>. Phase: **validate**. Playbook: `.claude/skills/playbook-<plattform>/`.
> Checks der Plattform ausführen, Testlücken nach der Checkliste schließen (keine Fachlogik ändern), UI-Checkliste abarbeiten (Widget-/Komponententests; lokal zusätzlich im Browser/Emulator). Abschnitte „Validierung“ und „UI-Review“ im Plan ergänzen.

Blockierende Punkte (🔴) zuerst beheben lassen, bevor `/reviewen <nr>` folgt.
