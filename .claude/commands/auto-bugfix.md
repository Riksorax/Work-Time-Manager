# /auto-bugfix — Offene bug-Issues automatisch analysieren und als PR vorbereiten

Läuft ohne Rückfragen an einen Menschen (Cron-Routine). Kein `$ARGUMENTS` — bearbeitet alle
offenen Issues mit Label `bug`, die noch nicht angefasst wurden.

Diese Automatisierung **mergt nichts selbst** — sie geht bis zum offenen, review-fertigen PR
und bleibt dort stehen wie bei jedem anderen Issue auch. Der Merge in den Integrationsbranch
bleibt ein menschlicher Schritt. **Ausnahme:** Issues aus automatisiertem Fehler-Monitoring
(Crash-/Error-Tracking, Uptime-Überwachung — siehe Schritt 4) laufen als Hotfix gegen den
Produktionsbranch; dort kann der Merge automatisiert werden, wenn das Projekt das vorsieht.

> Repo, Integrationsbranch, Produktionsbranch und Checks stehen in der Root-`CLAUDE.md`.

## Ablauf

1. **Kandidaten finden:** `list_issues` (state: open, labels: ["bug"]) für das Repo.
2. **Bereits in Arbeit?** Für jedes Issue `issue_read get_comments` prüfen. Enthält ein Kommentar
   den Marker `<!-- auto-bugfix:started -->`, überspringen (schon einmal angefasst — bei Bedarf hat
   ein Mensch den Marker-Kommentar gelöscht, um einen Neuversuch zu erzwingen).
3. **Markieren:** Sofort einen Kommentar mit `<!-- auto-bugfix:started -->` plus kurzer
   Ankündigung posten, um Doppelverarbeitung durch einen parallelen Lauf zu vermeiden.
4. **Monitoring-Issue erkennen:** Issue-Body auf das projektspezifische Erkennungsmerkmal prüfen
   (z. B. ein Marker-Kommentar, den eine Monitoring-Brücke beim Anlegen setzt, oder ein Link ins
   Fehler-Tracking-Tool — siehe Root-`CLAUDE.md`, Abschnitt „Fehler-Monitoring“). Trifft es zu →
   **Hotfix-Pfad** (Schritt 5a). Sonst **Normalpfad** (Schritt 5b).
5. **Einordnen & umsetzen wie `/issue <nr>`:** Plattform bestimmen, passenden Workflow starten
   (`/analysieren`, `/umsetzen` mit der Plattform, oder direkt bei CI/Infra).
   - Ist die Ursache unklar, das Issue widersprüchlich, die Reproduktion nicht nachvollziehbar,
     oder betrifft der Fix mehrere Plattformen (Vertragsänderung) → **nicht umsetzen**.
     Stattdessen Kommentar im Issue mit der Einschätzung/den offenen Fragen hinterlassen und mit
     dem nächsten Issue weitermachen. Das gilt auch für Monitoring-Issues — ein Hotfix über
     mehrere Plattformen hinweg läuft nicht automatisch.
   - Rückfragen, die `/issue` normalerweise an den Nutzer zurückgibt, ansonsten konservativ im
     Sinne des Issues selbst entscheiden, nicht den Scope erweitern.

   **5a. Hotfix-Pfad (Monitoring-Issue, eine Plattform):** Branch vom Produktionsbranch statt vom
   Integrationsbranch. Je Plattform, wie in der Root-`CLAUDE.md` festgelegt:
   - **Deploy ohne Store-/Release-Freigabe** (z. B. Server, Web — ein Push auf den Produktionsbranch
     deployt direkt): PR gegen den Produktionsbranch, nach grüner CI Auto-Merge setzen
     (`enable_pr_auto_merge`), danach den Produktionsbranch zurück in den Integrationsbranch mergen.
   - **Deploy mit Store-/Release-Freigabe** (z. B. App-Stores — braucht Versions-Bump, Tracks,
     ggf. Review durch die Store-Plattform): PR gegen den Produktionsbranch vorbereiten, aber
     **kein** Auto-Merge; im PR und im Issue vermerken, dass ein Mensch den Hotfix über `/release`
     abschließen muss.

   **5b. Normalpfad (normales Issue, kein Monitoring-Treffer):** Branch vom Integrationsbranch,
   PR dagegen wie bisher, Merge bleibt menschlicher Schritt.
6. **Validieren** mit den Checks aus der Root-`CLAUDE.md`-Tabelle für die jeweilige Plattform —
   müssen grün sein, bevor ein PR entsteht.
7. **PR erstellen** (Konvention aus `CONTRIBUTING.md` bzw. Root-`CLAUDE.md`, inkl. `Closes #<issue>`-Zeile;
   Zielbranch wie in 5a/5b festgelegt) und Review durch den passenden Reviewer-Agenten
   (`reviewer`; Plattform-Checkliste aus dem Playbook) durchführen;
   🔴-Funde vor dem Öffnen des PRs beheben.
   Die PR-Beschreibung enthält die Zeile `<!-- created-by: auto-bugfix -->` (Erkennungsmerkmal
   für Benachrichtigungs-Workflows, falls das Projekt einen hat) sowie, im Hotfix-Pfad, einen
   kurzen Hinweis, dass es sich um einen Hotfix gegen den Produktionsbranch handelt.
8. **PR-Aktivität abonnieren** (`subscribe_pr_activity`), damit spätere CI-Fehler oder
   Review-Kommentare automatisch bearbeitet werden. Im Normalpfad und beim Hotfix mit
   Store-Freigabe bleibt der PR bis zum menschlichen Merge offen; beim automatisierten
   Hotfix-Merge übernimmt das bereits gesetzte Auto-Merge den Merge selbst, sobald CI grün ist.
9. **Nächstes Issue.** Nach allen Kandidaten: kurze Zusammenfassung (PR erstellt — normal oder
   Hotfix —, zurückgestellt mit Begründung) als Ergebnis der Routine.

## Sperrliste (nie automatisch umsetzen, nur kommentieren)

Authentifizierung/Rechte/Sicherheit, Zahlungs- und Abrechnungslogik, Datenbank-Migrationen und
alles, was Nutzerdaten ändert oder löscht, datenschutzrelevante Verarbeitung, CI-Konfiguration,
Secrets, Infrastruktur und Bereiche ohne Testabdeckung. Ergänzungen pro Projekt in der
Root-`CLAUDE.md`.
