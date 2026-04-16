# Agent 10 — Testing

## Rolle
Du schreibst alle fehlenden Tests und stellst sicher dass die Coverage-Ziele erreicht werden. Du schreibst keine neuen Features — du testest nur was die anderen Agents implementiert haben.

## Input
- Alle Outputs von Agents 02–09
- `AGENT-00-flutter-analysis-report.md` (Berechnungsformeln als Ground Truth)

## Coverage-Ziele

| Schicht | Ziel |
|---|---|
| Business-Logik (util.ts) | > 90% |
| Services | > 75% |
| Guards | > 90% |
| Components | > 60% |
| Gesamt | > 70% |

## Test-Prioritäten

### Priorität 1: Business-Logik (Kritischster Pfad)

Datei: `time-calculations.util.spec.ts`

Alle Testfälle müssen die Formeln aus `AGENT-00-flutter-analysis-report.md` validieren:

**calculateNetMinutes:**
```
✅ Normale Session: 9h - 0min Pause = 540min
✅ Mit Pause: 9h - 30min = 510min
✅ Laufende Session (kein endTime): nutzt new Date() → Ergebnis ≈ erwartet ±1min
✅ Pausierte Session: pauseStartTime wird eingerechnet
✅ Kantenfälle: Pause > Bruttozeit → 0 (niemals negativ)
✅ endTime vor startTime → 0 (Dateneingabefehler)
```

**calculateOvertimeMinutes:**
```
✅ Überstunden: 510 - 480 = +30
✅ Unterzeit: 420 - 480 = -60
✅ Exakt Soll: 480 - 480 = 0
```

**formatDuration:**
```
✅ 510 → "8h 30min"
✅ 480 → "8h 00min"
✅ 0   → "0h 00min"
✅ -90 → "-1h 30min"
✅ -1  → "-0h 01min"
✅ 61  → "1h 01min"
```

**startOfWeek:**
```
✅ Mittwoch 17.01.2024 → Montag 15.01.2024
✅ Montag bleibt Montag
✅ Sonntag → Montag der gleichen Woche (nicht der nächsten!)
```

**calculateCategoryBreakdown:**
```
✅ Gruppierung nach Kategorie
✅ Summen korrekt
✅ Prozente summieren sich zu ≈ 100
✅ undefined Kategorie → "Keine Kategorie"
✅ Sortierung: meiste Minuten zuerst
```

### Priorität 2: Service Tests

**work-session.service.spec.ts:**
```typescript
// Setup: Fake Firestore + Mock AuthService
describe('WorkSessionService', () => {
  it('startSession erstellt Session mit isRunning: true')
  it('stopSession setzt endTime und isRunning: false')
  it('pauseSession setzt isPaused: true und pauseStartTime')
  it('resumeSession addiert Pausenzeit zu pauseDuration')
  it('deleteSession wirft sprechende Fehlermeldung bei Firestore-Fehler')  // Bug #108
  it('activeSession$ gibt null zurück wenn keine Session läuft')
})
```

**premium.service.spec.ts:**
```typescript
// Setup: Mock @revenuecat/purchases-js
describe('PremiumService', () => {
  it('isPremium ist false nach initialize ohne Entitlement')
  it('isPremium ist true nach initialize mit aktivem Entitlement')
  it('purchasePackage gibt false zurück bei userCancelled ohne Fehler')
  it('purchasePackage setzt purchaseError bei echtem Fehler')
  it('refreshStatus aktualisiert isPremium Signal')
  it('reset() wird aufgerufen wenn User ausloggt')
})
```

**user-profile.service.spec.ts:**
```typescript
describe('UserProfileService', () => {
  it('ensureProfile legt Profil an wenn noch nicht vorhanden')
  it('ensureProfile überschreibt nicht wenn bereits vorhanden (merge: true)')
  it('updateSettings nutzt Dot-Notation für verschachtelte Felder')
  it('profile Signal aktualisiert sich wenn Firestore-Dokument ändert')
})
```

### Priorität 3: Guard Tests

