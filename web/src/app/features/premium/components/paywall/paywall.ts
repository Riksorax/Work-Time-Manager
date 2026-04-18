import { Component, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { MatCardModule } from '@angular/material/card';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatListModule } from '@angular/material/list';
import { MatChipsModule } from '@angular/material/chips';
import { MatProgressSpinnerModule } from '@angular/material/progress-spinner';
import { PremiumService } from '../../services/premium.service';
import { LoadingSpinnerComponent } from '../../../../shared/components/loading-spinner/loading-spinner';

@Component({
  selector: 'app-paywall',
  standalone: true,
  imports: [
    CommonModule, 
    MatCardModule, 
    MatButtonModule, 
    MatIconModule, 
    MatListModule, 
    MatChipsModule,
    MatProgressSpinnerModule,
    LoadingSpinnerComponent
  ],
  template: `
    <div class="paywall-container">
      @if (!premiumService.isInitialized()) {
        <app-loading-spinner message="Premium-Status wird geprüft..."></app-loading-spinner>
      } @else {
        <mat-card class="main-card">
          <mat-card-header>
            <div mat-card-avatar class="premium-icon">
              <mat-icon>workspace_premium</mat-icon>
            </div>
            <mat-card-title>Work-Time-Manager Premium</mat-card-title>
            <mat-card-subtitle>Schalte alle Features für maximale Produktivität frei</mat-card-subtitle>
          </mat-card-header>

          <mat-card-content>
            <mat-list>
              <mat-list-item>
                <mat-icon matListItemIcon color="primary">check_circle</mat-icon>
                <div matListItemTitle>Mehrere Arbeitgeber (Multi-Profile)</div>
              </mat-list-item>
              <mat-list-item>
                <mat-icon matListItemIcon color="primary">check_circle</mat-icon>
                <div matListItemTitle>Monats- & Jahresberichte</div>
              </mat-list-item>
              <mat-list-item>
                <mat-icon matListItemIcon color="primary">check_circle</mat-icon>
                <div matListItemTitle>PDF- & CSV-Export</div>
              </mat-list-item>
              <mat-list-item>
                <mat-icon matListItemIcon color="primary">check_circle</mat-icon>
                <div matListItemTitle>Detaillierte Kategorie-Auswertung</div>
              </mat-list-item>
            </mat-list>

            @if (premiumService.isPremium()) {
              <div class="active-subscription">
                <mat-icon color="primary">stars</mat-icon>
                <div class="sub-info">
                  <h3>Du hast Premium!</h3>
                  @if (premiumService.premiumExpiresAt(); as expires) {
                    <p>Aktiv bis: {{ expires | date:'dd.MM.yyyy' }}</p>
                  }
                </div>
                <button mat-stroked-button (click)="premiumService.openCustomerPortal()">
                  Abo verwalten
                </button>
              </div>
            } @else {
              <div class="offerings">
                @if (premiumService.currentOffering(); as offering) {
                  <div class="packages-grid">
                    @for (pkg of offering.availablePackages; track pkg.identifier) {
                      <mat-card class="package-card" [class.highlight]="pkg.packageType === 'ANNUAL'">
                        @if (pkg.packageType === 'ANNUAL') {
                          <div class="badge">Beliebteste Wahl</div>
                        }
                        <mat-card-header>
                          <mat-card-title>{{ pkg.rcBillingProduct.title }}</mat-card-title>
                          <mat-card-subtitle>{{ pkg.rcBillingProduct.priceString }}</mat-card-subtitle>
                        </mat-card-header>
                        <mat-card-actions>
                          <button mat-raised-button color="primary" 
                                  [disabled]="premiumService.purchaseState() === 'loading'"
                                  (click)="premiumService.purchasePackage(pkg)">
                            Jetzt kaufen
                          </button>
                        </mat-card-actions>
                      </mat-card>
                    }
                  </div>
                } @else {
                  <p class="error">Keine Angebote verfügbar. Bitte versuchen Sie es später erneut.</p>
                }
                
                <div class="restore-action">
                  <button mat-button (click)="premiumService.restorePurchases()">
                    Käufe wiederherstellen
                  </button>
                </div>
              </div>
            }

            @if (premiumService.purchaseError(); as error) {
              <div class="purchase-error">
                <mat-icon>error</mat-icon>
                <span>{{ error }}</span>
              </div>
            }
          </mat-card-content>
        </mat-card>
      }
    </div>
  `,
  styles: `
    .paywall-container { display: flex; justify-content: center; padding: 1rem; }
    .main-card { width: 100%; max-width: 600px; }
    .premium-icon { background-color: #ffc107; color: white; display: flex; align-items: center; justify-content: center; border-radius: 50%; }
    .active-subscription { 
      background: rgba(63, 81, 181, 0.05); 
      padding: 1.5rem; 
      border-radius: 8px; 
      display: flex; 
      align-items: center; 
      gap: 1rem;
      margin-top: 2rem;
    }
    .sub-info { flex: 1; }
    .sub-info h3 { margin: 0; }
    .sub-info p { margin: 0; color: rgba(0, 0, 0, 0.6); font-size: 0.9rem; }
    .offerings { margin-top: 2rem; }
    .packages-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; }
    @media (max-width: 480px) { .packages-grid { grid-template-columns: 1fr; } }
    .package-card { position: relative; border: 1px solid rgba(0, 0, 0, 0.1); }
    .package-card.highlight { border: 2px solid #3f51b5; }
    .badge { 
      position: absolute; top: -12px; right: 12px; 
      background: #3f51b5; color: white; 
      padding: 2px 8px; border-radius: 4px; font-size: 10px; font-weight: bold;
    }
    .restore-action { text-align: center; margin-top: 1.5rem; }
    .purchase-error { 
      margin-top: 1rem; padding: 0.5rem; 
      background: #ffebee; color: #f44336; 
      border-radius: 4px; display: flex; align-items: center; gap: 0.5rem; 
    }
    .error { text-align: center; color: #f44336; }
  `
})
export class PaywallComponent {
  premiumService = inject(PremiumService);
}
