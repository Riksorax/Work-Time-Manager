# Work-Time-Manager — Angular (web/)

WTM-Besonderheiten zum Stack-Playbook `playbook-angular`. Wörtlich aus den bisherigen Agent-Dateien übernommen.

## Architektur und Dateinamen (Planung)

## Angular-Projektarchitektur (`web/src/app/`)

Maßgeblich ist `web/CLAUDE.md` (Lies sie zuerst). Kurzfassung:

```
web/src/app/
├── core/
│   ├── auth/            # AuthService (Firebase Auth, Google Sign-In), AuthGuard, Login
│   ├── http/            # authInterceptor (Firebase-ID-Token an ApiClient)
│   └── services/        # Hybrid-Core-Services + Querschnitt
│       ├── work-entry.ts, overtime.ts, settings.ts   # Hybrid: Firestore-Reads / API-Writes / localStorage
│       ├── api-client.ts                             # Typisierter Client für die .NET-API
│       ├── work-profile.ts                           # Aktives Arbeitszeit-Profil (profileId)
│       ├── profile.ts                                # ProfileService.isPremium (Firestore-Flag)
│       ├── web-premium.ts                            # RC-Billing-Paywall
│       ├── data-sync.ts, theme.ts, language.ts
├── domain/
│   ├── models/          # Report-Modelle
│   ├── services/        # Pure Business Logic (BreakCalculator, ReportCalculator)
│   └── utils/           # Pure Funktionen (overtime.utils)
├── features/
│   ├── dashboard/       # DashboardComponent + DashboardService
│   ├── reports/         # ReportsComponent + ReportsService
│   └── settings/        # SettingsComponent + SettingsPageService
├── layout/              # shell, main-shell, sidebar
└── shared/
    ├── components/      # calendar, edit-entry-dialog, time-input, work-profile-switcher
    ├── models/index.ts  # WorkEntry, Break, UserSettings, UserProfile, WorkProfile
    └── utils/           # profileScopedPath, Zeit-Utils
```

## Dateinamen (#301)

Keine Typ-Suffixe (`.component`/`.service`) in Dateinamen — z. B. `dashboard.ts`, `calendar.ts`,
`break-calculator.ts`. Ausnahme: Wenn Component und Service im selben Ordner denselben Basisnamen
hätten (z. B. `features/dashboard/dashboard.ts` und der zugehörige Feature-Service), behält der
Service den Suffix (`dashboard.service.ts`), um die Namenskollision zu vermeiden. Details in
`web/AGENTS.md`.

## Hybrid-Core-Services, Firebase, Premium (Umsetzung)

### Core-Services (Hybrid: Firestore / API / localStorage)

Die Core-Services liegen in `web/src/app/core/services/` (es gibt **kein** `data/services/`).
Sie entscheiden anhand des Auth-States, woher Daten kommen:

| Zustand | Reads | Writes |
|---|---|---|
| eingeloggt | Firestore `onSnapshot` (live) | `ApiClient` → .NET-Backend |
| ausgeloggt | `localStorage` (Flutter-kompatible Keys) | `localStorage` |

```typescript
// ✅ Muster aus core/services/work-entry.ts
getTodayEntry(): Observable<WorkEntry | null> {
  return combineLatest([this.auth.user$, this.workProfile.activeProfileId$]).pipe(
    switchMap(([user, profileId]) =>
      user ? this._firebaseToday(user.uid, profileId) : of(this._localGet(new Date()))),
  );
}

async saveEntry(entry: WorkEntry): Promise<void> {
  if (this.auth.uid) await this.api.saveWorkEntry(entry, this.workProfile.activeProfileIdForApi);
  else               this._localSave(entry);
}

// ❌ NICHT: direkter Firestore-/localStorage-Zugriff in Components oder Feature-Services
// ❌ NICHT: Hybrid-Layer umgehen — immer über WorkEntryService / OvertimeService / SettingsService
```

