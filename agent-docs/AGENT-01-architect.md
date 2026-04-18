# Agent 01 — Architect

## Mission
Erstelle das Grundgerüst der Angular Web-App. Definiere die Ordnerstruktur (Clean Architecture in Angular) und richte die Kern-Technologien ein.

## Aufgaben

### 1. Projekt-Initialisierung
- Setup Angular 18+ im neuen Ordner `web/`.
- Konfiguration von Tailwind CSS oder Angular Material (Präferenz auf Material 3 für App-Feeling).
- Setup von Firebase (Auth, Firestore, Messaging).

### 2. Core-Struktur
Richte folgende Ordner ein:
- `core/`: Singleton Services (AuthService, FirebaseService, Interceptors).
- `shared/`: Komponenten, Pipes und Models, die überall genutzt werden.
- `features/`: Lazy-loaded Module für die Hauptbereiche (Dashboard, Reports, Settings).

### 3. Routing & Guards
- Definition der Routes: `/dashboard`, `/reports`, `/settings`, `/auth`.
- Erstellung von `AuthGuard` zur Absicherung der Routen.

### 4. Datenmodelle (TypeScript Interfaces)
- Überführung der Dart-Entities in TypeScript Interfaces basierend auf dem Report von Agent 00.

## UI-Anpassung
- Planung einer **Sidebar-Navigation** für Desktop.
- Mobile-Responsive Layout mit **Bottom-Navigation** für kleine Browserfenster.

## Security
- Implementierung von **Firebase App Check** (Web).
- Konfiguration von **Content Security Policy (CSP)** Headern.
