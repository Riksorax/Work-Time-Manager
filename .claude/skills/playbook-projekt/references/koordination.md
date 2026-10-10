# Work-Time-Manager — Mehrplattform-Issues

WTM-Besonderheiten zum `cross-platform-coordinator`.

- Beispiele aus der Historie: Arbeitstage Mo–So (#217 → #229 Mobile, #230 Web, #231 API), Arbeitszeit-Profile (#138 → #239 API, #244 Web).
- Vertrag: Firestore-Pfad und Felder (Flutter-kanonisches Format, Root-`CLAUDE.md`), API-Endpunkt und DTO (additiv), Arbeitszeit-Profil-Bezug
  (`profileId`), Rechenregel (Backend kanonisch), Security Rule in `web/firestore.rules`.
- Reihenfolge: Backend → Web (nutzt den Endpunkt über `ApiClient`) → Mobile (nutzt `ApiDataSource`). PRs gegen `develop`.
- Paritätstabelle zusätzliche Zeilen: Premium-Gate (Web `ProfileService.isPremium`, Mobile `isPremiumProvider`), Texte de + en
  (`public/i18n/*.json`, `lib/l10n/*.arb`), Arbeitszeit-Profile.
- Deploy-Hinweise sammeln für `/release`: manuelles Firestore-Rules-Deploy, neue Secrets, Migrationshinweise.
