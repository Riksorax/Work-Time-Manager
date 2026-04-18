import { Injectable, inject, signal, effect } from '@angular/core';
import { AuthService } from '../../../core/auth/auth.service';
import { environment } from '../../../../environments/environment';
import { Purchases, CustomerInfo } from '@revenuecat/purchases-js';
import { UserProfileService } from '../../settings/services/user-profile.service';
import { User } from '@angular/fire/auth';
import { Observable } from 'rxjs';

@Injectable({
  providedIn: 'root'
})
export class PremiumService {
  private auth = inject(AuthService);
  private userProfile = inject(UserProfileService);

  readonly isPremium = signal(false);
  readonly premiumExpiresAt = signal<Date | null>(null);
  readonly currentOffering = signal<any | null>(null);
  readonly isInitialized = signal(false);
  readonly purchaseState = signal<'idle' | 'loading' | 'success' | 'error'>('idle');
  readonly purchaseError = signal<string | null>(null);

  constructor() {
    effect(async () => {
      const uid = this.auth.uid() as string | null;
      if (uid) {
        await this.initialize(uid);
      } else {
        this.reset();
      }
    });
  }

  async initialize(userId: string): Promise<void> {
    try {
      if (environment.revenueCatWebBillingKey === 'YOUR_REVENUECAT_KEY') {
        this.isInitialized.set(true);
        return;
      }

      await (Purchases as any).configure({ 
        apiKey: environment.revenueCatWebBillingKey, 
        appUserId: userId 
      });
      
      await Promise.all([
        this.refreshStatus(),
        this.loadOfferings()
      ]);
      
      this.isInitialized.set(true);
    } catch (error) {
      console.error('Fehler bei RevenueCat Initialisierung:', error);
      this.isInitialized.set(true);
    }
  }

  async refreshStatus(): Promise<void> {
    try {
      const customerInfo = await (Purchases as any).getCustomerInfo() as CustomerInfo;
      const entitlement = customerInfo.entitlements.active['premium'];
      
      const hasPremium = !!entitlement;
      this.isPremium.set(hasPremium);
      
      if (entitlement && entitlement.expirationDate) {
        this.premiumExpiresAt.set(new Date(entitlement.expirationDate));
      } else {
        this.premiumExpiresAt.set(null);
      }
    } catch (error) {
      console.error('Fehler beim Laden des Premium-Status:', error);
    }
  }

  async loadOfferings(): Promise<void> {
    try {
      const offerings = await (Purchases as any).getOfferings();
      if (offerings.current) {
        this.currentOffering.set(offerings.current);
      }
    } catch (error) {
      console.error('Fehler beim Laden der Offerings:', error);
    }
  }

  async purchasePackage(pkg: any): Promise<boolean> {
    this.purchaseState.set('loading');
    this.purchaseError.set(null);
    
    try {
      const user = this.auth.currentUser() as User | null;
      await (Purchases as any).purchase({ 
        rcPackage: pkg, 
        customerEmail: user?.email || undefined 
      });
      
      await this.refreshStatus();
      this.purchaseState.set('success');
      return true;
    } catch (error: any) {
      if (error.userCancelled) {
        this.purchaseState.set('idle');
      } else {
        this.purchaseState.set('error');
        this.purchaseError.set(error.message || 'Kauf fehlgeschlagen');
      }
      return false;
    }
  }

  async restorePurchases(): Promise<void> {
    try {
      await (Purchases as any).restorePurchases();
      await this.refreshStatus();
    } catch (error) {
      console.error('Fehler beim Wiederherstellen der Käufe:', error);
    }
  }

  async openCustomerPortal(): Promise<void> {
    try {
      const url = await (Purchases as any).getManagementURL();
      if (url) {
        window.open(url, '_blank');
      }
    } catch (error) {
      console.error('Fehler beim Öffnen des Customer Portals:', error);
    }
  }

  private reset() {
    this.isPremium.set(false);
    this.premiumExpiresAt.set(null);
    this.currentOffering.set(null);
    this.isInitialized.set(false);
  }
}
