# Work-Time-Manager — Konventionen, PR und Hotfix

- **Repo:** `Riksorax/Work-Time-Manager`. Integrationsbranch `develop`, PRs gegen `develop` (Squash), Release-PRs gegen `main` (Merge-Commit).
  Details: `CONTRIBUTING.md`.
- **Branches:** `feature/<issue>-<kurz>`, `fix/<issue>-<kurz>`; ist in der Session einer vorgegeben (`claude/...`), diesen verwenden.
- **Commits:** `feat|fix(mobile|web|api): Kurzbeschreibung auf Deutsch (#123)`; im Body `Schließt #123.` **und** `Closes #123`
  (nur das englische Schlüsselwort schließt das Issue beim Merge).
- **PR-Beschreibung:** nach `.github/pull_request_template.md`; Checkliste: Premium-Gate, Arbeitszeit-Profile (`profileId`),
  Rechenlogik wie Backend, Texte de + en (ARB bzw. `public/i18n/*.json`), `CLAUDE.md`-Doku.
- **`/issue`-Einordnung zusätzlich:** Premium-Feature? Arbeitszeit-Profil-bezogen? Neue Texte? Neuer Firestore-Pfad?
  Plattformen: `server/`, `web/`, `mobile/`, CI/Infra (`.github/`, `server/docker-compose.yml`).
- **`/auto-bugfix`:** Produktionsbranch ist `main`. Crash-Issues (Marker `auto-monitoring:crashlytics|uptime-kuma` oder Sentry-Link) laufen als
  Hotfix gegen `main`: Web/API mit Auto-Merge, Mobile ohne (Play-Store-Release braucht Versions-Bump und Track). Die vollständigen Regeln
  stehen in der Root-`CLAUDE.md`, Abschnitt „Fehler-Monitoring“. Die PR-Beschreibung enthält `<!-- created-by: auto-bugfix -->` (löst die
  Discord-Benachrichtigung in `.github/workflows/notify-review-needed.yml` aus).
