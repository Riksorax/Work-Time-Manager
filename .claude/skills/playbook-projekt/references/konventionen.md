# Work-Time-Manager — Konventionen, PR und Hotfix

- **Repo:** `Riksorax/Work-Time-Manager`. Integrationsbranch `develop`, PRs gegen `develop` (Squash), Release-PRs gegen `main` (Merge-Commit).
  Details: `CONTRIBUTING.md`.
- **Branches:** `feature/<issue>-<kurz>`, `fix/<issue>-<kurz>`; ist in der Session einer vorgegeben (`claude/...`), diesen verwenden.
- **Commits:** `feat|fix(mobile|web|api): Kurzbeschreibung auf Deutsch (#123)`; im Body `Schließt #123.` **und** `Closes #123`
  (nur das englische Schlüsselwort schließt das Issue beim Merge).
- **PR-Beschreibung:** nach `.github/pull_request_template.md`; Checkliste: Premium-Gate, Arbeitszeit-Profile (`profileId`),
  Rechenlogik wie Backend, Texte de + en (ARB bzw. `public/i18n/*.json`), `CLAUDE.md`-Doku.
  Bei UI- oder UX-Änderungen gehören Screenshots dazu (`entscheidungen.md`, „Oberfläche“).
- **`/issue`-Einordnung zusätzlich:** Premium-Feature? Arbeitszeit-Profil-bezogen? Neue Texte? Neuer Firestore-Pfad?
  Plattformen: `server/`, `web/`, `mobile/`, CI/Infra (`.github/`, `server/docker-compose.yml`).
- **iOS:** `mobile/` hat kein iOS-Projekt, die App erscheint nur für Android. iOS-Arbeit (Projekt anlegen, WidgetKit, Siri, Keychain)
  liegt gesammelt im Backlog-Issue #484 und wird **nur nach ausdrücklicher Freigabe durch den Repo-Inhaber** begonnen: nicht einplanen,
  nicht als Teil anderer Issues mit umsetzen, nicht von `/auto-bugfix` anfassen. Nennt ein Issue iOS als Plattform, gilt nur der Android-Teil.
- **`/auto-bugfix`:** Produktionsbranch ist `main`. Crash-Issues (Marker `auto-monitoring:crashlytics|uptime-kuma` oder Sentry-Link) laufen als
  Hotfix gegen `main`: Web/API mit Auto-Merge, Mobile ohne (Play-Store-Release braucht Versions-Bump und Track; `/release` hängt den
  PR später auf den Release-Branch `release/v<Patch>-<Charakter>` um, der von `main` abzweigt). Die vollständigen Regeln
  stehen in der Root-`CLAUDE.md`, Abschnitt „Fehler-Monitoring“. Die PR-Beschreibung enthält `<!-- created-by: auto-bugfix -->` (löst die
  Discord-Benachrichtigung in `.github/workflows/notify-review-needed.yml` aus).
