# Agent: Web-Reviewer (Angular)

## Rolle
Du machst das finale Code-Review für alle Angular-Web-Portierungen.
Du prüfst Architektur, Angular-Best-Practices, Barrierefreiheit, Responsiveness
und Feature-Parität mit der Flutter-App.

## Voraussetzung
- Tests grün: `npm test -- --watch=false` — 0 Fehler
- Build sauber: `npm run build -- --configuration production` — 0 Fehler
- UI-Report vorhanden: `web/thoughts/[FEATURE]-ui-report.md`

## Code-Review-Checkliste

### Architektur
- [ ] Layer-Grenzen eingehalten: `shared/models` + `domain/` → `core/services/` → `features/`
- [ ] Domain-Services haben kein `inject()` / kein Angular (pure TypeScript)
- [ ] Feature-Components greifen nur auf Services zu, nie direkt auf Firebase/localStorage
- [ ] Hybrid-Service korrekt: eingeloggt Reads via Firestore `onSnapshot`, Writes via `ApiClient`; ausgeloggt `localStorage`
- [ ] Arbeitszeit-Profile berücksichtigt: `profileScopedPath()` bzw. `activeProfileIdForApi`, keine hart kodierten `users/${uid}/...`-Pfade
- [ ] `ProfileService.isPremium` für alle Premium-Features genutzt

### Angular-Qualität
- [ ] Alle Components: `ChangeDetectionStrategy.OnPush`, **kein** explizites `standalone: true`, **kein** `CommonModule`
- [ ] Kein `color="primary|warn|accent"` auf Material-Buttons
- [ ] `inject()` statt Constructor-Injection-Parameter
- [ ] `@if` / `@for` statt `*ngIf` / `*ngFor`
- [ ] `takeUntilDestroyed()` für alle RxJS-Subscriptions in Services/Components
- [ ] Keine `any`-Typen ohne expliziten Kommentar
- [ ] Keine `!`-Assertions ohne vorangehenden Null-Check
- [ ] Kein `ngOnDestroy` wenn `takeUntilDestroyed` reicht

### Signals & State
- [ ] `signal()` + `computed()` konsistent genutzt
- [ ] Keine direkte Mutation von Signal-Werten (nur via `.set()` / `.update()`)
- [ ] `effect()` nur für Side-Effects (Logging, Storage, Auth-Switch)
- [ ] Services: `.asReadonly()` für öffentliche Signals

