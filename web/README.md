# Work Time Manager — Web

Angular-Web-App für den [Work Time Manager](../README.md). Portierung der Flutter-App mit identischem Firebase-Backend.

## Quickstart

```bash
npm ci --legacy-peer-deps   # Dependencies installieren
npm start                   # Dev-Server: http://localhost:4200
npm run build -- --configuration production
```

## Features

- **Dashboard** — Timer, Pausen, Tages- & Gesamtüberstunden
- **Berichte** — Täglich / Wöchentlich / Monatlich (Premium-Gate)
- **Einstellungen** — Profil, Arbeitszeit, Gleitzeit, Dark Mode, Cloud-Sync

## Architektur

```
src/app/
├── core/          AuthService, WorkEntryService, OvertimeService,
│                  SettingsService, ProfileService, ThemeService, DataSyncService
├── domain/        Pure TypeScript — ReportCalculatorService, BreakCalculatorService
├── features/      Dashboard · Reports · Settings (je mit eigenem *PageService)
├── layout/        MainShell (Sidenav + Toolbar)
└── shared/        CalendarComponent, EditEntryDialog, TimeInput, Models
```

Vollständige Architektur-Doku: [../CLAUDE.md](../CLAUDE.md)

## Deployment

GitHub Actions deployt automatisch nach Firebase Hosting:
- `main` → Live-Channel (`work-time-manager-riksorax.web.app`)
- `develop` → Build-Check (kein Deploy)
