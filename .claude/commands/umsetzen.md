# /umsetzen — Phase 3: Code umsetzen

Argumente: $ARGUMENTS  (`<issue-nr> [plattform]`, Plattform: `flutter` | `angular` | `dotnet` | `react`; ohne Angabe aus Issue und
Root-`CLAUDE.md` ableiten)

Voraussetzung: `<ordner>/thoughts/<nr>-plan.md` ist vom Nutzer freigegeben (Backend und kleine Änderungen: Vertrag bzw. Skizze, bei Client-Abhängigkeit zuerst nur den Vertrag zur Freigabe zurückgeben).

Starte den Subagent `developer` (Agent-Tool, `subagent_type: developer`) mit diesem Auftrag:

> Issue #<nr> im Repo aus der Root-`CLAUDE.md` bearbeiten (GitHub-MCP `issue_read`, lokal `gh issue view <nr> --comments`).
> Plattform: <plattform>. Phase: **implement**. Playbook: `.claude/skills/playbook-<plattform>/`.
> Plan Schritt für Schritt umsetzen (TDD: Test rot → Implementierung grün → Schritt abhaken). Am Ende die Checks der Plattform aus der Root-`CLAUDE.md` — alle grün.

Meldet der Subagent „unvollständig, weiter ab Schritt N“, einen neuen `developer` mit „weiter ab Schritt N“ starten. Nächster Schritt: `/validieren <nr>`.
