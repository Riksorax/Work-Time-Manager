// features/premium/services/premium.service.ts
// Agent 7 — Premium / RevenueCat Web Billing
//
// WICHTIG für Setup:
// 1. RevenueCat Dashboard → "Web Billing" Plattform anlegen
// 2. Stripe Account verbinden
// 3. Produkte anlegen (Monatlich + Jährlich)
// 4. Entitlement "premium" anlegen und Produkte zuordnen
// 5. Public Web Billing API Key → environment.revenueCatWebBillingKey
//
// Cross-Platform: Firebase UID als appUserId → gleiche Entitlements auf Mobile + Web

import { Injectable, inject, signal, computed, effect } from '@angular/core';
import { Purchases, CustomerInfo, Offering, Package } from '@revenuecat/purchases-js';
import { environment } from '../../../../environments/environment';
import { AuthService } from '../../../core/auth/auth.service';
import { UserProfileService } from '../../settings/services/user-profile.service';

export type PurchaseState = 'idle' | 'loading' | 'success' | 'error';

@Injectable({ providedIn: 'root' })
export class PremiumService {
  private auth = inject(AuthService);
  private userProfile = inject(UserProfileService);

  // ─── State (Signals) ─────────────────────────────────────────────────────
  readonly isPremium = signal(false);
  readonly premiumExpiresAt = signal<Date | null>(null);
  readonly currentOffering = signal<Offering | null>(null);
  readonly purchaseState = signal<PurchaseState>('idle');
  readonly purchaseError = signal<string | null>(null);
  readonly isInitialized = signal(false);

  private purchases: Purchases | null = null;

  constructor() {
    // RevenueCat initialisieren sobald User eingeloggt ist
    effect(() => {
      const uid = this.auth.uid();
      if (uid) {
        this.initialize(uid);
      } else {
        this.reset();
      }
    }, { allowSignalWrites: true });
  }

  // ─── Initialisierung ──────────────────────────────────────────────────────

  async initialize(userId: string): Promise<void> {
    try {
      // SDK konfigurieren — Firebase UID als appUserId für Cross-Platform Sync
      this.purchases = Purchases.configure({
        apiKey: environment.revenueCatWebBillingKey,
        appUserId: userId,
      });

      await this.refreshStatus();
      await this.loadOfferings();
      this.isInitialized.set(true);
    } catch (err) {
      console.error('[PremiumService] Initialisierung fehlgeschlagen:', err);
    }
  }

  private reset(): void {
    this.isPremium.set(false);
    this.premiumExpiresAt.set(null);
    this.currentOffering.set(null);
    this.isInitialized.set(false);
    this.purchases = null;
  }

  // ─── Status ───────────────────────────────────────────────────────────────

  async refreshStatus(): Promise<void> {
    if (!this.purchases) return;
    try {
      const info: CustomerInfo = await this.purchases.getCustomerInfo();
      const entitlement = info.entitlements.active[environment.premiumEntitlementId];
      const isActive = !!entitlement;

      this.isPremium.set(isActive);
      this.premiumExpiresAt.set(
        entitlement?.expirationDate ? new Date(entitlement.expirationDate) : null
      );

      // Firestore-Profil synchron halten
      await this.userProfile.updatePremiumStatus(isActive, this.premiumExpiresAt());
    } catch (err) {
      console.error('[PremiumService] Status-Refresh fehlgeschlagen:', err);
    }
  }

  // ─── Offerings laden ──────────────────────────────────────────────────────

  async loadOfferings(): Promise<void> {
    if (!this.purchases) return;
    try {
      const offerings = await this.purchases.getOfferings();
      this.currentOffering.set(offerings.current);
    } catch (err) {
      console.error('[PremiumService] Offerings laden fehlgeschlagen:', err);
    }
  }

  // ─── Kauf ─────────────────────────────────────────────────────────────────

  async purchasePackage(pkg: Package): Promise<boolean> {
    if (!this.purchases) return false;

    this.purchaseState.set('loading');
    this.purchaseError.set(null);

    try {
      // RevenueCat öffnet automatisch Stripe Checkout (Payment Sheet)
      // kein eigener Form nötig — Stripe Elements werden vom SDK gerendert
      await this.purchases.purchase({
        rcPackage: pkg,
        customerEmail: this.auth.currentUser()?.email ?? undefined,
      });

      await this.refreshStatus();
      this.purchaseState.set('success');
      return true;
    } catch (err: any) {
      // User hat abgebrochen → kein echter Fehler
      if (err?.userCancelled) {
        this.purchaseState.set('idle');
        return false;
      }
      console.error('[PremiumService] Kauf fehlgeschlagen:', err);
      this.purchaseError.set(err?.message ?? 'Kauf fehlgeschlagen. Bitte erneut versuchen.');
      this.purchaseState.set('error');
      return false;
    }
  }

  // ─── Restore ──────────────────────────────────────────────────────────────

  async restorePurchases(): Promise<void> {
    if (!this.purchases) return;
    this.purchaseState.set('loading');
    try {
      // Web Billing hat kein restorePurchases — Status neu laden genügt
      await this.refreshStatus();
      this.purchaseState.set('success');
    } catch (err: any) {
      this.purchaseError.set(err?.message ?? 'Wiederherstellen fehlgeschlagen.');
      this.purchaseState.set('error');
    }
  }

  // ─── Customer Portal ──────────────────────────────────────────────────────

  async openCustomerPortal(): Promise<void> {
    if (!this.purchases) return;
    try {
      // RevenueCat öffnet das Stripe Customer Portal (Abo verwalten, kündigen, etc.)
      const info: CustomerInfo = await this.purchases.getCustomerInfo();
      if (info.managementURL) {
        window.open(info.managementURL, '_blank');
      }
    } catch (err) {
      console.error('[PremiumService] Customer Portal fehlgeschlagen:', err);
    }
  }
}
