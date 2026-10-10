# Work-Time-Manager — Daten, Profile, Rechenlogik

- **Firestore-Datenpfade** (Flutter-kanonisch) stehen in der Root-`CLAUDE.md`. Neue Pfade brauchen eine Regel in `web/firestore.rules`;
  die Rules werden **nicht** automatisch deployt (`CONTRIBUTING.md`, „Deployment“).
- **Hybrid-Layer nie umgehen:** Flutter über `Hybrid*`-Repositories (Firebase/`WorkRepositoryImpl`, `Local*`, `ApiDataSource`), Web über
  `WorkEntryService`/`OvertimeService`/`SettingsService` (Muster in `web.md`).
- **Arbeitszeit-Profile (#138/#239/#244):** Standard-Profil am unveränderten Pfad `users/{uid}/...`, zusätzliche unter
  `users/{uid}/profiles/{profileId}/...`. Web: `profileScopedPath()`, API: `profileId` bzw. `activeProfileIdForApi`; Backend: `ProfileScope`.
- **Rechenlogik:** Das Backend (`server/.../Domain/`) ist kanonisch, Web rechnet identisch, Flutter weicht bekannt ab
  (`server/CLAUDE.md`, „Rechenlogik“). Neue Logik immer an das Backend angleichen.
- **Premium:** `isPremiumProvider` (Flutter) bzw. `ProfileService.isPremium` (Web, Firestore-Flag `users/{uid}.isPremium`).
