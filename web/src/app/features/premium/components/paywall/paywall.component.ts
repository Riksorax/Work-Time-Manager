import { ChangeDetectionStrategy, Component, inject, signal, computed } from '@angular/core';
import { DatePipe } from '@angular/common';
import { MatCardModule } from '@angular/material/card';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatDividerModule } from '@angular/material/divider';
import { MatProgressSpinnerModule } from '@angular/material/progress-spinner';
import { TranslateModule } from '@ngx-translate/core';
import { PremiumService } from '../../services/premium.service';
import { Package } from '@revenuecat/purchases-js';
import { ToastService } from '../../../../shared/components/toast/toast.service';

const FEATURE_ICONS: Record<string, string> = {
  multiProfile: 'work',
  weeklyReflection: 'self_improvement',
  yearlyReport: 'bar_chart',
  pdfExport: 'picture_as_pdf',
  categoryAnalysis: 'donut_large',
};

@Component({
  selector: 'wtm-paywall',
  standalone: true,
  imports: [
    DatePipe,
    MatCardModule,
    MatButtonModule,
    MatIconModule,
    MatDividerModule,
    MatProgressSpinnerModule,
    TranslateModule,
  ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  styles: [`
    :host { display: block; padding: 16px; max-width: 600px; margin: 0 auto; }

    .header {
      text-align: center;
      margin-bottom: 28px;

      mat-icon {
        font-size: 56px;
        width: 56px;
        height: 56px;
        color: var(--wtm-premium-color);
      }

      h1 { margin: 8px 0 4px; font-size: 1.5rem; font-weight: 700; }
      p { margin: 0; color: var(--mat-sys-on-surface-variant); }
    }

    .already-premium {
      text-align: center;
      padding: 24px;

      mat-icon {
        font-size: 56px;
        width: 56px;
        height: 56px;
        color: #2e7d32;
      }

      h2 { margin: 12px 0 4px; }
      p { color: var(--mat-sys-on-surface-variant); margin: 0 0 20px; }
    }

    .features-list {
      margin-bottom: 24px;

      .feature-item {
        display: flex;
        align-items: center;
        gap: 12px;
        padding: 10px 0;

        mat-icon { color: var(--wtm-premium-color); }
        span { font-size: 0.95rem; }
      }
    }

    .packages {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 12px;
      margin-bottom: 20px;
    }

    .package-card {
      cursor: pointer;
      border: 2px solid var(--mat-sys-outline-variant);
      transition: border-color 0.2s, background 0.2s;
      position: relative;

      &.selected {
        border-color: var(--mat-sys-primary);
        background: var(--mat-sys-primary-container);
      }

      mat-card-content {
        text-align: center;
        padding: 16px !important;
      }

      .pkg-period {
        font-size: 0.8rem;
        color: var(--mat-sys-on-surface-variant);
        text-transform: uppercase;
        letter-spacing: 0.5px;
      }

      .pkg-price {
        font-size: 1.75rem;
        font-weight: 700;
        color: var(--mat-sys-primary);
        margin: 4px 0;
      }

      .pkg-per {
        font-size: 0.75rem;
        color: var(--mat-sys-on-surface-variant);
      }

      .badge-save {
        position: absolute;
        top: -10px;
        right: -10px;
        background: var(--wtm-premium-color);
        color: white;
        font-size: 0.7rem;
        font-weight: 700;
        padding: 3px 8px;
        border-radius: 12px;
      }
    }

    .cta {
      display: flex;
      flex-direction: column;
      gap: 8px;

      button { width: 100%; }
    }

    .error-msg {
      color: var(--mat-sys-error);
      font-size: 0.875rem;
      text-align: center;
      margin-top: 8px;
    }
  `],
  template: `
    @if (premium.isPremium()) {
      <mat-card appearance="outlined">
        <mat-card-content class="already-premium">
          <mat-icon>verified</mat-icon>
          <h2>{{ 'premium.alreadyPremium' | translate }}</h2>
          @if (premium.premiumExpiresAt()) {
            <p>{{ 'premium.activeUntil' | translate:{date: premium.premiumExpiresAt() | date:'d. MMMM yyyy'} }}</p>
          }
          <button mat-stroked-button (click)="premium.openCustomerPortal()">
            <mat-icon>manage_accounts</mat-icon>
            {{ 'premium.manageSubscription' | translate }}
          </button>
        </mat-card-content>
      </mat-card>
    } @else {
      <div class="header">
        <mat-icon>workspace_premium</mat-icon>
        <h1>{{ 'premium.title' | translate }}</h1>
        <p>{{ 'premium.subtitle' | translate }}</p>
      </div>

      <mat-card appearance="outlined">
        <mat-card-content>
          <div class="features-list">
            @for (entry of featureEntries; track entry.key) {
              <div class="feature-item">
                <mat-icon>{{ entry.icon }}</mat-icon>
                <span>{{ 'premium.features.' + entry.key | translate }}</span>
              </div>
              <mat-divider />
            }
          </div>

          @if (packages().length > 0) {
            <div class="packages">
              @for (pkg of packages(); track pkg.identifier) {
                <mat-card
                  appearance="outlined"
                  class="package-card"
                  [class.selected]="selectedPackage()?.identifier === pkg.identifier"
                  (click)="selectedPackage.set(pkg)"
                >
                  @if (isYearly(pkg)) {
                    <span class="badge-save">Spare 20%</span>
                  }
                  <mat-card-content>
                    <div class="pkg-period">
                      {{ isYearly(pkg) ? ('premium.yearly' | translate) : ('premium.monthly' | translate) }}
                    </div>
                    <div class="pkg-price">{{ formatPrice(pkg) }}</div>
                    <div class="pkg-per">
                      {{ isYearly(pkg) ? ('premium.perYear' | translate) : ('premium.perMonth' | translate) }}
                    </div>
                  </mat-card-content>
                </mat-card>
              }
            </div>

            <div class="cta">
              <button
                mat-flat-button
                (click)="purchase()"
                [disabled]="!selectedPackage() || premium.purchaseState() === 'loading'"
              >
                @if (premium.purchaseState() === 'loading') {
                  <mat-spinner diameter="18" />
                } @else {
                  <ng-container>
                    <mat-icon>workspace_premium</mat-icon>
                    {{ 'premium.subscribe' | translate }}
                  </ng-container>
                }
              </button>

              <button mat-button (click)="restore()">
                {{ 'premium.restore' | translate }}
              </button>
            </div>

            @if (premium.purchaseError()) {
              <p class="error-msg">{{ premium.purchaseError() }}</p>
            }
          } @else {
            <div style="text-align:center;padding:24px">
              <mat-spinner diameter="32" />
            </div>
          }
        </mat-card-content>
      </mat-card>
    }
  `,
})
export class PaywallComponent {
  protected premium = inject(PremiumService);
  private toast = inject(ToastService);

  readonly selectedPackage = signal<Package | null>(null);
  readonly packages = computed(() => this.premium.currentOffering()?.availablePackages ?? []);

  readonly featureEntries = Object.entries(FEATURE_ICONS).map(([key, icon]) => ({ key, icon }));

  isYearly(pkg: Package): boolean {
    return pkg.identifier.toLowerCase().includes('annual') ||
      pkg.identifier.toLowerCase().includes('yearly') ||
      pkg.identifier.toLowerCase().includes('year');
  }

  formatPrice(pkg: Package): string {
    const price = pkg.rcBillingProduct?.currentPrice;
    if (!price) return '–';
    return price.formattedPrice;
  }

  async purchase(): Promise<void> {
    const pkg = this.selectedPackage();
    if (!pkg) return;
    const success = await this.premium.purchasePackage(pkg);
    if (success) this.toast.success('premium.purchaseSuccess');
  }

  async restore(): Promise<void> {
    await this.premium.restorePurchases();
    if (this.premium.purchaseState() === 'success') {
      this.toast.success('premium.purchaseSuccess');
    }
  }
}
