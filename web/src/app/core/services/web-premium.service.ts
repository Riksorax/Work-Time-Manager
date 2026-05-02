import { Injectable, Injector, inject, runInInjectionContext, signal } from '@angular/core';
import { Firestore, doc, setDoc } from '@angular/fire/firestore';
import { Purchases } from '@revenuecat/purchases-js';
import { environment } from '../../../environments/environment';
import { AuthService } from '../auth/auth';

// Entitlement-IDs — identisch zu Flutter (inkl. Tippfehler-Fallback)
const ENTITLEMENT_IDS = [
  'work_time_manager_premium',
  'work_time_manager_premiun',
  'premium',
  'Premium',
];

@Injectable({ providedIn: 'root' })
export class WebPremiumService {
  private readonly auth      = inject(AuthService);
  private readonly firestore = inject(Firestore);
  private readonly injector  = inject(Injector);

  private _purchases: Purchases | null = null;

  readonly isRestoring  = signal(false);
  readonly isPurchasing = signal(false);

  get isConfigured(): boolean {
    return !!environment.rcWebApiKey;
  }

  // Kauf wiederherstellen (für mobile Käufer)
  async restorePurchases(): Promise<boolean> {
    const purchases = this._init();
    if (!purchases) return false;

    this.isRestoring.set(true);
    try {
      const info = await purchases.getCustomerInfo();
      const active = ENTITLEMENT_IDS.some(id => info.entitlements.active[id]?.isActive);
      // Nur auf true setzen, nie downgraden — Downgrade kommt vom mobilen Sync
      if (active) await this._syncToFirestore(true);
      return active;
    } finally {
      this.isRestoring.set(false);
    }
  }

  // Paywall anzeigen (neuer Web-Kauf via RC Billing / Stripe)
  async presentPaywall(): Promise<boolean> {
    const purchases = this._init();
    if (!purchases) throw new Error('RevenueCat ist nicht konfiguriert.');

    this.isPurchasing.set(true);
    try {
      const result = await purchases.presentPaywall({});
      const purchased = ENTITLEMENT_IDS.some(
        id => result?.customerInfo?.entitlements?.active[id]?.isActive,
      );
      if (purchased) await this._syncToFirestore(true);
      return purchased;
    } finally {
      this.isPurchasing.set(false);
    }
  }

  private _init(): Purchases | null {
    if (!environment.rcWebApiKey) return null;
    const uid = this.auth.uid;
    if (!uid) return null;

    if (!this._purchases) {
      this._purchases = Purchases.configure({
        apiKey:    environment.rcWebApiKey,
        appUserId: uid,
      });
    }
    return this._purchases;
  }

  private async _syncToFirestore(isPremium: boolean): Promise<void> {
    const uid = this.auth.uid;
    if (!uid) return;
    const ref = doc(this.firestore, `users/${uid}`);
    await runInInjectionContext(this.injector, () =>
      setDoc(ref, { isPremium }, { merge: true })
    );
  }
}
