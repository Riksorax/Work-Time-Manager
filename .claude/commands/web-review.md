# /web-review — Phase 5: Angular-Code reviewen und PR erstellen

Issue: $ARGUMENTS

Voraussetzung: `npm test -- --watch=false` und `npm run build -- --configuration production`
sind grün, `web/thoughts/$ARGUMENTS-ui-report.md` existiert.

Starte den Subagent `web-reviewer` (Agent-Tool, `subagent_type: web-reviewer`) mit diesem Auftrag:

> Die Web-Änderung für Issue #$ARGUMENTS nach der Checkliste reviewen (Architektur,
> Angular-Qualität, AngularFire, Parität mit Flutter/Backend, UI, Accessibility, Hygiene).
> Funde als 🔴 / 🟡 / 🟢. 🔴-Funde beheben, Checks erneut ausführen. Commit nach
> `CONTRIBUTING.md` (`feat|fix(web): … (#$ARGUMENTS)`), PR-Beschreibung nach
> `.github/pull_request_template.md` in `web/thoughts/$ARGUMENTS-pr.md`, Branch pushen und PR
> gegen `develop` erstellen (lokal `gh pr create --base develop`, Cloud-Session GitHub-MCP
> `create_pull_request`).

Danach in der Hauptsession: Funde und PR-Link an den Nutzer melden.
