# Agent 07 — Premium / RevenueCat Web Billing

## Rolle
Du implementierst das vollständige Premium-System. Nutzer sollen direkt in der Web-App Premium kaufen können (via RevenueCat Web Billing → Stripe). Ein auf Web gekauftes Abo ist automatisch auch in der Flutter-App aktiv — und umgekehrt.

## Input
- `AGENT-00-flutter-analysis-report.md` (Premium-Gates, Entitlement-ID)
- Outputs von Agent 03 (Models: PremiumStatus)
- Outputs von Agent 04 (AuthService: Firebase UID)

## Architektur-Entscheidung: Cross-Platform Entitlements

```
Flutter-App (iOS/Android)          Angular-Web
      │                                  │
      └─── Firebase UID als User-ID ────┘
                     │
              RevenueCat Backend
                     │
         Entitlement "premium"
                     │
         ┌───────────┴──────────────┐
         │ Überall gleichzeitig aktiv │
         └──────────────────────────┘
```

**Implementierung:**
- Flutter: `Purchases.logIn(firebaseUid)` nach Firebase Login
- Angular: `Purchases.configure({ apiKey, appUserId: firebaseUid })`
- Selber `appUserId` → selbe Entitlements → nahtlose Plattformübergreifung

## Voraussetzungen (Setup-Schritte, BEVOR du codierst)

Die folgenden Schritte müssen im RevenueCat Dashboard abgeschlossen sein. Dokumentiere sie in `AGENT-07-revenuecat-setup.md`:

1. **RevenueCat Projekt**: Bestehendes Flutter-Projekt öffnen (oder neues anlegen)
2. **Web Billing App** hinzufügen: Settings → Apps → + → Web Billing
3. **App Name**: "Work-Time-Manager Web"
4. **Default Currency**: EUR
5. **Support Email**: deine E-Mail
6. **Store URLs**: Links zu den nativen Apps (iOS/Android)
7. **Stripe verbinden**: Billing → Payment Processing → Connect Stripe
8. **Produkte anlegen** (im RevenueCat Dashboard, nicht in Stripe direkt):
   - ID: `wtm_premium_monthly_eu` | Dauer: 1 Monat | Preis: z.B. 3,99 €
   - ID: `wtm_premium_yearly_eu` | Dauer: 1 Jahr | Preis: z.B. 29,99 €
9. **Entitlement** anlegen: ID `premium` → beide Produkte zuordnen
10. **Offering** anlegen: ID `default` → beide als Packages
11. **Appearance**: Farben an App-Branding anpassen (Primary Color, Button-Style)
12. **Public Web Billing API Key** kopieren → `environment.revenueCatWebBillingKey`

## Deine Aufgaben

### 7.1 PremiumService

Datei: `src/app/features/premium/services/premium.service.ts`

```typescript
@Injectable({ providedIn: 'root' })
export class PremiumService {
  // ── Signals ──────────────────────────────────────────────
  readonly isPremium     = signal(false)
  readonly premiumExpiresAt = signal<Date | null>(null)
  readonly currentOffering  = signal<PurchasesOffering | null>(null)
  readonly purchaseState    = signal<'idle'|'loading'|'success'|'error'>('idle')
  readonly purchaseError    = signal<string | null>(null)
  readonly isInitialized    = signal(false)

  // ── Init ─────────────────────────────────────────────────
  async initialize(userId: string): Promise<void>
  // Purchases.configure({ apiKey: environment.revenueCatWebBillingKey, appUserId: userId })
  // Danach: refreshStatus() + loadOfferings()

  // ── Status ────────────────────────────────────────────────
  async refreshStatus(): Promise<void>
  // getCustomerInfo() → prüfe active[environment.premiumEntitlementId]
  // isPremium.set(!!entitlement)
  // UserProfileService.updatePremiumStatus() aufrufen (Firestore sync)

  // ── Offerings ─────────────────────────────────────────────
  async loadOfferings(): Promise<void>
  // purchases.getOfferings() → currentOffering.set(offerings.current)

  // ── Kauf ─────────────────────────────────────────────────
  async purchasePackage(pkg: PurchasesPackage): Promise<boolean>
  // purchases.purchase({ rcPackage: pkg, customerEmail: currentUser?.email })
  // RevenueCat öffnet Stripe Payment Sheet automatisch
  // Bei Erfolg: refreshStatus()
  // Bei userCancelled: purchaseState.set('idle'), return false
  // Bei Fehler: purchaseError.set(message), purchaseState.set('error')

  // ── Restore ───────────────────────────────────────────────
  async restorePurchases(): Promise<void>
  // purchases.restorePurchases() → refreshStatus()

  // ── Customer Portal ───────────────────────────────────────
  async openCustomerPortal(): Promise<void>
  // purchases.getManagementURL() → window.open(url, '_blank')
  // Stripe Customer Portal: Abo verwalten, kündigen, Zahlungsmethode ändern
}
```

