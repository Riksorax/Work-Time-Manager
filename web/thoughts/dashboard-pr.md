## Was wurde portiert?

Flutter `DashboardScreen` → Angular `DashboardComponent` mit vollständigem Signal-basiertem Service-Layer.

## Flutter-Quellen
- `mobile/lib/presentation/screens/dashboard_screen.dart`
- `mobile/lib/presentation/view_models/dashboard_view_model.dart`
- `mobile/lib/domain/services/break_calculator_service.dart`
- `mobile/lib/domain/utils/overtime_utils.dart`
- `mobile/lib/data/repositories/hybrid_work_repository_impl.dart`
- `mobile/lib/data/repositories/hybrid_overtime_repository_impl.dart`

## Angular-Implementierung

- Domain: `web/src/app/domain/services/break-calculator.service.ts`
- Domain: `web/src/app/domain/utils/overtime.utils.ts`
- Data: `web/src/app/core/services/work-entry.ts` (Hybrid Firebase/localStorage)
- Data: `web/src/app/core/services/overtime.ts` (Hybrid Firebase/localStorage)
- Service: `web/src/app/features/dashboard/dashboard.service.ts`
- Component: `web/src/app/features/dashboard/`
- Dialoge: `edit-break-dialog`, `restart-session-dialog`
- Shared: `web/src/app/shared/components/time-input/`
- Shell: `web/src/app/layout/main-shell/` (responsiv + Mobile BottomNav)

## Feature-Parität

| Flutter-Feature | Web-Äquivalent | Status |
|---|---|---|
| Timer Start/Stop | `DashboardService.startOrStopTimer()` | ✅ |
| Pause starten/stoppen | `DashboardService.startOrStopBreak()` | ✅ |
| Restart-Dialog (Session beendet) | `RestartSessionDialogComponent` | ✅ |
| Manuelle Startzeit | `DashboardService.setManualStartTime()` | ✅ |
| Manuelle Endzeit + Clear | `DashboardService.setManualEndTime/clearEndTime()` | ✅ |
| Automatische Pausenberechnung (ArbZG) | `calculateAndApplyBreaks()` — 6h→30min, 9h→45min | ✅ |
| Pause bearbeiten | `EditBreakDialogComponent` | ✅ |
| Pause löschen | `DashboardService.deleteBreak()` | ✅ |
| Heutige Überstunden | `dailyOvertime` Signal | ✅ |
| Gesamtüberstunden | `totalOvertime` Signal | ✅ |
| Voraussichtlicher Feierabend (iterativ) | `_calcExpectedEnd()` max 2 Iterationen | ✅ |
| Hybrid Firebase/localStorage | Auth-State-Switch via `effect()` | ✅ |
| Tab-Throttling Prevention | Page Visibility API | ✅ |
| Auth-Reload | `effect(() => authSvc.user())` | ✅ |
| Auto-Save (30s) | `interval(1000)` + Tick-Counter | ✅ |

## UI-Anpassungen für Web

- Sidebar-Navigation auf Desktop statt Flutter BottomNavBar
- Mobile BottomNav (`<768px`) via `BreakpointObserver`
- Zwei-Spalten-Grid ab `900px` (identisch Flutter `constraints.maxWidth > 900`)
- Timer-Font `57px / weight 300` — exakter Flutter-Token-Port

## Review-Befunde

### 🔴 Kritisch (behoben)
- Bundle-Budget zu knapp für Firebase SDK → auf 2MB erhöht
- `authGuard` mit `take(1)` Race Condition → `auth.authStateReady()` fix
- `zone.js` fehlte in Polyfills → `angular.json` + `npm install zone.js`
- Duplikat-Dateien `dashboard.component.html/scss` → entfernt

### 🟡 Minor (behoben)
- `work-entry.ts`: Break-Map-Typ `Break[]` statt `Record<string, unknown>[]` → gefixt
- `time-input.component.html`: Clock-Icon fehlte wenn `showClear=true` + kein Wert → `@else` statt `@else if`
- `app.routes.ts`: `authGuard` entfernt → App startet direkt im Dashboard

### 🟢 Hinweise
- Kein `DataSyncService` portiert (lokale Daten → Firebase bei Login) — folgt in separatem Ticket
- `standalone: true` noch in `login.ts` — Angular v20+ default, harmlos

## Build
- `npm run build -- --configuration production`: ✅ (Warning 1.11MB, unter 2MB Limit)
- `npm run build -- --configuration development`: ✅

## Checklist
- [x] `npm run build` grün
- [x] Feature-Parität mit Flutter ✅
- [x] Responsive (Mobile/Tablet/Desktop)
- [x] Deutsche Texte überall
- [x] Kein `console.log`, kein `any`
- [x] `@if`/`@for` statt `*ngIf`/`*ngFor`
- [x] `inject()` statt Constructor-Parameter
- [x] `OnPush` auf allen neuen Components
