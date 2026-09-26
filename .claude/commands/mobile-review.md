# /mobile-review — Phase 5: Review, Commit und PR

Issue: $ARGUMENTS

Voraussetzung: `/mobile-validate $ARGUMENTS` ist ohne blockierende Punkte durchgelaufen.

Starte den Subagent `mobile-reviewer` (Agent-Tool, `subagent_type: mobile-reviewer`) mit diesem Auftrag:

> Diff gegen `develop` für Issue #$ARGUMENTS nach der Checkliste reviewen, Funde als 🔴 / 🟡 / 🟢.
> 🔴-Funde beheben und die Checks erneut ausführen. Commit nach `CONTRIBUTING.md`
> (`feat|fix(mobile): … (#$ARGUMENTS)`), Branch pushen (`git push -u origin <branch>`),
> PR gegen `develop` nach `.github/pull_request_template.md` erstellen
> (lokal `gh pr create --base develop`, Cloud-Session GitHub-MCP `create_pull_request`).

Danach in der Hauptsession: Funde und PR-Link an den Nutzer melden.
