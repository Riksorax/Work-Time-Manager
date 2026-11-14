# Work-Time-Manager — Mehrplattform-Issues

WTM-Besonderheiten zum `cross-platform-coordinator`.

- Beispiele aus der Historie: Arbeitstage Mo–So (#217 → #229 Mobile, #230 Web, #231 API), Arbeitszeit-Profile (#138 → #239 API, #244 Web).
- Vertrag: Firestore-Pfad und Felder (Flutter-kanonisches Format, Root-`CLAUDE.md`), API-Endpunkt und DTO (additiv), Arbeitszeit-Profil-Bezug
  (`profileId`), Rechenregel (Backend kanonisch), Security Rule in `web/firestore.rules`.
- Reihenfolge: Backend → Web (nutzt den Endpunkt über `ApiClient`) → Mobile (nutzt `ApiDataSource`). PRs gegen `develop`.
- Paritätstabelle zusätzliche Zeilen: Premium-Gate (Web `ProfileService.isPremium`, Mobile `isPremiumProvider`), Texte de + en
  (`public/i18n/*.json`, `lib/l10n/*.arb`), Arbeitszeit-Profile.
- Deploy-Hinweise sammeln für `/release`: manuelles Firestore-Rules-Deploy, neue Secrets, Migrationshinweise.

## Schaltzentrale (mehrere Issues steuern)

Gilt, wenn die Hauptsession ein Release oder mehrere Issues gleichzeitig steuert (Entscheidung 14.11.2026).

- **Rollen:** Die Hauptsession plant, verteilt und prüft; sie schreibt selbst keinen Feature-Code. Die Arbeit machen die
  Phasen-Agents (`analyst` → `developer` → `reviewer`), bei mehreren Plattformen plant vorher der `cross-platform-coordinator`.
- **Plan:** Ein Plan-Issue je Release (für 1.9: #533) hält Umfang, Reihenfolge, Abhängigkeiten und Überschneidungen. Es wird
  nach jedem gemergten Schritt abgehakt.
- **Ein Schritt = ein Issue-Teil = ein Branch = ein PR gegen `develop`.** Reihenfolge je Issue: Backend → Web → Mobile.
- **Parallel nur, was keine Dateien teilt.** Die Überschneidungen stehen im Plan-Issue; parallele Agents arbeiten in eigenen
  Worktrees. Schritte, die dieselben Dateien anfassen, laufen nacheinander und bauen auf dem gemergten Vorgänger auf.
- **Auftrag an einen Agent:** Issue-Nummer, welcher Teil, Branch, die verbindlichen Entscheidungen und der Vertrag aus dem Issue,
  und was nicht dazugehört. Der Agent liest das Issue selbst; die Hauptsession tippt es nicht ab.
- **Der Vertrag im Issue ist verbindlich.** Trägt er nicht, hält der Agent an und meldet es; die Hauptsession ändert zuerst
  das Issue (mit Begründung), dann geht es weiter.
- **Rückfragen:** Fachliche Entscheidungen (Verhalten, Free/Premium, Umfang, Texte mit Außenwirkung) trifft der Repo-Inhaber.
  Die Hauptsession sammelt sie, gibt eine Empfehlung dazu und lässt alles weiterlaufen, was nicht davon abhängt. Technische
  Detailfragen entscheidet sie selbst und vermerkt sie im Issue.
- **Prüfen vor dem Weitergeben:** Die Hauptsession liest den Diff und das CI-Ergebnis des PR und verlässt sich nicht allein auf
  den Bericht des Agents.
- **Mergen** nur auf ausdrückliche Anweisung des Repo-Inhabers; nach `main` nie ohne sie.
- **Bericht an den Repo-Inhaber:** was fertig ist (mit PR), was läuft, was blockiert ist und welche Entscheidung gebraucht wird.
