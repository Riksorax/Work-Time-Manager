import { ChangeDetectionStrategy, Component, input, output } from '@angular/core';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatProgressSpinnerModule } from '@angular/material/progress-spinner';
import { TranslatePipe } from '@ngx-translate/core';

/**
 * Gesperrter Jahresvergleich (#530) im Jahres-Tab: kompakt, ohne unscharfes Beispiel. Angemeldet ohne Premium mit
 * „Premium freischalten“ (nur mit konfiguriertem RC Billing) und „Kauf wiederherstellen“, nicht angemeldet mit
 * „Anmelden“. Reine Darstellung, die Aktionen führt `ReportsComponent` aus.
 */
@Component({
  selector: 'app-yearly-comparison-locked',
  imports: [MatButtonModule, MatIconModule, MatProgressSpinnerModule, TranslatePipe],
  changeDetection: ChangeDetectionStrategy.OnPush,
  host: { class: 'no-print' },
  template: `
    <section class="locked" aria-labelledby="year-compare-locked-title">
      <mat-icon class="locked-icon" aria-hidden="true">{{ loggedIn() ? 'workspace_premium' : 'lock_person' }}</mat-icon>
      <div class="locked-body">
        <h3 id="year-compare-locked-title">{{ 'reports.yearComparePremiumTitle' | translate }}</h3>
        <p>{{ (loggedIn() ? 'reports.yearComparePremiumText' : 'reports.authRequiredYearCompareText') | translate }}</p>
        <div class="locked-actions">
          @if (!loggedIn()) {
            <button mat-stroked-button type="button" (click)="login.emit()">{{ 'reports.loginButton' | translate }}</button>
          } @else {
            @if (canPurchase()) {
              <button mat-flat-button type="button" [disabled]="purchasing()" (click)="unlock.emit()"
                      [attr.aria-label]="'reports.unlockPremiumAria' | translate">
                @if (purchasing()) {
                  <mat-spinner diameter="18" aria-hidden="true" />
                } @else {
                  <mat-icon aria-hidden="true">workspace_premium</mat-icon>
                }
                {{ 'reports.unlockPremiumButton' | translate }}
              </button>
            }
            <button mat-stroked-button type="button" [disabled]="restoring()" (click)="restore.emit()"
                    [attr.aria-label]="'reports.restorePurchaseAria' | translate">
              @if (restoring()) {
                <mat-spinner diameter="18" aria-hidden="true" />
              } @else {
                <mat-icon aria-hidden="true">restore</mat-icon>
              }
              {{ 'reports.restorePurchaseButton' | translate }}
            </button>
          }
        </div>
      </div>
    </section>
  `,
  styles: `
    :host { display: block; }
    .locked {
      display: flex;
      gap: 12px;
      align-items: flex-start;
      padding: 16px 20px;
      border-radius: 16px;
      background: var(--mat-sys-surface-container-low);
    }
    .locked-icon { color: var(--mat-sys-primary); flex: none; }
    .locked-body { display: flex; flex-direction: column; gap: 8px; min-width: 0; }
    h3 { margin: 0; font-size: 1rem; font-weight: 500; }
    p { margin: 0; color: var(--mat-sys-on-surface-variant); }
    .locked-actions { display: flex; flex-wrap: wrap; gap: 8px; }
  `,
})
export class YearlyComparisonLockedComponent {
  readonly loggedIn = input.required<boolean>();
  readonly canPurchase = input(false);
  readonly purchasing = input(false);
  readonly restoring = input(false);

  readonly unlock = output<void>();
  readonly restore = output<void>();
  readonly login = output<void>();
}
