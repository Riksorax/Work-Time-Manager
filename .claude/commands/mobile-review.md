# /mobile-review — Phase 5: Review, Commit und PR

Aktiviere den Mobile-Reviewer-Agenten (lies `.claude/agents/mobile-reviewer.md` vollständig).

Issue: $ARGUMENTS

## Voraussetzung
`/mobile-validate $ARGUMENTS` ist ohne blockierende Punkte durchgelaufen.

## Aufgabe
1. Diff gegen `develop` nach der Checkliste reviewen, Funde als 🔴 / 🟡 / 🟢 auflisten.
2. 🔴-Funde beheben, Checks erneut ausführen.
3. Commit nach `CONTRIBUTING.md` (`feat|fix(mobile): … (#$ARGUMENTS)`).
4. Branch pushen (`git push -u origin <branch>`).
5. PR gegen `develop` nach `.github/pull_request_template.md` erstellen
   (lokal `gh pr create --base develop`, Cloud-Session: GitHub-MCP `create_pull_request`).
