# /reviewen — Phase 5: Review, Commit und PR

Argumente: $ARGUMENTS  (`<issue-nr> [plattform]`, Plattform: `flutter` | `angular` | `dotnet` | `react`; ohne Angabe aus Issue und
Root-`CLAUDE.md` ableiten)

Voraussetzung: `/validieren` ist ohne blockierende Punkte durchgelaufen.

Starte den Subagent `reviewer` (Agent-Tool, `subagent_type: reviewer`) mit diesem Auftrag:

> Issue #<nr> im Repo aus der Root-`CLAUDE.md` bearbeiten (GitHub-MCP `issue_read`, lokal `gh issue view <nr> --comments`).
> Plattform: <plattform>. Phase: **review**. Playbook: `.claude/skills/playbook-<plattform>/`.
> Diff gegen den Integrationsbranch nach der Checkliste reviewen, Funde als 🔴 / 🟡 / 🟢. 🔴-Funde beheben und die Checks erneut ausführen. Commit, Push und PR nach den Konventionen des Projekts.

Danach in der Hauptsession: Funde und PR-Link an den Nutzer melden.