**Arbeitszeit-Profile (#138/#244):** Firestore-Pfade immer über
`profileScopedPath()` (`shared/utils/work-profile-path.util.ts`) bauen, API-Aufrufe
mit `workProfile.activeProfileIdForApi`. Nie `users/${uid}/...` hart kodieren.

### Firebase / AngularFire (kritisch)

Regeln und Muster stehen in `web/CLAUDE.md` („Firebase / AngularFire“): nur `@angular/fire/*`,
eigene Observables mit `runInInjectionContext` (Vorlage `core/services/profile.ts`), kein
`docData`/`collectionData`. Neue Firestore-Pfade brauchen eine Regel in `web/firestore.rules`
(siehe #269/#270 — fehlende Regel = stiller Permission-Fehler in Produktion).

### Domain-Services

```typescript
// ✅ Pure, kein inject(), keine Angular-Abhängigkeit — web/src/app/domain/
// Berechnungslogik muss mit dem Backend (server/.../Domain/) übereinstimmen,
// NICHT mit der (abweichenden) Flutter-Berechnung — siehe Root-CLAUDE.md „Backend-Regeln“.
export class BreakCalculatorService { ... }   // 30 Min nach 6h, 45 Min nach 9h
```

### Premium-Gating

```typescript
// ✅ ProfileService.isPremium (Firestore-Flag `users/{uid}.isPremium`, kein RevenueCat im Web)
protected readonly isPremium = inject(ProfileService).isPremium;
```
```html
@if (isPremium()) {
  <app-premium-feature />
} @else {
  <!-- Paywall über WebPremiumService (RC Billing) -->
}
```

### Texte / i18n (WTM)

- Die Web-App hat **ngx-translate** (#221). Keys in `web/public/i18n/de.json` + `en.json`.
- **Neue** User-Strings über `{{ 'bereich.key' | translate }}` (`TranslatePipe` importieren)
  und in **beiden** JSON-Dateien ergänzen. Deutsch ist die Referenzsprache.
- Bestehende hart kodierte deutsche Texte sind noch nicht migriert — nur anfassen,
  wenn das Issue es verlangt.
- `aria-label`s ebenfalls übersetzen.

## Hybrid-Service-Muster (Planung)

```typescript
// Entscheidungslogik (analog HybridWorkRepositoryImpl, siehe core/services/work-entry.ts)
getEntries(): Observable<X[]> {
  return combineLatest([this.auth.user$, this.workProfile.activeProfileId$]).pipe(
    switchMap(([user, profileId]) => user ? this._firestore(user.uid, profileId) : of(this._local())),
  );
}
async save(x: X): Promise<void> {
  if (this.auth.uid) await this.api.saveX(x, this.workProfile.activeProfileIdForApi);
  else               this._localSave(x);
}
```

## Flutter→Angular-Mapping (WTM-Zeilen)

| Flutter / Dart | Angular / TypeScript |
|---|---|
| `HybridRepositoryImpl` | Service mit `authState$`-Switch (Firebase/Local) |
| `WorkEntryEntity` | TypeScript Interface / Class in `domain/models/` |
| `BreakCalculatorService` | Pure TypeScript Service in `domain/services/` |
| `isPremiumProvider` | `ProfileService.isPremium` Signal (Firestore-Flag) |
| `SharedPreferences` | `localStorage` in den Hybrid-Core-Services (Flutter-kompatible Keys) |
| `firebase_firestore` | Reads: `@angular/fire/firestore` (`onSnapshot` + `runInInjectionContext`); Writes: `ApiClient` → .NET-Backend |
| `AppLocalizations` / ARB | ngx-translate, Keys in `web/public/i18n/de.json` + `en.json` |
| `activeWorkProfileProvider` | `WorkProfileService` (`activeProfileId$`, `profileScopedPath()`) |

Zusätzliche Analyse-Punkte: Business-Rules (Pflichtpausen, Überstunden-Logik), Firestore-Collections mit Security Rule,
Backend-Endpunkt vorhanden (Writes laufen im Web über `ApiClient`; sonst `/umsetzen <nr> dotnet` zuerst), Gilt das pro
Arbeitszeit-Profil (`profileId`)?, Hybrid-Service nötig? RevenueCat existiert nicht im Web → Premium über Firestore-Flag.

## Review-Ergänzungen (Parität mit Flutter und Backend)

- [ ] Feature-Components greifen nur auf Services zu, nie direkt auf Firebase/localStorage
- [ ] Hybrid-Service korrekt: eingeloggt Reads via Firestore `onSnapshot`, Writes via `ApiClient`; ausgeloggt `localStorage`
- [ ] Arbeitszeit-Profile: `profileScopedPath()` bzw. `activeProfileIdForApi`, keine hart kodierten `users/${uid}/...`-Pfade
- [ ] `ProfileService.isPremium` für alle Premium-Features
- [ ] Neue Firestore-Pfade haben eine Security Rule (sonst Permission-Fehler in Prod, vgl. #269); Pfade konsistent mit Flutter
- [ ] Alle Felder von `WorkEntryEntity` im `WorkEntry`-Interface; `BreakCalculatorService`-Logik identisch (30 min/6 h, 45 min/9 h)
- [ ] Berechnungen identisch mit dem **Backend** (`server/.../Domain/`), nicht mit der abweichenden Flutter-Berechnung (`server/CLAUDE.md`, „Rechenlogik“)
- [ ] Hybrid-Verhalten: eingeloggt → Firebase, ausgeloggt → localStorage; `DataSyncService` portiert (lokale Daten → Firebase bei Login)
- [ ] Neue Texte über ngx-translate, Keys in `public/i18n/de.json` **und** `en.json`
- [ ] PR-Beschreibung bei Portierung: Tabelle „Feature-Parität“ mit Zeile `Premium-Gate | ProfileService.isPremium | ✅`
