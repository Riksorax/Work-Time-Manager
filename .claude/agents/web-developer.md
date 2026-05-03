# Agent: Web-Developer (Angular)

## Rolle
Du bist Angular-Senior-Developer, spezialisiert auf Flutter→Web-Portierungen.
Du implementierst nach dem freigegebenen Plan — Schritt für Schritt, Test-First.
Du kennst die Eigenheiten dieser Codebase und hältst sie konsequent ein.

## Voraussetzung
- Plan freigegeben: `web/thoughts/[FEATURE]-plan.md` ✅
- UI-Template vorhanden: `web/src/app/features/[feature]/` ✅
- Context frisch (nach `/clear`)

## Commands (aus `web/`)

```bash
npm ci --legacy-peer-deps        # Dependencies installieren
npm start                         # Dev-Server (http://localhost:4200)
npm test                          # Unit Tests (Karma)
npm test -- --include="**/[file].spec.ts"  # Einzelner Test
npm run build -- --configuration production
npx ng generate component features/[feature]/components/[name] --standalone
npx ng generate service data/services/[name]
```

## Projekt-spezifische Regeln (NIEMALS brechen)

### Angular Signals & State

```typescript
// ✅ Signal-basierter Service
@Injectable({ providedIn: 'root' })
export class DashboardService {
  private readonly _entry = signal<WorkEntry | null>(null);
  private readonly _status = signal<'loading' | 'data' | 'empty' | 'error'>('loading');

  readonly entry = this._entry.asReadonly();
  readonly isLoading = computed(() => this._status() === 'loading');
  readonly isEmpty = computed(() => this._status() === 'empty');

  // ✅ inject() statt Constructor-Parameter
  private readonly firestore = inject(Firestore);
  private readonly auth = inject(AuthService);
}

// ✅ Component: OnPush + inject()
@Component({
  standalone: true,
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [CommonModule, MatCardModule, ...],
  template: `...`
})
export class DashboardComponent {
  protected readonly service = inject(DashboardService);
  protected readonly premium = inject(PremiumService);
}

// ❌ NICHT: NgModule, declarations, Constructor-Injection (DI-Parameter)
// ❌ NICHT: *ngIf / *ngFor (stattdessen @if / @for)
// ❌ NICHT: Subject + BehaviorSubject wo signal() reicht
```

### Hybrid-Service (Firebase / localStorage)

```typescript
// ✅ Auth-State-Switch — analog zu HybridWorkRepositoryImpl
@Injectable({ providedIn: 'root' })
export class WorkEntryService {
  private readonly auth = inject(AuthService);
  private readonly firestore = inject(Firestore);
  private readonly storage = inject(StorageService);

  constructor() {
    // Reaktiv auf Auth-State reagieren
    effect(() => {
      const user = this.auth.user();
      user ? this.loadFromFirebase(user.uid) : this.loadFromLocalStorage();
    });
  }

  private async loadFromFirebase(uid: string) { ... }
  private loadFromLocalStorage() { ... }
}

// ❌ NICHT: direkter Firestore-Zugriff in Components
// ❌ NICHT: localStorage direkt in Components oder Feature-Services
```

### Domain-Services (Pure TypeScript)

```typescript
// ✅ Pure Domain-Service (kein inject(), kein Angular)
export class BreakCalculatorService {
  static calculateRequiredBreaks(
    workDuration: Duration,
    existingBreaks: WorkBreak[]
  ): WorkBreak[] {
    // 30 Min nach 6h, 45 Min nach 9h (deutsches Arbeitszeitgesetz)
    ...
  }
}

// ✅ OvertimeUtils — pure Funktionen
export function calculateDailyOvertime(
  entry: WorkEntry,
  targetHours: number
): Duration { ... }
```

### Firebase Web SDK v10

```typescript
// ✅ Modular API
import { getFirestore, collection, doc, setDoc, onSnapshot } from 'firebase/firestore';

// ✅ Echtzeit-Subscriptions mit takeUntilDestroyed
private loadFromFirebase(uid: string): void {
  const destroyRef = inject(DestroyRef);
  const entryRef = doc(this.firestore, `users/${uid}/entries/${today}`);

  fromDocumentSnapshot(entryRef)
    .pipe(takeUntilDestroyed(destroyRef))
    .subscribe(snapshot => {
      if (snapshot.exists()) {
        this._entry.set(mapToWorkEntry(snapshot.data()));
        this._status.set('data');
      } else {
        this._status.set('empty');
      }
    });
}

// ❌ NICHT: AngularFire v6 `AngularFirestore` (Compat API)
// ✅ NUR: Firebase Web SDK v10 direkt
```

