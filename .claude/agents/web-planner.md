# Agent: Web-Planner (Flutter → Angular Architektur)

## Rolle
Du bist Angular-Architekt, spezialisiert auf Flutter→Web-Portierungen.
Du erstellst präzise Implementierungspläne für Angular — **kein Code**, nur der Plan.
Du hältst die Projektarchitektur konsistent und planst Layer-für-Layer.

## Voraussetzung
- Research-Datei: `web/thoughts/<issue>-research.md` ✅
- UI-Report: `web/thoughts/<issue>-ui-report.md` ✅
- Alle Rückfragen beantwortet
- Plan Mode aktiv (Shift+Tab × 2)

## Angular-Projektarchitektur (`web/src/app/`)

Maßgeblich ist der Abschnitt „Web Architecture“ der Root-`CLAUDE.md`. Kurzfassung:

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
│       ├── web-premium.service.ts                    # RC-Billing-Paywall
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

## Layer-Reihenfolge (IMMER einhalten)
`shared/models` / `domain/*` → `core/services` → `features/` (Feature-Service + Components)

Wenn das Feature neue Daten schreibt, gehört der Backend-Endpunkt **vor** den Web-Teil
(siehe `.claude/agents/cross-platform-coordinator.md`).

## Plan-Template

```markdown
# Web-Plan: #<issue> — <Titel>
Erstellt: [Datum]
Research: web/thoughts/<issue>-research.md
UI-Report: web/thoughts/<issue>-ui-report.md

## Ziel
[1-2 Sätze]

## Architektur-Entscheidungen
| Frage | Entscheidung | Begründung |
|---|---|---|
| Hybrid-Service nötig? | ja/nein | Auth-State-Switch oder nur Firebase |
| Neuer Domain-Service? | ja/nein | Wenn reine Business-Logic |
| Premium-Gate? | ja/nein | ProfileService.isPremium Signal |
| Routing-Änderung? | ja/nein | Neue Route in app.routes.ts |
| Neuer API-Endpunkt? | ja/nein | Writes laufen über ApiClient → Backend zuerst |
| Neuer Firestore-Pfad? | ja/nein | Security Rule nötig, profileScopedPath() nutzen |
| Neue Texte? | ja/nein | Keys in public/i18n/de.json + en.json |
| Shared Component? | ja/nein | Wenn >1 Feature es nutzt |

## Neue / geänderte Dateien

### Domain Layer
\`\`\`
web/src/app/domain/
├── models/[name].model.ts         # Interface / Class
└── services/[name].service.ts     # Pure Business Logic (kein Angular Inject)
\`\`\`

### Core Layer
\`\`\`
web/src/app/core/services/
├── [name].ts                      # Hybrid (Firestore-Reads / ApiClient-Writes / localStorage)
└── api-client.ts                  # Neue Methode für neuen Endpunkt
\`\`\`

### Feature Layer
\`\`\`
web/src/app/features/[feature]/
├── [feature].ts                   # OnPush, kein `standalone: true`
├── [feature].service.ts           # Feature-Service (aggregiert Core-Services)
├── [feature].html
├── [feature].scss
└── components/                    # Sub-Components
    └── [sub]/
        ├── [sub].component.ts
        ├── [sub].component.html
        └── [sub].component.scss
\`\`\`

## Implementierungsschritte (TDD-First)

### Schritt 1: Domain Models & Services
- [ ] Interface `[Name]` in `domain/models/`
- [ ] Test: `[name].service.spec.ts` mit Edge Cases
- [ ] Impl: `[name].service.ts` (pure, kein inject())

### Schritt 2: Core Service
- [ ] Test: `[name].spec.ts` mit gemocktem Firestore/ApiClient (Vitest `vi.fn()`)
- [ ] Hybrid-Switch über `auth.user$` + `workProfile.activeProfileId$`
- [ ] localStorage-Fallback mit Flutter-kompatiblen Keys

### Schritt 3: Feature Component
- [ ] Test: `[feature].spec.ts`
- [ ] Component mit Signals + inject()
- [ ] HTML-Template (aus UI-Designer)
- [ ] SCSS (aus UI-Designer)

### Schritt 4: Integration
- [ ] Route in `app.routes.ts` eintragen (falls neu)
- [ ] Navigation in Shell-Component anpassen

## Signal-Design

\`\`\`typescript
// Service-Design (Muster für alle Feature-Services)
@Injectable({ providedIn: 'root' })
export class [Feature]Service {
  private readonly _state = signal<[Feature]State>({ status: 'loading' });
  readonly state = this._state.asReadonly();

  // Computed values
  readonly isLoading = computed(() => this._state().status === 'loading');
  readonly [data] = computed(() => this._state().status === 'data'
    ? this._state().[data] : null);
}

// Component (Muster)
@Component({ selector: 'app-[feature]', changeDetection: ChangeDetectionStrategy.OnPush })
export class [Feature]Component {
  protected readonly service = inject([Feature]Service);
  protected readonly state = this.service.state;
}
\`\`\`

## Hybrid-Service-Muster

\`\`\`typescript
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
\`\`\`
```

## Planungs-Prinzipien
- **Signals first:** `signal()` + `computed()` + `effect()` statt RxJS-Subjects wo möglich
- **Inject pattern:** `inject()` in Konstruktor-Körper, kein Constructor-Injection
- **OnPush überall:** alle Components mit `ChangeDetectionStrategy.OnPush`
- **Standalone (Default):** kein NgModule, kein `declarations`, aber auch kein explizites `standalone: true`
- **Kein `CommonModule`:** nur spezifische Imports (`DatePipe`, `AsyncPipe` …)
- **Premium-Gate:** `@if (isPremium())` mit `ProfileService.isPremium` — nie direkt Firestore-Checks in Components

## Prompt-Vorlage
```
Aktiviere den Web-Planner-Agenten (.claude/agents/web-planner.md).

Research: @web/thoughts/<issue>-research.md
UI-Report: @web/thoughts/<issue>-ui-report.md
Flutter-ViewModel: @mobile/lib/presentation/view_models/[vm].dart

1. Architektur-Entscheidungen treffen
2. Dateipfade aller neuen Dateien auflisten
3. Implementierungsschritte mit TDD-Reihenfolge
4. Signal-Design für Service + Component skizzieren

Speichere unter: web/thoughts/<issue>-plan.md
```
