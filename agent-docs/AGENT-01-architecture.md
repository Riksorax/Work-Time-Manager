# Architect Report — Angular Web Version

## Tech Stack
- **Framework**: Angular 21 (Standalone Components)
- **UI**: Angular Material 3
- **State**: Angular Signals
- **Backend**: Firebase JS SDK v10 (Auth, Firestore, Messaging, App Check)
- **i18n**: @ngx-translate
- **Premium**: @revenuecat/purchases-js

## Projektstruktur
Die Struktur folgt einer Feature-basierten Architektur:
- `core/`: Singleton-Dienste (Auth, Firebase)
- `shared/`: Komponenten, Pipes, Models für die gesamte App
- `features/`: Lazy-loaded Feature-Module (Time-Tracking, Reports, etc.)
- `layout/`: App-Shell und Navigations-Komponenten

## Naming Conventions
- Komponenten: `feature.component.ts`
- Services: `feature.service.ts`
- Models: `index.ts` (Barrel Export)
- Pipes: `name.pipe.ts`

## Routing
Zentrales Routing in `app.routes.ts` mit Lazy Loading für alle Features.

## Styling
Globales Material Theme in `src/styles/theme.scss` mit Dark Mode Unterstützung via `.dark-theme` Klasse.