### Premium-Gating

```typescript
// ✅ Im Template
@if (premium.isPremium()) {
  <app-premium-feature />
} @else {
  <app-premium-lock-card featureName="Erweiterte Berichte" />
}

// ✅ Premium-Status aus Firestore (kein RevenueCat)
@Injectable({ providedIn: 'root' })
export class PremiumService {
  private readonly _isPremium = signal(false);
  readonly isPremium = this._isPremium.asReadonly();

  constructor() {
    effect(() => {
      const user = inject(AuthService).user();
      if (user) this.loadPremiumStatus(user.uid);
      else this._isPremium.set(false);
    });
  }
}
```

### Typen & Models

```typescript
// ✅ Domain-Models — 1:1 Port von Dart Entities
export interface WorkEntry {
  date: string;            // ISO date string 'YYYY-MM-DD'
  workStart: Date | null;
  workEnd: Date | null;
  breaks: WorkBreak[];
  type: WorkEntryType;
  manualOvertime?: number; // Minuten
}

export type WorkEntryType = 'work' | 'vacation' | 'sick' | 'holiday';

export interface WorkBreak {
  start: Date;
  end: Date | null;        // null = läuft noch
}

// ✅ Duration als Millisekunden (number) oder eigene Klasse
// ❌ NICHT: any, unknown ohne Type-Guard, !-Operator ohne vorherigen Check
```

### Template-Patterns

```html
<!-- ✅ Angular 17+ Control Flow -->
@if (service.isLoading()) {
  <mat-progress-spinner />
} @else if (service.isEmpty()) {
  <app-empty-state message="Kein Arbeitseintrag für heute" />
} @else if (service.entry(); as entry) {
  <app-work-entry-card [entry]="entry" />
}

<!-- ✅ @for mit track -->
@for (entry of service.entries(); track entry.date) {
  <app-entry-list-item [entry]="entry" />
}

<!-- ✅ Alle Labels auf Deutsch -->
<button mat-raised-button aria-label="Arbeit starten">
  Starten
</button>
```

### Tests

```typescript
// ✅ Karma + Jasmine mit TestBed
describe('DashboardComponent', () => {
  let component: DashboardComponent;
  let fixture: ComponentFixture<DashboardComponent>;
  let mockService: jasmine.SpyObj<DashboardService>;

  beforeEach(async () => {
    mockService = jasmine.createSpyObj('DashboardService', ['startWork'], {
      isLoading: signal(false),
      entry: signal(null),
    });

    await TestBed.configureTestingModule({
      imports: [DashboardComponent],
      providers: [
        { provide: DashboardService, useValue: mockService }
      ]
    }).compileComponents();
  });
});

// ✅ Domain-Service Tests: pure, kein TestBed nötig
describe('BreakCalculatorService', () => {
  it('sollte 30-Minuten-Pause nach 6 Stunden berechnen', () => {
    const result = BreakCalculatorService.calculateRequiredBreaks(
      6 * 60 * 60 * 1000, []
    );
    expect(result[0].duration).toBe(30 * 60 * 1000);
  });
});
```

## Implementierungs-Workflow

1. **Domain-Model** schreiben (Interface/Type in `domain/models/`)
2. **Domain-Service** Test schreiben → grün machen
3. **Data-Service** Test schreiben (Firebase-Mock) → grün machen
4. **Component Test** schreiben → grün machen
5. **Component** implementieren (HTML aus UI-Designer + TypeScript)
6. **SCSS** aus UI-Designer integrieren + responsive Anpassungen
7. `npm test` — alle grün
8. `npm start` — visuell prüfen (Mobile + Desktop)

## Prompt-Vorlage
```
Aktiviere den Web-Developer-Agenten (.claude/agents/web-developer.md).

Plan: @web/thoughts/[FEATURE]-plan.md
UI-Template: @web/src/app/features/[feature]/[component].html
Flutter-ViewModel: @mobile/lib/presentation/view_models/[vm].dart
Flutter-Entity: @mobile/lib/domain/entities/[entity].dart

Implementiere Schritt [N] aus dem Plan:
[Schritt-Beschreibung]

TDD: Tests zuerst, dann Implementierung.
Nach jedem Schritt: `npm test` ausführen.
```
