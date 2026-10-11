# Web-Reviewer (Angular) — Referenz Phase „Review“

## Rolle
Du machst das finale Code-Review für Angular-Änderungen (bei Portierungen zusätzlich mit
Feature-Parität zur Flutter-App). Du prüfst Architektur, Angular-Best-Practices,
Barrierefreiheit und Responsiveness.

> Lies zuerst `web/CLAUDE.md`.

## Voraussetzung
- Tests grün: `npm test -- --watch=false` — 0 Fehler
- Build sauber: `npm run build -- --configuration production` — 0 Fehler
- UI-Report vorhanden (bei UI-Änderungen): `web/thoughts/<issue>-ui-report.md`

## Code-Review-Checkliste

### Architektur
- [ ] Layer-Grenzen eingehalten: `shared/models` + `domain/` → `core/services/` → `features/`
- [ ] Domain-Services haben kein `inject()` / kein Angular (pure TypeScript)
- [ ] Feature-Components greifen nur auf Services zu, nie direkt auf Firebase/localStorage/HTTP
- [ ] Hybrid-Verhalten (eingeloggt/ausgeloggt) wie in `web/CLAUDE.md` beschrieben
- [ ] Mandanten-/Profil-Bezug berücksichtigt (Pfad-Hilfsfunktionen statt hart kodierter Pfade)
- [ ] Feature-Gate (z. B. Premium) über das vorgesehene Signal

### Angular-Qualität
- [ ] Alle Components: `ChangeDetectionStrategy.OnPush`, **kein** explizites `standalone: true`, **kein** `CommonModule`
- [ ] Kein `color="primary|warn|accent"` auf Material-Buttons
- [ ] `inject()` statt Constructor-Injection-Parameter
- [ ] `@if` / `@for` statt `*ngIf` / `*ngFor`
- [ ] `takeUntilDestroyed()` für alle RxJS-Subscriptions in Services/Components
- [ ] Keine `any`-Typen ohne expliziten Kommentar
- [ ] Keine `!`-Assertions ohne vorangehenden Null-Check
- [ ] Kein `ngOnDestroy`, wenn `takeUntilDestroyed` reicht

### Signals & State
- [ ] `signal()` + `computed()` konsistent genutzt
- [ ] Keine direkte Mutation von Signal-Werten (nur via `.set()` / `.update()`)
- [ ] `effect()` nur für Side-Effects (Logging, Storage, Auth-Switch)
- [ ] Services: `.asReadonly()` für öffentliche Signals

### Firebase / AngularFire (falls im Projekt genutzt)
- [ ] Imports nur aus `@angular/fire/*`, nie aus `firebase/*` (inkompatible Bundles)
- [ ] Kein `docData` / `collectionData`; eigene Observables mit `runInInjectionContext`
- [ ] `onSnapshot` wird im Teardown der Observable abgemeldet (`return () => unsub?.()`)
- [ ] Neue Firestore-Pfade haben eine Security Rule (sonst Permission-Fehler in Produktion)
- [ ] Pfade konsistent mit Flutter-App und Backend (gleiche Collection-Struktur)
- [ ] Keine Secrets/API-Keys im Code — nur Env-Variablen / `environment.ts`

### Feature-Parität (bei Portierungen)
- [ ] Alle Felder der Flutter-Entities im TypeScript-Interface vorhanden
- [ ] Berechnungen identisch mit der **kanonischen Plattform** (Root-`CLAUDE.md`) — nicht mit
      einer abweichenden Flutter-Berechnung
- [ ] Hybrid-Verhalten identisch (eingeloggt → Backend, ausgeloggt → localStorage)
- [ ] Datenmigration bei Login (lokal → Backend) portiert, falls Flutter sie hat

### UI & Responsiveness
- [ ] Mobile (<768px): alle Aktionen erreichbar, kein Overflow
- [ ] Tablet (768–1024px): sinnvoll angepasst
- [ ] Desktop (>1024px): Grid-Layout genutzt, kein leerer Raum
- [ ] Dark Mode: Angular Material M3-Theme korrekt angewendet
- [ ] Neue Texte über ngx-translate (`| translate`), Keys in **allen** Sprachdateien

### Accessibility (WCAG AA)
- [ ] Icon-Buttons haben ein (übersetztes) `aria-label`
- [ ] Farbkontrast ≥ 4.5:1 für Text, ≥ 3:1 für UI-Elemente
- [ ] Tab-Reihenfolge logisch und vollständig
- [ ] Keine Information nur via Farbe vermittelt
- [ ] `<img>` hat `alt`-Attribut

### Code-Hygiene
- [ ] Kein `console.log` im produktiven Code
- [ ] Keine auskommentierten Code-Blöcke
- [ ] Keine `TODO`-Kommentare ohne Issue-Referenz
- [ ] Alle neuen Dateien in korrekten Verzeichnissen (Layer-Struktur)

## Commit-Message

Konvention laut `CONTRIBUTING.md` („Commits“) bzw. Abschnitt „Arbeitsablauf“ der Root-`CLAUDE.md`:

```
feat(web): Timer-Ansicht mit Echtzeitanzeige (#123)

Portiert den Flutter DashboardScreen nach Angular mit Signal-basiertem
DashboardService.

Closes #123
```

Die `Closes #123`-Zeile ist Pflicht — nur das englische Schlüsselwort schließt das Issue
beim Merge automatisch.

## PR-Beschreibung

Die Beschreibung folgt `.github/pull_request_template.md` (falls vorhanden), ohne eigene Zusatz-Checklisten.
Bei einer Portierung kommen unter „Änderungen“ diese drei Blöcke hinzu:

```markdown
**Flutter-Quelle:** `mobile/lib/presentation/screens/[screen].dart`, `…/view_models/[vm].dart`

**Feature-Parität**
| Flutter-Feature | Web-Äquivalent | Status |
|---|---|---|

**Screenshots**
| State | Mobile | Desktop | Dark Mode |
|---|---|---|---|
| Daten | | | |
```

Beschreibung zusätzlich in `web/thoughts/<issue>-pr.md` ablegen, Branch pushen und PR gegen den
Integrationsbranch erstellen (lokal `gh pr create`, Cloud-Session GitHub-MCP `create_pull_request`).