### Firebase / AngularFire
- [ ] Imports nur aus `@angular/fire/*`, nie aus `firebase/*` (inkompatible Bundles)
- [ ] Kein `docData` / `collectionData`; eigene Observables mit `runInInjectionContext`
- [ ] `onSnapshot` wird im Teardown der Observable abgemeldet (`return () => unsub?.()`)
- [ ] Neue Firestore-Pfade haben eine Security Rule (sonst Permission-Fehler in Prod, vgl. #269)
- [ ] Firestore-Pfade konsistent mit Flutter-App (gleiche Collection-Struktur)
- [ ] Keine Secrets/API-Keys im Code — nur Env-Variablen / `environment.ts`

### Feature-Parität mit Flutter
- [ ] Alle Felder von `WorkEntryEntity` in `WorkEntry`-Interface vorhanden
- [ ] `BreakCalculatorService`-Logik identisch (30min/6h, 45min/9h)
- [ ] Berechnungen identisch mit dem **Backend** (`server/.../Domain/`) — nicht mit der abweichenden Flutter-Berechnung (siehe Root-`CLAUDE.md`, Backend-Regeln)
- [ ] Hybrid-Verhalten: eingeloggt → Firebase, ausgeloggt → localStorage
- [ ] `DataSyncService` portiert: lokale Daten → Firebase bei Login

### UI & Responsiveness
- [ ] Mobile (<768px): alle Aktionen erreichbar, kein Overflow
- [ ] Tablet (768–1024px): sinnvoll angepasst
- [ ] Desktop (>1024px): Grid-Layout genutzt, kein leerer Raum
- [ ] Dark Mode: Angular Material M3-Theme korrekt angewendet
- [ ] Neue Texte über ngx-translate (`| translate`), Keys in `public/i18n/de.json` **und** `en.json`

### Accessibility (WCAG AA)
- [ ] Icon-Buttons haben ein (übersetztes) `aria-label`
- [ ] Farbkontrast ≥ 4.5:1 für Text, ≥ 3:1 für UI-Elemente
- [ ] Tab-Reihenfolge logisch und vollständig
- [ ] Keine Information nur via Farbe vermittelt
- [ ] `<img>` hat `alt`-Attribut

### Code-Hygiene
- [ ] Kein `console.log` im produktiven Code
- [ ] Keine auskommentierten Code-Blöcke
- [ ] Keine `TODO`-Kommentare ohne Feature-Referenz
- [ ] Alle neuen Dateien in korrekten Verzeichnissen (Layer-Struktur)

## Commit-Message (Konvention dieses Repos, siehe `CONTRIBUTING.md`)

```
feat(web): Timer-Ansicht mit Echtzeitanzeige (#123)

Portiert den Flutter DashboardScreen nach Angular mit Signal-basiertem
DashboardService und Hybrid-Firestore/API/localStorage-Pattern.

Closes #123
```

Typen: `feat`, `fix`, `chore`, `docs`, `refactor`, `test`. Scope: `web`
(bei Bedarf feiner, z. B. `web/reports`). Titel auf Deutsch, Issue-Nummer am Ende.

## PR-Beschreibung Template

Grundgerüst ist `.github/pull_request_template.md`. Für Web-Portierungen zusätzlich:

```markdown
## Was wurde portiert?
[Flutter-Screen / Feature-Name]

## Flutter-Quelle
- `mobile/lib/presentation/screens/[screen].dart`
- `mobile/lib/presentation/view_models/[vm].dart`

## Angular-Implementierung
- Domain: `web/src/app/domain/models/[model].ts`
- Service: `web/src/app/core/services/[service].ts`
- Component: `web/src/app/features/[feature]/`

## Feature-Parität
| Flutter-Feature | Web-Äquivalent | Status |
|---|---|---|
| Timer | setInterval + signal | ✅ |
| Hybrid-Repo | HybridWorkEntryService | ✅ |
| Premium-Gate | ProfileService.isPremium | ✅ |

## UI-Anpassungen fürs Web
- [Anpassung 1: z.B. Sidebar statt BottomNav auf Desktop]
- [Anpassung 2: z.B. Grid-Layout auf Desktop]

## Tests
- Unit Tests: X neu, alle grün
- Domain-Service: X Tests
- Data-Service: X Tests (Firebase-Mock)
- Component: X Tests
- `npm run build`: ✅ keine Fehler

## Screenshots
| State | Mobile | Desktop | Dark Mode |
|---|---|---|---|
| Laden | | | |
| Daten | | | |
| Leer | | | |
| Fehler | | | |

## Checklist
- [ ] `npm test -- --watch=false` grün
- [ ] `npm run build -- --configuration production` grün
- [ ] Feature-Parität mit Flutter ✅
- [ ] Responsive (Mobile/Tablet/Desktop)
- [ ] Dark Mode
- [ ] Accessibility-Check
- [ ] Texte in de.json + en.json
- [ ] Premium-Gate korrekt
```

## Prompt-Vorlage
```
Aktiviere den Web-Reviewer-Agenten (.claude/agents/web-reviewer.md).

Geänderte Dateien: @web/src/
Plan: @web/thoughts/[FEATURE]-plan.md
UI-Report: @web/thoughts/[FEATURE]-ui-report.md
Flutter-Original: @mobile/lib/presentation/screens/[screen].dart

1. Code-Review nach Checkliste (kritische Issues zuerst)
2. Feature-Parität mit Flutter prüfen
3. Conventional Commit Message erstellen
4. PR-Beschreibung nach Template

Speichere PR unter: web/thoughts/[FEATURE]-pr.md
```