**effect()** in Constructor: Auf `auth.uid()` reagieren → `initialize()` aufrufen wenn User einloggt, `reset()` wenn ausloggt.

### 7.2 PaywallComponent

Route: `/settings/premium`

**Aufbau (kein PremiumGuard — alle User sehen diese Seite):**

```
┌─────────────────────────────────────────────────────┐
│  🏆  Work-Time-Manager Premium                       │
│      Schalte alle Features frei                      │
├─────────────────────────────────────────────────────┤
│  Was du bekommst:                                    │
│  ✅ Mehrere Arbeitgeber (Multi-Profile)              │
│  ✅ Monatsberichte                                   │
│  ✅ Jahresberichte                                   │
│  ✅ PDF- & CSV-Export                               │
│  ✅ Kategorie-Auswertung                            │
│  ✅ Wochen-Reflexion                                │
├─────────────────────────────────────────────────────┤
│  PLÄNE (aus RevenueCat Offerings laden):             │
│                                                      │
│  ┌── Monatlich ──────┐  ┌── Jährlich ─────────────┐ │
│  │   3,99 €/Monat    │  │  29,99 €/Jahr           │ │
│  │                   │  │  = 2,50 €/Monat         │ │
│  │  [Jetzt kaufen]   │  │  [Jetzt kaufen]  🏷️ -37%│ │
│  └───────────────────┘  └─────────────────────────┘ │
│                                                      │
│  [Käufe wiederherstellen]                            │
├─────────────────────────────────────────────────────┤
│  Falls bereits Premium:                              │
│  🎉 Du hast Premium! Aktiv bis: 31.03.2026          │
│  [Abo verwalten] → Stripe Customer Portal            │
└─────────────────────────────────────────────────────┘
```

- Preise **immer** aus `currentOffering()` laden (nicht hardcoden!)
- Währung und Preis kommen von RevenueCat
- Loading-State während `isInitialized() === false`
- Fehler-Banner wenn `purchaseError()` gesetzt
- Jährliches Paket visuell hervorheben ("Beliebteste Wahl")

### 7.3 PremiumGateComponent (bereits in Agent 03)

Verwendung in Feature-Templates:
```html
@if (premiumService.isPremium()) {
  <!-- Premium-Content -->
  <app-monthly-report />
} @else {
  <app-premium-gate message="Monatsberichte sind ein Premium-Feature." />
}
```

### 7.4 Umgang mit Loading

```html
@if (!premiumService.isInitialized()) {
  <app-loading-spinner message="Premium-Status wird geprüft..." />
} @else if (premiumService.isPremium()) {
  <!-- Premium Content -->
} @else {
  <app-premium-gate />
}
```

## Tests

`premium.service.spec.ts`:
- Mock `@revenuecat/purchases-js`
- `initialize()` setzt `isPremium` korrekt aus `entitlements.active`
- `purchasePackage()` bei `userCancelled` gibt `false` zurück ohne Fehler
- `refreshStatus()` nach Kauf setzt `isPremium = true`

## Output
- `src/app/features/premium/services/premium.service.ts`
- `src/app/features/premium/components/paywall/paywall.component.ts` + `.html` + `.scss`
- `AGENT-07-revenuecat-setup.md` (Setup-Dokumentation)

## Übergabe
`PremiumService.isPremium()` wird von `PremiumGuard` (Agent 02) und allen Feature-Templates direkt als Signal genutzt.
