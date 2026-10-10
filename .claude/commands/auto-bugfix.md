# /auto-bugfix — Offene bug-Issues automatisch analysieren und als PR vorbereiten

Läuft ohne Rückfragen an einen Menschen (Cron-Routine). Kein `$ARGUMENTS` — bearbeitet alle
offenen Issues mit Label `bug`, die noch nicht angefasst wurden.

Diese Automatisierung **mergt nichts selbst** — sie geht bis zum offenen, review-fertigen PR
und bleibt dort stehen wie bei jedem anderen Issue auch. Der Merge nach `develop` bleibt ein
menschlicher Schritt. **Ausnahme:** Issues aus gemeldeten Crashes (Crashlytics/Sentry/Uptime-Kuma,
siehe Schritt 4) laufen als Hotfix gegen `main` — dort wird der Merge für Web/API automatisiert.

## Ablauf

1. **Kandidaten finden:** `list_issues` (state: open, labels: ["bug"]) für
   `Riksorax/Work-Time-Manager`.
2. **Bereits in Arbeit?** Für jedes Issue `issue_read get_comments` prüfen. Enthält ein Kommentar
   den Marker `<!-- auto-bugfix:started -->`, überspringen (schon einmal angefasst — bei Bedarf hat
   ein Mensch den Marker-Kommentar gelöscht, um einen Neuversuch zu erzwingen).
3. **Markieren:** Sofort einen Kommentar mit `<!-- auto-bugfix:started -->` plus kurzer
   Ankündigung posten, um Doppelverarbeitung durch einen parallelen Lauf zu vermeiden.
4. **Crash-Issue erkennen:** Issue-Body prüfen auf
   - Marker `<!-- auto-monitoring:crashlytics:... -->` oder `<!-- auto-monitoring:uptime-kuma:... -->`
     (gesetzt von den Cloud Functions, `web/functions/src/github.ts`), oder
   - einen `sentry.io/organizations/...`-Link (Sentrys eigene GitHub-Integration, kein eigener Marker).

   Trifft eines zu → **Hotfix-Pfad** (Schritt 5a). Sonst **Normalpfad** (Schritt 5b).
5. **Einordnen & umsetzen wie `/issue $ARGUMENTS`:** Plattform bestimmen, passenden Workflow
   starten (`/mobile-analyze`, `/web-analyze`, `/server-implement`, oder direkt bei CI/Infra).
   - Ist die Ursache unklar, das Issue widersprüchlich, die Reproduktion nicht nachvollziehbar,
     oder betrifft der Fix mehrere Plattformen (Vertragsänderung) → **nicht umsetzen**.
     Stattdessen Kommentar im Issue mit der Einschätzung/den offenen Fragen hinterlassen und mit
     dem nächsten Issue weitermachen. Das gilt auch für Crash-Issues — Mehrplattform-Crash-Fixes
     laufen nicht automatisch.
   - Rückfragen, die `/issue` normalerweise an den Nutzer zurückgibt, ansonsten konservativ im
     Sinne des Issues selbst entscheiden, nicht den Scope erweitern.

   **5a. Hotfix-Pfad (Crash-Issue, eine Plattform):**
   - **Web/API:** Branch von `main` (nicht `develop`). Nach Schritt 6 (Validierung) PR gegen
     `main` erstellen (Schritt 7) und zusätzlich `enable_pr_auto_merge` setzen, sobald CI läuft —
     der Merge-Commit nach grüner CI löst `deploy-api.yml`/`deploy-angular.yml` automatisch aus.
     Nach erfolgreichem Merge `main` zurück nach `develop` mergen (wie `CONTRIBUTING.md`,
     „Release“, Schritt „Zurückmergen“), damit `develop` den Fix enthält.
   - **Mobile:** Branch ebenfalls von `main`, PR gegen `main` — aber **kein** Auto-Merge, da ein
     Play-Store-Release einen Versions-Bump und einen vorbereiteten Closed-Testing-Track braucht
     (`CONTRIBUTING.md`, „Hotfix / Bugfix-Release“). Im PR und im Issue vermerken, dass ein Mensch
     den Hotfix per `/release` abschließen muss.

   **5b. Normalpfad (normaler bug, kein Crash-Marker):** Branch von `develop`, PR gegen `develop`
   wie bisher, Merge bleibt menschlicher Schritt.
6. **Validieren** mit den Checks aus der Root-`CLAUDE.md`-Tabelle für die jeweilige Plattform —
   müssen grün sein, bevor ein PR entsteht.
7. **PR erstellen** (Konvention `CONTRIBUTING.md`, inkl. `Closes #<issue>`-Zeile; Zielbranch wie in
   5a/5b festgelegt) und Review durch den passenden Reviewer-Agenten (`mobile-reviewer`,
   `web-reviewer`, oder die Checkliste aus `server-implement.md`) durchführen; 🔴-Funde vor dem
   Öffnen des PRs beheben.
   Die PR-Beschreibung muss die Zeile `<!-- created-by: auto-bugfix -->` enthalten (löst die
   Discord-Benachrichtigung in `.github/workflows/notify-review-needed.yml` aus) sowie, im
   Hotfix-Pfad, einen kurzen Hinweis, dass es sich um einen Crash-Hotfix gegen `main` handelt.
8. **PR-Aktivität abonnieren** (`subscribe_pr_activity`), damit spätere CI-Fehler oder
   Review-Kommentare automatisch bearbeitet werden. Im Normalpfad und beim Mobile-Hotfix bleibt
   der PR bis zum menschlichen Merge offen; im Web/API-Hotfix-Pfad übernimmt das bereits gesetzte
   Auto-Merge den Merge selbst, sobald CI grün ist.
9. **Nächstes Issue.** Nach allen Kandidaten: kurze Zusammenfassung (PR erstellt — normal oder
   Hotfix —, zurückgestellt mit Begründung) als Ergebnis der Routine.
