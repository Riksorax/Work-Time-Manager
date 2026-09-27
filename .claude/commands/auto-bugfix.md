# /auto-bugfix — Offene bug-Issues automatisch analysieren und als PR vorbereiten

Läuft ohne Rückfragen an einen Menschen (Cron-Routine). Kein `$ARGUMENTS` — bearbeitet alle
offenen Issues mit Label `bug`, die noch nicht angefasst wurden.

Diese Automatisierung **mergt nichts selbst** — sie geht bis zum offenen, review-fertigen PR
und bleibt dort stehen wie bei jedem anderen Issue auch. Der Merge nach `develop` bleibt ein
menschlicher Schritt.

## Ablauf

1. **Kandidaten finden:** `list_issues` (state: open, labels: ["bug"]) für
   `Riksorax/Work-Time-Manager`.
2. **Bereits in Arbeit?** Für jedes Issue `issue_read get_comments` prüfen. Enthält ein Kommentar
   den Marker `<!-- auto-bugfix:started -->`, überspringen (schon einmal angefasst — bei Bedarf hat
   ein Mensch den Marker-Kommentar gelöscht, um einen Neuversuch zu erzwingen).
3. **Markieren:** Sofort einen Kommentar mit `<!-- auto-bugfix:started -->` plus kurzer
   Ankündigung posten, um Doppelverarbeitung durch einen parallelen Lauf zu vermeiden.
4. **Einordnen & umsetzen wie `/issue $ARGUMENTS`:** Plattform bestimmen, Branch von `develop`,
   passenden Workflow starten (`/mobile-analyze`, `/web-analyze`, `/server-implement`, oder direkt
   bei CI/Infra).
   - Ist die Ursache unklar, das Issue widersprüchlich, die Reproduktion nicht nachvollziehbar,
     oder betrifft der Fix mehrere Plattformen (Vertragsänderung) → **nicht umsetzen**.
     Stattdessen Kommentar im Issue mit der Einschätzung/den offenen Fragen hinterlassen und mit
     dem nächsten Issue weitermachen.
   - Rückfragen, die `/issue` normalerweise an den Nutzer zurückgibt, ansonsten konservativ im
     Sinne des Issues selbst entscheiden, nicht den Scope erweitern.
5. **Validieren** mit den Checks aus der Root-`CLAUDE.md`-Tabelle für die jeweilige Plattform —
   müssen grün sein, bevor ein PR entsteht.
6. **PR erstellen** (Konvention `CONTRIBUTING.md`, inkl. `Closes #<issue>`-Zeile) und Review durch
   den passenden Reviewer-Agenten (`mobile-reviewer`, `web-reviewer`, oder die Checkliste aus
   `server-implement.md`) durchführen; 🔴-Funde vor dem Öffnen des PRs beheben.
   Die PR-Beschreibung muss die Zeile `<!-- created-by: auto-bugfix -->` enthalten (löst die
   Discord-Benachrichtigung in `.github/workflows/notify-review-needed.yml` aus).
7. **PR-Aktivität abonnieren** (`subscribe_pr_activity`), damit spätere CI-Fehler oder
   Review-Kommentare automatisch bearbeitet werden — der PR selbst bleibt aber bis zum
   menschlichen Merge offen.
8. **Nächstes Issue.** Nach allen Kandidaten: kurze Zusammenfassung (PR erstellt, zurückgestellt
   mit Begründung) als Ergebnis der Routine.