**auth.guard.spec.ts:**
```typescript
describe('authGuard', () => {
  it('gibt true zurück wenn User eingeloggt')
  it('leitet zu /auth/login weiter wenn nicht eingeloggt')
})
```

**premium.guard.spec.ts:**
```typescript
describe('premiumGuard', () => {
  it('gibt true zurück wenn isPremium() === true')
  it('leitet zu /settings/premium weiter wenn isPremium() === false')
})
```

### Priorität 4: Component Tests

**login.component.spec.ts:**
```typescript
describe('LoginComponent', () => {
  it('Submit-Button ist deaktiviert wenn Formular invalid')
  it('zeigt Fehler bei auth/user-not-found')
  it('zeigt Fehler bei auth/wrong-password')
  it('navigiert zu /dashboard nach erfolgreichen Login')
})
```

**dashboard.component.spec.ts:**
```typescript
describe('DashboardComponent', () => {
  it('zeigt "Kein aktiver Timer" wenn keine activeSession')
  it('zeigt Tages-Summe korrekt formatiert')
  it('Start-Button ruft sessionService.startSession() auf')
})
```

### Priorität 5: Notification Tests

**notification.service.spec.ts:**
```typescript
describe('NotificationService', () => {
  it('msUntilNextTime("08:00") gibt positive Zahl zurück')
  it('msUntilNextTime bei vergangener Uhrzeit gibt Zeit für morgen zurück')
  it('scheduleWorkStartReminder setzt Timer')
  it('cancelReminder löscht Timer')
  it('requestPermission gibt false zurück wenn Permission denied')
})
```

## Test-Setup

### karma.config.js
```javascript
module.exports = function(config) {
  config.set({
    basePath: '',
    frameworks: ['jasmine', '@angular-devkit/build-angular'],
    plugins: [...],
    client: { jasmine: { random: true } },
    coverageReporter: {
      dir: 'coverage/',
      reporters: [
        { type: 'html', subdir: 'report-html' },
        { type: 'lcovonly', subdir: '.', file: 'report-lcov.info' },
        { type: 'text-summary' }
      ]
    },
    reporters: ['progress', 'kjhtml', 'coverage'],
    browsers: ['ChromeHeadless'],
    singleRun: false,
    restartOnFileChange: true,
    coverageItkReporter: { thresholds: { global: { lines: 70 } } }
  });
};
```

### Test-Hilfsfunktionen

Erstelle `src/testing/test-helpers.ts`:
```typescript
// Fake WorkSession erstellen
export function makeSession(overrides: Partial<WorkSession> = {}): WorkSession { ... }

// Fake UserProfile erstellen
export function makeUserProfile(overrides: Partial<UserProfile> = {}): UserProfile { ... }

// Mock AuthService
export function mockAuthService(uid: string = 'test-uid') { ... }
```

## CI-Integration

`package.json` Scripts:
```json
{
  "test": "ng test",
  "test:ci": "ng test --watch=false --browsers=ChromeHeadless --code-coverage",
  "test:coverage": "ng test --watch=false --browsers=ChromeHeadless --code-coverage && open coverage/report-html/index.html"
}
```

GitHub Actions (bereits in `deploy.yml` von Agent 11):
- `npm run test:ci` läuft bei jedem Push und PR
- Coverage-Report als Artifact hochladen
- PR-Check schlägt fehl wenn Coverage < 70%

## Output
- `src/app/features/time-tracking/utils/time-calculations.util.spec.ts`
- `src/app/features/time-tracking/services/work-session.service.spec.ts`
- `src/app/features/premium/services/premium.service.spec.ts`
- `src/app/features/settings/services/user-profile.service.spec.ts`
- `src/app/core/auth/auth.guard.spec.ts`
- `src/app/core/security/premium.guard.spec.ts`
- `src/app/features/auth/components/login/login.component.spec.ts`
- `src/app/features/time-tracking/components/dashboard/dashboard.component.spec.ts`
- `src/app/core/notifications/notification.service.spec.ts`
- `src/testing/test-helpers.ts`
- `karma.config.js` (angepasst)
